import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
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

async function fixture(t) {
  let now=1000000;
  const pushes=[];
  const server=createSidecar({managerUrl:'http://traccar:8082',owners:{10:1},now:()=>now,
    push:{send:async(device,until)=>pushes.push({deviceId:device.deviceId,until})},
    fetcher:async(url,options)=> {
      const user=options.headers.Cookie==='JSESSIONID=owner' ? 1 : 2;
      const body=url.endsWith('/session') ? {id:user} : [{id:10,uniqueId:'phone'}, ...(user===1 ? [{id:11,uniqueId:'other'}] : [])];
      return new Response(JSON.stringify(body),{status:200});
    }});
  server.listen(0,'127.0.0.1');
  await once(server,'listening');
  t.after(()=>new Promise(resolve=>server.close(resolve)));
  const base=`http://127.0.0.1:${server.address().port}`;
  const call=(path,method='GET',body,user='owner')=>fetch(base+path,{method,
    headers:{'X-Traccar-Session':`JSESSIONID=${user}`,'Content-Type':'application/json'},
    body:body===undefined ? undefined : JSON.stringify(body)});
  return {call,base,pushes,advance:ms=>{now+=ms;}};
}

test('registration requires owner mapping, not merely access to a shared device',async t=> {
  const {call}=await fixture(t);
  const input={uniqueId:'phone',platform:'android',pushToken:'valid-push-token-123'};
  assert.equal((await call('/v1/devices','POST',input,'friend')).status,403);
  assert.equal((await call('/v1/devices','POST',input)).status,200);
});

test('one push starts a session; renewals and overlapping viewers do not repeat it',async t=> {
  const {call,base,pushes,advance}=await fixture(t);
  const registration=await (await call('/v1/devices','POST',{
    uniqueId:'phone',platform:'android',pushToken:'valid-push-token-123',
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
  })).json();
  await call('/v1/devices','DELETE',{deviceId:10});
  assert.equal((await fetch(base+'/v1/device-session',{
    headers:{Authorization:`Bearer ${deviceToken}`},
  })).status,401);
});

test('unacknowledged Android kicks are retried after the initial lease expires',async t=> {
  const {call,pushes,advance}=await fixture(t);
  await call('/v1/devices','POST',{uniqueId:'phone',platform:'android',pushToken:'valid-push-token-123'});
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
