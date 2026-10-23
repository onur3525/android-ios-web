// ═══════════════════════════════════════════════════════════════
// YAPILANDIRMA — yalnız ortam değişkenlerinden okunur.
//
// ⚠ Sırlar koda YAZILMAZ. Üretimde zorunlu olanlar eksikse sunucu
// AÇILMAZ (fail-closed).
// ═══════════════════════════════════════════════════════════════
import { randomBytes } from 'node:crypto';
import { servisHesabiOku } from './servis_hesabi.js';

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
 *   tanımsız  — ÜRETİMDE izinli: gönderim yalnız admin panelinden
 *               etkinleştirilen entegrasyonla yapılır (bildirim.js önce onu
 *               kullanır). İkisi de yoksa her gönderim outbound_messages'a
 *               FAILED ("sağlayıcı yapılandırılmamış") düşer; OTP isteği 503
 *               döner. Sessiz başarı YOK, sahte sağlayıcı YOK.
 *               (Telefon doğrulaması uygulamada Firebase Authentication ile
 *               yapılır; bu kanal sunucu OTP'si ve hesap bildirimleri içindir.)
 */
function saglayici(tur) {
  const ham = (env[`HC_${tur}_PROVIDER`] ?? '').trim();
  const ad = ham || (uretim ? 'yok' : 'log');
  if (ad === 'yok') return { ad };
  if (!['log', 'webhook'].includes(ad)) {
    throw new Error(`HC_${tur}_PROVIDER geçersiz ("${ham.slice(0, 20)}"): webhook (canlı), log (yalnız geliştirme) ya da tanımsız (yalnız admin entegrasyonu) olmalıdır.`);
  }
  if (uretim && ad === 'log') throw new Error(`Üretimde HC_${tur}_PROVIDER=log kullanılamaz.`);
  if (ad === 'webhook') {
    const url = zorunlu(`HC_${tur}_WEBHOOK_URL`);
    if (!url.startsWith('https://')) throw new Error(`HC_${tur}_WEBHOOK_URL https olmalıdır.`);
    return { ad, url, anahtar: zorunlu(`HC_${tur}_WEBHOOK_TOKEN`) };
  }
  return { ad };
}

function corsKokenleri() {
  const ham = (env.HC_CORS_ORIGINS ?? (uretim ? 'https://hizmetcep.com,https://www.hizmetcep.com' : '')).split(',').map((s) => s.trim()).filter(Boolean);
  for (const k of ham) {
    if (k === '*' || k.includes('*')) throw new Error('HC_CORS_ORIGINS joker (*) içeremez');
    let u;
    try { u = new URL(k); } catch { throw new Error(`HC_CORS_ORIGINS geçersiz köken: ${k}`); }
    if (u.origin !== k) throw new Error(`HC_CORS_ORIGINS yalnız köken olmalı (yol/sonda / yok): ${k}`);
    if (uretim && u.protocol !== 'https:') throw new Error(`Üretimde CORS kökeni https olmalı: ${k}`);
  }
  return ham;
}

// ── EK ÜRETİM DENETİMLERİ (yanlış/yarım değer sessizce yanlış davranmasın) ──
// S3: değişkenlerden biri bile verildiyse dördü de zorunlu; aksi hâlde
// depolama sessizce "yapılandırılmamış" sayılırdı. Üretimde uç https.
function depolamaDenetimi() {
  const adlar = ['HC_S3_ENDPOINT', 'HC_S3_BUCKET', 'HC_S3_ACCESS_KEY_ID', 'HC_S3_SECRET_ACCESS_KEY'];
  const verilen = adlar.filter((a) => (env[a] || '').trim());
  if (verilen.length && verilen.length !== adlar.length) {
    throw new Error(`Depolama yapılandırması yarım: ${adlar.filter((a) => !verilen.includes(a)).join(', ')} eksik.`);
  }
  if (verilen.length) {
    let u;
    try { u = new URL(env.HC_S3_ENDPOINT); } catch { throw new Error('HC_S3_ENDPOINT geçerli bir adres değil.'); }
    if (uretim && u.protocol !== 'https:') throw new Error('Üretimde HC_S3_ENDPOINT https olmalıdır.');
  }
  if (env.HC_S3_PATH_STYLE && !['true', 'false'].includes(env.HC_S3_PATH_STYLE)) {
    throw new Error('HC_S3_PATH_STYLE true ya da false olmalıdır.');
  }
}

// FCM servis hesabı: verildiyse açılışta doğrulanır (bozuk değer push'u
// sessizce kapatmasın). İçerik günlüğe YAZILMAZ.
//
// ÜRETİMDE ZORUNLU: push bildirimleri ürünün parçasıdır; servis hesabı
// eksikse bildirimler sessizce SKIPPED olurdu. Ayrıca servis hesabının
// projesi Firebase Authentication projesiyle (HC_FIREBASE_PROJECT_ID) AYNI
// olmalı: farklı projenin hesabıyla gönderim SENDER_ID_MISMATCH verir ve
// kullanıcıların cihaz kayıtları geçersiz sayılıp silinirdi.
function fcmDenetimi() {
  // Okuma/doğrulama tek kaynakta (servis_hesabi.js): ortam değeri YA DA
  // Secret File yolu (HC_FCM_SERVICE_ACCOUNT_FILE).
  const s = servisHesabiOku(env);
  if (!s) {
    if (uretim) {
      throw new Error('Üretimde HC_FCM_SERVICE_ACCOUNT zorunludur (servis hesabı JSON değeri) ya da HC_FCM_SERVICE_ACCOUNT_FILE ile dosya yolu verilmelidir (ör. Render Secret File: /etc/secrets/<dosya adı>).');
    }
    return false;
  }
  const proje = (env.HC_FIREBASE_PROJECT_ID || 'hizmetcep-fe036').trim();
  if (uretim && s.hesap.project_id !== proje) {
    throw new Error(`Firebase servis hesabı projesi (${s.hesap.project_id}) Firebase projesiyle (${proje}) aynı değil.`);
  }
  return true;
}

// İstemci IP'si: GÜVENİLEN proxy altyapısının X-Forwarded-For başlığının
// SAĞINA eklediği DEĞER sayısı (bkz. http.js istemciIp).
// ⚠ Bu, fiziksel proxy sayısı DEĞİLDİR: bir proxy birden fazla değer
// ekleyebilir. Örnek: Google harici yük dengeleyicisi TEK proxy olduğu hâlde
// sona İKİ değer ekler ("<istemci>,<dengeleyici IP>") → değer 2 olur.
// ⚠ VARSAYILAN YOK: tanımsız ya da 0 → başlığa hiç güvenilmez, yalnız
// soket adresi kullanılır. Üretim değeri dağıtım topolojisinde ÖLÇÜLEREK
// verilir (DEPLOY.md); tahminle yazılmaz.
// Eski `HC_TRUST_PROXY=true` başlığın EN SOLUNDAKİ (istemcinin yazabildiği)
// değeri alıyordu; yanlış yorumlanmasın diye artık açıkça reddedilir.
function proxyHopSayisi() {
  if (env.HC_TRUST_PROXY !== undefined) {
    throw new Error('HC_TRUST_PROXY artık kullanılmıyor; güvenilen proxy altyapısının istemci IP başlığının sağına eklediği değer sayısını HC_TRUST_PROXY_HOPS ile verin (bkz. DEPLOY.md).');
  }
  const ham = (env.HC_TRUST_PROXY_HOPS ?? '').trim();
  if (ham === '') return 0;
  if (!/^[0-5]$/.test(ham)) throw new Error('HC_TRUST_PROXY_HOPS 0 ile 5 arasında bir tam sayı olmalıdır.');
  return Number(ham);
}

// Yalnız test kancaları üretimde KESİNLİKLE kapalı (kod zaten yok sayıyor;
// yanlışlıkla tanımlanmışsa açıkça reddedilir).
if (uretim && env.HC_TEST_OTP_KANCASI) throw new Error('Üretimde HC_TEST_OTP_KANCASI tanımlanamaz.');
// SSRF korumasını kapatan geliştirme anahtarı üretimde KESİNLİKLE yok.
if (uretim && env.HC_INTEGRATION_ALLOW_PRIVATE) throw new Error('Üretimde HC_INTEGRATION_ALLOW_PRIVATE tanımlanamaz.');
depolamaDenetimi();

export const config = {
  fcmEtkin: fcmDenetimi(),
  // Eşzamanlı push çalıştırıcısı (danışma kilidi yuvası) sayısı; bkz. fcm.js pushKuyrugunuIsle.
  pushParalel: Math.max(1, Math.min(32, Number(env.HC_PUSH_PARALEL || 1) || 1)),
  port: Number(env.PORT || 8080),
  // Güvenilen altyapının X-Forwarded-For'un SAĞINA eklediği değer sayısı (proxy sayısı değil; 0 = başlığa güvenme).
  guvenilirProxySayisi: proxyHopSayisi(),
  jwtSirri: jwtSirri(),
  erisimSuresi: 15 * 60 * 1000, // erişim token'ı 15 dk
  yenilemeSuresi: 30 * 24 * 60 * 60 * 1000, // yenileme token'ı 30 gün
  // Firebase Authentication: kimlik doğrulaması Firebase'de; hesap,
  // rol ve iş verisi burada. Doğrulama AÇIK sertifikalarla (gizli yok).
  firebaseProjeId: (env.HC_FIREBASE_PROJECT_ID || 'hizmetcep-fe036').trim(),
  // Açık web API anahtarı (gizli değil); telefon+şifre girişinde şifreyi
  // Firebase'e doğrulatmak için. Boşsa yerel şifre özeti kullanılır.
  firebaseWebApiKey: (env.HC_FIREBASE_WEB_API_KEY || '').trim(),
  sms: saglayici('SMS'),
  eposta: saglayici('EMAIL'),
  // E-postalardaki logo görsellerinin herkese açık kökü (21 Eki). Gizli
  // değildir; varsayılan canlı sunucu adresidir.
  epostaVarlikKoku: (env.HC_PUBLIC_BASE_URL || 'https://hizmetcep-backend.onrender.com').trim(),
  // 23 Eki: yönetici uyarılarının (yeni talep, sistem sorunu, yavaşlama, yönetici
  // girişi) gideceği işletme adresi (yonetici_uyarilari.js).
  yoneticiUyariEposta: (env.HC_UYARI_EPOSTA || 'onur@hizmetcep.com').trim(),
  veritabani: veritabaniAyari(),
  anaAnahtar: anaAnahtar(),
  // Çerez Secure bayrağı: üretimde HER ZAMAN açık.
  cerezSecure: uretim ? true : env.HC_COOKIE_SECURE === 'true',
  // CORS izin listesi (yalnız kullanıcı API'si). '*' YOK; tam köken eşleşmesi.
  // Üretim varsayılanı production web kökeni; geliştirmede boş (davranış aynı).
  corsKokenleri: corsKokenleri(),
  // 21 Eki (kullanıcı kararı): 30 dk çok uzundu — en çok 5 dk hareketsizlik.
  // Panel de aynı süreyi /auth/me yanıtından alır ve ekranı kendisi kilitler.
  // 15 dk hareketsizlik (22 Eki: her değişiklik zaten şifre + kod ister).
  adminOturumBosta: 15 * 60 * 1000,
  adminOturumMutlak: 8 * 60 * 60 * 1000, // 8 saat
  // Şifre + kod doğrulaması ile değişiklik arasındaki azami süre (tek kullanımlık izin).
  yenidenDogrulamaSuresi: 2 * 60 * 1000,
};
