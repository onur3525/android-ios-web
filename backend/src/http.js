// ═══════════════════════════════════════════════════════════════
// HTTP KATMANI — küçük yönlendirici, JSON, hata sözleşmesi, güvenlik
//
// HATA SÖZLEŞMESİ (Flutter `api_error_mapper.dart` ile aynı):
//   { "error": { "code": "NOT_FOUND", "message": "..." }, "requestId": "..." }
// Başarı yanıtı ZARFSIZ düz JSON'dur (istemci `_list`/nesne bekler).
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { isIP } from 'node:net';
import { config } from './config.js';

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
 * İstemci IP'si — hız sınırları, oturum kayıtları ve denetim kayıtlarının
 * TEK kaynağı (başka yerde soket adresi ya da X-Forwarded-For okunmaz).
 *
 * ⚠ X-Forwarded-For'un EN SOLDAKİ değeri istemcinin kendi yazdığı değerdir
 * ve doğrulanmaz; proxy'ler gerçek adresi SONA ekler. Bu yüzden değer
 * SAĞDAN, güvenilen altyapının başlığa eklediği DEĞER sayısı kadar sayılarak
 * alınır (`HC_TRUST_PROXY_HOPS`; ör. 1 → en sağdaki, 2 → sondan ikinci).
 * Bu sayı fiziksel proxy sayısı değildir: Google harici yük dengeleyicisi
 * tek başına iki değer ekler.
 * Proxy'ye güvenilmiyorsa (0), başlıkta yeterli değer yoksa ya da seçilen
 * değer geçerli bir IP değilse SOKET ADRESİ kullanılır.
 *
 * ⚠ IPv4-EŞLENMİŞ IPv6 DÜZ IPv4'E ÇEVRİLİR. Çift yığınlı (`::`) dinleyen
 * sunucuda IPv4 istemcinin soket adresi `::ffff:127.0.0.1` biçiminde gelir;
 * aynı makine bir istekte `127.0.0.1`, başka bir istekte `::ffff:127.0.0.1`
 * olarak yazılırsa hız sınırı sayacı İKİYE BÖLÜNÜR ve oturum/denetim
 * kayıtları tutarsızlaşır. Çeviri, değer SEÇİLİP DOĞRULANDIKTAN SONRA
 * yapılır: hangi değerin seçileceğini değiştirmez, yalnız yazımını
 * tekleştirir. Diğer IPv6 adresleri olduğu gibi kalır.
 */
export function istemciIp(req) {
  const soketHam = req.socket?.remoteAddress;
  const soket = soketHam ? ipBicimle(soketHam) : 'bilinmiyor';
  const hop = config.guvenilirProxySayisi;
  if (!hop) return soket;
  const baslik = req.headers?.['x-forwarded-for'];
  const ham = Array.isArray(baslik) ? baslik.join(',') : baslik;
  if (typeof ham !== 'string' || !ham.trim()) return soket;
  const parcalar = ham.split(',').map((s) => s.trim());
  if (parcalar.length < hop) return soket;
  const aday = parcalar[parcalar.length - hop];
  if (aday.length > 64 || isIP(aday) === 0) return soket;
  return ipBicimle(aday);
}

/**
 * Geçerli bir IP'yi tek yazıma indirir: IPv4-eşlenmiş IPv6
 * (`::ffff:a.b.c.d`, `::ffff:7f00:1`, `0:0:0:0:0:ffff:…`) → `a.b.c.d`.
 * IPv4 ve diğer IPv6 adresleri DEĞİŞMEZ; geçersiz değer de olduğu gibi
 * döner (doğrulama çağıranın işidir).
 */
export function ipBicimle(ip) {
  if (typeof ip !== 'string' || isIP(ip) !== 6) return ip;
  let kanonik;
  try {
    // WHATWG URL, IPv6'yı kanonik biçime getirir; eşlenmiş adres her
    // zaman `::ffff:XXXX:XXXX` olarak serileşir.
    kanonik = new URL(`http://[${ip}]/`).hostname.slice(1, -1);
  } catch {
    return ip; // ör. bölge kimlikli (`fe80::1%eth0`) adres: dokunma
  }
  const m = /^::ffff:([0-9a-f]{1,4}):([0-9a-f]{1,4})$/.exec(kanonik);
  if (!m) return ip;
  const ust = parseInt(m[1], 16);
  const alt = parseInt(m[2], 16);
  return `${ust >> 8}.${ust & 255}.${alt >> 8}.${alt & 255}`;
}

/**
 * ORTAK hız sınırı — sayaç VERİTABANINDA (`rate_limits`), bu yüzden
 * bütün backend örnekleri AYNI sayacı görür (örnek sayısı artınca sınır
 * çoğalmaz). Sabit pencere; tek atomik UPSERT.
 */
export class HizSiniri {
  /** Tanımlı bütün sınırlayıcılar — eski pencere satırlarının temizliği için (bkz. hizKayitlariniTemizle). */
  static hepsi = [];

  constructor(ad, adet, pencereMs) {
    this.ad = ad;
    this.adet = adet;
    this.pencereMs = pencereMs;
    HizSiniri.hepsi.push(this);
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

/**
 * Süresi geçmiş hız sınırı satırlarını siler. Her anahtar (IP/kullanıcı)
 * için bir satır tutulduğundan temizlenmezse tablo SINIRSIZ büyür.
 * Yalnız içinde bulunulan pencereden ESKİ satırlar silinir — sayım etkilenmez.
 */
export async function hizKayitlariniTemizle(db) {
  let silinen = 0;
  for (const s of HizSiniri.hepsi) {
    const onek = `${s.ad}:`;
    const r = await db.prepare('DELETE FROM rate_limits WHERE substr(key, 1, ?) = ? AND window_start < ?')
      .run(onek.length, onek, Math.floor(Date.now() / s.pencereMs));
    silinen += r.changes ?? 0;
  }
  return silinen;
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
