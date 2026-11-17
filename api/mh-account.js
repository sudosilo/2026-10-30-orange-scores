const L = require('./_lib.js');
const M = require('./_mh.js');

// POST { action: 'create' | 'login', name, pass } returns a sign in token.
module.exports = async function (req, res) {
  if (L.start(req, res)) return;
  if (req.method !== 'POST') return L.fail(res, 405, 'method_not_allowed');
  const b = L.body(req);
  if (!b) return L.fail(res, 413, 'bad_body');
  const name = typeof b.name === 'string' ? b.name.trim().toLowerCase() : '';
  const pass = typeof b.pass === 'string' ? b.pass : '';
  if (!/^[a-z0-9_]{3,20}$/.test(name)) return L.fail(res, 400, 'bad_name');
  if (pass.length < 8 || pass.length > 100) return L.fail(res, 400, 'bad_password');
  if (L.textHasSlur(name)) return L.fail(res, 400, 'bad_name');
  try {
    if (!(await M.under('mha:' + L.ipKey(req), 20, 600))) return L.fail(res, 429, 'slow_down');
    if (b.action === 'create') {
      if (!(await M.under('mhc:' + L.ipKey(req), 3, 86400))) return L.fail(res, 429, 'too_many_accounts');
      const id = await M.rpc('mh_signup', { p_name: name, p_hash: M.hashPass(pass) });
      if (!id) return L.fail(res, 409, 'name_taken');
      return L.send(res, 200, { ok: true, name: name, token: M.sign(id) });
    }
    if (b.action === 'login') {
      if (!(await M.under('mhl:' + name, 10, 600))) return L.fail(res, 429, 'slow_down');
      const rows = await M.rpc('mh_login', { p_name: name });
      const row = Array.isArray(rows) ? rows[0] : null;
      if (!row || !M.checkPass(pass, row.pass_hash)) return L.fail(res, 401, 'wrong_login');
      return L.send(res, 200, { ok: true, name: name, token: M.sign(row.id) });
    }
    return L.fail(res, 400, 'bad_action');
  } catch (e) {
    L.fail(res, 503, 'service_unavailable');
  }
};
