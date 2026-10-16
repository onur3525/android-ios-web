// 16 Eki — Yönetici MFA yenileme bakım aracı (GitHub Actions). Kural:
// src/bakim/admin_mfa_yenileme.js. Gerçek canlı veritabanına dokunulmaz;
// bellek içi veritabanında tüm güvenlik kontrolleri sınanır.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createCipheriv, randomBytes, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { anahtarParmakIzi, base32Uret, sirCoz, sirSifrele, sifreOzetle } = await import('../src/auth.js');
const { adminMfaYenile, yeniSirDogrula } = await import('../src/bakim/admin_mfa_yenileme.js');

const HEDEF = 'onur_butun@hotmail.com';
/** Başka bir ana anahtarla şifrelenmiş sır (canlıdaki durumun aynısı). */
function baskaAnahtarlaSifrele(duz) {
  const iv = randomBytes(12);
  const c = createCipheriv('aes-256-gcm', randomBytes(32), iv);
  const icerik = Buffer.concat([c.update(duz, 'utf8'), c.final()]);
  return `v1.${iv.toString('base64')}.${c.getAuthTag().toString('base64')}.${icerik.toString('base64')}`;
}
async function kurulum({ bozuk = true } = {}) {
  const db = await testDb();
  const id = randomUUID();
  const digerId = randomUUID();
  const eski = bozuk ? baskaAnahtarlaSifrele(base32Uret()) : sirSifrele(base32Uret());
  const digerEnc = baskaAnahtarlaSifrele(base32Uret());
  const ekle = db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, 'super_admin', ?, ?, ?)`);
  await ekle.run(id, HEDEF, 'Onur', sifreOzetle('GucluSifre12345'), eski, simdi());
  await ekle.run(digerId, 'diger@hc.test', 'Diğer', sifreOzetle('GucluSifre12345'), digerEnc, simdi());
  await db.prepare(`INSERT INTO admin_sessions (token_hash, admin_id, stage, created_at, last_seen) VALUES (?, ?, 'full', ?, ?)`).run('h1', id, simdi(), simdi());
  return { db, id, digerId, eski, digerEnc };
}
const yeni = () => base32Uret(20); // 32 karakter
const oz = () => anahtarParmakIzi();

test('kontrol modu: denetimler geçer, HİÇBİR ŞEY yazılmaz', async () => {
  const { db, id, eski } = await kurulum();
  const s = await adminMfaYenile(db, { email: HEDEF, yeniSir: yeni(), mod: 'kontrol', sunucuParmakIzi: oz() });
  assert.equal(s.durum, 'kontrol-tamam');
  assert.equal((await db.prepare('SELECT totp_secret_enc FROM admins WHERE id = ?').get(id)).totp_secret_enc, eski);
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM admin_mfa_yedekleri').get()).n), 0);
});

test('uygula: yalnız hedef hesap yenilenir; yedek, oturum kapatma, denetim; sır dönüşlerde yok', async () => {
  const { db, id, digerId, eski, digerEnc } = await kurulum();
  const sir = yeni();
  const s = await adminMfaYenile(db, { email: HEDEF, yeniSir: sir.toLowerCase().replace(/(.{4})/g, '$1 '), mod: 'uygula', sunucuParmakIzi: oz() });
  assert.equal(s.durum, 'yenilendi');
  const a = await db.prepare('SELECT totp_secret_enc, failed_count, locked_until, active FROM admins WHERE id = ?').get(id);
  assert.equal(sirCoz(a.totp_secret_enc), sir, 'yeni sır canlı anahtarla çözülür');
  assert.equal(a.active, 1, 'hesap silinmez/pasifleşmez');
  assert.ok(a.totp_secret_enc, 'MFA kapatılmaz');
  assert.equal((await db.prepare('SELECT totp_secret_enc FROM admins WHERE id = ?').get(digerId)).totp_secret_enc, digerEnc, 'diğer yöneticiye dokunulmaz');
  const yedek = await db.prepare('SELECT admin_id, eski_sir_enc FROM admin_mfa_yedekleri').all();
  assert.deepEqual(yedek.map((y) => [y.admin_id, y.eski_sir_enc]), [[id, eski]]);
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM admin_sessions WHERE admin_id = ?').get(id)).n), 0);
  assert.ok(await db.prepare(`SELECT 1 FROM audit_log WHERE action = 'admin.mfa_yenilendi' AND target_id = ?`).get(id));
  assert.ok(!JSON.stringify(s).includes(sir), 'düz sır dönüşte/mesajda yok');
});

test('güvenlik: izinsiz hesap, anahtar uyuşmazlığı, geçersiz sır, eksik parmak izi → yazma yok', async () => {
  const { db, id, eski } = await kurulum();
  await assert.rejects(adminMfaYenile(db, { email: 'diger@hc.test', yeniSir: yeni(), mod: 'uygula', sunucuParmakIzi: oz() }), /izinli/);
  await assert.rejects(adminMfaYenile(db, { email: HEDEF, yeniSir: yeni(), mod: 'uygula', sunucuParmakIzi: '0000000000000000' }), /AYNI DEĞİL/);
  await assert.rejects(adminMfaYenile(db, { email: HEDEF, yeniSir: yeni(), mod: 'uygula', sunucuParmakIzi: null }), /parmak izi/);
  await assert.rejects(adminMfaYenile(db, { email: HEDEF, yeniSir: 'KISA', mod: 'uygula', sunucuParmakIzi: oz() }), /geçersiz/);
  await assert.rejects(adminMfaYenile(db, { email: HEDEF, yeniSir: yeni(), mod: 'sil', sunucuParmakIzi: oz() }), /Mod/);
  assert.equal((await db.prepare('SELECT totp_secret_enc FROM admins WHERE id = ?').get(id)).totp_secret_enc, eski);
});

test('kontrol modu: mevcut sır çözülebilse de veritabanına yazılmaz', async () => {
  const { db, id, eski } = await kurulum({ bozuk: false });
  const sonuc = await adminMfaYenile(db, {
    email: HEDEF,
    yeniSir: yeni(),
    mod: 'kontrol',
    sunucuParmakIzi: oz()
  });

  assert.equal(sonuc.durum, 'kontrol-tamam');
  assert.equal(
    (await db.prepare('SELECT totp_secret_enc FROM admins WHERE id = ?').get(id)).totp_secret_enc,
    eski
  );
  assert.equal(
    Number((await db.prepare('SELECT COUNT(*) n FROM admin_mfa_yedekleri').get()).n),
    0
  );
});

test('yeni sır biçimi', () => {
  assert.equal(yeniSirDogrula('abcd efgh ijkl mnop qrst uvwx yz23 4567'), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567');
  assert.throws(() => yeniSirDogrula('ABCDEFGH01'), /geçersiz/);
});

test('iş akışı: yalnız elle, main, onay metni, sırlar Secrets\'tan, ürün yüklemez; göç yok', () => {
  const w = readFileSync(new URL('../../.github/workflows/admin-mfa-yenile.yml', import.meta.url), 'utf8');
  assert.match(w, /^on:\n {2}workflow_dispatch:/m);
  assert.ok(!/^\s+(push|pull_request|schedule):/m.test(w));
  assert.match(w, /if: github\.ref == 'refs\/heads\/main'/);
  assert.match(w, /"\$ONAY" != "YENILE onur_butun@hotmail\.com"/);
  assert.ok(!/upload-artifact/.test(w));
  assert.match(w, /HC_YENI_TOTP_SIRRI: \$\{\{ secrets\.HC_YENI_TOTP_SIRRI \}\}/);
  const b = readFileSync(new URL('../scripts/admin_mfa_yenile.js', import.meta.url), 'utf8');
  assert.ok(!/veritabaniAc|gocUygula/.test(b), 'bakım aracı göç çalıştırmaz');
});
