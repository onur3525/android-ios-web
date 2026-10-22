// DESTEK BİLGİSİ KODA GÖMÜLÜ (22 Eki, kullanıcı kararı)
//   Admin düzenlemesi kaldırıldı; uygulama ve e-postalar tek sabiti kullanır.
//   Veritabanında eski bir değer kalmış olsa bile OKUNMAZ.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { simdi } = await import('../src/db.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { DESTEK_BILGISI } = await import('../src/destek_bilgisi.js');

let db, sunucu, taban, cerez;
before(async () => {
  db = await testDb();
  // Eski panelden kalmış farklı bir değer: artık kullanılmamalı.
  await db.prepare('INSERT INTO support_info (id, description, email, updated_at) VALUES (1, ?, ?, ?)').run('Eski açıklama metni', 'eski@ornek.com', simdi());
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const sir = base32Uret();
  await db.prepare("INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, 'd@hc.test', 'D', 'super_admin', ?, ?, ?)")
    .run(randomUUID(), sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 'd@hc.test', password: 'GucluSifre12345' }) });
  cerez = g.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: cerez, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('sabit: destek@hizmetcep.com', () => {
  assert.equal(DESTEK_BILGISI.email, 'destek@hizmetcep.com');
  assert.ok(Object.isFrozen(DESTEK_BILGISI));
});

test('uygulamanın Destek Merkezi sabiti alır (veritabanındaki eski değer okunmaz)', async () => {
  const r = await fetch(`${taban}/api/v1/legal/support`).then((x) => x.json());
  assert.deepEqual(r, { description: DESTEK_BILGISI.description, email: 'destek@hizmetcep.com' });
});

test('admin düzenleme uçları kaldırıldı', async () => {
  const h = { Cookie: cerez, 'X-HC-Admin': '1', 'Content-Type': 'application/json' };
  assert.equal((await fetch(`${taban}/admin/v1/support`, { headers: h })).status, 404);
  assert.equal((await fetch(`${taban}/admin/v1/support`, { method: 'PUT', headers: h, body: JSON.stringify({ description: 'yeni açıklama metni', email: 'x@y.z' }) })).status, 404);
});
