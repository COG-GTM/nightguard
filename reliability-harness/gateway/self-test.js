'use strict';

const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const readline = require('node:readline');

function argumentsMap(args) {
  const values = {};
  for (let index = 0; index < args.length; index += 2) {
    values[args[index]] = args[index + 1];
  }
  for (const required of ['--replica-a', '--replica-b', '--token-file']) {
    if (!values[required]) throw new Error(`Missing ${required}`);
  }
  return values;
}

function request(port, route, body) {
  return new Promise((resolve, reject) => {
    const payload = body === undefined ? null : Buffer.from(JSON.stringify(body));
    const outgoing = http.request({
      hostname: '127.0.0.1',
      port,
      path: route,
      method: payload ? 'POST' : 'GET',
      headers: payload ? {
        'content-type': 'application/json',
        'content-length': payload.length
      } : {}
    }, (response) => {
      response.resume();
      response.on('end', () => resolve(response.statusCode));
    });
    outgoing.setTimeout(5000, () => outgoing.destroy(new Error('Gateway request timed out')));
    outgoing.on('error', reject);
    if (payload) outgoing.write(payload);
    outgoing.end();
  });
}

async function main() {
  const args = argumentsMap(process.argv.slice(2));
  const replicas = {
    A: { port: Number(args['--replica-a']) },
    B: { port: Number(args['--replica-b']) }
  };
  const tokenData = JSON.parse(fs.readFileSync(args['--token-file'], 'utf8'));
  const token = tokenData.accessToken;
  assert.equal(typeof token, 'string');

  const profilePath = path.join(__dirname, '..', 'profiles', 'fault-profile.pilot.json');
  const profile = JSON.parse(fs.readFileSync(profilePath, 'utf8'));
  const runSeed = profile.run_seed || 135;
  profile.episodes = {};
  for (const name of profile.per_request.order) {
    if (name === 'hang') profile.per_request[name].max_hold_s = 0.05;
    if (name === 'slow') profile.per_request[name].delay_ms = [1, 3];
  }

  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'nightguard-gateway-self-test-'));
  const logFile = path.join(temporaryDirectory, 'gateway.jsonl');
  const gateway = spawn(process.execPath, [
    path.join(__dirname, 'gateway.js'),
    '--port',
    '0',
    '--slots',
    JSON.stringify({ 1: replicas }),
    '--log',
    logFile
  ], { stdio: ['ignore', 'pipe', 'ignore'] });
  let port;

  try {
    const lines = readline.createInterface({ input: gateway.stdout });
    const ready = await new Promise((resolve, reject) => {
      lines.once('line', (line) => resolve(JSON.parse(line)));
      gateway.once('error', reject);
      gateway.once('exit', (code) => reject(new Error(`Gateway exited before startup (${code})`)));
    });
    lines.close();
    assert.equal(ready.status, 'ready');
    port = ready.port;

    const requestClasses = [
      ['/api/v3/version', 'version'],
      ['/api/v2/authorization/request/self-test', 'jwt'],
      ['/api/v3/entries/sgv.json?count=1', 'v3_entries'],
      ['/api/v1/entries.json?count=1', 'v1_entries']
    ];
    const runs = [];
    for (const sessionId of ['gateway-self-test-first', 'gateway-self-test-second']) {
      const registered = await request(port, '/__control/register', {
        sessionId,
        sessionIndex: 17,
        slot: 1,
        profile,
        runSeed,
        eventFile: path.join(temporaryDirectory, `${sessionId}.jsonl`)
      });
      assert.equal(registered, 200);
      const started = await request(port, '/__control/faults-start-at', {
        sessionId,
        faultsStartAt: Date.now()
      });
      assert.equal(started, 200);

      for (let index = 0; index < 50; index += 1) {
        for (const [route] of requestClasses) {
          const separator = route.includes('?') ? '&' : '?';
          const status = await request(
            port,
            `/s/${sessionId}${route}${separator}token=${encodeURIComponent(token)}`
          );
          assert.ok(status >= 200 && status < 600);
        }
      }
      const rows = fs.readFileSync(logFile, 'utf8')
        .trim()
        .split('\n')
        .map((line) => JSON.parse(line))
        .filter((row) => row.sessionId === sessionId && row.endpointClass !== 'control');
      assert.equal(rows.length, 200);
      for (const [, endpointClass] of requestClasses) {
        assert.ok(
          rows.some((row) => row.endpointClass === endpointClass),
          `endpoint class ${endpointClass} was not exercised`
        );
      }
      runs.push(rows.map(({ endpointClass, fault, episode }) => ({ endpointClass, fault, episode })));
    }

    const rows = runs[0];
    const internalErrors = fs.readFileSync(logFile, 'utf8')
      .trim()
      .split('\n')
      .map((line) => JSON.parse(line))
      .filter((row) => row.sessionId?.startsWith('gateway-self-test-')
        && row.statusReturned === 500
        && row.upstreamStatus === null
        && row.fault === null
        && row.episode === null);
    assert.equal(internalErrors.length, 0, 'gateway returned an internal HTTP 500');
    for (const name of profile.per_request.order) {
      assert.ok(rows.some((row) => row.fault === name), `fault ${name} was not applied`);
    }
    assert.deepEqual(runs[0], runs[1], 'same seed and session index changed request decisions');

    const counts = Object.fromEntries(
      profile.per_request.order.map((name) => [name, rows.filter((row) => row.fault === name).length])
    );
    console.log(
      `Gateway self-test passed: 200 requests/run across 4 classes; `
      + `internal500=0; faults=${JSON.stringify(counts)}; deterministic=true`
    );
  } finally {
    if (gateway.exitCode === null && gateway.signalCode === null) {
      await new Promise((resolve) => {
        gateway.once('exit', resolve);
        gateway.kill('SIGTERM');
      });
    }
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(`Gateway self-test failed: ${error.message}`);
  process.exitCode = 1;
});
