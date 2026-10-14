import {readFileSync} from 'node:fs';
import {createPrivateKey, sign} from 'node:crypto';
import {connect} from 'node:http2';

const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
function jwt(header, claims, key, algorithm, options = {}) {
  const data = `${encode(header)}.${encode(claims)}`;
  return `${data}.${sign(algorithm, Buffer.from(data), {key: createPrivateKey(key), ...options}).toString('base64url')}`;
}

export class PushSender {
  constructor(env = process.env) { this.env = env; }
  async send(device, until) {
    const payload = {type: 'live_tracking', expiresAt: String(until)};
    return device.platform === 'ios' ? this.apns(device, payload) : this.fcm(device, payload);
  }
  async fcm(device, payload) {
    const account = JSON.parse(readFileSync(this.env.FCM_SERVICE_ACCOUNT_FILE, 'utf8'));
    if (!this.googleToken || this.googleToken.expiry < Date.now() + 60000) {
      const now = Math.floor(Date.now() / 1000);
      const assertion = jwt({alg:'RS256',typ:'JWT'}, {
        iss:account.client_email, scope:'https://www.googleapis.com/auth/firebase.messaging',
        aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600,
      }, account.private_key, 'RSA-SHA256');
      const response = await fetch('https://oauth2.googleapis.com/token', {
        method:'POST',body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),
        signal:AbortSignal.timeout(10000),
      });
      if (!response.ok) throw new Error('fcm_auth');
      const body = await response.json();
      this.googleToken = {value:body.access_token,expiry:Date.now()+body.expires_in*1000};
    }
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
      method:'POST',headers:{Authorization:`Bearer ${this.googleToken.value}`,'Content-Type':'application/json'},
      body:JSON.stringify({message:{token:device.pushToken,data:payload,
        android:{priority:'normal',ttl:'30s',collapse_key:'live_tracking'}}}),
      signal:AbortSignal.timeout(10000),
    });
    if (!response.ok) throw new Error(`fcm_${response.status}`);
  }
  async apns(device, payload) {
    const now = Math.floor(Date.now()/1000);
    if (!this.appleToken || this.appleToken.issued < now-3000) {
      this.appleToken = {issued:now,value:jwt({alg:'ES256',kid:this.env.APNS_KEY_ID},
        {iss:this.env.APNS_TEAM_ID,iat:now},readFileSync(this.env.APNS_KEY_FILE),'sha256', {dsaEncoding:'ieee-p1363'})};
    }
    const host = this.env.APNS_SANDBOX === 'true' ? 'api.sandbox.push.apple.com' : 'api.push.apple.com';
    await new Promise((resolve,reject) => {
      const session = connect(`https://${host}`);
      const timer = setTimeout(() => finish(new Error('apns_timeout')),10000);
      const finish = error => {clearTimeout(timer);session.close();error ? reject(error) : resolve();};
      session.on('error',finish);
      const request = session.request({':method':'POST',':path':`/3/device/${device.pushToken}`,
        authorization:`bearer ${this.appleToken.value}`,'apns-topic':`${this.env.APNS_BUNDLE_ID}.location-query`,
        'apns-push-type':'location','apns-priority':'10','apns-expiration':String(Math.floor(Number(payload.expiresAt)/1000)),
        'apns-collapse-id':'live_tracking'});
      let status;
      request.on('response',headers => {status=headers[':status'];});
      request.on('data',() => {});
      request.on('error',finish);
      request.on('end',() => finish(status===200 ? null : new Error(`apns_${status}`)));
      request.end(JSON.stringify({aps:{},...payload}));
    });
  }
}
