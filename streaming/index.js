// @ts-check

const os = require('os');
const throng = require('throng');
const dotenv = require('dotenv');
const express = require('express');
const http = require('http');
const redis = require('redis');
const pg = require('pg');
const log = require('npmlog');
const url = require('url');
const uuid = require('uuid');
const fs = require('fs');
const WebSocket = require('ws');

const env = process.env.NODE_ENV || 'development';
const alwaysRequireAuth = process.env.LIMITED_FEDERATION_MODE === 'true' || process.env.WHITELIST_MODE === 'true' || process.env.AUTHORIZED_FETCH === 'true';

dotenv.config({
  path: env === 'production' ? '.env.production' : '.env',
});

log.level = process.env.LOG_LEVEL || 'verbose';

/**
 * @param {string} dbUrl
 * @return {Object.<string, any>}
 */
const dbUrlToConfig = (dbUrl) => {
  if (!dbUrl) {
    return {};
  }

  const params = url.parse(dbUrl, true);
  const config = {};

  if (params.auth) {
    [config.user, config.password] = params.auth.split(':');
  }

  if (params.hostname) {
    config.host = params.hostname;
  }

  if (params.port) {
    config.port = params.port;
  }

  if (params.pathname) {
    config.database = params.pathname.split('/')[1];
  }

  const ssl = params.query && params.query.ssl;

  if (ssl && ssl === 'true' || ssl === '1') {
    config.ssl = true;
  }

  return config;
};

/**
 * @param {Object.<string, any>} defaultConfig
 * @param {string} redisUrl
 */
const redisUrlToClient = (defaultConfig, redisUrl) => {
  const config = defaultConfig;

  if (!redisUrl) {
    return redis.createClient(config);
  }

  if (redisUrl.startsWith('unix://')) {
    return redis.createClient(redisUrl.slice(7), config);
  }

  return redis.createClient(Object.assign(config, {
    url: redisUrl,
  }));
};

const numWorkers = +process.env.STREAMING_CLUSTER_NUM || (env === 'development' ? 1 : Math.max(os.cpus().length - 1, 1));

/**
 * @param {string} json
 * @return {Object.<string, any>|null}
 */
const parseJSON = (json) => {
  try {
    return JSON.parse(json);
  } catch (err) {
    log.error(err);
    return null;
  }
};

const startMaster = () => {
  if (!process.env.SOCKET && process.env.PORT && isNaN(+process.env.PORT)) {
    log.warn('UNIX domain socket is now supported by using SOCKET. Please migrate from PORT hack.');
  }

  log.warn(`Starting streaming API server master with ${numWorkers} workers`);
};

const startWorker = (workerId) => {
  log.warn(`Starting worker ${workerId}`);

  const pgConfigs = {
    development: {
      user:     process.env.DB_USER || pg.defaults.user,
      password: process.env.DB_PASS || pg.defaults.password,
      database: process.env.DB_NAME || 'mastodon_development',
      host:     process.env.DB_HOST || pg.defaults.host,
      port:     process.env.DB_PORT || pg.defaults.port,
      max:      10,
    },

    production: {
      user:     process.env.DB_USER || 'mastodon',
      password: process.env.DB_PASS || '',
      database: process.env.DB_NAME || 'mastodon_production',
      host:     process.env.DB_HOST || 'localhost',
      port:     process.env.DB_PORT || 5432,
      max:      10,
    },
  };

  if (!!process.env.DB_SSLMODE && process.env.DB_SSLMODE !== 'disable') {
    pgConfigs.development.ssl = true;
    pgConfigs.production.ssl  = true;
  }

  const app = express();

  app.set('trusted proxy', process.env.TRUSTED_PROXY_IP || 'loopback,uniquelocal');

  const pgPool = new pg.Pool(Object.assign(pgConfigs[env], dbUrlToConfig(process.env.DATABASE_URL)));
  const server = http.createServer(app);
  const redisNamespace = process.env.REDIS_NAMESPACE || null;

  const redisParams = {
    host:     process.env.REDIS_HOST     || '127.0.0.1',
    port:     process.env.REDIS_PORT     || 6379,
    db:       process.env.REDIS_DB       || 0,
    password: process.env.REDIS_PASSWORD || undefined,
  };

  if (redisNamespace) {
    redisParams.namespace = redisNamespace;
  }

  const redisPrefix = redisNamespace ? `${redisNamespace}:` : '';

  const redisSubscribeClient = redisUrlToClient(redisParams, process.env.REDIS_URL);
  const redisClient = redisUrlToClient(redisParams, process.env.REDIS_URL);

  /**
   * @type {Object.<string, Array.<function(string): void>>}
   */
  const subs = {};

  redisSubscribeClient.on('message', (channel, message) => {
    const callbacks = subs[channel];

    log.silly(`New message on channel ${channel}`);

    if (!callbacks) {
      return;
    }

    callbacks.forEach(callback => callback(message));
  });

  /**
   * @param {string[]} channels
   * @return {function(): void}
   */
  const subscriptionHeartbeat = channels => {
    const interval = 6 * 60;

    const tellSubscribed = () => {
      channels.forEach(channel => redisClient.set(`${redisPrefix}subscribed:${channel}`, '1', 'EX', interval * 3));
    };

    tellSubscribed();

    const heartbeat = setInterval(tellSubscribed, interval * 1000);

    return () => {
      clearInterval(heartbeat);
    };
  };

  /**
   * @param {string} channel
   * @param {function(string): void} callback
   */
  const subscribe = (channel, callback) => {
    log.silly(`Adding listener for ${channel}`);
    subs[channel] = subs[channel] || [];

    if (subs[channel].length === 0) {
      log.verbose(`Subscribe ${channel}`);
      redisSubscribeClient.subscribe(channel);
    }

    subs[channel].push(callback);
  };

  /**
   * @param {string} channel
   * @param {function(string): void} callback
   */
  const unsubscribe = (channel, callback) => {
    log.silly(`Removing listener for ${channel}`);

    if (!subs[channel]) {
      return;
    }

    subs[channel] = subs[channel].filter(item => item !== callback);

    if (subs[channel].length === 0) {
      log.verbose(`Unsubscribe ${channel}`);
      redisSubscribeClient.unsubscribe(channel);
      delete subs[channel];
    }
  };

  const FALSE_VALUES = [
    false,
    0,
    '0',
    'f',
    'F',
    'false',
    'FALSE',
    'off',
    'OFF',
  ];

  /**
   * @param {any} value
   * @return {boolean}
   */
  const isTruthy = value =>
    value && !FALSE_VALUES.includes(value);

  /**
   * @param {any} req
   * @param {any} res
   * @param {function(Error=): void}
   */
  const allowCrossDomain = (req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Authorization, Accept, Cache-Control');
    res.header('Access-Control-Allow-Methods', 'GET, OPTIONS');

    next();
  };

  /**
   * @param {any} req
   * @param {any} res
   * @param {function(Error=): void}
   */
  const setRequestId = (req, res, next) => {
    req.requestId = uuid.v4();
    res.header('X-Request-Id', req.requestId);

    next();
  };

  /**
   * @param {any} req
   * @param {any} res
   * @param {function(Error=): void}
   */
  const setRemoteAddress = (req, res, next) => {
    req.remoteAddress = req.connection.remoteAddress;

    next();
  };

  /**
   * @param {string} token
   * @param {any} req
   * @return {Promise.<void>}
   */
  const accountFromToken = (token, req) => new Promise((resolve, reject) => {
    pgPool.connect((err, client, done) => {
      if (err) {
        reject(err);
        return;
      }

      client.query('SELECT oauth_access_tokens.id, oauth_access_tokens.resource_owner_id, users.account_id, users.chosen_languages, oauth_access_tokens.scopes, devices.device_id FROM oauth_access_tokens INNER JOIN users ON oauth_access_tokens.resource_owner_id = users.id LEFT OUTER JOIN devices ON oauth_access_tokens.id = devices.access_token_id WHERE oauth_access_tokens.token = $1 AND oauth_access_tokens.revoked_at IS NULL LIMIT 1', [token], (err, result) => {
        done();

        if (err) {
          reject(err);
          return;
        }

        if (result.rows.length === 0) {
          err = new Error('Invalid access token');
          err.status = 401;

          reject(err);
          return;
        }

        req.accessTokenId = result.rows[0].id;
        req.scopes = result.rows[0].scopes.split(' ');
        req.accountId = result.rows[0].account_id;
        req.chosenLanguages = result.rows[0].chosen_languages;
        req.allowNotifications = req.scopes.some(scope => ['read', 'read:notifications'].includes(scope));
        req.deviceId = result.rows[0].device_id;

        resolve();
      });
    });
  });

  /**
   * @param {any} req
   * @param {boolean=} required
   * @return {Promise.<void>}
   */
  const accountFromRequest = (req, required = true) => new Promise((resolve, reject) => {
    const authorization = req.headers.authorization;
    const location      = url.parse(req.url, true);
    const accessToken   = location.query.access_token || req.headers['sec-websocket-protocol'];

    if (!authorization && !accessToken) {
      if (required) {
        const err = new Error('Missing access token');
        err.status = 401;

        reject(err);
        return;
      } else {
        resolve();
        return;
      }
    }

    const token = authorization ? authorization.replace(/^Bearer /, '') : accessToken;

    resolve(accountFromToken(token, req));
  });

  /**
   * @param {any} req
   * @return {string}
   */
  const channelNameFromPath = req => {
    const { path, query } = req;
    const onlyMedia = isTruthy(query.only_media);

    switch(path) {
    case '/api/v1/streaming/user':
      return 'user';
    case '/api/v1/streaming/user/notification':
      return 'user:notification';
    case '/api/v1/streaming/public':
      return onlyMedia ? 'public:media' : 'public';
    case '/api/v1/streaming/public/local':
      return onlyMedia ? 'public:local:media' : 'public:local';
    case '/api/v1/streaming/public/remote':
      return onlyMedia ? 'public:remote:media' : 'public:remote';
    case '/api/v1/streaming/hashtag':
      return 'hashtag';
    case '/api/v1/streaming/hashtag/local':
      return 'hashtag:local';
    case '/api/v1/streaming/direct':
      return 'direct';
    case '/api/v1/streaming/list':
      return 'list';
    default:
      return undefined;
    }
  };

  const PUBLIC_CHANNELS = [
    'public',
    'public:media',
    'public:local',
    'public:local:media',
    'public:remote',
    'public:remote:media',
    'hashtag',
    'hashtag:local',
  ];

  /**
   * @param {any} req
   * @param {string} channelName
   * @return {Promise.<void>}
   */
  const checkScopes = (req, channelName) => new Promise((resolve, reject) => {
    log.silly(req.requestId, `Checking OAuth scopes for ${channelName}`);

    // When accessing public channels, no scopes are needed
    if (PUBLIC_CHANNELS.includes(channelName)) {
      resolve();
      return;
    }

    // The `read` scope has the highest priority, if the token has it
    // then it can access all streams
    const requiredScopes = ['read'];

    // When accessing specifically the notifications stream,
    // we need a read:notifications, while in all other cases,
    // we can allow access with read:statuses. Mind that the
    // user stream will not contain notifications unless
    // the token has either read or read:notifications scope
    // as well, this is handled separately.
    if (channelName === 'user:notification') {
      requiredScopes.push('read:notifications');
    } else {
      requiredScopes.push('read:statuses');
    }

    if (requiredScopes.some(requiredScope => req.scopes.includes(requiredScope))) {
      resolve();
      return;
    }

    const err = new Error('Access token does not cover required scopes');
    err.status = 401;

    reject(err);
  });

  /**
   * @param {any} info
   * @param {function(boolean, number, string): void} callback
   */
  const wsVerifyClient = (info, callback) => {
    // When verifying the websockets connection, we no longer pre-emptively
    // check OAuth scopes and drop the connection if they're missing. We only
    // drop the connection if access without token is not allowed by environment
    // variables. OAuth scope checks are moved to the point of subscription
    // to a specific stream.

    accountFromRequest(info.req, alwaysRequireAuth).then(() => {
      callback(true, undefined, undefined);
    }).catch(err => {
      log.error(info.req.requestId, err.toString());
      callback(false, 401, 'Unauthorized');
    });
  };

  /**
   * @typedef SystemMessageHandlers
   * @property {function(): void} onKill
   */

  /**
   * @param {any} req
   * @param {SystemMessageHandlers} eventHandlers
   * @return {function(string): void}
   */
  const createSystemMessageListener = (req, eventHandlers) => {
    return message => {
      const json = parseJSON(message);

      if (!json) return;

      const { event } = json;

      log.silly(req.requestId, `System message for ${req.accountId}: ${event}`);

      if (event === 'kill') {
        log.verbose(req.requestId, `Closing connection for ${req.accountId} due to expired access token`);
        eventHandlers.onKill();
      }
    };
  };

  /**
   * @param {any} req
   * @param {any} res
   */
  const subscribeHttpToSystemChannel = (req, res) => {
    const systemChannelId = `timeline:access_token:${req.accessTokenId}`;

    const listener = createSystemMessageListener(req, {

      onKill () {
        res.end();
      },

    });

    res.on('close', () => {
      unsubscribe(`${redisPrefix}${systemChannelId}`, listener);
    });

    subscribe(`${redisPrefix}${systemChannelId}`, listener);
  };

  /**
   * @param {any} req
   * @param {any} res
   * @param {function(Error=): void} next
   */
  const authenticationMiddleware = (req, res, next) => {
    if (req.method === 'OPTIONS') {
      next();
      return;
    }

    accountFromRequest(req, alwaysRequireAuth).then(() => checkScopes(req, channelNameFromPath(req))).then(() => {
      subscribeHttpToSystemChannel(req, res);
    }).then(() => {
      next();
    }).catch(err => {
      next(err);
    });
  };

  /**
   * @param {Error} err
   * @param {any} req
   * @param {any} res
   * @param {function(Error=): void} next
   */
  const errorMiddleware = (err, req, res, next) => {
    log.error(req.requestId, err.toString());

    if (res.headersSent) {
      next(err);
      return;
    }

    res.writeHead(err.status || 500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: err.status ? err.toString() : 'An unexpected error occurred' }));
  };

  /**
   * @param {array}
   * @param {number=} shift
   * @return {string}
   */
  const placeholders = (arr, shift = 0) => arr.map((_, i) => `$${i + 1 + shift}`).join(', ');

  /**
   * @param {string} listId
   * @param {any} req
   * @return {Promise.<void>}
   */
  const authorizeListAccess = (listId, req) => new Promise((resolve, reject) => {
    const { accountId } = req;

    pgPool.connect((err, client, done) => {
      if (err) {
        reject();
        return;
      }

      client.query('SELECT id, account_id FROM lists WHERE id = $1 LIMIT 1', [listId], (err, result) => {
        done();

        if (err || result.rows.length === 0 || result.rows[0].account_id !== accountId) {
          reject();
          return;
        }

        resolve();
      });
    });
  });

  /**
   * @param {string[]} ids
   * @param {any} req
   * @param {function(string, string): void} output
   * @param {function(string[], function(string): void): void} attachCloseHandler
   * @param {boolean=} needsFiltering
   * @param {boolean=} notificationOnly
   * @return {function(string): void}
   */
  const streamFrom = (ids, req, output, attachCloseHandler, needsFiltering = false, notificationOnly = false) => {
    const accountId  = req.accountId || req.remoteAddress;
    const streamType = notificationOnly ? ' (notification)' : '';

    log.verbose(req.requestId, `Starting stream from ${ids.join(', ')} for ${accountId}${streamType}`);

    const listener = message => {
      const json = parseJSON(message);

      if (!json) return;

      const { event, payload, queued_at } = json;

      const transmit = () => {
        const now            = new Date().getTime();
        const delta          = now - queued_at;
        const encodedPayload = typeof payload === 'object' ? JSON.stringify(payload) : payload;

        log.silly(req.requestId, `Transmitting for ${accountId}: ${event} ${encodedPayload} Delay: ${delta}ms`);
        output(event, encodedPayload);
      };

      if (notificationOnly && event !== 'notification') {
        return;
      }

      if (event === 'notification' && !req.allowNotifications) {
        return;
      }

      // Only send local-only statuses to logged-in users
      if (payload.local_only && !req.accountId) {
        log.silly(req.requestId, `Message ${payload.id} filtered because it was local-only`);
        return;
      }

      // Only messages that may require filtering are statuses, since notifications
      // are already personalized and deletes do not matter
      if (!needsFiltering || event !== 'update') {
        transmit();
        return;
      }

      const unpackedPayload  = payload;
      const targetAccountIds = [unpackedPayload.account.id].concat(unpackedPayload.mentions.map(item => item.id));
      const accountDomain    = unpackedPayload.account.acct.split('@')[1];

      if (Array.isArray(req.chosenLanguages) && unpackedPayload.language !== null && req.chosenLanguages.indexOf(unpackedPayload.language) === -1) {
        log.silly(req.requestId, `Message ${unpackedPayload.id} filtered by language (${unpackedPayload.language})`);
        return;
      }

      // When the account is not logged in, it is not necessary to confirm the block or mute
      if (!req.accountId) {
        transmit();
        return;
      }

      pgPool.connect((err, client, done) => {
        if (err) {
          log.error(err);
          return;
        }

        const queries = [
          client.query(`SELECT 1 FROM blocks WHERE (account_id = $1 AND target_account_id IN (${placeholders(targetAccountIds, 2)})) OR (account_id = $2 AND target_account_id = $1) UNION SELECT 1 FROM mutes WHERE account_id = $1 AND target_account_id IN (${placeholders(targetAccountIds, 2)})`, [req.accountId, unpackedPayload.account.id].concat(targetAccountIds)),
        ];

        if (accountDomain) {
          queries.push(client.query('SELECT 1 FROM account_domain_blocks WHERE account_id = $1 AND domain = $2', [req.accountId, accountDomain]));
        }

        Promise.all(queries).then(values => {
          done();

          if (values[0].rows.length > 0 || (values.length > 1 && values[1].rows.length > 0)) {
            return;
          }

          transmit();
        }).catch(err => {
          done();
          log.error(err);
        });
      });
    };

    ids.forEach(id => {
      subscribe(`${redisPrefix}${id}`, listener);
    });

    if (attachCloseHandler) {
      attachCloseHandler(ids.map(id => `${redisPrefix}${id}`), listener);
    }

    return listener;
  };

  /**
   * @param {any} req
   * @param {any} res
   * @return {function(string, string): void}
   */
  const streamToHttp = (req, res) => {
    const accountId = req.accountId || req.remoteAddress;

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Transfer-Encoding', 'chunked');

    res.write(':)\n');

    const heartbeat = setInterval(() => res.write(':thump\n'), 15000);

    req.on('close', () => {
      log.verbose(req.requestId, `Ending stream for ${accountId}`);
      clearInterval(heartbeat);
    });

    return (event, payload) => {
      res.write(`event: ${event}\n`);
      res.write(`data: ${payload}\n\n`);
    };
  };

  /**
   * @param {any} req
   * @param {function(): void} [closeHandler]
   * @return {function(string[], function(string): void)}
   */
  const streamHttpEnd = (req, closeHandler = undefined) => (ids, listener) => {
    req.on('close', () => {
      ids.forEach(id => {
        unsubscribe(id, listener);
      });

      if (closeHandler) {
        closeHandler();
      }
    });
  };

  /**
   * @param {any} req
   * @param {any} ws
   * @param {string[]} streamName
   * @return {function(string, string): void}
   */
  const streamToWs = (req, ws, streamName) => (event, payload) => {
    if (ws.readyState !== ws.OPEN) {
      log.error(req.requestId, 'Tried writing to closed socket');
      return;
    }

    ws.send(JSON.stringify({ stream: streamName, event, payload }));
  };

  /**
   * @param {any} res
   */
  const httpNotFound = res => {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  };

  app.use(setRequestId);
  app.use(setRemoteAddress);
  app.use(allowCrossDomain);

  app.get('/api/v1/streaming/health', (req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK');
  });

  app.use(authenticationMiddleware);
  app.use(errorMiddleware);

  app.get('/api/v1/streaming/*', (req, res) => {
    channelNameToIds(req, channelNameFromPath(req), req.query).then(({ channelIds, options }) => {
      const onSend = streamToHttp(req, res);
      const onEnd  = streamHttpEnd(req, subscriptionHeartbeat(channelIds));

      streamFrom(channelIds, req, onSend, onEnd, options.needsFiltering, options.notificationOnly);
    }).catch(err => {
      log.verbose(req.requestId, 'Subscription error:', err.toString());
      httpNotFound(res);
    });
  });

  const wss = new WebSocket.Server({ server, verifyClient: wsVerifyClient });

  /**
   * @typedef StreamParams
   * @property {string} [tag]
   * @property {string} [list]
   * @property {string} [only_media]
   */

  /**
   * @param {any} req
   * @param {string} name
   * @param {StreamParams} params
   * @return {Promise.<{ channelIds: string[], options: { needsFiltering: boolean, notificationOnly: boolean } }>}
   */
  const channelNameToIds = (req, name, params) => new Promise((resolve, reject) => {
    switch(name) {
    case 'user':
      resolve({
        channelIds: req.deviceId ? [`timeline:${req.accountId}`, `timeline:${req.accountId}:${req.deviceId}`] : [`timeline:${req.accountId}`],
        options: { needsFiltering: false, notificationOnly: false },
      });

      break;
    case 'user:notification':
      resolve({
        channelIds: [`timeline:${req.accountId}`],
        options: { needsFiltering: false, notificationOnly: true },
      });

      break;
    case 'public':
      resolve({
        channelIds: ['timeline:public'],
        options: { needsFiltering: true, notificationOnly: false },
      });

      break;
    case 'public:local':
      resolve({
        channelIds: ['timeline:public:local'],
        options: { needsFiltering: true, notificationOnly: false },
      });

      break;
    case 'public:remote':
      resolve({
        channelIds: ['timeline:public:remote'],
        options: { needsFiltering: true, notificationOnly: false },
      });

      break;
    case 'public:media':
      resolve({
        channelIds: ['timeline:public:media'],
        options: { needsFiltering: true, notificationOnly: false },
      });

      break;
    case 'public:local:media':
      resolve({
        channelIds: ['timeline:public:local:media'],
        options: { needsFiltering: true, notificationOnly: false },
      });

      break;
    case 'public:remote:media':
      resolve({
        channelIds: ['timeline:public:remote:media'],
        options: { needsFiltering: true, notificationOnly: false },
      });

      break;
    case 'direct':
      resolve({
        channelIds: [`timeline:direct:${req.accountId}`],
        options: { needsFiltering: false, notificationOnly: false },
      });

      break;
    case 'hashtag':
      if (!params.tag || params.tag.length === 0) {
        reject('No tag for stream provided');
      } else {
        resolve({
          channelIds: [`timeline:hashtag:${params.tag.toLowerCase()}`],
          options: { needsFiltering: true, notificationOnly: false },
        });
      }

      break;
    case 'hashtag:local':
      if (!params.tag || params.tag.length === 0) {
        reject('No tag for stream provided');
      } else {
        resolve({
          channelIds: [`timeline:hashtag:${params.tag.toLowerCase()}:local`],
          options: { needsFiltering: true, notificationOnly: false },
        });
      }

      break;
    case 'list':
      authorizeListAccess(params.list, req).then(() => {
        resolve({
          channelIds: [`timeline:list:${params.list}`],
          options: { needsFiltering: false, notificationOnly: false },
        });
      }).catch(() => {
        reject('Not authorized to stream this list');
      });

      break;
    default:
      reject('Unknown stream type');
    }
  });

  /**
   * @param {string} channelName
   * @param {StreamParams} params
   * @return {string[]}
   */
  const streamNameFromChannelName = (channelName, params) => {
    if (channelName === 'list') {
      return [channelName, params.list];
    } else if (['hashtag', 'hashtag:local'].includes(channelName)) {
      return [channelName, params.tag];
    } else {
      return [channelName];
    }
  };

  /**
   * @typedef WebSocketSession
   * @property {any} socket
   * @property {any} request
   * @property {Object.<string, { listener: function(string): void, stopHeartbeat: function(): void }>} subscriptions
   */

  /**
   * @param {WebSocketSession} session
   * @param {string} channelName
   * @param {StreamParams} params
   */
  const subscribeWebsocketToChannel = ({ socket, request, subscriptions }, channelName, params) =>
    checkScopes(request, channelName).then(() => channelNameToIds(request, channelName, params)).then(({ channelIds, options }) => {
      if (subscriptions[channelIds.join(';')]) {
        return;
      }

      const onSend        = streamToWs(request, socket, streamNameFromChannelName(channelName, params));
      const stopHeartbeat = subscriptionHeartbeat(channelIds);
      const listener      = streamFrom(channelIds, request, onSend, undefined, options.needsFiltering, options.notificationOnly);

      subscriptions[channelIds.join(';')] = {
        listener,
        stopHeartbeat,
      };
    }).catch(err => {
      log.verbose(request.requestId, 'Subscription error:', err.toString());
      socket.send(JSON.stringify({ error: err.toString() }));
    });

  /**
   * @param {WebSocketSession} session
   * @param {string} channelName
   * @param {StreamParams} params
   */
  const unsubscribeWebsocketFromChannel = ({ socket, request, subscriptions }, channelName, params) =>
    channelNameToIds(request, channelName, params).then(({ channelIds }) => {
      log.verbose(request.requestId, `Ending stream from ${channelIds.join(', ')} for ${request.accountId}`);

      const subscription = subscriptions[channelIds.join(';')];

      if (!subscription) {
        return;
      }

      const { listener, stopHeartbeat } = subscription;

      channelIds.forEach(channelId => {
        unsubscribe(`${redisPrefix}${channelId}`, listener);
      });

      stopHeartbeat();

      delete subscriptions[channelIds.join(';')];
    }).catch(err => {
      log.verbose(request.requestId, 'Unsubscription error:', err);
      socket.send(JSON.stringify({ error: err.toString() }));
    });

  /**
   * @param {WebSocketSession} session
   */
  const subscribeWebsocketToSystemChannel = ({ socket, request, subscriptions }) => {
    const systemChannelId = `timeline:access_token:${request.accessTokenId}`;

    const listener = createSystemMessageListener(request, {

      onKill () {
        socket.close();
      },

    });

    subscribe(`${redisPrefix}${systemChannelId}`, listener);

    subscriptions[systemChannelId] = {
      listener,
      stopHeartbeat: () => {},
    };
  };

  /**
   * @param {string|string[]} arrayOrString
   * @return {string}
   */
  const firstParam = arrayOrString => {
    if (Array.isArray(arrayOrString)) {
      return arrayOrString[0];
    } else {
      return arrayOrString;
    }
  };

  wss.on('connection', (ws, req) => {
    const location = url.parse(req.url, true);

    req.requestId     = uuid.v4();
    req.remoteAddress = ws._socket.remoteAddress;

    ws.isAlive = true;

    ws.on('pong', () => {
      ws.isAlive = true;
    });

    /**
     * @type {WebSocketSession}
     */
    const session = {
      socket: ws,
      request: req,
      subscriptions: {},
    };

    const onEnd = () => {
      const keys = Object.keys(session.subscriptions);

      keys.forEach(channelIds => {
        const { listener, stopHeartbeat } = session.subscriptions[channelIds];

        channelIds.split(';').forEach(channelId => {
          unsubscribe(`${redisPrefix}${channelId}`, listener);
        });

        stopHeartbeat();
      });
    };

    ws.on('close', onEnd);
    ws.on('error', onEnd);

    ws.on('message', data => {
      const json = parseJSON(data);

      if (!json) return;

      const { type, stream, ...params } = json;

      if (type === 'subscribe') {
        subscribeWebsocketToChannel(session, firstParam(stream), params);
      } else if (type === 'unsubscribe') {
        unsubscribeWebsocketFromChannel(session, firstParam(stream), params);
      } else {
        // Unknown action type
      }
    });

    subscribeWebsocketToSystemChannel(session);

    if (location.query.stream) {
      subscribeWebsocketToChannel(session, firstParam(location.query.stream), location.query);
    }
  });

  setInterval(() => {
    wss.clients.forEach(ws => {
      if (ws.isAlive === false) {
        ws.terminate();
        return;
      }

      ws.isAlive = false;
      ws.ping('', false);
    });
  }, 30000);

  attachServerWithConfig(server, address => {
    log.warn(`Worker ${workerId} now listening on ${address}`);
  });

  const onExit = () => {
    log.warn(`Worker ${workerId} exiting`);
    server.close();
    process.exit(0);
  };

  const onError = (err) => {
    log.error(err);
    server.close();
    process.exit(0);
  };

  process.on('SIGINT', onExit);
  process.on('SIGTERM', onExit);
  process.on('exit', onExit);
  process.on('uncaughtException', onError);
};

/**
 * @param {any} server
 * @param {function(string): void} [onSuccess]
 */
const attachServerWithConfig = (server, onSuccess) => {
  if (process.env.SOCKET || process.env.PORT && isNaN(+process.env.PORT)) {
    server.listen(process.env.SOCKET || process.env.PORT, () => {
      if (onSuccess) {
        fs.chmodSync(server.address(), 0o666);
        onSuccess(server.address());
      }
    });
  } else {
    server.listen(+process.env.PORT || 4000, process.env.BIND || '127.0.0.1', () => {
      if (onSuccess) {
        onSuccess(`${server.address().address}:${server.address().port}`);
      }
    });
  }
};

/**
 * @param {function(Error=): void} onSuccess
 */
const onPortAvailable = onSuccess => {
  const testServer = http.createServer();

  testServer.once('error', err => {
    onSuccess(err);
  });

  testServer.once('listening', () => {
    testServer.once('close', () => onSuccess());
    testServer.close();
  });

  attachServerWithConfig(testServer);
};

onPortAvailable(err => {
  if (err) {
    log.error('Could not start server, the port or socket is in use');
    return;
  }

  throng({
    workers: numWorkers,
    lifetime: Infinity,
    start: startWorker,
    master: startMaster,
  });
});
