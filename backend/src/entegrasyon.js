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
import { config, uretim } from './config.js';

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

/**
 * GÖNDERİM/DEPOLAMA KANALLARININ GERÇEK KAYNAĞI (23 Eki) — panel ve Özet
 * aynı bilgiyi buradan alır. Gönderimde kullanılan sırayla aynıdır:
 * etkin panel entegrasyonu → ortam değişkeni → yok. Sır döndürülmez.
 *   source: 'panel' | 'ortam' | 'yok'
 *   provider: panelde sağlayıcı adı; ortamda 'webhook' | 'log' | 's3'
 */
export async function kanalKaynaklari(db) {
  const panel = await db.prepare(
    'SELECT type, provider, active, last_test_at, last_test_ok, last_test_message FROM integrations WHERE deleted_at IS NULL ORDER BY created_at',
  ).all();
  const evet = (v) => v === 1 || v === true;
  // 23 Eki: depolama ve e-postanın 15 dakikalık otomatik kontrolü (sistem_izleme.js).
  const sonuc = (x) => (x ? { autoCheckAt: x.checked_at, autoCheckOk: evet(x.check_ok), autoCheckMessage: x.check_message } : { autoCheckAt: null, autoCheckOk: null, autoCheckMessage: null });
  const depo = sonuc(await db.prepare('SELECT checked_at, check_ok, check_message FROM storage_monitor WHERE id = 1').get());
  const eposta = sonuc(await db.prepare('SELECT checked_at, check_ok, check_message FROM email_monitor WHERE id = 1').get());
  // 23 Eki (kullanıcı kuralı): ana ekranlar SON 24 SAATİ gösterir; eski kayıtlar
  // yalnız "SMS / E-posta Kayıtları" sayfasında. Kanal kartları bu sayıları kullanır.
  const gun = { SMS: { sent24h: 0, failed24h: 0 }, EMAIL: { sent24h: 0, failed24h: 0 } };
  for (const x of await db.prepare(`SELECT channel, status, COUNT(*) n FROM outbound_messages WHERE created_at > ? AND status IN ('SENT', 'FAILED') GROUP BY channel, status`)
    .all(new Date(Date.now() - 86_400_000).toISOString())) {
    if (gun[x.channel]) gun[x.channel][x.status === 'SENT' ? 'sent24h' : 'failed24h'] = Number(x.n);
  }
  return ['SMS', 'EMAIL', 'STORAGE'].map((tur) => {
    const k = kanal(tur);
    if (tur === 'STORAGE') return { ...k, ...depo };
    // E-posta otomatik kontrolü yalnız etkin panel Resend entegrasyonu için yapılır.
    const oto = tur === 'EMAIL' && k.source === 'panel' && k.provider === 'resend' ? eposta : {};
    return { ...k, ...gun[tur], ...oto };
  });
  function kanal(tur) {
    const e = panel.find((x) => x.type === tur && evet(x.active));
    if (e) {
      return {
        type: tur, source: 'panel', provider: e.provider, lastTestAt: e.last_test_at,
        lastTestOk: e.last_test_ok === null ? null : evet(e.last_test_ok), lastTestMessage: e.last_test_message,
      };
    }
    const bos = { lastTestAt: null, lastTestOk: null, lastTestMessage: null };
    if (tur === 'STORAGE') {
      const env = process.env;
      return env.HC_S3_ENDPOINT && env.HC_S3_BUCKET && env.HC_S3_ACCESS_KEY_ID && env.HC_S3_SECRET_ACCESS_KEY
        ? { type: tur, source: 'ortam', provider: 's3', ...bos }
        : { type: tur, source: 'yok', provider: null, ...bos };
    }
    const s = tur === 'SMS' ? config.sms : config.eposta;
    return s.ad === 'yok' ? { type: tur, source: 'yok', provider: null, ...bos } : { type: tur, source: 'ortam', provider: s.ad, ...bos };
  }
}

/** Depolama yapılandırması: entegrasyon → ortam değişkeni → yok. */
export async function depolamaAyari(db) {
  const e = await etkinEntegrasyon(db, 'STORAGE');
  if (e) return { endpoint: e.config.endpoint, region: e.config.region, bucket: e.config.bucket, pathStyle: e.config.pathStyle === true, accessKeyId: e.secret.accessKeyId, secretAccessKey: e.secret.secretAccessKey };
  const env = process.env;
  if (env.HC_S3_ENDPOINT && env.HC_S3_BUCKET && env.HC_S3_ACCESS_KEY_ID && env.HC_S3_SECRET_ACCESS_KEY) {
    return { endpoint: env.HC_S3_ENDPOINT, region: env.HC_S3_REGION || 'auto', bucket: env.HC_S3_BUCKET, pathStyle: env.HC_S3_PATH_STYLE === 'true', accessKeyId: env.HC_S3_ACCESS_KEY_ID, secretAccessKey: env.HC_S3_SECRET_ACCESS_KEY };
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
  // Canlıda yalnız https; http yalnız geliştirme/test (yerel MinIO vb.).
  if (u.protocol !== 'https:' && !(u.protocol === 'http:' && !uretim)) throw new Error('Depolama adresi https olmalıdır');
  // Sanal-host (S3/R2) ya da yol biçimi (MinIO: HC_S3_PATH_STYLE=true).
  const host = ayar.pathStyle ? u.host : `${ayar.bucket}.${u.host}`;
  const tarih = simdi.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, ''); // yyyyMMddTHHmmssZ
  const gun = tarih.slice(0, 8);
  const kapsam = `${gun}/${ayar.region}/s3/aws4_request`;
  const yol = (ayar.pathStyle ? `/${kodla(ayar.bucket)}` : '') + '/' + anahtar.split('/').map(kodla).join('/');
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
  return `${u.protocol}//${host}${yol}?${kanonikSorgu}&X-Amz-Signature=${imza}`;
}
