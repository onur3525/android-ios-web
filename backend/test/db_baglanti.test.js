// Veritabanı bağlantısı, göçler ve temel CRUD — HER İKİ sürücüde:
//   yerel/CI SQLite (geçici dosya) · CI PostgreSQL 16 (HC_TEST_DB=postgres,
//   dosyaya özel rastgele şema). ⚠ Canlı veritabanı bilgisi KULLANILMAZ;
//   bu test canlı bağlantının çalıştığını KANITLAMAZ.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { veritabaniAc, gocDosyalari, simdi, tekilIhlaliMi } from '../src/db.js';

const pg = process.env.HC_TEST_DB === 'postgres';
const klasor = mkdtempSync(join(tmpdir(), 'hc-db-'));
const ayar = pg
  ? { surucu: 'postgres', url: process.env.HC_DATABASE_URL, ssl: false, sema: `t_${randomUUID().replace(/-/g, '').slice(0, 20)}` }
  : { surucu: 'sqlite', yol: join(klasor, 'test.db') };
const acik = [];
const ac = async () => { const d = await veritabaniAc(ayar); acik.push(d); return d; };
after(async () => {
  for (const d of acik) await d.close();
  rmSync(klasor, { recursive: true, force: true });
});

const kullaniciEkle = (db, id, tel) => db.prepare(
  `INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, created_at, updated_at)
   VALUES (?, ?, NULL, 'Deneme', 'x', TRUE, FALSE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, ?, ?)`,
).run(id, tel, simdi(), simdi());

let db;
const ID = randomUUID();

test('bağlantı açılır ve BÜTÜN göçler sırayla uygulanır', async () => {
  db = await ac();
  assert.equal(db.surucu, ayar.surucu);
  const uygulanan = (await db.prepare('SELECT id FROM schema_migrations ORDER BY id').all()).map((x) => x.id);
  const beklenen = gocDosyalari(ayar.surucu).map((g) => g.id).sort();
  assert.deepEqual(uygulanan, beklenen);
  assert.ok(beklenen.length >= 13, 'göç dosyaları okunamadı');
});

test('CRUD: ekle → oku → güncelle → sil', async () => {
  await kullaniciEkle(db, ID, '5390000001');
  const u = await db.prepare('SELECT name, status FROM users WHERE id = ?').get(ID);
  assert.deepEqual({ ...u }, { name: 'Deneme', status: 'ACTIVE' });
  const g = await db.prepare('UPDATE users SET name = ? WHERE id = ?').run('Güncel', ID);
  assert.equal(g.changes, 1);
  assert.equal((await db.prepare('SELECT name FROM users WHERE id = ?').get(ID)).name, 'Güncel');
  const gecici = randomUUID();
  await kullaniciEkle(db, gecici, '5390000002');
  assert.equal((await db.prepare('DELETE FROM users WHERE id = ?').run(gecici)).changes, 1);
  assert.equal(await db.prepare('SELECT id FROM users WHERE id = ?').get(gecici), undefined);
});

test('tekil kısıt ihlali tanınır (500 yerine anlamlı yanıt için)', async () => {
  await assert.rejects(() => kullaniciEkle(db, ID, '5390000003'), (e) => tekilIhlaliMi(e));
});

test('işlem: hata olursa geri alınır, başarıda kalıcı olur', async () => {
  await assert.rejects(() => db.tx(async () => {
    await db.prepare('UPDATE users SET name = ? WHERE id = ?').run('GeriAlinacak', ID);
    throw new Error('bilerek');
  }), /bilerek/);
  assert.equal((await db.prepare('SELECT name FROM users WHERE id = ?').get(ID)).name, 'Güncel');
  await db.tx(async () => { await db.prepare('UPDATE users SET name = ? WHERE id = ?').run('Kalici', ID); });
  assert.equal((await db.prepare('SELECT name FROM users WHERE id = ?').get(ID)).name, 'Kalici');
});

test('yeniden açılış: göçler İKİNCİ KEZ uygulanmaz, veri korunur', async () => {
  const ikinci = await ac();
  const n = Number((await ikinci.prepare('SELECT COUNT(*) n FROM schema_migrations').get()).n);
  assert.equal(n, gocDosyalari(ayar.surucu).length);
  assert.equal((await ikinci.prepare('SELECT name FROM users WHERE id = ?').get(ID)).name, 'Kalici');
});

test('PostgreSQL: geçersiz şema adı reddedilir (SQL enjeksiyonu yok)', { skip: !pg && 'yalnız HC_TEST_DB=postgres' }, async () => {
  await assert.rejects(() => veritabaniAc({ ...ayar, sema: 'x; DROP SCHEMA public' }), /Geçersiz şema adı/);
});
