// YASAL METİNLER — SİSTEMLE UYUM (054, 6 Kas)
//   · Yeni kurulumda (boş veritabanı) 053 ve 054 sırayla yayımlanır; her
//     belgede tek yayım sürümü vardır; özet (SHA-256) metinle aynıdır.
//   · Canlıdaki durum (053 yayımda) → 054 yayıma geçer, 053 arşivlenir;
//     tekrar çalışınca çoğalmaz; Çerez ve Ticari İleti değişmez.
//   · Metindeki sayılar sistemdeki kurallarla AYNI (48 saat, 3 teklif,
//     30 saat); iç madde atıfları doğru.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { baslangicVerisiniHazirla, GUNCEL_YASAL_GOCLER } = await import('../src/baslangic_verisi.js');
const { ILAN_OMRU_MS, ILAN_AZAMI_TEKLIF } = await import('../src/routes/ilan.js');

let db;
const yayimda = (slug) => db.prepare(`SELECT * FROM legal_versions WHERE slug = ? AND status = 'PUBLISHED'`).get(slug);
const sql = (surucu, ad) => readFileSync(new URL(`../migrations/${surucu}/${ad}.sql`, import.meta.url), 'utf8');

before(async () => {
  db = await testDb();
  await baslangicVerisiniHazirla(db);
});
after(async () => { await db?.close(); });

test('054 iki veritabanında aynı ve yeni kurulumda 053\'ten sonra çalışır', () => {
  assert.deepEqual(GUNCEL_YASAL_GOCLER, ['053_yasal_yeni_surum', '054_yasal_sistem_uyumu']);
  const p = sql('postgres', '054_yasal_sistem_uyumu').split('\n').slice(1).join('\n');
  const s = sql('sqlite', '054_yasal_sistem_uyumu').split('\n').slice(1).join('\n');
  assert.equal(p, s);
});

test('yeni kurulum: her belgede tek yayım sürümü; 054 metinleri yayımda; özet doğru', async () => {
  for (const [slug, id] of [['terms', 'f001'], ['kvkk', 'f002'], ['privacy', 'f003']]) {
    const y = await yayimda(slug);
    assert.equal(y.id, `7b0e6f2a-3c1d-4e5f-9a8b-06112026${id}`, slug);
    assert.equal(createHash('sha256').update(y.body).digest('hex'), y.sha256, `${slug}: özet`);
  }
  for (const slug of ['terms', 'kvkk', 'privacy', 'cookies', 'marketing']) {
    assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM legal_versions WHERE slug = ? AND status = 'PUBLISHED'`).get(slug)).n), 1, slug);
  }
  // 053 sürümleri silinmedi, arşivde.
  assert.equal((await db.prepare(`SELECT status FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-05112026f001'`).get()).status, 'ARCHIVED');
  // Çerez ve Ticari İleti 053'teki gibi.
  assert.equal((await yayimda('marketing')).id, '7b0e6f2a-3c1d-4e5f-9a8b-05112026f004');
});

test('tekrar çalışınca çoğalmaz; panelden yayımlanmış sürüme dokunmaz', async () => {
  const once = Number((await db.prepare('SELECT COUNT(*) n FROM legal_versions').get()).n);
  await db.exec(sql(db.surucu, '054_yasal_sistem_uyumu'));
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM legal_versions').get()).n), once);
});

test('metindeki kurallar sistemle aynı; iç atıflar doğru', async () => {
  const t = (await yayimda('terms')).body;
  const k = (await yayimda('kvkk')).body;
  const g = (await yayimda('privacy')).body;
  assert.ok(t.includes(`${ILAN_OMRU_MS / 3_600_000} saat yayında kalır`), 'ilan süresi');
  assert.ok(t.includes(`en fazla ${ILAN_AZAMI_TEKLIF} Hizmet Veren teklif verebilir`), 'teklif sınırı');
  const talepSaat = Number(readFileSync(new URL('../src/routes/sohbet_talep.js', import.meta.url), 'utf8')
    .match(/const TALEP_TEKLIF_OMRU = (\d+) \* 60 \* 60 \* 1000;/)[1]);
  assert.ok(t.includes(`${talepSaat} saat içinde`), 'teklif talebi süresi');
  // Madde numaraları 1..23 sırayla; atıflar var olan maddelere.
  const basliklar = [...t.matchAll(/^## Madde (\d+) – (.+)$/gm)].map((m) => [Number(m[1]), m[2]]);
  assert.deepEqual(basliklar.map((b) => b[0]), Array.from({ length: 23 }, (_, i) => i + 1));
  const ad = Object.fromEntries(basliklar);
  assert.match(ad[8], /Sıralama/);
  assert.match(ad[9], /Yorum/);
  assert.match(ad[14], /Tedbirler/);
  assert.match(ad[15], /dondurma ve silme/);
  assert.match(ad[20], /güncelleme/);
  assert.ok(t.includes("Madde 14'e göre kapatılabilir"));
  assert.ok(t.includes("Madde 20'ye göre yapılır"));
  assert.ok(g.includes("Kullanım Sözleşmesi'nin 15. maddesinde"));
  assert.ok(k.includes("Gizlilik Politikası'nın 8. maddesindedir"));
  assert.match(g, /^## 8\. Diğer kullanıcıların görebildiği bilgiler$/m);
  // Profili eksik hizmet veren aktif değil; e-posta/telefon değişiminde şifre yok.
  assert.ok(t.includes('Platform\'da aktif hesap sayılmaz'));
  assert.ok(t.includes('Bu iki işlemde mevcut şifre istenmez'));
  // Eski, artık yanlış ifadeler kalmadı.
  assert.ok(!t.includes('uygulamada gösterilen süre sonunda kendiliğinden kapanır'));
  assert.ok(!g.includes("Sözleşmesi'nin 13. maddesinde"));
});
