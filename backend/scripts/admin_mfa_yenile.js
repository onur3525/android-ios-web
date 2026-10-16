// ═══════════════════════════════════════════════════════════════
// YÖNETİCİ MFA YENİLEME — GitHub Actions bakım aracı (tek seferlik, elle)
// İş akışı: .github/workflows/admin-mfa-yenile.yml · Kural: src/bakim/admin_mfa_yenileme.js
//
// ⚠ GÖÇ (migration) ÇALIŞTIRMAZ: canlı veritabanına yalnız bu işin
//   sorgularıyla bağlanır; şema değişikliği yalnız sunucu yayınıyla olur.
// ⚠ Düz sır, veritabanı adresi ve anahtar ASLA yazdırılmaz.
//
// Ortam: HC_DATABASE_URL, HC_MASTER_KEY, HC_YENI_TOTP_SIRRI, HEDEF_EMAIL,
//        MOD (kontrol|uygula), SUNUCU_ADRESI
// ═══════════════════════════════════════════════════════════════
const zorunlu = ['HC_DATABASE_URL', 'HC_MASTER_KEY', 'HC_YENI_TOTP_SIRRI', 'HEDEF_EMAIL', 'MOD', 'SUNUCU_ADRESI'];
const eksik = zorunlu.filter((k) => !String(process.env[k] ?? '').trim());
if (eksik.length) {
  console.error(`Eksik ayar: ${eksik.join(', ')} (GitHub sırları tanımlı mı?)`);
  process.exit(1);
}
const adres = new URL(process.env.SUNUCU_ADRESI);
if (adres.protocol !== 'https:') {
  console.error('SUNUCU_ADRESI https olmalı.');
  process.exit(1);
}

const { adminMfaYenile, BakimHatasi } = await import('../src/bakim/admin_mfa_yenileme.js');
const { PostgresDbSinif } = await import('../src/db.js');

async function parmakIziAl() {
  // Render ücretsiz planda sunucu uyuyor olabilir: birkaç kez dene.
  for (let i = 0; i < 6; i++) {
    try {
      const r = await fetch(new URL('/healthz', adres), { signal: AbortSignal.timeout(30_000) });
      if (r.ok) return (await r.json()).anahtar ?? null;
    } catch { /* yeniden dene */ }
    await new Promise((ok) => setTimeout(ok, 10_000));
  }
  return null;
}

let db;
let kod = 0;
try {
  const sunucuParmakIzi = await parmakIziAl();
  const { default: pg } = await import('pg');
  db = new PostgresDbSinif(pg, process.env.HC_DATABASE_URL, { ssl: process.env.HC_DB_SSL !== 'false', havuz: 1 });
  const s = await adminMfaYenile(db, {
    email: process.env.HEDEF_EMAIL,
    yeniSir: process.env.HC_YENI_TOTP_SIRRI,
    mod: process.env.MOD,
    sunucuParmakIzi,
  });
  for (const m of s.mesajlar) console.log(m);
  console.log(s.durum === 'yenilendi'
    ? 'SONUÇ: MFA sırrı yenilendi. Doğrulayıcı uygulamaya eklediğiniz YENİ anahtarla giriş yapın; GitHub sırrı HC_YENI_TOTP_SIRRI’yi şimdi silin.'
    : 'SONUÇ: kontrol tamam. Uygulamak için iş akışını mod=uygula ve onay metniyle yeniden çalıştırın.');
} catch (e) {
  kod = 1;
  // Yalnız kendi mesajlarımız; sürücü/ağ hatalarında ayrıntı (adres/sorgu) yazılmaz.
  console.error(e instanceof BakimHatasi ? `DURDU: ${e.message}` : `DURDU: beklenmeyen hata (${e?.code ?? e?.name ?? 'bilinmiyor'}). Hiçbir şey yazılmadıysa işlem geri alınmıştır.`);
} finally {
  await db?.close?.().catch(() => {});
}
process.exit(kod);
