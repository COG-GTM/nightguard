'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { URL } = require('node:url');

const options = parseArguments(process.argv.slice(2));
const sessions = new Map();
const logFile = options.log;

function parseArguments(args) {
  const result = { port: 0, slots: {}, log: null };
  for (let index = 0; index < args.length; index += 2) {
    const key = args[index];
    const value = args[index + 1];
    if (key === '--port') {
      result.port = Number(value);
    } else if (key === '--slots') {
      result.slots = JSON.parse(value);
    } else if (key === '--log') {
      result.log = value;
    } else {
      throw new Error(`Unknown option: ${key}`);
    }
  }
  if (!result.log) throw new Error('--log is required');
  return result;
}

function fnv1a32(value) {
  let hash = 0x811c9dc5;
  for (const byte of Buffer.from(String(value), 'utf8')) {
    hash = Math.imul(hash ^ byte, 0x01000193) >>> 0;
  }
  return hash;
}

function mulberry32(seed) {
  let state = seed >>> 0;
  return function next() {
    state = (state + 0x6d2b79f5) >>> 0;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function randomFor(seed) {
  return mulberry32(fnv1a32(seed))();
}

function timestamp() {
  return new Date().toISOString();
}

function appendLog(entry) {
  fs.appendFileSync(logFile, `${JSON.stringify(entry)}\n`);
}

function redactPath(path) {
  return path
    .replace(/([?&]token=)[^&]*/gi, '$1[REDACTED]')
    .replace(/(\/api\/v2\/authorization\/request\/)[^/?]+/gi, '$1[REDACTED]');
}

function endpointClass(pathname) {
  if (/^\/api\/v3\/version\/?$/.test(pathname)) return 'version';
  if (/^\/api\/v2\/authorization\/request\/[^/]+\/?$/.test(pathname)) return 'jwt';
  if (/^\/api\/v3\/entries(?:[./]|$)/.test(pathname)) return 'v3_entries';
  if (/^\/api\/v1\/entries(?:[./]|$)/.test(pathname)) return 'v1_entries';
  if (/^\/api\/v2\/properties(?:[./]|$)/.test(pathname)) return 'properties';
  if (/^\/api\/[^/]+\/treatments(?:[./]|$)/.test(pathname)) return 'treatments';
  if (/^\/api\/[^/]+\/devicestatus(?:[./]|$)/.test(pathname)) return 'devicestatus';
  return 'other';
}

function deriveEpisodes(session) {
  const { profile, sessionSeed } = session;
  if (!profile) return [];
  return Object.entries(profile.episodes)
    .filter(([type, config]) => !type.startsWith('_') && config && typeof config === 'object')
    .map(([type, config]) => {
    const random = mulberry32(fnv1a32(`${sessionSeed}:episode:${type}`));
    if (random() >= config.p_session) return { type, config, occurs: false };
    const start = config.start_window_s[0] +
      random() * (config.start_window_s[1] - config.start_window_s[0]);
    const duration = config.duration_s[0] +
      random() * (config.duration_s[1] - config.duration_s[0]);
    const modeIndex = Math.floor(random() * (config.mode_choices || config.status_choices || [null]).length);
    const choices = config.mode_choices || config.status_choices;
    return {
      type,
      config,
      occurs: true,
      offsetMs: start * 1000,
      durationMs: duration * 1000,
      mode: choices ? choices[modeIndex] : null
    };
    });
}

function episodeFor(session, requestClass, now) {
  if (session.faultsStartAt === null) return null;
  for (const episode of session.episodes) {
    const applies = episode.type === 'replica_down'
      ? true
      : episode.config.classes?.includes(requestClass);
    if (!episode.occurs || !applies) continue;
    const start = session.faultsStartAt + episode.offsetMs;
    if (now >= start && now < start + episode.durationMs) return episode;
  }
  return null;
}

function perRequestFault(session, requestClass, requestIndex) {
  if (!session.profile || requestClass === 'other') return null;
  const rules = session.profile.per_request;
  const draw = randomFor(`${session.sessionSeed}:${requestClass}:${requestIndex}`);
  let cumulative = 0;
  for (const name of session.profile.order) {
    const rule = rules[name];
    if (!rule || !rule.applies_to.includes(requestClass)) continue;
    cumulative += rule.p;
    if (draw < cumulative) return { name, rule };
  }
  return null;
}

function pickInteger(seed, minimum, maximum) {
  return minimum + Math.floor(randomFor(seed) * (maximum - minimum + 1));
}

function mutateEntries(body, requestClass) {
  let parsed;
  try {
    parsed = JSON.parse(body.toString('utf8'));
  } catch {
    return body;
  }

  const items = Array.isArray(parsed) ? parsed : Array.isArray(parsed.result) ? parsed.result : null;
  if (!items) return body;

  const copies = items.map((record) => {
    const copy = { ...record };
    if (requestClass === 'v1_entries') {
      copy._id = `${record._id || crypto.randomUUID()}-dup`;
    } else {
      copy.identifier = crypto.randomUUID();
      if (Object.prototype.hasOwnProperty.call(copy, '_id')) copy._id = crypto.randomUUID();
    }
    return copy;
  });
  if (Array.isArray(parsed)) return Buffer.from(JSON.stringify(items.concat(copies)));
  return Buffer.from(JSON.stringify({ ...parsed, result: items.concat(copies) }));
}

function responseHeaders(headers) {
  const filtered = { ...headers };
  delete filtered['content-length'];
  delete filtered['content-encoding'];
  delete filtered['transfer-encoding'];
  delete filtered.connection;
  return filtered;
}

function sendJson(response, status, value) {
  response.writeHead(status, { 'content-type': 'application/json' });
  response.end(JSON.stringify(value));
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1024 * 1024) {
        reject(new Error('Control request exceeds 1 MiB'));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'));
      } catch (error) {
        reject(error);
      }
    });
    request.on('error', reject);
  });
}

async function handleControl(request, response, pathname, requestStart) {
  let body = {};
  if (request.method === 'POST') body = await readJson(request);
  if (pathname === '/__control/register' && request.method === 'POST') {
    const { sessionId, sessionIndex, slot, profile, runSeed, eventFile } = body;
    const replicas = options.slots[String(slot)];
    if (!sessionId || !Number.isInteger(sessionIndex) || !replicas) {
      sendJson(response, 400, { error: 'sessionId, sessionIndex and a configured slot are required' });
      return;
    }
    const resultsRoot = path.resolve(path.dirname(logFile));
    const resolvedEventFile = eventFile ? path.resolve(eventFile) : null;
    if (!resolvedEventFile || !resolvedEventFile.startsWith(`${resultsRoot}${path.sep}`)) {
      sendJson(response, 400, { error: 'eventFile must be under the gateway log directory' });
      return;
    }
    const sessionSeed = fnv1a32(`${runSeed}:${sessionIndex}`);
    const session = {
      sessionId,
      sessionIndex,
      slot,
      replicas,
      eventFile: resolvedEventFile,
      profile: profile || null,
      runSeed,
      sessionSeed,
      faultsStartAt: null,
      nextReplica: 0,
      requestIndexes: new Map(),
      successfulBodies: new Map(),
      episodes: []
    };
    session.episodes = deriveEpisodes(session);
    sessions.set(sessionId, session);
    sendJson(response, 200, {
      sessionId,
      sessionSeed,
      episodes: session.episodes.map(({ type, occurs, offsetMs, durationMs, mode }) => ({
        type, occurs, offsetMs, durationMs, mode
      }))
    });
  } else if (pathname === '/__control/faults-start-at' && request.method === 'POST') {
    const session = sessions.get(body.sessionId);
    if (!session || !Number.isFinite(body.faultsStartAt)) {
      sendJson(response, 400, { error: 'registered session and numeric faultsStartAt are required' });
      return;
    }
    session.faultsStartAt = body.faultsStartAt;
    sendJson(response, 200, { sessionId: session.sessionId, faultsStartAt: session.faultsStartAt });
  } else if (pathname === '/__control/events' && request.method === 'POST') {
    const session = sessions.get(body.sessionId);
    if (!session || !Array.isArray(body.events)) {
      sendJson(response, 400, { error: 'registered session and events array are required' });
      return;
    }
    fs.mkdirSync(path.dirname(session.eventFile), { recursive: true });
    fs.appendFileSync(
      session.eventFile,
      body.events.map((event) => JSON.stringify({ ...event, sessionId: session.sessionId })).join('\n') + '\n'
    );
    sendJson(response, 200, { saved: body.events.length });
  } else if (pathname === '/__control/health' && request.method === 'GET') {
    sendJson(response, 200, { status: 'ok', sessions: sessions.size });
  } else {
    sendJson(response, 404, { error: 'unknown control route' });
  }
  appendLog({
    tsStart: requestStart,
    tsEnd: timestamp(),
    sessionId: body.sessionId || null,
    method: request.method,
    path: redactPath(request.url || pathname),
    endpointClass: 'control',
    replica: null,
    fault: null,
    episode: null,
    upstreamStatus: null,
    statusReturned: response.statusCode,
    durationMs: Date.now() - Date.parse(requestStart),
    clientAborted: false
  });
  response.gatewayRequestLogged = true;
}

function findSessionRoute(pathname) {
  const match = pathname.match(/^\/s\/([^/]+)(\/.*)?$/);
  if (!match) return null;
  return { sessionId: decodeURIComponent(match[1]), upstreamPath: match[2] || '/' };
}

function finishRequest(request, response, log) {
  if (log.written) return;
  log.written = true;
  response.gatewayRequestLogged = true;
  appendLog({
    tsStart: log.tsStart,
    tsEnd: timestamp(),
    sessionId: log.sessionId,
    method: request.method,
    path: redactPath(log.path),
    endpointClass: log.endpointClass,
    replica: log.replica,
    fault: log.fault,
    episode: log.episode,
    upstreamStatus: log.upstreamStatus,
    statusReturned: response.headersSent ? response.statusCode : null,
    durationMs: Date.now() - log.startedMs,
    clientAborted: log.clientAborted
  });
}

function abortResponse(response, log) {
  if (response.destroyed || response.writableEnded) return;
  log.clientAborted = true;
  response.destroy();
}

function proxy(request, response, session, route, requestStart) {
  const parsed = new URL(request.url, 'http://gateway.local');
  const requestClass = endpointClass(route.upstreamPath);
  const replicaName = session.nextReplica++ % 2 === 0 ? 'A' : 'B';
  const replica = session.replicas[replicaName];
  const log = {
    tsStart: requestStart,
    startedMs: Date.now(),
    sessionId: session.sessionId,
    path: request.url,
    endpointClass: requestClass,
    replica: replicaName,
    fault: null,
    episode: null,
    upstreamStatus: null,
    clientAborted: false,
    written: false
  };
  let requestIndex = 0;
  const faultsActive = session.faultsStartAt !== null && Date.now() >= session.faultsStartAt;
  if (faultsActive) {
    requestIndex = session.requestIndexes.get(requestClass) || 0;
    session.requestIndexes.set(requestClass, requestIndex + 1);
  }

  const episode = faultsActive
    ? episodeFor(session, requestClass, Date.now())
    : null;
  const selectedFault = faultsActive && !episode
    ? perRequestFault(session, requestClass, requestIndex)
    : null;
  let faultName = episode?.type || selectedFault?.name || null;
  let faultRule = selectedFault?.rule || null;
  if (episode) log.episode = episode.type;
  log.fault = faultName;

  response.on('close', () => {
    if (!response.writableEnded) log.clientAborted = true;
    finishRequest(request, response, log);
  });
  request.on('aborted', () => {
    log.clientAborted = true;
    finishRequest(request, response, log);
  });

  if (episode?.type === 'replica_down' && replicaName === 'B') {
    proxyToClosedPort(request, response, route.upstreamPath + parsed.search, log);
    return;
  }
  if (episode?.type === 'jwt_auth_failure') {
    sendLocalFault(request, response, log, episode.mode || 500);
    return;
  }
  if (episode?.type === 'v3_down') {
    if (episode.mode === 'conn_reset') {
      response.destroy();
      finishRequest(request, response, log);
    } else {
      sendLocalFault(request, response, log, 503);
    }
    return;
  }
  if (faultName === 'http_503') {
    sendLocalFault(request, response, log, 503);
    return;
  }
  if (faultName === 'hang') {
    const maximumHold = selectedFault?.rule?.max_hold_s || 120;
    const timer = setTimeout(() => {
      if (!response.destroyed && !response.writableEnded) {
        log.upstreamStatus = null;
        response.writeHead(504, { 'content-type': 'text/plain' });
        response.end('gateway timeout');
        finishRequest(request, response, log);
      }
    }, maximumHold * 1000);
    timer.unref();
    response.on('close', () => clearTimeout(timer));
    return;
  }

  const useStale = faultName === 'stale_entries' &&
    (requestClass === 'v3_entries' || requestClass === 'v1_entries');
  if (useStale) {
    const bodies = session.successfulBodies.get(requestClass) || [];
    if (bodies.length) {
      const cached = bodies[0];
      response.writeHead(cached.status, responseHeaders(cached.headers));
      response.end(cached.body);
      finishRequest(request, response, log);
      return;
    }
    faultName = null;
    log.fault = null;
  }

  const targetPort = replica.port;
  const headers = { ...request.headers };
  delete headers.host;
  delete headers['accept-encoding'];
  headers['accept-encoding'] = 'identity';
  const upstream = http.request({
    hostname: '127.0.0.1',
    port: targetPort,
    method: request.method,
    path: route.upstreamPath + parsed.search,
    headers
  }, (upstreamResponse) => {
    const chunks = [];
    upstreamResponse.on('data', (chunk) => chunks.push(chunk));
    upstreamResponse.on('end', () => {
      const body = Buffer.concat(chunks);
      log.upstreamStatus = upstreamResponse.statusCode || null;
      const storedBodies = session.successfulBodies.get(requestClass) || [];
      if (upstreamResponse.statusCode >= 200 && upstreamResponse.statusCode < 300) {
        storedBodies.push({
          status: upstreamResponse.statusCode,
          headers: upstreamResponse.headers,
          body
        });
        session.successfulBodies.set(requestClass, storedBodies.slice(-3));
      }

      let outgoingBody = body;
      if (faultName === 'duplicate_entries') outgoingBody = mutateEntries(body, requestClass);
      const delay = faultName === 'slow'
        ? pickInteger(
          `${session.sessionSeed}:${requestClass}:${requestIndex}:slow-delay`,
          faultRule.delay_ms[0],
          faultRule.delay_ms[1]
        )
        : 0;
      setTimeout(() => {
        if (response.destroyed || response.writableEnded) {
          finishRequest(request, response, log);
          return;
        }
        response.writeHead(upstreamResponse.statusCode || 502, responseHeaders(upstreamResponse.headers));
        response.end(outgoingBody);
        finishRequest(request, response, log);
      }, delay);
    });
  });
  upstream.on('error', () => {
    if (response.destroyed || response.writableEnded) {
      finishRequest(request, response, log);
      return;
    }
    log.upstreamStatus = null;
    response.writeHead(502, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ error: 'upstream connection failed' }));
    finishRequest(request, response, log);
  });
  response.on('close', () => upstream.destroy());
  request.pipe(upstream);
}

function sendLocalFault(request, response, log, status) {
  log.upstreamStatus = null;
  if (response.destroyed || response.writableEnded) {
    finishRequest(request, response, log);
    return;
  }
  response.writeHead(status, { 'content-type': 'application/json' });
  response.end(JSON.stringify({ status, error: 'synthetic reliability fault' }));
  finishRequest(request, response, log);
}

function proxyToClosedPort(request, response, path, log) {
  const closed = http.request({
    hostname: '127.0.0.1',
    port: 1,
    method: request.method,
    path,
    headers: request.headers
  });
  closed.on('error', () => {
    if (response.destroyed || response.writableEnded) {
      finishRequest(request, response, log);
      return;
    }
    log.upstreamStatus = null;
    response.writeHead(502, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ error: 'upstream connection refused' }));
    finishRequest(request, response, log);
  });
  request.pipe(closed);
}

async function handleRequest(request, response) {
  const requestStart = timestamp();
  const startedMs = Date.now();
  response.once('finish', () => {
    if (response.gatewayRequestLogged) return;
    const parsedRequest = (() => {
      try {
        return new URL(request.url, 'http://gateway.local');
      } catch {
        return null;
      }
    })();
    const route = parsedRequest && findSessionRoute(parsedRequest.pathname);
    appendLog({
      tsStart: requestStart,
      tsEnd: timestamp(),
      sessionId: route?.sessionId || null,
      method: request.method,
      path: redactPath(request.url || ''),
      endpointClass: parsedRequest?.pathname.startsWith('/__control/') ? 'control' :
        route ? endpointClass(route.upstreamPath) : 'other',
      replica: null,
      fault: null,
      episode: null,
      upstreamStatus: null,
      statusReturned: response.statusCode,
      durationMs: Date.now() - startedMs,
      clientAborted: false
    });
  });
  let parsed;
  try {
    parsed = new URL(request.url, 'http://gateway.local');
  } catch {
    sendJson(response, 400, { error: 'invalid URL' });
    return;
  }

  if (parsed.pathname.startsWith('/__control/')) {
    try {
      await handleControl(request, response, parsed.pathname, requestStart);
    } catch (error) {
      sendJson(response, 400, { error: error.message });
    }
    return;
  }

  const route = findSessionRoute(parsed.pathname);
  const session = route && sessions.get(route.sessionId);
  if (!route || !session) {
    sendJson(response, 404, { error: 'session route is not registered' });
    return;
  }
  proxy(request, response, session, route, requestStart);
}

const server = http.createServer((request, response) => {
  handleRequest(request, response).catch((error) => {
    if (!response.headersSent) sendJson(response, 500, { error: error.message });
    else response.destroy();
  });
});

server.listen(options.port, '127.0.0.1', () => {
  const address = server.address();
  process.stdout.write(`${JSON.stringify({ status: 'ready', port: address.port })}\n`);
});
