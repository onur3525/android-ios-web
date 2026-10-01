// ═══════════════════════════════════════════════════════════════
// HTTP KATMANI — küçük yönlendirici, JSON, hata sözleşmesi, güvenlik
//
// HATA SÖZLEŞMESİ (Flutter `api_error_mapper.dart` ile aynı):
//   { "error": { "code": "NOT_FOUND", "message": "..." }, "requestId": "..." }
// Başarı yanıtı ZARFSIZ düz JSON'dur (istemci `_list`/nesne bekler).
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';

export class ApiHatasi extends Error {
  constructor(durum, kod, mesaj, ek) {
    super(mesaj);
    this.durum = durum;
    this.kod = kod;
    this.ek = ek;
  }
}

export const hata = {
  dogrulama: (m, ek) => new ApiHatasi(400, 'VALIDATION_ERROR', m, ek),
  kimlik: (m = 'Oturum gerekli') => new ApiHatasi(401, 'UNAUTHENTICATED', m),
  yetki: (m = 'Bu işlem için yetkiniz yok') => new ApiHatasi(403, 'FORBIDDEN', m),
  bulunamadi: (m = 'Kayıt bulunamadı') => new ApiHatasi(404, 'NOT_FOUND', m),
  cakisma: (m) => new ApiHatasi(409, 'CONFLICT', m),
  durum: (m) => new ApiHatasi(409, 'INVALID_STATE', m),
  hiz: (m = 'Çok fazla deneme. Lütfen daha sonra tekrar deneyin.') =>
    new ApiHatasi(429, 'RATE_LIMITED', m),
};

const GUVENLIK_BASLIKLARI = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'X-Frame-Options': 'DENY',
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cache-Control': 'no-store',
};

export function jsonGonder(res, durum, govde, ekBaslik = {}) {
  const metin = govde === undefined ? '' : JSON.stringify(govde);
  res.writeHead(durum, {
    ...GUVENLIK_BASLIKLARI,
    ...(metin ? { 'Content-Type': 'application/json; charset=utf-8' } : {}),
    ...ekBaslik,
  });
  res.end(metin);
}

export async function govdeOku(req, sinir = 1024 * 1024) {
  const parcalar = [];
  let boy = 0;
  for await (const p of req) {
    boy += p.length;
    if (boy > sinir) throw new ApiHatasi(413, 'PAYLOAD_TOO_LARGE', 'İstek gövdesi çok büyük');
    parcalar.push(p);
  }
  if (!boy) return {};
  try {
    const v = JSON.parse(Buffer.concat(parcalar).toString('utf8'));
    if (v === null || typeof v !== 'object' || Array.isArray(v)) {
      throw new Error();
    }
    return v;
  } catch {
    throw hata.dogrulama('Geçersiz JSON gövdesi');
  }
}

export function cerezleriOku(req) {
  const out = {};
  for (const p of (req.headers.cookie || '').split(';')) {
    const i = p.indexOf('=');
    if (i > 0) out[p.slice(0, i).trim()] = decodeURIComponent(p.slice(i + 1).trim());
  }
  return out;
}

export function cerez(ad, deger, { maxAgeSn, secure, path = '/' }) {
  const parcalar = [
    `${ad}=${encodeURIComponent(deger)}`,
    `Path=${path}`,
    'HttpOnly',
    'SameSite=Strict',
  ];
  if (secure) parcalar.push('Secure');
  if (maxAgeSn !== undefined) parcalar.push(`Max-Age=${maxAgeSn}`);
  return parcalar.join('; ');
}

/**
 * İstemci IP'si. Yük dengeleyici arkasında (HC_TRUST_PROXY=true) gerçek
 * IP X-Forwarded-For'un SOLDAN İLK değeridir; güvenilmeyen ortamda bu
 * başlık YOK SAYILIR (sahte IP ile hız sınırı aşılamasın).
 */
export function istemciIp(req) {
  if (process.env.HC_TRUST_PROXY === 'true') {
    const x = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
    if (x) return x.slice(0, 64);
  }
  return req.socket?.remoteAddress || 'bilinmiyor';
}

/**
 * ORTAK hız sınırı — sayaç VERİTABANINDA (`rate_limits`), bu yüzden
 * bütün backend örnekleri AYNI sayacı görür (örnek sayısı artınca sınır
 * çoğalmaz). Sabit pencere; tek atomik UPSERT.
 */
export class HizSiniri {
  constructor(ad, adet, pencereMs) {
    this.ad = ad;
    this.adet = adet;
    this.pencereMs = pencereMs;
  }
  async denetle(db, anahtar) {
    const pencere = Math.floor(Date.now() / this.pencereMs);
    const r = await db.prepare(
      `INSERT INTO rate_limits (key, window_start, count) VALUES (?, ?, 1)
       ON CONFLICT(key) DO UPDATE SET
         count = CASE WHEN rate_limits.window_start = excluded.window_start THEN rate_limits.count + 1 ELSE 1 END,
         window_start = excluded.window_start
       RETURNING count`,
    ).get(`${this.ad}:${anahtar}`, pencere);
    if (r.count > this.adet) throw hata.hiz();
  }
}

/** Yol desenli yönlendirici: '/admin/v1/categories/:id'. */
export class Yonlendirici {
  constructor() {
    this.rotalar = [];
  }
  ekle(yontem, desen, isleyici) {
    const anahtarlar = [];
    const re = new RegExp(
      '^' +
        desen.replace(/\/:([a-zA-Z]+)/g, (_, k) => {
          anahtarlar.push(k);
          return '/([^/]+)';
        }) +
        '/?$',
    );
    this.rotalar.push({ yontem, re, anahtarlar, isleyici });
  }
  get(d, f) { this.ekle('GET', d, f); }
  post(d, f) { this.ekle('POST', d, f); }
  put(d, f) { this.ekle('PUT', d, f); }
  patch(d, f) { this.ekle('PATCH', d, f); }
  delete(d, f) { this.ekle('DELETE', d, f); }

  bul(yontem, yol) {
    let yolVar = false;
    for (const r of this.rotalar) {
      const m = r.re.exec(yol);
      if (!m) continue;
      yolVar = true;
      if (r.yontem !== yontem) continue;
      const params = {};
      r.anahtarlar.forEach((k, i) => (params[k] = decodeURIComponent(m[i + 1])));
      return { isleyici: r.isleyici, params };
    }
    return yolVar ? 'YONTEM' : null;
  }
}

export function istekKimligi() {
  return randomUUID();
}
