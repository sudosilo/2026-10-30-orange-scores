const MANIFESTS = require('./_manifests.js');

// Public and read only. Copies of a game can live on any server, a flash drive or
// a file on disk, so every origin may read this.
module.exports = function (req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Cache-Control', 'public, max-age=60');
  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    return res.end();
  }
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  if (req.method !== 'GET') {
    res.statusCode = 405;
    return res.end(JSON.stringify({ ok: false, error: 'method_not_allowed' }));
  }
  const g = typeof req.query.game === 'string' ? req.query.game : '';
  if (!Object.prototype.hasOwnProperty.call(MANIFESTS, g)) {
    res.statusCode = 404;
    return res.end(JSON.stringify({ ok: false, error: 'unknown_game' }));
  }
  res.statusCode = 200;
  res.end(JSON.stringify(Object.assign({ ok: true, game: g }, MANIFESTS[g])));
};
