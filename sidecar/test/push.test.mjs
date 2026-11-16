import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {PushSender} from '../push.mjs';

test('Android activation uses high priority without an alert payload', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'trakkar-push-'));
  t.after(() => rm(directory, {recursive: true, force: true}));
  const account = join(directory, 'account.json');
  await writeFile(account, JSON.stringify({project_id: 'test-project'}));
  const sender = new PushSender({FCM_SERVICE_ACCOUNT_FILE: account});
  sender.googleToken = {value: 'test-access-token', expiry: Date.now() + 3600000};
  const requests = [];
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    requests.push({url, body: JSON.parse(options.body)});
    return new Response('{}', {status: 200});
  });

  await sender.send({platform: 'android', pushToken: 'test-device-token'}, 123456789);

  assert.deepEqual(requests, [{
    url: 'https://fcm.googleapis.com/v1/projects/test-project/messages:send',
    body: {message: {
      token: 'test-device-token',
      data: {type: 'live_tracking', expiresAt: '123456789'},
      android: {priority: 'high', ttl: '30s', collapse_key: 'live_tracking'},
    }},
  }]);
});
