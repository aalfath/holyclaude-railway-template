// Creates or updates CloudCLI's single login from CLOUDCLI_USERNAME and
// CLOUDCLI_PASSWORD before the public port opens. Upstream CloudCLI lets the
// first visitor create the account, which is unsafe on a public URL.
// - No account yet: create it from the variables.
// - Account exists: apply the variables only when they changed since the last
//   boot, so a password changed in the web UI survives redeploys until you
//   edit the variable (which is also how you reset a forgotten password).
import { createRequire } from 'node:module';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const APP = '/usr/local/lib/node_modules/@cloudcli-ai/cloudcli';
const require = createRequire(`${APP}/package.json`);
const bcrypt = require('bcrypt');
const { initializeDatabase } = await import(`${APP}/dist-server/server/modules/database/init-db.js`);
const { getConnection, closeConnection } = await import(`${APP}/dist-server/server/modules/database/connection.js`);

const say = (m) => console.log(`[railway] ${m}`);
const username = (process.env.CLOUDCLI_USERNAME || '').trim();
const password = process.env.CLOUDCLI_PASSWORD || '';
if (username.length < 3 || password.length < 12) {
  say('login variables missing or too short; refusing to start');
  process.exit(1);
}
const marker = path.join(path.dirname(process.env.DATABASE_PATH), '.railway-login');
const fingerprint = crypto.createHash('sha256').update(`${username}\0${password}`).digest('hex');
const previous = fs.existsSync(marker) ? fs.readFileSync(marker, 'utf8').trim() : '';

const log = console.log;
console.log = () => {};
await initializeDatabase();
console.log = log;
const db = getConnection();
const users = db.prepare('SELECT id, username FROM users ORDER BY id').all();

if (users.length === 0) {
  db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)').run(username, bcrypt.hashSync(password, 12));
  say(`login "${username}" created from the service variables`);
} else if (previous !== fingerprint) {
  db.prepare('UPDATE users SET username = ?, password_hash = ?, is_active = 1 WHERE id = ?')
    .run(username, bcrypt.hashSync(password, 12), users[0].id);
  // A new signing secret signs every browser out after a login change.
  db.prepare("DELETE FROM app_config WHERE key = 'jwt_secret'").run();
  say(`login set to "${username}" from the service variables; every browser was signed out`);
} else {
  say(`login "${users[0].username}" unchanged`);
}
closeConnection();
fs.writeFileSync(marker, fingerprint + '\n', { mode: 0o600 });
