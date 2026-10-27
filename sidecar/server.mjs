import {createServer} from 'node:http';
import {randomBytes,createHash} from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';
import {pathToFileURL} from 'node:url';
import {Leases} from './leases.mjs';
import {PushSender} from './push.mjs';

const hash = value => createHash('sha256').update(value).digest('hex');
const fail = status => Object.assign(new Error('request_failed'),{status});
export function createSidecar({managerUrl,database = ':memory:',push = new PushSender(),fetcher = fetch,now = Date.now,env = process.env} = {}) {
  if (!managerUrl) throw new Error('TRACCAR_MANAGER_URL is required');
  const db = new DatabaseSync(database);
  db.exec(`CREATE TABLE IF NOT EXISTS registrations (
    deviceId INTEGER PRIMARY KEY, userId INTEGER NOT NULL, platform TEXT NOT NULL,
    pushToken TEXT NOT NULL, accessHash TEXT UNIQUE NOT NULL, lastPush INTEGER NOT NULL DEFAULT 0)`);
  db.exec(`CREATE TABLE IF NOT EXISTS device_claims (
    deviceId INTEGER PRIMARY KEY, userId INTEGER NOT NULL, installationHash TEXT NOT NULL)`);
  const leases = new Leases({now});
  const inFlight = new Set();
  const activeKicks = new Map();
  const rate = new Map();
  const debug = env.TRAKKAR_DEUG === '1';
  const diagnostic = (event, fields = {}, level = 'info') => {
    if (debug) console[level](JSON.stringify({event, ...fields}));
  };
  async function traccar(path,cookie) {
    const response = await fetcher(`${managerUrl.replace(/\/$/,'')}/api/${path}`, {
      headers:{Cookie:cookie,Accept:'application/json'},signal:AbortSignal.timeout(10000),redirect:'error',
    });
    if (response.status===401 || response.status===403) throw fail(401);
    if (!response.ok) throw fail(502);
    return response.json();
  }
  async function authenticate(request) {
    const cookie = request.headers['x-traccar-session'];
    if (typeof cookie!=='string' || !/^JSESSIONID=[A-Za-z0-9._-]+$/.test(cookie)) throw fail(401);
    const user = await traccar('session',cookie);
    if (!Number.isSafeInteger(user.id) || user.disabled) throw fail(401);
    const entry=rate.get(user.id) ?? {at:now(),count:0};
    if (now()-entry.at>60000) {entry.at=now();entry.count=0;}
    if (++entry.count>120) throw fail(429);
    if (rate.size>10000) for (const [id,item] of rate) if (now()-item.at>60000) rate.delete(id);
    rate.set(user.id,entry);
    const devices = await traccar('devices',cookie);
    return {user,devices};
  }
  async function body(request) {
    let data='';
    for await (const chunk of request) {data+=chunk;if (data.length>16384) throw fail(413);}
    try {
      const value=JSON.parse(data);
      if (!value || typeof value!=='object' || Array.isArray(value)) throw fail(400);
      return value;
    } catch {throw fail(400);}
  }
  function installationHash(input) {
    if (typeof input.installationToken!=='string' || !/^[A-Za-z0-9_-]{43}$/.test(input.installationToken)) throw fail(400);
    return hash(input.installationToken);
  }
  function claim(deviceId,userId,input,replace = false) {
    const nextHash=installationHash(input);
    const previous=db.prepare('SELECT * FROM device_claims WHERE deviceId=?').get(deviceId);
    if (previous && previous.installationHash!==nextHash && !replace) throw fail(409);
    db.prepare(`INSERT INTO device_claims(deviceId,userId,installationHash) VALUES(?,?,?)
      ON CONFLICT(deviceId) DO UPDATE SET userId=excluded.userId,installationHash=excluded.installationHash`)
      .run(deviceId,userId,nextHash);
    if (replace || !previous || previous.installationHash!==nextHash) {
      // A confirmed transfer revokes the old phone before the new push token is available.
      db.prepare('DELETE FROM registrations WHERE deviceId=?').run(deviceId);
      activeKicks.delete(deviceId);
    }
  }
  async function send(deviceId) {
    const device=db.prepare('SELECT * FROM registrations WHERE deviceId=?').get(deviceId);
    if (!device || inFlight.has(deviceId)) {
      diagnostic('push_skipped', {deviceId, reason: !device ? 'not_registered' : 'in_flight'});
      return;
    }
    const until=leases.until(deviceId);
    if ((activeKicks.get(deviceId) ?? 0)>now()) {
      diagnostic('push_skipped', {deviceId, reason: 'active_session'});
      return;
    }
    const interval=device.platform==='ios' ? 180000 : 15000;
    if (device.lastPush && now()-device.lastPush<interval) {
      diagnostic('push_skipped', {deviceId, reason: 'cooldown'});
      return;
    }
    if (until<=now()) return;
    inFlight.add(deviceId);
    diagnostic('push_attempt', {deviceId, platform: device.platform, expiresAt: until});
    try {
      await push.send(device,until);
      diagnostic('push_accepted', {deviceId, platform: device.platform});
      const updated=db.prepare('UPDATE registrations SET lastPush=? WHERE deviceId=? AND accessHash=?')
        .run(now(),deviceId,device.accessHash);
      if (updated.changes) activeKicks.set(deviceId,leases.until(deviceId));
    } catch (error) {
      // Only a safe error category; never print session cookies or push tokens.
      diagnostic('push_failed', {deviceId, platform: device.platform,
        reason: /^((fcm|apns)_\w+)$/.test(error.message) ? error.message : 'provider_error'}, 'error');
    } finally {
      inFlight.delete(deviceId);
      const current=db.prepare('SELECT accessHash FROM registrations WHERE deviceId=?').get(deviceId);
      if (current && current.accessHash!==device.accessHash) void send(deviceId);
    }
  }
  const server=createServer(async (request,response) => {
    response.setHeader('Content-Type','application/json');
    response.setHeader('Cache-Control','no-store');
    try {
      const path=new URL(request.url,'http://localhost').pathname;
      if (request.method==='GET' && path==='/health') {response.end('{"ok":true}');return;}
      if (path==='/v1/device-session' && request.method==='GET') {
        const token=request.headers.authorization?.replace(/^Bearer /,'');
        if (!token) throw fail(401);
        const device=db.prepare('SELECT * FROM registrations WHERE accessHash=?').get(hash(token));
        if (!device) throw fail(401);
        const until=leases.until(device.deviceId);
        diagnostic('device_session_checked', {deviceId: device.deviceId, active: until>now(), expiresAt: until});
        if (until>now()) activeKicks.set(device.deviceId,until);
        response.end(JSON.stringify({expiresAt:until,serverTime:now()}));return;
      }
      const {user,devices}=await authenticate(request);
      if (path==='/v1/devices/claim' && request.method==='POST') {
        const input=await body(request);
        const device=devices.find(d => d.uniqueId===input.uniqueId);
        if (!device) throw fail(403);
        if (input.replace!==undefined && typeof input.replace!=='boolean') throw fail(400);
        claim(device.id,user.id,input,input.replace===true);
        response.end(JSON.stringify({deviceId:device.id}));return;
      }
      if (path==='/v1/devices' && request.method==='POST') {
        const input=await body(request);
        const device=devices.find(d => d.uniqueId===input.uniqueId);
        if (!device) throw fail(403);
        if (!['android','ios'].includes(input.platform) || typeof input.pushToken!=='string' ||
          input.pushToken.length<16 || input.pushToken.length>4096) throw fail(400);
        claim(device.id,user.id,input);
        const token=randomBytes(32).toString('base64url');
        db.prepare(`INSERT INTO registrations(deviceId,userId,platform,pushToken,accessHash)
          VALUES(?,?,?,?,?) ON CONFLICT(deviceId) DO UPDATE SET userId=excluded.userId,
          platform=excluded.platform,pushToken=excluded.pushToken,accessHash=excluded.accessHash,lastPush=0`)
          .run(device.id,user.id,input.platform,input.pushToken,hash(token));
        response.end(JSON.stringify({deviceId:device.id,deviceToken:token}));
        activeKicks.delete(device.id);
        diagnostic('device_registered', {deviceId: device.id, platform: input.platform});
        void send(device.id);return;
      }
      if (path==='/v1/devices' && request.method==='DELETE') {
        const input=await body(request);
        if (!Number.isSafeInteger(input.deviceId)) throw fail(400);
        if (!devices.some(d => d.id===input.deviceId)) throw fail(403);
        const owner=db.prepare('SELECT * FROM device_claims WHERE deviceId=?').get(input.deviceId);
        if (!owner || owner.installationHash!==installationHash(input)) throw fail(403);
        db.prepare('DELETE FROM registrations WHERE deviceId=?').run(input.deviceId);
        activeKicks.delete(input.deviceId);
        response.end('{}');return;
      }
      const match=path.match(/^\/v1\/views\/([A-Za-z0-9-]{16,80})$/);
      if (match && request.method==='DELETE') {
        leases.release(user.id,match[1]);response.end('{}');return;
      }
      if (match && request.method==='PUT') {
        const input=await body(request);
        if (!Array.isArray(input.deviceIds) || input.deviceIds.length>100 ||
          !input.deviceIds.every(Number.isSafeInteger)) throw fail(400);
        const ids=[...new Set(input.deviceIds)];
        const allowed=new Set(devices.map(d => d.id));
        if (ids.some(id => !allowed.has(id))) throw fail(403);
        leases.renew(user.id,match[1],ids);
        // Coalesced kicks also retry failed pushes on later renewals.
        for (const id of ids) void send(id);
        response.end(JSON.stringify({expiresAt:now()+30000}));return;
      }
      throw fail(404);
    } catch (error) {
      response.statusCode=error.status ?? 503;
      response.end(JSON.stringify({error:response.statusCode}));
    }
  });
  server.on('close',() => db.close());
  return server;
}
if (process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  createSidecar({managerUrl:process.env.TRACCAR_MANAGER_URL,
    database:process.env.DATABASE_PATH ?? '/data/live-tracking.sqlite'})
    .listen(Number(process.env.PORT ?? 8080),'0.0.0.0');
}
