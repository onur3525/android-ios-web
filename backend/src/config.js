// ═══════════════════════════════════════════════════════════════
// YAPILANDIRMA — yalnız ortam değişkenlerinden okunur.
//
// ⚠ Sırlar koda YAZILMAZ. Üretimde zorunlu olanlar eksikse sunucu
// AÇILMAZ (fail-closed).
// ═══════════════════════════════════════════════════════════════
import { randomBytes } from 'node:crypto';

const env = process.env;
export const uretim = env.NODE_ENV === 'production';

function zorunlu(ad) {
  const v = env[ad];
  if (!v || !v.trim()) {
    throw new Error(`Üretimde ${ad} zorunludur.`);
  }
  return v.trim();
}

/** 32 baytlık ana anahtar (base64). Sırları (TOTP, entegrasyon) şifreler. */
function anaAnahtar() {
  if (env.HC_MASTER_KEY) {
    const k = Buffer.from(env.HC_MASTER_KEY, 'base64');
    if (k.length !== 32) throw new Error('HC_MASTER_KEY 32 bayt (base64) olmalıdır.');
    return k;
  }
  if (uretim) zorunlu('HC_MASTER_KEY');
  // Yalnız geliştirme/test: süreç başına rastgele anahtar (kalıcı değil).
  return randomBytes(32);
}

/**
 * Veritabanı seçimi.
 * ⚠ CANLI (NODE_ENV=production) YALNIZ PostgreSQL ile açılır; SQLite
 * üretimde REDDEDİLİR. SQLite yalnız geliştirme ve testler içindir.
 */
function veritabaniAyari() {
  const surucu = (env.HC_DB_DRIVER || (uretim ? 'postgres' : 'sqlite')).trim();
  if (!['sqlite', 'postgres'].includes(surucu)) throw new Error('HC_DB_DRIVER sqlite ya da postgres olmalıdır.');
  if (uretim && surucu !== 'postgres') throw new Error('Üretimde yalnız PostgreSQL kullanılabilir (HC_DB_DRIVER=postgres).');
  if (surucu === 'postgres') {
    const ssl = env.HC_DB_SSL !== 'false';
    if (uretim && !ssl) throw new Error('Üretimde veritabanı bağlantısı TLS olmadan açılamaz.');
    return {
      surucu,
      url: zorunlu('HC_DATABASE_URL'),
      ssl,
      ca: env.HC_DB_CA_PEM || undefined,
      havuz: Number(env.HC_DB_POOL || 10),
    };
  }
  return { surucu, yol: env.HC_DB_PATH || ':memory:' };
}

function jwtSirri() {
  if (env.HC_JWT_SECRET) {
    if (env.HC_JWT_SECRET.length < 32) throw new Error('HC_JWT_SECRET en az 32 karakter olmalıdır.');
    return env.HC_JWT_SECRET;
  }
  if (uretim) zorunlu('HC_JWT_SECRET');
  return randomBytes(48).toString('base64');
}

/**
 * Bildirim sağlayıcıları (SMS / e-posta).
 *   'log'     — YALNIZ geliştirme/test: gönderim yapılmaz, kayıt düşülür.
 *               Üretimde REDDEDİLİR.
 *   'webhook' — sağlayıcıdan bağımsız HTTPS POST (JSON); gerçek SMS/e-posta
 *               sağlayıcısına köprü. Adres ve anahtar ortamdan gelir.
 */
function saglayici(tur) {
  const ad = (env[`HC_${tur}_PROVIDER`] || (uretim ? '' : 'log')).trim();
  if (!['log', 'webhook'].includes(ad)) {
    throw new Error(`HC_${tur}_PROVIDER log ya da webhook olmalıdır.`);
  }
  if (uretim && ad === 'log') throw new Error(`Üretimde HC_${tur}_PROVIDER=log kullanılamaz.`);
  if (ad === 'webhook') {
    const url = zorunlu(`HC_${tur}_WEBHOOK_URL`);
    if (!url.startsWith('https://')) throw new Error(`HC_${tur}_WEBHOOK_URL https olmalıdır.`);
    return { ad, url, anahtar: zorunlu(`HC_${tur}_WEBHOOK_TOKEN`) };
  }
  return { ad };
}

export const config = {
  port: Number(env.PORT || 8080),
  jwtSirri: jwtSirri(),
  erisimSuresi: 15 * 60 * 1000, // erişim token'ı 15 dk
  yenilemeSuresi: 30 * 24 * 60 * 60 * 1000, // yenileme token'ı 30 gün
  sms: saglayici('SMS'),
  eposta: saglayici('EMAIL'),
  veritabani: veritabaniAyari(),
  anaAnahtar: anaAnahtar(),
  // Çerez Secure bayrağı: üretimde HER ZAMAN açık.
  cerezSecure: uretim ? true : env.HC_COOKIE_SECURE === 'true',
  adminOturumBosta: 30 * 60 * 1000, // 30 dk hareketsizlik
  adminOturumMutlak: 8 * 60 * 60 * 1000, // 8 saat
  yenidenDogrulamaSuresi: 5 * 60 * 1000, // kritik işlem için 5 dk
};
