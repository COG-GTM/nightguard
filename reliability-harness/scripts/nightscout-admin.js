'use strict';

const http = require('node:http');
const crypto = require('node:crypto');

const args = parseArguments(process.argv.slice(2));

function parseArguments(values) {
  const result = {};
  for (let index = 0; index < values.length; index += 2) {
    result[values[index].replace(/^--/, '')] = values[index + 1];
  }
  return result;
}

function request(port, method, pathname, headers = {}, body = null) {
  return new Promise((resolve, reject) => {
    const requestOptions = {
      hostname: '127.0.0.1',
      port: Number(port),
      method,
      path: pathname,
      headers: { accept: 'application/json', ...headers },
      timeout: 10_000
    };
    const outgoing = http.request(requestOptions, (response) => {
      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        let parsed = null;
        try {
          parsed = JSON.parse(raw);
        } catch {}
        resolve({ status: response.statusCode, raw, body: parsed });
      });
    });
    outgoing.on('timeout', () => outgoing.destroy(new Error('Nightscout request timed out')));
    outgoing.on('error', reject);
    if (body) {
      const serialized = JSON.stringify(body);
      outgoing.setHeader('content-type', 'application/json');
      outgoing.setHeader('content-length', Buffer.byteLength(serialized));
      outgoing.write(serialized);
    }
    outgoing.end();
  });
}

async function ensureSubject(port) {
  const apiSecret = args.apiSecret || process.env.HARNESS_API_SECRET;
  const secretHeader = {
    'api-secret': crypto.createHash('sha1').update(apiSecret).digest('hex')
  };
  let subjectsResponse = await request(
    port,
    'GET',
    '/api/v2/authorization/subjects',
    secretHeader
  );
  if (subjectsResponse.status !== 200 || !Array.isArray(subjectsResponse.body)) {
    throw new Error(`Unable to list authorization subjects: HTTP ${subjectsResponse.status}`);
  }
  let subject = subjectsResponse.body.find((item) => item.name === args.subject);
  if (!subject) {
    const created = await request(port, 'POST', '/api/v2/authorization/subjects', secretHeader, {
      name: args.subject,
      roles: ['readable'],
      notes: 'Synthetic Nightguard reliability harness subject'
    });
    if (created.status !== 200) {
      throw new Error(`Unable to create readable subject: HTTP ${created.status}`);
    }
    subjectsResponse = await request(
      port,
      'GET',
      '/api/v2/authorization/subjects',
      secretHeader
    );
    subject = subjectsResponse.body?.find((item) => item.name === args.subject);
  }
  if (!subject?.accessToken) throw new Error(`Readable subject ${args.subject} has no access token`);
  return subject.accessToken;
}

async function main() {
  const accessToken = await ensureSubject(args.portA);
  const jwtResponse = await request(
    args.portA,
    'GET',
    `/api/v2/authorization/request/token=${encodeURIComponent(accessToken)}`
  );
  if (jwtResponse.status !== 200 || !jwtResponse.body?.token) {
    throw new Error(`JWT issuance failed: HTTP ${jwtResponse.status}`);
  }
  const jwt = jwtResponse.body.token;
  const jwtValidation = await request(
    args.portA,
    'GET',
    `/api/v2/authorization/request/${encodeURIComponent(jwt)}`
  );
  if (jwtValidation.status !== 200 || !jwtValidation.body?.token) {
    throw new Error(`JWT validation failed: HTTP ${jwtValidation.status}`);
  }
  const results = {};
  for (const port of [Number(args.portA), Number(args.portB)]) {
    const checks = [
      ['version', '/api/v3/version'],
      ['v3Entries', '/api/v3/entries?limit=100'],
      ['v1Entries', '/api/v1/entries.json?count=100']
    ];
    results[port] = {};
    for (const [name, pathname] of checks) {
      const response = await request(port, 'GET', pathname, {
        ...(name === 'v1Entries'
          ? { 'api-secret': accessToken }
          : { Authorization: `Bearer ${jwt}` })
      });
      if (response.status < 200 || response.status >= 300) {
        const message = response.body?.message ? ` (${response.body.message})` : '';
        throw new Error(`${name} verification failed on ${port}: HTTP ${response.status}${message}`);
      }
      results[port][name] = response.status;
    }
  }
  process.stdout.write(`${JSON.stringify({ accessToken, jwt, checks: results })}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
