// ═══════════════════════════════════════════════════════════════
// AĞ GÜVENLİĞİ — admin'in girdiği dış adreslere (entegrasyonlar) SSRF
// koruması
//
// Entegrasyon adresleri (SMS/e-posta köprüsü, depolama uç noktası)
// admin panelinden girilir ve backend bu adreslere istek atar (bağlantı
// testi, webhook gönderimi). Kötü niyetli ya da ele geçirilmiş bir admin
// hesabı bu yolla iç ağa (localhost, özel ağ, bulut meta veri servisi
// 169.254.169.254 …) istek attırıp yanıt durumunu okuyabilirdi.
//
// Kurallar:
//   · Yalnız https; kullanıcı bilgisi (user@) yok.
//   · Ad düzeyinde: localhost, *.localhost, *.local, *.internal ve meta
//     veri adları reddedilir; IP yazılmışsa özel/ayrılmış aralıklar reddedilir.
//   · İstek anında: DNS çözümlemesi bağlantının KENDİSİNDE denetlenir
//     (`lookup` kancası) — çözülen adres özel/ayrılmışsa bağlantı KURULMAZ.
//     Denetlenen adresle bağlanılan adres aynıdır (DNS rebinding yok).
//   · Yönlendirme İZLENMEZ (https.request izlemez).
//
// Yalnız GELİŞTİRMEDE (NODE_ENV≠production) `HC_INTEGRATION_ALLOW_PRIVATE=true`
// ile kapatılabilir (yerel köprü/MinIO denemeleri). Üretimde bu değişken
// tanımlanırsa sunucu AÇILMAZ (config.js).
// ═══════════════════════════════════════════════════════════════
import { lookup as dnsLookup } from 'node:dns';
import { request } from 'node:https';
import { isIP } from 'node:net';

const uretimMi = () => process.env.NODE_ENV === 'production';
const ozelSerbest = () => !uretimMi() && process.env.HC_INTEGRATION_ALLOW_PRIVATE === 'true';

function v4Sayi(ip) {
  return ip.split('.').reduce((a, p) => (a << 8) + Number(p), 0) >>> 0;
}
const V4_YASAK = [
  ['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10], ['127.0.0.0', 8],
  ['169.254.0.0', 16], ['172.16.0.0', 12], ['192.0.0.0', 24], ['192.0.2.0', 24],
  ['192.168.0.0', 16], ['198.18.0.0', 15], ['198.51.100.0', 24], ['203.0.113.0', 24],
  ['224.0.0.0', 4], ['240.0.0.0', 4],
].map(([a, n]) => [v4Sayi(a), n === 0 ? 0 : (0xffffffff << (32 - n)) >>> 0]);

/** IP özel, döngü, bağlantı-yerel, çoklu yayın ya da ayrılmış bir aralıkta mı? */
export function ozelAdresMi(ip) {
  const s = String(ip || '').toLowerCase().replace(/^\[|\]$/g, '').split('%')[0];
  const tur = isIP(s);
  if (tur === 4) {
    const x = v4Sayi(s);
    return V4_YASAK.some(([ag, maske]) => ((x & maske) >>> 0) === ag);
  }
  if (tur === 6) {
    if (s === '::' || s === '::1') return true;
    const eslenmis = /^::ffff:(?:0:)?(\d+\.\d+\.\d+\.\d+)$/.exec(s);
    if (eslenmis) return ozelAdresMi(eslenmis[1]);
    if (/^::ffff:/.test(s)) return true; // onaltılık biçimli eşlenmiş v4: güvenli tarafta kal
    if (s.startsWith('64:ff9b:')) return true; // NAT64 (iç v4'e çevrilebilir)
    const ilk = parseInt(s.split(':')[0] || '0', 16);
    if ((ilk & 0xfe00) === 0xfc00) return true; // fc00::/7 benzersiz yerel
    if ((ilk & 0xffc0) === 0xfe80) return true; // fe80::/10 bağlantı-yerel
    if ((ilk & 0xff00) === 0xff00) return true; // ff00::/8 çoklu yayın
    if (ilk === 0x2001 && s.startsWith('2001:db8:')) return true; // belgeleme
    return false;
  }
  return true; // IP değilse güvenli tarafta kal
}

const YASAK_AD = /(^|\.)(localhost|local|internal|localdomain|home\.arpa)$/;
const META_ADLARI = new Set(['metadata', 'metadata.google.internal', 'instance-data']);

/**
 * Dış adres denetimi (ad düzeyinde, ağ isteği yapmaz). Uygunsa null,
 * değilse Türkçe ret gerekçesi.
 */
export function disAdresSorunu(adres) {
  let u;
  try { u = new URL(String(adres)); } catch { return 'geçerli bir adres değil'; }
  if (u.protocol !== 'https:') return 'https ile başlamalıdır';
  if (u.username || u.password) return 'kullanıcı bilgisi içeremez';
  if (ozelSerbest()) return null;
  const host = u.hostname.toLowerCase().replace(/^\[|\]$/g, '').replace(/\.$/, '');
  if (!host) return 'geçerli bir adres değil';
  if (META_ADLARI.has(host) || YASAK_AD.test(host)) return 'iç ağ adresi kullanılamaz';
  if (isIP(host) && ozelAdresMi(host)) return 'iç ağ adresi kullanılamaz';
  return null;
}

/** https.request için DNS kancası: özel adrese çözülen ad BAĞLANMAZ. */
export function guvenliLookup(ad, secenek, geri) {
  dnsLookup(ad, { ...secenek, all: true }, (hata, adresler) => {
    if (hata) return geri(hata);
    const liste = Array.isArray(adresler) ? adresler : [{ address: adresler, family: secenek?.family || 4 }];
    if (!ozelSerbest() && (!liste.length || liste.some((a) => ozelAdresMi(a.address)))) {
      const e = new Error('iç ağ adresine bağlantı engellendi');
      e.code = 'HC_SSRF_ENGELLENDI';
      return geri(e);
    }
    if (secenek?.all) return geri(null, liste);
    return geri(null, liste[0].address, liste[0].family);
  });
}

/**
 * Entegrasyon adresine korumalı HTTPS isteği. Yönlendirme izlenmez.
 * @returns {Promise<{status:number, text:string}>}
 */
export function guvenliIstek(adres, { method = 'GET', headers = {}, body, timeoutMs = 10_000 } = {}) {
  const sorun = disAdresSorunu(adres);
  if (sorun) return Promise.reject(new Error(`Adres reddedildi: ${sorun}`));
  return new Promise((coz, reddet) => {
    const govde = body === undefined ? undefined : Buffer.from(body);
    const istek = request(adres, {
      method,
      headers: { ...headers, ...(govde ? { 'Content-Length': govde.length } : {}) },
      lookup: guvenliLookup,
      timeout: timeoutMs,
    }, (yanit) => {
      const parcalar = [];
      let boy = 0;
      yanit.on('data', (p) => { if (boy < 4096) { parcalar.push(p); boy += p.length; } });
      yanit.on('end', () => coz({ status: yanit.statusCode, text: Buffer.concat(parcalar).toString('utf8') }));
      yanit.on('error', reddet);
    });
    istek.on('timeout', () => istek.destroy(new Error('zaman aşımı')));
    istek.on('error', reddet);
    if (govde) istek.write(govde);
    istek.end();
  });
}
