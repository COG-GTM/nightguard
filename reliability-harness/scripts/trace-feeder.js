'use strict';

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const args = parseArguments(process.argv.slice(2));
args.token = args.token || process.env.HARNESS_NIGHTSCOUT_TOKEN;
const shape = JSON.parse(fs.readFileSync(args.shape, 'utf8'));
const nightscoutRoot = path.resolve(args.nightscoutRoot);
const { MongoClient, ObjectId } = require(path.join(nightscoutRoot, 'node_modules/mongodb'));

function parseArguments(values) {
  const result = {};
  for (let index = 0; index < values.length; index += 2) {
    result[values[index].replace(/^--/, '')] = values[index + 1];
  }
  return result;
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function requestJson(port, pathname, token) {
  return new Promise((resolve, reject) => {
    const request = http.get({
      hostname: '127.0.0.1',
      port,
      path: `${pathname}${pathname.includes('?') ? '&' : '?'}token=${encodeURIComponent(token)}`,
      headers: { accept: 'application/json', 'api-secret': token },
      timeout: 10_000
    }, (response) => {
      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => {
        const body = Buffer.concat(chunks).toString('utf8');
        if (response.statusCode < 200 || response.statusCode >= 300) {
          reject(new Error(`Nightscout on ${port} returned HTTP ${response.statusCode}: ${body.slice(0, 200)}`));
          return;
        }
        try {
          resolve(JSON.parse(body));
        } catch (error) {
          reject(error);
        }
      });
    });
    request.on('timeout', () => request.destroy(new Error(`Nightscout on ${port} timed out`)));
    request.on('error', reject);
  });
}

function entryFor(sgv, date) {
  return {
    _id: new ObjectId(),
    date,
    dateString: new Date(date).toISOString(),
    sgv,
    direction: shape.direction,
    type: 'sgv',
    device: shape.device
  };
}

async function waitUntilReadable(ports, token, entry) {
  const started = Date.now();
  while (Date.now() - started < 120_000) {
    let readableOnBoth = true;
    for (const port of ports) {
      try {
        const entries = await requestJson(port, '/api/v1/entries.json?count=100', token);
        const found = entries.some((item) => Number(item.date) === entry.date && Number(item.sgv) === entry.sgv);
        if (!found) readableOnBoth = false;
      } catch {
        readableOnBoth = false;
      }
    }
    if (readableOnBoth) return Date.now();
    await delay(500);
  }
  throw new Error(`Reading ${entry.sgv} at ${entry.date} was not readable from both replicas`);
}

async function openDatabase() {
  const client = new MongoClient(args.mongoUri);
  await client.connect();
  return { client, entries: client.db().collection('entries') };
}

async function seed() {
  const { client, entries } = await openDatabase();
  try {
    await entries.deleteMany({});
    const t0Ms = Date.now();
    const historyEndMs = t0Ms - shape.history_end_offset_minutes * 60_000;
    const stepMs = shape.reading_interval_minutes * 60_000;
    const history = shape.initial_history_values_mgdl.map((sgv, index) =>
      entryFor(sgv, historyEndMs - (shape.initial_history_values_mgdl.length - 1 - index) * stepMs)
    );
    await entries.insertMany(history);
    const records = [];
    for (const entry of history) {
      const availableAtMs = await waitUntilReadable([Number(args.portA), Number(args.portB)], args.token, entry);
      records.push({
        timestampMs: entry.date,
        availableAtMs,
        sgv: entry.sgv,
        type: entry.type,
        direction: entry.direction,
        device: entry.device
      });
    }
    return {
      t0Ms,
      historyEndMs,
      t0Sgv: history.at(-1).sgv,
      readings: records,
      insertedAtMs: Date.now()
    };
  } finally {
    await client.close();
  }
}

async function waitForT0Event(eventFile) {
  while (true) {
    if (fs.existsSync(eventFile)) {
      const events = fs.readFileSync(eventFile, 'utf8').split('\n').filter(Boolean);
      for (const line of events) {
        const event = JSON.parse(line);
        if (event.bgValue && Number(event.bgValue) === Number(args.t0Sgv)) {
          return Number(event.hostWallClockMs);
        }
      }
    }
    await delay(500);
  }
}

async function feed() {
  const { client, entries } = await openDatabase();
  try {
    const t0HostMs = await waitForT0Event(args.eventFile);
    const records = [];
    for (const reading of shape.realtime_readings) {
      const targetTimestamp = t0HostMs + reading.offset_minutes * 60_000;
      while (Date.now() < targetTimestamp) await delay(Math.min(500, targetTimestamp - Date.now()));
      const entry = entryFor(reading.sgv, targetTimestamp);
      await entries.insertOne(entry);
      const availableAtMs = await waitUntilReadable(
        [Number(args.portA), Number(args.portB)],
        args.token,
        entry
      );
      records.push({
        timestampMs: entry.date,
        availableAtMs,
        sgv: entry.sgv,
        type: entry.type,
        direction: entry.direction,
        device: entry.device
      });
      process.stdout.write(`${JSON.stringify({ reading: records.at(-1) })}\n`);
    }
    process.stdout.write(`${JSON.stringify({ complete: true, readings: records })}\n`);
  } finally {
    await client.close();
  }
}

async function main() {
  if (args.mode === 'seed') {
    process.stdout.write(`${JSON.stringify(await seed())}\n`);
  } else if (args.mode === 'feed') {
    await feed();
  } else {
    throw new Error('--mode must be seed or feed');
  }
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
