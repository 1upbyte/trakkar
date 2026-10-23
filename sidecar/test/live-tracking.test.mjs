import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {once} from 'node:events';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import {Leases} from '../leases.mjs';
import {createSidecar} from '../server.mjs';

test('leases combine viewers, expire, and replace a changed target list', () => {
  let now=1000;
  const leases=new Leases({now:()=>now});
  assert.deepEqual(leases.renew(1,'view-a',[10]),[10]);
  now+=15000;
  assert.deepEqual(leases.renew(2,'view-b',[10]),[]);
  leases.release(1,'view-a');
  assert.equal(leases.until(10),46000);
  leases.renew(2,'view-b',[11]);
  assert.equal(leases.until(10),0);
  now=46000;
  assert.equal(leases.until(11),0);
});

const installationToken='a'.repeat(43);
const replacementToken='b'.repeat(43);
const registration={uniqueId:'phone',platform:'android',pushToken:'valid-push-token-123',installationToken};

async function fixture(t,{database=':memory:',push} = {}) {
  let now=1000000;
  const pushes=[];
  const server=createSidecar({managerUrl:'http://traccar:8082',database,now:()=>now,
    push:push ?? {send:async(device,until)=>pushes.push({deviceId:device.deviceId,pushToken:device.pushToken,until})},
    fetcher:async(url,options)=> {
      const user=options.headers.Cookie==='JSESSIONID=owner' ? 1 : 2;
      const body=url.endsWith('/session') ? {id:user} : [{id:10,uniqueId:'phone'}, ...(user===1 ? [{id:11,uniqueId:'other'}] : [])];
      return new Response(JSON.stringify(body),{status:200});
    }});
  server.listen(0,'127.0.0.1');
  await once(server,'listening');
  t.after(()=>server.listening ? new Promise(resolve=>server.close(resolve)) : undefined);
  const base=`http://127.0.0.1:${server.address().port}`;
  const call=(path,method='GET',body,user='owner')=>fetch(base+path,{method,
    headers:{'X-Traccar-Session':`JSESSIONID=${user}`,'Content-Type':'application/json'},
    body:body===undefined ? undefined : JSON.stringify(body)});
  return {call,base,pushes,server,advance:ms=>{now+=ms;}};
}

test('registration automatically claims accessible devices without an owner mapping',async t=> {
  const {call}=await fixture(t);
  assert.equal((await call('/v1/devices','POST',{...registration,uniqueId:'other'},'friend')).status,403);
  assert.equal((await call('/v1/devices','POST',registration,'friend')).status,200);
  assert.equal((await call('/v1/devices','POST',{...registration,uniqueId:'other'})).status,200);
});

test('one push starts a session; renewals and overlapping viewers do not repeat it',async t=> {
  const {call,base,pushes,advance}=await fixture(t);
  const registration=await (await call('/v1/devices','POST',{
    uniqueId:'phone',platform:'android',pushToken:'valid-push-token-123',
    installationToken,
  })).json();
  const session=async()=> (await fetch(base+'/v1/device-session',{
    headers:{Authorization:`Bearer ${registration.deviceToken}`},
  })).json();
  const view='/v1/views/abcdefghijklmnop';
  assert.equal((await call(view,'PUT',{deviceIds:[10]})).status,200);
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(pushes.length,1);
  await session();
  advance(15000);
  await call(view,'PUT',{deviceIds:[10]});
  await call('/v1/views/another-view-12345','PUT',{deviceIds:[10]},'friend');
  assert.equal(pushes.length,1);
  await call(view,'DELETE');
  assert.equal((await session()).expiresAt,1045000);
  advance(30001);
  assert.equal((await session()).expiresAt,0);
  await call(view,'PUT',{deviceIds:[10]});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(pushes.length,2);
});

test('rejects unauthorized targets and revokes native access on unregister',async t=> {
  const {call,base}=await fixture(t);
  assert.equal((await call('/v1/views/abcdefghijklmnop','PUT',{deviceIds:[11]},'friend')).status,403);
  const {deviceToken}=await (await call('/v1/devices','POST',{
    uniqueId:'phone',platform:'ios',pushToken:'0123456789abcdef',
    installationToken,
  })).json();
  await call('/v1/devices','DELETE',{deviceId:10,installationToken});
  assert.equal((await fetch(base+'/v1/device-session',{
    headers:{Authorization:`Bearer ${deviceToken}`},
  })).status,401);
});

test('unacknowledged Android kicks are retried after the initial lease expires',async t=> {
  const {call,pushes,advance}=await fixture(t);
  await call('/v1/devices','POST',registration);
  const view='/v1/views/abcdefghijklmnop';
  await call(view,'PUT',{deviceIds:[10]});
  await new Promise(resolve=>setImmediate(resolve));
  advance(15000);
  await call(view,'PUT',{deviceIds:[10]});
  assert.equal(pushes.length,1);
  advance(15001);
  await call(view,'PUT',{deviceIds:[10]});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(pushes.length,2);
});

test('an acknowledged device suppresses pushes throughout a long renewed session',async t=> {
  const {call,base,pushes,advance}=await fixture(t);
  const {deviceToken}=await (await call('/v1/devices','POST',{
    uniqueId:'phone',platform:'ios',pushToken:'0123456789abcdef',
    installationToken,
  })).json();
  const view='/v1/views/abcdefghijklmnop';
  await call(view,'PUT',{deviceIds:[10]});
  await new Promise(resolve=>setImmediate(resolve));
  for (let i=0;i<20;i++) {
    advance(15000);
    await call(view,'PUT',{deviceIds:[10]});
    await fetch(base+'/v1/device-session',{headers:{Authorization:`Bearer ${deviceToken}`}});
  }
  assert.equal(pushes.length,1);
});

test('another phone needs explicit takeover, which revokes access before push setup',async t=> {
  const {call,base}=await fixture(t);
  const {deviceToken}=await (await call('/v1/devices','POST',registration)).json();
  const oldSession=()=>fetch(base+'/v1/device-session',{headers:{Authorization:`Bearer ${deviceToken}`}});
  const replacement={uniqueId:'phone',installationToken:replacementToken};
  assert.equal((await call('/v1/devices/claim','POST',replacement)).status,409);
  assert.equal((await call('/v1/devices','POST',{...registration,installationToken:replacementToken,replace:true})).status,409);
  assert.equal((await oldSession()).status,200);
  const response=await call('/v1/devices/claim','POST',{...replacement,replace:true});
  assert.equal(response.status,200);
  assert.equal((await response.json()).deviceId,10);
  assert.equal((await oldSession()).status,401);
  assert.equal((await call('/v1/devices','POST',registration)).status,409);
  assert.equal((await call('/v1/devices/claim','POST',{uniqueId:'phone',installationToken})).status,409);
  const next=await call('/v1/devices','POST',{...registration,installationToken:replacementToken});
  assert.equal(next.status,200);
  const {deviceToken:nextToken}=await next.json();
  // The old phone shares the same manager login, but cannot unregister the new phone.
  assert.equal((await call('/v1/devices','DELETE',{deviceId:10,installationToken})).status,403);
  assert.equal((await fetch(base+'/v1/device-session',{headers:{Authorization:`Bearer ${nextToken}`}})).status,200);
});

test('the same installation can reconnect and refresh its push token without a takeover',async t=> {
  const {call,base}=await fixture(t);
  const first=await (await call('/v1/devices','POST',registration)).json();
  assert.equal((await call('/v1/devices/claim','POST',{uniqueId:'phone',installationToken})).status,200);
  assert.equal((await fetch(base+'/v1/device-session',{headers:{Authorization:`Bearer ${first.deviceToken}`}})).status,200);
  const next=await call('/v1/devices','POST',{...registration,pushToken:'refreshed-push-token'});
  assert.equal(next.status,200);
  assert.equal((await fetch(base+'/v1/device-session',{headers:{Authorization:`Bearer ${first.deviceToken}`}})).status,401);
});

test('takeover immediately sends an active view to the replacement phone',async t=> {
  const {call,pushes}=await fixture(t);
  await call('/v1/devices','POST',{...registration,platform:'ios'});
  await call('/v1/views/abcdefghijklmnop','PUT',{deviceIds:[10]});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(pushes.length,1);
  await call('/v1/devices/claim','POST',{uniqueId:'phone',installationToken:replacementToken,replace:true});
  await call('/v1/devices','POST',{...registration,platform:'ios',installationToken:replacementToken,pushToken:'replacement-push-token'});
  await new Promise(resolve=>setImmediate(resolve));
  assert.deepEqual(pushes.map(p=>p.pushToken),[registration.pushToken,'replacement-push-token']);
});

test('an old push finishing after takeover does not suppress the new phone',async t=> {
  let finish;
  const pending=new Promise(resolve=>{finish=resolve;});
  const sent=[];
  const {call}=await fixture(t,{push:{send:async device=>{
    sent.push(device.pushToken);
    if (device.pushToken===registration.pushToken) await pending;
  }}});
  await call('/v1/devices','POST',{...registration,platform:'ios'});
  await call('/v1/views/abcdefghijklmnop','PUT',{deviceIds:[10]});
  await call('/v1/devices/claim','POST',{uniqueId:'phone',installationToken:replacementToken,replace:true});
  await call('/v1/devices','POST',{...registration,platform:'ios',installationToken:replacementToken,pushToken:'replacement-push-token'});
  finish();
  await new Promise(resolve=>setImmediate(resolve));
  assert.deepEqual(sent,[registration.pushToken,'replacement-push-token']);
});

test('claim validation requires device access and a valid installation credential',async t=> {
  const {call,base}=await fixture(t);
  assert.equal((await call('/v1/devices/claim','POST',{uniqueId:'other',installationToken},'friend')).status,403);
  assert.equal((await call('/v1/devices/claim','POST',{uniqueId:'phone',installationToken,replace:'true'})).status,400);
  assert.equal((await call('/v1/devices/claim','POST',{uniqueId:'phone'})).status,400);
  assert.equal((await call('/v1/devices','POST',{...registration,installationToken:'short'})).status,400);
  assert.equal((await fetch(base+'/v1/devices/claim',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({uniqueId:'phone',installationToken})})).status,401);
});

test('claims survive restart and migrate an existing registration database',{timeout:5000},async t=> {
  const directory=await mkdtemp(join(tmpdir(),'trakkar-sidecar-'));
  t.after(()=>rm(directory,{recursive:true,force:true}));
  const database=join(directory,'tracking.sqlite');
  const legacy=new DatabaseSync(database);
  legacy.exec(`CREATE TABLE registrations (
    deviceId INTEGER PRIMARY KEY, userId INTEGER NOT NULL, platform TEXT NOT NULL,
    pushToken TEXT NOT NULL, accessHash TEXT UNIQUE NOT NULL, lastPush INTEGER NOT NULL DEFAULT 0)`);
  const legacyToken='legacy-device-token';
  legacy.prepare('INSERT INTO registrations(deviceId,userId,platform,pushToken,accessHash) VALUES(?,?,?,?,?)')
    .run(10,1,'android',registration.pushToken,createHash('sha256').update(legacyToken).digest('hex'));
  legacy.close();
  const first=await fixture(t,{database});
  const legacySession=()=>fetch(first.base+'/v1/device-session',{headers:{Authorization:`Bearer ${legacyToken}`}});
  assert.equal((await legacySession()).status,200);
  await first.call('/v1/devices','POST',registration);
  assert.equal((await legacySession()).status,401);
  first.server.closeAllConnections();
  await new Promise(resolve=>first.server.close(resolve));
  const second=await fixture(t,{database});
  assert.equal((await second.call('/v1/devices','POST',{...registration,installationToken:replacementToken})).status,409);
  assert.equal((await second.call('/v1/devices','POST',registration)).status,200);
});
