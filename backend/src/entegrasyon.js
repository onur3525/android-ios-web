// ═══════════════════════════════════════════════════════════════
// ENTEGRASYONLAR — SMS / E-POSTA / DEPOLAMA sağlayıcıları
//
// Admin panelinden yönetilir; ayarlar `integrations` tablosunda.
//   · Gizli olmayan ayarlar (adres, bölge, kova) → config_json
//   · Sırlar (anahtar, token) → AES-256-GCM ile şifreli (HC_MASTER_KEY);
//     admin'e ve hiçbir yanıta DÜZ DEĞER dönmez, yalnız son 4 karakter.
// Bir türde etkin entegrasyon yoksa ortam değişkenleri kullanılır
// (bildirim: HC_SMS_*/HC_EMAIL_*; depolama: HC_S3_*).
//
// Bütün sunucu örnekleri ayarı VERİTABANINDAN okur → admin'in yaptığı
// değişiklik her örnekte geçerli olur (yerel önbellek 30 sn).
// ═══════════════════════════════════════════════════════════════
import { createHash, createHmac } from 'node:crypto';
import { sirCoz } from './auth.js';
import { olaylar } from './olaylar.js';

const ONBELLEK_MS = 30_000;
const onbellek = new Map();

export function onbellegiTemizle() {
  onbellek.clear();
}
// Herhangi bir örnekte entegrasyon değişince HER örnek önbelleğini boşaltır.
olaylar.on('integrations.changed', onbellegiTemizle);

/** Etkin entegrasyon: { provider, config, secret } ya da null. */
export async function etkinEntegrasyon(db, tur) {
  const o = onbellek.get(tur);
  if (o && Date.now() - o.zaman < ONBELLEK_MS) return o.deger;
  const x = await db.prepare(`SELECT * FROM integrations WHERE type = ? AND active = TRUE AND deleted_at IS NULL`).get(tur);
  const deger = x ? { id: x.id, provider: x.provider, config: JSON.parse(x.config_json), secret: x.secret_enc ? JSON.parse(sirCoz(x.secret_enc)) : {} } : null;
  onbellek.set(tur, { zaman: Date.now(), deger });
  return deger;
}

/** Depolama yapılandırması: entegrasyon → ortam değişkeni → yok. */
export async function depolamaAyari(db) {
  const e = await etkinEntegrasyon(db, 'STORAGE');
  if (e) return { endpoint: e.config.endpoint, region: e.config.region, bucket: e.config.bucket, accessKeyId: e.secret.accessKeyId, secretAccessKey: e.secret.secretAccessKey };
  const env = process.env;
  if (env.HC_S3_ENDPOINT && env.HC_S3_BUCKET && env.HC_S3_ACCESS_KEY_ID && env.HC_S3_SECRET_ACCESS_KEY) {
    return { endpoint: env.HC_S3_ENDPOINT, region: env.HC_S3_REGION || 'auto', bucket: env.HC_S3_BUCKET, accessKeyId: env.HC_S3_ACCESS_KEY_ID, secretAccessKey: env.HC_S3_SECRET_ACCESS_KEY };
  }
  return null;
}

// ── AWS Signature V4 — imzalı adres (S3 / Cloudflare R2 / MinIO) ──
// Flutter `yukleme_adresi.dart` şunları ister: https, izinli alan,
// X-Amz-Algorithm/Credential/Date/Expires/Signature, süre ≤ 7 gün.
const kodla = (s) => encodeURIComponent(s).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
const hmac = (k, v) => createHmac('sha256', k).update(v).digest();

export function s3ImzaliAdres(ayar, { yontem, anahtar, sureSn = 900, icerikTuru, simdi = new Date() }) {
  const u = new URL(ayar.endpoint);
  if (u.protocol !== 'https:') throw new Error('Depolama adresi https olmalıdır');
  const host = `${ayar.bucket}.${u.host}`; // sanal-host biçimi
  const tarih = simdi.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, ''); // yyyyMMddTHHmmssZ
  const gun = tarih.slice(0, 8);
  const kapsam = `${gun}/${ayar.region}/s3/aws4_request`;
  const yol = '/' + anahtar.split('/').map(kodla).join('/');
  const imzaliBasliklar = icerikTuru ? 'content-type;host' : 'host';
  const sorgu = {
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': `${ayar.accessKeyId}/${kapsam}`,
    'X-Amz-Date': tarih,
    'X-Amz-Expires': String(sureSn),
    'X-Amz-SignedHeaders': imzaliBasliklar,
  };
  const kanonikSorgu = Object.keys(sorgu).sort().map((k) => `${kodla(k)}=${kodla(sorgu[k])}`).join('&');
  const kanonikBaslik = (icerikTuru ? `content-type:${icerikTuru}\n` : '') + `host:${host}\n`;
  const kanonik = [yontem, yol, kanonikSorgu, kanonikBaslik, imzaliBasliklar, 'UNSIGNED-PAYLOAD'].join('\n');
  const imzalanacak = ['AWS4-HMAC-SHA256', tarih, kapsam, createHash('sha256').update(kanonik).digest('hex')].join('\n');
  const kImza = hmac(hmac(hmac(hmac(`AWS4${ayar.secretAccessKey}`, gun), ayar.region), 's3'), 'aws4_request');
  const imza = createHmac('sha256', kImza).update(imzalanacak).digest('hex');
  return `https://${host}${yol}?${kanonikSorgu}&X-Amz-Signature=${imza}`;
}
