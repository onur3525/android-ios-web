// ═══════════════════════════════════════════════════════════════
// KULLANICI API'Sİ — KİMLİK, OTURUM, PROFİL (/api/v1)
//
// Biçimler Flutter `auth_api.dart` / `profile_api.dart` / `mappers.dart`
// ile birebir. Telefon istemcide olduğu gibi 10 hane ('5XXXXXXXXX').
//
// ⚠ HESAP DURUMU HER İSTEKTE SUNUCUDA DENETLENİR: askıya alınmış ya da
// banlı kullanıcının geçerli token'ı olsa bile hiçbir korumalı uç
// çalışmaz (403 ACCOUNT_SUSPENDED / ACCOUNT_BANNED). Askı/ban anında
// bütün oturumları da iptal edilir.
// ═══════════════════════════════════════════════════════════════
import { createHash, randomBytes, randomInt, randomUUID, timingSafeEqual } from 'node:crypto';
import { sifreDogrulaAsenkron, sifreOzetleAsenkron } from '../auth.js';
import { gonder, kanalHazir } from '../bildirim.js';
import { config, uretim } from '../config.js';
import { simdi } from '../db.js';
import { dosyalariDogrula, imzaliGorselAdresi } from '../depo_dogrulama.js';
import { dosyalariBagla } from './depolama_entegrasyon.js';
import { silinmekUzereIsaretle } from '../dosya_temizligi.js';
import { ApiHatasi, HizSiniri, cerez, cerezleriOku, hata, istemciIp } from '../http.js';
import { jwtDogrula, jwtImzala } from '../jwt.js';
import { olaylar } from '../olaylar.js';
import {
  firebaseKullaniciBilgisi, firebaseKullaniciSil, firebaseOturumlariniIptalEt, firebaseSifreAyarla, firebaseSifreDegistir, firebaseSifreDogrula,
  firebaseOzelBelge, firebaseTelefonAyarla, firebaseTokenDogrula, firebaseYonetimiHazir,
  firebaseEpostaAyarla, firebaseEpostaBaglantisi,
} from '../firebase_token.js';
import { firebaseIslemiKuyrugaEkle } from '../firebase_islemleri.js';

const OTP_SURESI = 3 * 60 * 1000;
const OTP_DENEME = 5;
const GIRIS_KILIT_ESIGI = 5;
const GIRIS_KILIT_SURESI = 15 * 60 * 1000;
const otpIpSiniri = new HizSiniri('otp_ip', 20, 60 * 60 * 1000);
const girisIpSiniri = new HizSiniri('giris_ip', 30, 15 * 60 * 1000);
// Rol ekleme: kullanıcı başına 15 dakikada en çok 5 deneme (şifre denemesi
// bu uçtan sınırsız yapılamasın).
const rolEklemeSiniri = new HizSiniri('rol_ekleme', 5, 15 * 60 * 1000);
// Oturumla yapılan şifre denetimleri (şifre doğrulama, telefon değiştirme,
// hesap silme talebi): kullanıcı başına 15 dakikada en çok 10 deneme —
// çalınmış oturumla şifre tahmini sınırlanır. İstemci tek işlemde iki kez
// sorar (önce doğrulama, sonra işlemin kendisi). Sayaç şifre denetiminden
// ÖNCE işler.
export const kritikIslemSiniri = new HizSiniri('kritik_islem', 10, 15 * 60 * 1000);

const ozet = (v) => createHash('sha256').update(v).digest('hex');
const otpOzet = (telefon, amac, kod) => ozet(`${config.jwtSirri}|${telefon}|${amac}|${kod}`);

export function telefon(v) {
  const t = String(v ?? '').replace(/\D/g, '').replace(/^90(?=5\d{9}$)/, '').replace(/^0+/, '');
  if (!/^5\d{9}$/.test(t)) throw hata.dogrulama('Geçerli bir cep telefonu numarası giriniz');
  return t;
}
function sifreKurali(s) {
  if (typeof s !== 'string' || s.length < 8 || s.length > 64) throw hata.dogrulama('Şifre 8-64 karakter olmalıdır');
  return s;
}
function eposta(v) {
  const e = String(v ?? '').trim().toLowerCase();
  // ⚠ UZUNLUK ÖNCE: bu desen çok uzun girdide karesel geri izleme yapar
  // (1 MB gövdeyle tek bir oturumsuz istek olay döngüsünü dakikalarca
  // kilitleyebiliyordu). 254 sınırı zaten geçerliydi; yalnız sıra değişti.
  if (e.length > 254 || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)) throw hata.dogrulama('Geçerli bir e-posta giriniz');
  return e;
}
function adSoyad(v) {
  const t = String(v ?? '').trim().replace(/\s+/g, ' ');
  if (t.length < 2 || t.length > 100) throw hata.dogrulama('Ad soyad 2-100 karakter olmalıdır');
  return t;
}
const rolDogrula = (r) => {
  if (r !== 'CUSTOMER' && r !== 'PROVIDER') throw hata.dogrulama('Geçersiz rol');
  return r;
};
const roller = (u) => u.roles.split(',').filter(Boolean);

/** Hesap durumu kapısı — her korumalı istekte ve girişte. */
export function durumKapisi(u) {
  if (u.status === 'SUSPENDED') throw new ApiHatasi(403, 'ACCOUNT_SUSPENDED', 'Hesabınız askıya alınmıştır.');
  if (u.status === 'BANNED') throw new ApiHatasi(403, 'ACCOUNT_BANNED', 'Hesabınız kapatılmıştır.');
}

/** Profil fotoğraflarının (rol bazlı) imzalı görüntüleme adresleri. */
export async function profilFotograflari(db, u) {
  return {
    customer: await imzaliGorselAdresi(db, u.photo_customer_ref),
    provider: await imzaliGorselAdresi(db, u.photo_provider_ref),
  };
}

export function kullaniciGorunumu(u, saglayici, fotograflar = null) {
  return {
    ...(fotograflar ? { photos: fotograflar } : {}),
    id: u.id, name: u.name, email: u.email ?? '', phone: u.phone,
    phoneVerified: u.phone_verified === 1, emailVerified: u.email_verified === 1,
    roles: roller(u), activeRole: u.active_role, createdAt: u.created_at,
    // Bildirim tercihleri sunucuda tutulur (push gönderimi bunlara uyar).
    notificationPrefs: {
      offer: u.notif_offer !== 0, message: u.notif_message !== 0,
      announcement: u.notif_announcement !== 0, email: u.notif_email !== 0,
    },
    ...(saglayici ? { providerProfile: saglayici } : {}),
  };
}

// ── OTP ─────────────────────────────────────────────────────
const smsYok = () => new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Doğrulama kodu şu anda gönderilemiyor. Lütfen daha sonra tekrar deneyin.');

async function otpUret(db, tel, amac, ip) {
  await otpIpSiniri.denetle(db, ip);
  const son = await db.prepare(
    `SELECT created_at FROM otp_codes WHERE phone = ? AND purpose = ? ORDER BY created_at DESC LIMIT 1`,
  ).get(tel, amac);
  if (son && Date.now() - Date.parse(son.created_at) < 60_000) throw hata.hiz('Yeni kod istemek için 60 saniye bekleyin');
  const saatlik = await db.prepare(
    `SELECT COUNT(*) n FROM otp_codes WHERE phone = ? AND created_at > ?`,
  ).get(tel, new Date(Date.now() - 3_600_000).toISOString());
  if (saatlik.n >= 5) throw hata.hiz('Bu numara için çok fazla kod istendi. Lütfen daha sonra deneyin.');
  const kod = String(randomInt(0, 1_000_000)).padStart(6, '0');
  await db.prepare(
    `INSERT INTO otp_codes (id, phone, purpose, code_hash, expires_at, attempts, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)`,
  ).run(randomUUID(), tel, amac, otpOzet(tel, amac, kod), new Date(Date.now() + OTP_SURESI).toISOString(), simdi());
  const g = await gonder(db, { kanal: 'SMS', hedef: `+90${tel}`, sablon: 'OTP', degerler: { KOD: kod }, gizliGovde: true });
  if (g.status !== 'SENT') {
    // Kod kullanıcıya ULAŞMADI: kayıt geri alınır (60 sn bekleme/saatlik
    // sınır boşa harcanmasın). Neden outbound_messages'ta FAILED durur.
    await db.prepare('DELETE FROM otp_codes WHERE phone = ? AND purpose = ? AND consumed_at IS NULL AND code_hash = ?')
      .run(tel, amac, otpOzet(tel, amac, kod));
    // Kayıtlı OLMAYAN numara için yapılan amaçlarda (REGISTER/PHONE_CHANGE)
    // hata açıkça döner. FORGOT/LOGIN/ROLE_ADD yanıtı NÖTR kalır: aksi hâlde
    // "503 = numara kayıtlı" diye kayıt bilgisi sızardı. (Sağlayıcı hiç
    // yapılandırılmamışsa rota numaraya bakmadan önce 503 döner.)
    if (amac === 'REGISTER' || amac === 'PHONE_CHANGE') throw smsYok();
    return null;
  }
  return kod; // yalnız testlerde kullanılır; yanıta ASLA yazılmaz
}

async function otpTuket(db, tel, amaclar, kod) {
  if (!/^\d{6}$/.test(String(kod ?? ''))) throw new ApiHatasi(400, 'OTP_INVALID', 'Doğrulama kodu hatalı');
  const yer = amaclar.map(() => '?').join(', ');
  const k = await db.prepare(
    `SELECT * FROM otp_codes WHERE phone = ? AND purpose IN (${yer}) AND consumed_at IS NULL
      ORDER BY created_at DESC LIMIT 1`,
  ).get(tel, ...amaclar);
  if (!k || Date.parse(k.expires_at) < Date.now()) throw new ApiHatasi(400, 'OTP_EXPIRED', 'Doğrulama kodunun süresi doldu. Yeni kod isteyin.');
  if (k.attempts >= OTP_DENEME) throw hata.hiz('Çok fazla hatalı deneme. Yeni kod isteyin.');
  const dogru = Buffer.from(otpOzet(tel, k.purpose, String(kod)));
  if (!timingSafeEqual(dogru, Buffer.from(k.code_hash))) {
    await db.prepare('UPDATE otp_codes SET attempts = attempts + 1 WHERE id = ?').run(k.id);
    throw new ApiHatasi(400, 'OTP_INVALID', 'Doğrulama kodu hatalı');
  }
  // Koşullu tüketim: aynı kod eşzamanlı iki istekte İKİ KEZ kullanılamaz.
  const t = await db.prepare('UPDATE otp_codes SET consumed_at = ? WHERE id = ? AND consumed_at IS NULL').run(simdi(), k.id);
  if (t.changes !== 1) throw new ApiHatasi(400, 'OTP_EXPIRED', 'Doğrulama kodunun süresi doldu. Yeni kod isteyin.');
}

// ── Oturum ──────────────────────────────────────────────────
async function oturumVer(db, kullaniciId, req) {
  // DONDURULMUŞ HESAP YENİDEN GİRİŞLE ETKİNLEŞİR (uygulamadaki metin:
  // "Dilediğiniz zaman tekrar giriş yaparak hesabınızı etkinleştirebilirsiniz").
  // Oturum yalnız kimlik doğrulandıktan sonra verildiği için tek kapı burası.
  await db.prepare('UPDATE users SET frozen_at = NULL, updated_at = ? WHERE id = ? AND frozen_at IS NOT NULL').run(simdi(), kullaniciId);
  const jti = randomUUID();
  const yenileme = randomBytes(32).toString('base64url');
  const z = simdi();
  await db.prepare(
    `INSERT INTO user_sessions (id, user_id, refresh_hash, created_at, last_used, expires_at, ip, user_agent)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(jti, kullaniciId, ozet(yenileme), z, z, new Date(Date.now() + config.yenilemeSuresi).toISOString(),
    istemciIp(req), String(req.headers['user-agent'] ?? '').slice(0, 200));
  return { accessToken: erisimTokeni(kullaniciId, jti), refreshToken: yenileme };
}
// ── WEB OTURUMU: HttpOnly YENİLEME ÇEREZİ (15 Eki) ──
// Web istemcisi (X-HC-Web: 1) yenileme token'ını KALICI depoya yazmaz
// (güvenlik turu M-05); oturumun sayfa yenilenince/sekme kapanınca
// sürmesi için sunucu token'ı JavaScript'in okuyamadığı bir çereze koyar.
//   · HttpOnly + Secure; yalnız /api/v1/auth yoluna gider.
//   · SameSite=None: test sitesi (github.io) ile API farklı sitelerde.
//     CSRF koruması: çerez YALNIZ X-HC-Web başlığıyla kabul edilir; özel
//     başlık CORS ön kontrolünü zorunlu kılar ve yalnız izin listesindeki
//     kökenler geçer. Yanıtı da yalnız onlar okuyabilir.
//   · Mobil istemci (başlıksız) davranışı AYNEN: çerez yazılmaz/okunmaz.
const YENILEME_CEREZI = 'hc_rt';
const YENILEME_YARIS_PAYI_MS = 60_000;
const yenilemeCerezAyari = { secure: true, path: '/api/v1/auth', sameSite: 'None' };
const webIstemcisi = (req) => req.headers['x-hc-web'] === '1';
function yenilemeCereziYaz(ctx, rt) {
  if (webIstemcisi(ctx.req)) {
    ctx.cerezEkle(cerez(YENILEME_CEREZI, rt, { ...yenilemeCerezAyari, maxAgeSn: Math.floor(config.yenilemeSuresi / 1000) }));
  }
}
function yenilemeCereziSil(ctx) {
  if (webIstemcisi(ctx.req)) {
    ctx.cerezEkle(cerez(YENILEME_CEREZI, '', { ...yenilemeCerezAyari, maxAgeSn: 0 }));
  }
}
/** Oturum yanıtı: web istemcisine yenileme çerezi de yazılır. */
function oturumYaniti(ctx, oturum) {
  yenilemeCereziYaz(ctx, oturum.refreshToken);
  return oturum;
}

function erisimTokeni(kullaniciId, jti) {
  return jwtImzala({ sub: kullaniciId, jti, exp: Math.floor((Date.now() + config.erisimSuresi) / 1000) });
}
export async function oturumlariIptal(db, kullaniciId, neden, haric) {
  await db.prepare(
    `UPDATE user_sessions SET revoked_at = ?, revoke_reason = ? WHERE user_id = ? AND revoked_at IS NULL ${haric ? 'AND id <> ?' : ''}`,
  ).run(simdi(), neden, kullaniciId, ...(haric ? [haric] : []));
  // Açık gerçek zamanlı bağlantılar da kapanır.
  await olaylar.yayinla('user.sessions.revoked', { userId: kullaniciId, haric: haric ?? null });
}

/** Bearer token → kullanıcı (+ oturum). Hesap durumu kapısı dahil. */
export async function kullaniciCoz(db, req) {
  const b = String(req.headers.authorization ?? '');
  if (!b.startsWith('Bearer ')) throw hata.kimlik();
  const yuk = jwtDogrula(b.slice(7));
  if (!yuk) throw hata.kimlik('Oturum süresi doldu');
  const o = await db.prepare('SELECT * FROM user_sessions WHERE id = ?').get(yuk.jti);
  if (!o || o.revoked_at || o.user_id !== yuk.sub) throw hata.kimlik('Oturum sonlandırılmış');
  const u = await db.prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').get(yuk.sub);
  if (!u) throw hata.kimlik();
  durumKapisi(u);
  // Dondurulmuş hesap API kullanamaz (oturumları zaten kapatılır; ikinci savunma).
  if (u.frozen_at) throw new ApiHatasi(401, 'ACCOUNT_FROZEN', 'Hesabınız dondurulmuş. Tekrar giriş yaparak etkinleştirebilirsiniz.');
  return { u, oturum: o };
}

async function saglayiciProfili(db, kullaniciId) {
  const p = await db.prepare('SELECT * FROM provider_profiles WHERE user_id = ?').get(kullaniciId);
  return p ? { categories: JSON.parse(p.categories_json), districts: JSON.parse(p.districts_json) } : null;
}

/**
 * ŞİFRE DOĞRULAMASI — TEK KAYNAK (giriş, şifre doğrulama, rol ekleme,
 * şifre değiştirme AYNI kuralı kullanır).
 *
 * Firebase'e bağlı ve e-postası olan hesapta şifrenin kaynağı Firebase'dir
 * (e-postayla sıfırlama yalnız Firebase'i değiştirir). Önceden yalnız giriş
 * Firebase'e bakıyor, şifre doğrulama / rol ekleme yerel özete bakıyordu:
 * Firebase'den sıfırlanan şifreyle giriş olur ama HESAP SİLME'nin şifre
 * adımı DOĞRU şifreyle de reddedilirdi. Firebase yapılandırılmamışsa ya da
 * ulaşılamıyorsa (null) yerel özet kullanılır — girişteki mevcut davranış.
 * Firebase doğrularsa yerel özet de eşitlenir (Firebase kesintisinde yedek
 * doğrulama eski şifreyi kabul etmesin).
 */
export async function sifreDogruMu(db, u, sifre) {
  let fb = u.firebase_uid && u.email ? await firebaseSifreDogrula(u.email, sifre).catch(() => null) : null;
  // ── ⚠ E-POSTASI FIREBASE'DE DEĞİŞMİŞ HESAP (21 Eki, kullanıcı bulgusu) ──
  // "Doğrula ve değiştir" bağlantısı tıklanınca adres Firebase'de değişir;
  // sunucu henüz eski adresi tutuyorsa Firebase şifre denetimi ESKİ adresle
  // yapılıp reddediliyordu ve kullanıcı doğru şifreyle giriş yapamıyordu.
  // Reddedilirse Firebase'deki güncel adresle bir kez daha denenir; o adres
  // doğrulanmışsa (ve başka hesapta değilse) hesaba da işlenir.
  if (fb === false && u.firebase_uid && firebaseYonetimiHazir()) {
    const k = await firebaseKullaniciBilgisi(u.firebase_uid).catch(() => null);
    const fbEposta = String(k?.email || '').trim().toLowerCase();
    if (fbEposta && fbEposta !== String(u.email).trim().toLowerCase()) {
      fb = await firebaseSifreDogrula(fbEposta, sifre).catch(() => null);
      if (fb === true && k.epostaDogrulandi
          && !(await db.prepare('SELECT 1 FROM users WHERE lower(email) = ? AND id <> ? AND deleted_at IS NULL').get(fbEposta, u.id))) {
        await db.prepare('UPDATE users SET email = ?, email_verified = TRUE, updated_at = ? WHERE id = ?').run(fbEposta, simdi(), u.id);
      }
    }
  }
  if (fb === null) return await sifreDogrulaAsenkron(sifre, u.password_hash);
  if (fb === true && !await sifreDogrulaAsenkron(sifre, u.password_hash)) {
    await db.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?').run(await sifreOzetleAsenkron(sifre), simdi(), u.id);
  }
  return fb;
}

/** Firebase ID token → yük; geçersizse 401. */
async function firebaseKimlikIste(token) {
  const yuk = await firebaseTokenDogrula(token).catch(() => null);
  if (!yuk) throw new ApiHatasi(401, 'AUTH_FAILED', 'Doğrulama geçersiz ya da süresi dolmuş');
  return yuk;
}

/** Token'daki doğrulanmış telefon, beklenen numarayla AYNI olmalı. */
function firebaseTelefonu(yuk, beklenen) {
  let tel = null;
  try {
    tel = yuk.phone_number ? telefon(yuk.phone_number) : null;
  } catch {
    tel = null;
  }
  if (!tel || (beklenen && tel !== beklenen)) {
    throw new ApiHatasi(400, 'OTP_INVALID', 'Doğrulanan telefon numarası eşleşmiyor');
  }
  return tel;
}

// ── ⚠ FIREBASE BELGESİ İPTAL DENETİMİ (15 Eki güvenlik denetimi) ──
//
// Şifre sıfırlama/değiştirme ve telefon değişikliğinden sonra, o andan ÖNCE
// kimlik doğrulaması yapılmış Firebase belgeleriyle (başka bir cihazda açık
// kalmış Firebase oturumunun yenilediği belgeler dahil — yenilemede
// `auth_time` DEĞİŞMEZ) yeni sunucu oturumu açılmaz. İki katman:
//   1. Yerel: users.firebase_valid_since (her zaman; Google'a ulaşılamasa da).
//   2. Firebase: Admin SDK `verifyIdToken(checkRevoked)` ile aynı kural —
//      `accounts:lookup` → `disabled` ya da `auth_time < validSince` → red.
//      Servis hesabı varsa çalışır; Google'a ulaşılamazsa kapalı kalır (503).
function iptalHatasi(durum) {
  return new ApiHatasi(durum, 'AUTH_REVOKED', 'Bu doğrulama artık geçerli değil. Lütfen yeniden giriş yapın.');
}
export async function firebaseBelgesiIptalDenetimi(db, u, yuk, { durum = 401 } = {}) {
  const yerel = u?.firebase_valid_since == null ? null : Number(u.firebase_valid_since);
  if (yerel && !(yuk.auth_time >= yerel)) throw iptalHatasi(durum);
  if (!firebaseYonetimiHazir()) return;
  let k;
  try {
    k = await firebaseKullaniciBilgisi(yuk.sub);
  } catch {
    throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Doğrulama şu anda yapılamıyor. Lütfen daha sonra tekrar deneyin.');
  }
  if (!k || k.disabled || (k.validSince && !(yuk.auth_time >= k.validSince))) throw iptalHatasi(durum);
}

/**
 * Hesabın Firebase oturumlarını kapatır: yerel geçerlilik sınırı HER ZAMAN
 * yazılır; Firebase'deki yenileme belirteçleri servis hesabı varsa iptal
 * edilir. Firebase'e yazılamazsa (ya da servis hesabı yoksa) ana işlem geri
 * alınmaz — yerel sınır yeni sunucu oturumunu zaten engeller — ve iptal
 * KALICI kuyruğa (firebase_islem_kuyrugu, REVOKE) yazılıp arka planda
 * tamamlanır. Dönen değer: 'tamam' · 'kuyrukta' · null (Firebase'e bağlı değil).
 */
export async function firebaseOturumlariniKapat(db, u, gecerlilikSn = Math.floor(Date.now() / 1000), { firebaseYazildi = false } = {}) {
  // Sınır geriye gitmez (eşzamanlı iki işlemde küçük olan büyüğü ezmesin).
  await db.prepare('UPDATE users SET firebase_valid_since = ? WHERE id = ? AND (firebase_valid_since IS NULL OR firebase_valid_since < ?)')
    .run(gecerlilikSn, u.id, gecerlilikSn);
  if (!u.firebase_uid) return null;
  if (firebaseYazildi) return 'tamam';
  if (firebaseYonetimiHazir()) {
    try {
      await firebaseOturumlariniIptalEt(u.firebase_uid, gecerlilikSn);
      return 'tamam';
    } catch (e) {
      console.error(`firebase_oturum_iptali: ${String(e?.message ?? '').slice(0, 120)}`);
    }
  }
  await firebaseIslemiKuyrugaEkle(db, u.id, 'REVOKE', gecerlilikSn);
  return 'kuyrukta';
}

// ── ⚠ FIREBASE'DE DIŞARIDA YAPILAN DEĞİŞİKLİKLERİN UZLAŞTIRILMASI (15 Eki) ──
//
// E-posta bağlantısıyla şifre sıfırlama tamamen Firebase'de olur (Firebase'in
// sayfası); sunucu haberdar edilmez. Firebase bu değişiklikte kullanıcının
// yenileme belirteçlerini kendisi iptal eder ve kaydına `validSince`
// (tokensValidAfterTime) ile `passwordUpdatedAt` yazar — Firebase Admin
// `getUser` / Identity Toolkit `accounts:lookup` ile okunabilen GERÇEK alanlar.
// Sunucu her oturum yenilemesinde (erişim belirteci 15 dk) kaydı en çok 5
// dakikada bir okur. Firebase sınırı yerel sınırdan YENİYSE (dışarıda iptal:
// e-postayla sıfırlama, konsoldan iptal, Firebase'de şifre değişikliği):
//   · o andan ÖNCE açılmış bütün sunucu oturumları kapatılır (yenileme
//     reddedilir, soketler kapanır), sonradan yeni şifreyle açılanlar kalır;
//   · yerel sınır Firebase'inkine çekilir (eski belgeyle oturum açılmaz);
//   · iptal bir şifre değişikliğinden geldiyse yerel şifre özeti
//     kullanılamaz yapılır — Firebase'e ulaşılamadığında yedek doğrulama
//     ESKİ şifreyi kabul etmesin; Firebase yeni şifreyi doğrulayınca özet
//     yeniden eşitlenir (sifreDogruMu).
// Devre dışı bırakılmış Firebase kullanıcısının bütün oturumları kapanır.
// Firebase'e ulaşılamazsa yenileme ENGELLENMEZ (bir sonraki yenilemede yine
// denenir); Google kesintisi bütün kullanıcıları çıkış yaptırmasın.
const UZLASTIRMA_ARALIGI_MS = 5 * 60_000;
export async function firebaseDisDegisiklikleriniUzlastir(db, u) {
  if (!u.firebase_uid || !firebaseYonetimiHazir()) return;
  const son = u.firebase_checked_at ? Date.parse(u.firebase_checked_at) : 0;
  if (Date.now() - son < UZLASTIRMA_ARALIGI_MS) return;
  await db.prepare('UPDATE users SET firebase_checked_at = ? WHERE id = ?').run(simdi(), u.id);
  let k;
  try {
    k = await firebaseKullaniciBilgisi(u.firebase_uid);
  } catch (e) {
    console.error(`firebase_uzlastirma: ${String(e?.message ?? '').slice(0, 120)}`);
    return;
  }
  if (!k) return;
  if (k.disabled) {
    await oturumlariIptal(db, u.id, 'FIREBASE_DISABLED');
    return;
  }
  const yerel = Number(u.firebase_valid_since ?? 0);
  if (!k.validSince || k.validSince <= yerel) return;
  const sinirIso = new Date(k.validSince * 1000).toISOString();
  const sifreDegisti = k.sifreGuncellemeMs != null && k.sifreGuncellemeMs >= (k.validSince - 5) * 1000;
  await db.tx(async () => {
    await db.prepare(`UPDATE user_sessions SET revoked_at = ?, revoke_reason = 'FIREBASE_REVOKED' WHERE user_id = ? AND revoked_at IS NULL AND created_at < ?`)
      .run(simdi(), u.id, sinirIso);
    await db.prepare('UPDATE users SET firebase_valid_since = ? WHERE id = ?').run(k.validSince, u.id);
    if (sifreDegisti) {
      await db.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?').run(`firebase-disi$${randomUUID()}`, simdi(), u.id);
    }
  });
  await olaylar.yayinla('user.sessions.revoked', { userId: u.id, haric: null });
}

/**
 * ── KRİTİK İŞLEM: YAKIN ZAMANDA, YENİ TELEFON DOĞRULAMASI (15 Eki) ──
 *
 * Firebase ID token 1 saat geçerlidir ve oturum boyunca YENİLENİR; yeni bir
 * token, kullanıcının yeni bir doğrulama yaptığını GÖSTERMEZ (yenilemede
 * `iat` değişir, `auth_time` DEĞİŞMEZ). Bu yüzden üç koşul birlikte aranır:
 *   1. `firebase.sign_in_provider === 'phone'` — son kimlik doğrulama SMS
 *      koduyla yapıldı (şifre/e-posta oturumunun belgesi kabul edilmez);
 *   2. `auth_time` son YAKIN_DOGRULAMA_SN içinde (gelecek zaman ve saat
 *      kayması firebaseTokenDogrula'da reddedilir);
 *   3. `auth_time`, bu SUNUCU OTURUMUNUN açılışından en az OTURUM_PAYI_SN
 *      SONRA — telefonla girişte alınan belge (doğrulama oturumdan hemen
 *      ÖNCE yapılır) rol eklemede YENİDEN KULLANILAMAZ; kullanıcı rol ekleme
 *      sırasında YENİ bir kod doğrulamak zorundadır. Oturum yenilemede
 *      (`/auth/refresh`) açılış zamanı korunur, bu yüzden pencere kaymaz.
 */
const YAKIN_DOGRULAMA_SN = 10 * 60;
const OTURUM_PAYI_SN = 30; // sunucu ile Firebase saat farkına pay
export function yakinTelefonDogrulamasi(yuk, oturumBaslangici, simdiMs = Date.now()) {
  const an = Math.floor(simdiMs / 1000);
  const yontem = yuk?.firebase?.sign_in_provider;
  // ISO metin (SQLite `simdi()` ve PostgreSQL ayrıştırıcısı: UTC 'Z') ya da Date.
  // ⚠ Boş değer 0'a (1970) dönüşüp denetimi etkisizleştirmesin: NaN → red.
  const acilis = oturumBaslangici ? Math.floor(new Date(oturumBaslangici).getTime() / 1000) : NaN;
  if (yontem !== 'phone' || typeof yuk.auth_time !== 'number' || an - yuk.auth_time > YAKIN_DOGRULAMA_SN
      || !Number.isFinite(acilis) || yuk.auth_time < acilis + OTURUM_PAYI_SN) {
    throw new ApiHatasi(400, 'REAUTH_REQUIRED', 'Güvenliğiniz için telefonunuza gelen yeni kodla doğrulama yapın.');
  }
}

/**
 * Telefon doğrulama kanıtı: Firebase ID token (canlı yol) YA DA sunucunun
 * kendi OTP'si (eski/yedek yol). Firebase yolunda dönen `uid` hesaba bağlanır.
 */
async function telefonKaniti(db, body, tel, amaclar, { yakinDogrulama = null } = {}) {
  if (body.firebaseIdToken) {
    // İmza, proje (aud/iss), süre ve sub denetimi firebaseTokenDogrula'da.
    let yuk;
    if (yakinDogrulama) {
      // Oturum AÇIKKEN yapılan kritik işlem: geçersiz kanıt 401 DEĞİL 400
      // döner — istemci 401'de oturum yenileyip isteği TEKRARLAR (hız
      // sınırını iki kez tüketirdi) ve kanıt hatası oturum hatası değildir.
      yuk = await firebaseTokenDogrula(body.firebaseIdToken).catch(() => null);
      if (!yuk) throw new ApiHatasi(400, 'PHONE_PROOF_INVALID', 'Telefon doğrulaması geçersiz ya da süresi dolmuş. Yeni kod isteyin.');
      // Belgenin geçerli olması YETMEZ — yakın zamanda ve bu oturum
      // açıldıktan SONRA telefonla yeniden doğrulama (yakinTelefonDogrulamasi).
      yakinTelefonDogrulamasi(yuk, yakinDogrulama.oturumBaslangici);
    } else {
      yuk = await firebaseKimlikIste(body.firebaseIdToken);
    }
    firebaseTelefonu(yuk, tel);
    return { uid: yuk.sub, yuk };
  }
  await otpTuket(db, tel, amaclar, body.otpCode);
  return { uid: null, yuk: null };
}

export function kullaniciRotalar(r, db) {
  const korumali = (f) => async (ctx) => {
    const { u, oturum } = await kullaniciCoz(db, ctx.req);
    ctx.kullanici = u;
    ctx.kOturum = oturum;
    return f(ctx);
  };

  // ── OTP ──
  r.post('/api/v1/auth/otp/request', async (ctx) => {
    const tel = telefon(ctx.body.phone);
    const amac = String(ctx.body.purpose ?? '');
    if (!['REGISTER', 'LOGIN', 'FORGOT', 'PHONE_CHANGE', 'ROLE_ADD'].includes(amac)) throw hata.dogrulama('Geçersiz amaç');
    // Gönderim yolu hiç yoksa (üretimde sağlayıcı tanımsız + admin
    // entegrasyonu kapalı) numaraya BAKMADAN açıkça reddedilir.
    if (!(await kanalHazir(db, 'SMS'))) throw smsYok();
    const var_ = await db.prepare('SELECT id FROM users WHERE phone = ? AND deleted_at IS NULL').get(tel);
    if ((amac === 'REGISTER' || amac === 'PHONE_CHANGE') && var_) throw hata.cakisma('Bu telefon numarası kayıtlı');
    // FORGOT/LOGIN: numara kayıtlı değilse de AYNI yanıt (kayıt bilgisi sızmaz),
    // ama SMS gönderilmez.
    if ((amac === 'FORGOT' || amac === 'LOGIN' || amac === 'ROLE_ADD') && !var_) return undefined;
    const kod = await otpUret(db, tel, amac, ctx.ip);
    if (!uretim && process.env.HC_TEST_OTP_KANCASI) globalThis.__sonOtp = kod; // yalnız test kancası
    return undefined;
  });

  // ── KAYIT ──
  r.post('/api/v1/auth/register', async (ctx) => {
    const tel = telefon(ctx.body.phone);
    const sifre = sifreKurali(ctx.body.password);
    const isim = adSoyad(ctx.body.name);
    const mail = eposta(ctx.body.email);
    const rol = rolDogrula(ctx.body.role);
    // ── ⚠ SÖZLEŞME ONAYI SUNUCUDA ZORUNLU (15 Eki, işletmeci kararı) ──
    // Uygulama "sözleşme onayı sunucuda da doğrulanır" diyordu ama sunucu
    // onayı hiç denetlemeden terms_accepted=TRUE yazıyordu.
    // ── 16 Eki: AYRI 18 YAŞ KUTUSU KALDIRILDI (Kullanım Sözleşmesi, B/2) ──
    // 18 yaş koşulu artık Kullanım Sözleşmesi madde 4'te sözleşme hükmüdür:
    // kullanıcı sözleşmeyi kabul ederek 18 yaşını doldurduğunu beyan eder.
    // Ayrı `ageConfirmed` alanı istenmez (gönderilirse yok sayılır); beyanın
    // zamanı (`age_confirmed_at`) sözleşme kabulüyle aynı andır.
    if (ctx.body.termsAccepted !== true) throw new ApiHatasi(400, 'TERMS_REQUIRED', 'Kullanım Sözleşmesi onayı zorunludur');
    const kanit = await telefonKaniti(db, ctx.body, tel, ['REGISTER']);
    if (kanit.uid && await db.prepare('SELECT 1 FROM users WHERE firebase_uid = ? AND deleted_at IS NULL').get(kanit.uid)) {
      throw hata.cakisma('Bu doğrulama başka bir hesaba bağlı');
    }
    if (await db.prepare('SELECT 1 FROM users WHERE phone = ? AND deleted_at IS NULL').get(tel)) throw hata.cakisma('Bu telefon numarası kayıtlı');
    if (await db.prepare('SELECT 1 FROM users WHERE lower(email) = ? AND deleted_at IS NULL').get(mail)) throw hata.cakisma('Bu e-posta adresi kayıtlı');
    const id = randomUUID();
    const z = simdi();
    await db.prepare(
      `INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role,
                          status, terms_accepted, failed_logins, created_at, updated_at, firebase_uid, age_confirmed_at)
       VALUES (?, ?, ?, ?, ?, TRUE, ?, ?, ?, 'ACTIVE', TRUE, 0, ?, ?, ?, ?)`,
    ).run(id, tel, mail, isim, await sifreOzetleAsenkron(sifre),
      kanit.yuk?.email_verified === true && String(kanit.yuk.email || '').toLowerCase() === mail ? 1 : 0,
      rol, rol, z, z, kanit.uid, z);
    // Kayıt ekranında bağlantısı verilen belgelerin (Kullanım Koşulları,
    // Gizlilik Politikası) YAYINDAKİ sürümleri onaylandı olarak kaydedilir:
    // hangi metnin onaylandığı (sürüm + SHA-256) sonradan kanıtlanabilir.
    // Onay isteyen diğer belgeler girişteki onay akışında istenir.
    const pl = ['android', 'ios', 'web'].includes(ctx.body.platform) ? ctx.body.platform : null;
    // ── 16 Eki: KAYITTA İKİ ZORUNLU ONAY ──
    // Yeni kayıt ekranında kullanıcı Kullanım Sözleşmesi ile KVKK
    // Aydınlatma Metni'ni AYRI ayrı onaylar (`aydinlatmaAccepted`); kaydı
    // onayladığı belgelere yazılır. Eski uygulama sürümlerinde tek onay
    // satırı "Kullanım sözleşmesi ve gizlilik politikası" idi; onlarda
    // önceki davranış (terms + privacy) korunur.
    const onaylananlar = ctx.body.aydinlatmaAccepted === true ? ['terms', 'kvkk'] : ['terms', 'privacy'];
    for (const v of await db.prepare(
      `SELECT v.* FROM legal_versions v JOIN legal_documents d ON d.slug = v.slug
        WHERE v.slug IN (?, ?) AND v.status = 'PUBLISHED' AND d.active = TRUE`,
    ).all(...onaylananlar)) {
      await db.prepare('INSERT INTO legal_acceptances (id, user_id, slug, version_id, version, sha256, platform, accepted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        .run(randomUUID(), id, v.slug, v.id, v.version, v.sha256, pl, z);
    }
    return oturumYaniti(ctx, await oturumVer(db, id, ctx.req));
  });

  // ── GİRİŞ ──
  r.post('/api/v1/auth/login', async (ctx) => {
    await girisIpSiniri.denetle(db, ctx.ip);
    const tel = telefon(ctx.body.phone);
    const u = await db.prepare('SELECT * FROM users WHERE phone = ? AND deleted_at IS NULL').get(tel);
    const genel = () => new ApiHatasi(401, 'WRONG_PASSWORD', 'Telefon numarası ya da şifre hatalı');
    if (!u) {
      await sifreOzetleAsenkron('zamanlama-esitleme');
      throw genel();
    }
    if (u.locked_until && Date.parse(u.locked_until) > Date.now()) throw hata.hiz('Çok fazla hatalı deneme. Lütfen 15 dakika sonra tekrar deneyin.');
    const sifre = String(ctx.body.password ?? '');
    // Firebase'e bağlı hesapta şifrenin kaynağı Firebase'dir (e-postayla
    // sıfırlama sonrası da geçerli); yapılandırılmamışsa yerel özet.
    if (!(await sifreDogruMu(db, u, sifre))) {
      const n = u.failed_logins + 1;
      await db.prepare('UPDATE users SET failed_logins = ?, locked_until = ? WHERE id = ?').run(
        n >= GIRIS_KILIT_ESIGI ? 0 : n,
        n >= GIRIS_KILIT_ESIGI ? new Date(Date.now() + GIRIS_KILIT_SURESI).toISOString() : null, u.id);
      throw genel();
    }
    durumKapisi(u);
    await db.prepare('UPDATE users SET failed_logins = 0, locked_until = NULL WHERE id = ?').run(u.id);
    return oturumYaniti(ctx, await oturumVer(db, u.id, ctx.req));
  });

  // ── YENİLEME (rotasyon + yeniden kullanım tespiti) ──
  r.post('/api/v1/auth/refresh', async (ctx) => {
    try {
      return oturumYaniti(ctx, await yenile(ctx));
    } catch (e) {
      // Geçersiz/iptal edilmiş çerez tarayıcıda kalmasın.
      if (e instanceof ApiHatasi && e.durum === 401) yenilemeCereziSil(ctx);
      throw e;
    }
  });
  async function yenile(ctx) {
    // Web: token gövdede DEĞİL çerezde gelir (sekmeler arası ortak ve hep
    // güncel; eski bir bellek kopyası yeniden kullanım sayılmaz).
    const rt = String(ctx.body.refreshToken ?? '')
      || (webIstemcisi(ctx.req) ? String(cerezleriOku(ctx.req)[YENILEME_CEREZI] ?? '') : '');
    let o = rt ? await db.prepare('SELECT * FROM user_sessions WHERE refresh_hash = ?').get(ozet(rt)) : null;
    if (!o) throw hata.kimlik();
    // ── ⚠ EŞZAMANLI YENİLEME PAYI (15 Eki, kullanıcı bulgusu: "kapatıp açınca
    // yeniden giriş istiyor") ──
    // Aynı tarayıcıda iki sekme / kısayol + sekme açılışta AYNI çerezle
    // birlikte yeniler, ya da mobilde yanıt yolda kaybolup istek tekrarlanır.
    // İkinci istek az önce döndürülmüş belirteci taşır ve "tekrar kullanım"
    // sayılıp kullanıcının BÜTÜN oturumları kapatılıyordu. Döndürmeden
    // sonraki kısa pay içinde (aynı oturum soyu, aynı cihaz) bu bir hırsızlık
    // değil yarıştır: soyun güncel halkası döndürülür. Pay dışında tespit
    // kuralı aynen sürer.
    // ⚠ MOBİL: SÜRE PAYI YOK (15 Eki, kullanıcı kesin kuralı: "çıkış
    // yapılmadan asla şifre istenmeyecek, cihaz hatırlanacak"). Mobil
    // istemci yanıtı kaybolan ya da uygulama kapanırken yarım kalan
    // yenilemeyi ne zaman tekrarlarsa tekrarlasın, aynı cihazın oturum soyu
    // sürer. Soy kapatılmışsa (çıkış, şifre/telefon değişikliği, askı)
    // halef yoktur ve yenileme reddedilir. Web'de 60 sn payı aynen.
    const mobil = !webIstemcisi(ctx.req);
    if (o.revoked_at && o.revoke_reason === 'ROTATED' && (mobil || Date.now() - Date.parse(o.revoked_at) < YENILEME_YARIS_PAYI_MS)) {
      const halef = await db.prepare(
        `SELECT * FROM user_sessions WHERE user_id = ? AND created_at = ? AND revoked_at IS NULL
           AND (user_agent IS NOT DISTINCT FROM ?) ORDER BY last_used DESC LIMIT 1`,
      ).get(o.user_id, o.created_at, o.user_agent);
      if (halef) o = halef;
    }
    if (o.revoked_at) {
      // İptal edilmiş yenileme token'ı tekrar kullanıldı → çalınmış olabilir:
      // kullanıcının BÜTÜN oturumları kapatılır.
      if (o.revoke_reason === 'ROTATED') await oturumlariIptal(db, o.user_id, 'REUSE_DETECTED');
      throw hata.kimlik();
    }
    // Mobil oturum süresi kullanımla uzar (aşağıda): açık tutulan uygulama
    // 30 günde bir yeniden giriş istemez.
    if (Date.parse(o.expires_at) < Date.now()) throw hata.kimlik('Oturum süresi doldu');
    const u = await db.prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').get(o.user_id);
    if (!u || u.frozen_at) throw hata.kimlik();
    durumKapisi(u);
    // Firebase'de dışarıda yapılan şifre sıfırlama / iptal (bkz. yukarı).
    await firebaseDisDegisiklikleriniUzlastir(db, u);
    if ((await db.prepare('SELECT revoked_at FROM user_sessions WHERE id = ?').get(o.id))?.revoked_at) throw hata.kimlik('Oturum sonlandırılmış');
    const yeniJti = randomUUID();
    const yeni = randomBytes(32).toString('base64url');
    const z = simdi();
    await db.tx(async () => {
      // Koşullu döndürme: aynı yenileme token'ı eşzamanlı iki istekte
      // kullanılırsa yalnız BİRİ yeni oturum alır (diğeri tekrar kullanım
      // sayılır ve bütün oturumlar kapanır).
      const d = await db.prepare(`UPDATE user_sessions SET revoked_at = ?, revoke_reason = 'ROTATED' WHERE id = ? AND revoked_at IS NULL`).run(z, o.id);
      if (d.changes !== 1) throw hata.kimlik();
      await db.prepare(
        `INSERT INTO user_sessions (id, user_id, refresh_hash, created_at, last_used, expires_at, ip, user_agent)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      ).run(yeniJti, u.id, ozet(yeni), o.created_at, z,
        mobil ? new Date(Date.now() + config.yenilemeSuresi).toISOString() : o.expires_at, ctx.ip, o.user_agent);
    });
    return { accessToken: erisimTokeni(u.id, yeniJti), refreshToken: yeni };
  }

  // ── FIREBASE İLE OTURUM ──
  // Firebase kimliği doğrular (telefon OTP ya da e-posta/şifre); HizmetCep
  // hesabı, rolü ve durumu buradadır. Eşleştirme sırası:
  //   1) firebase_uid  2) doğrulanmış telefon  3) doğrulanmış e-posta
  // (2/3'te hesap ilk kez bu Firebase kullanıcısına BAĞLANIR; başka bir
  // uid'ye bağlı hesap asla devralınmaz).
  r.post('/api/v1/auth/firebase/session', async (ctx) => {
    await girisIpSiniri.denetle(db, ctx.ip);
    const yuk = await firebaseKimlikIste(ctx.body.idToken);
    let u = await db.prepare('SELECT * FROM users WHERE firebase_uid = ? AND deleted_at IS NULL').get(yuk.sub);
    if (!u && yuk.phone_number) {
      const tel = firebaseTelefonu(yuk);
      u = await db.prepare('SELECT * FROM users WHERE phone = ? AND deleted_at IS NULL').get(tel);
    }
    if (!u && yuk.email && yuk.email_verified === true) {
      u = await db.prepare('SELECT * FROM users WHERE lower(email) = ? AND deleted_at IS NULL').get(String(yuk.email).toLowerCase());
    }
    if (!u) throw hata.bulunamadi('Bu bilgilerle kayıtlı hesap bulunamadı');
    if (u.firebase_uid && u.firebase_uid !== yuk.sub) throw new ApiHatasi(401, 'AUTH_FAILED', 'Hesap başka bir doğrulamaya bağlı');
    durumKapisi(u);
    // İptal edilmiş (şifre sıfırlama/değiştirme, telefon değişikliği öncesi) belgeyle oturum açılmaz.
    await firebaseBelgesiIptalDenetimi(db, u, yuk);
    // E-posta değişikliği Firebase'de doğrulama bağlantısıyla yapılır
    // (verifyBeforeUpdateEmail); doğrulanmış yeni adres burada hesaba
    // işlenir — başka hesapta kayıtlıysa DEĞİŞTİRİLMEZ.
    const fbEposta = String(yuk.email || '').toLowerCase();
    if (yuk.email_verified === true && fbEposta && fbEposta !== String(u.email || '').toLowerCase()
        && !(await db.prepare('SELECT 1 FROM users WHERE lower(email) = ? AND id <> ? AND deleted_at IS NULL').get(fbEposta, u.id))) {
      await db.prepare('UPDATE users SET email = ?, email_verified = TRUE, updated_at = ? WHERE id = ?').run(fbEposta, simdi(), u.id);
      u = { ...u, email: fbEposta };
    }
    const epostaDogru = yuk.email_verified === true && u.email && fbEposta === u.email.toLowerCase();
    await db.prepare(`UPDATE users SET firebase_uid = ?, email_verified = CASE WHEN ? THEN TRUE ELSE email_verified END,
                        failed_logins = 0, locked_until = NULL, updated_at = ? WHERE id = ?`)
      .run(yuk.sub, epostaDogru ? 1 : 0, simdi(), u.id);
    return oturumYaniti(ctx, await oturumVer(db, u.id, ctx.req));
  });

  r.post('/api/v1/auth/logout', korumali(async (ctx) => {
    await db.prepare(`UPDATE user_sessions SET revoked_at = ?, revoke_reason = 'LOGOUT' WHERE id = ?`).run(simdi(), ctx.kOturum.id);
    yenilemeCereziSil(ctx);
    // Bu oturumla açılmış gerçek zamanlı bağlantı da kapanır.
    await olaylar.yayinla('user.sessions.revoked', { userId: ctx.kullanici.id, oturumId: ctx.kOturum.id });
    return undefined;
  }));

  r.post('/api/v1/auth/password/change', korumali(async (ctx) => {
    const yeni = sifreKurali(ctx.body.newPassword);
    const u = ctx.kullanici;
    const mevcut = String(ctx.body.currentPassword ?? '');
    if (!(await sifreDogruMu(db, u, mevcut))) throw new ApiHatasi(400, 'WRONG_PASSWORD', 'Mevcut şifre hatalı');
    // Firebase'e bağlı hesapta giriş Firebase şifresiyle doğrulanır: yeni şifre
    // ÖNCE Firebase'e yazılır. Yazılamazsa yerel şifre de DEĞİŞMEZ (aksi hâlde
    // kullanıcı yeni şifreyle giremez, eski şifre çalışmaya devam ederdi).
    if (u.firebase_uid && u.email) {
      const fb = await firebaseSifreDegistir(u.email, mevcut, yeni).catch(() => undefined);
      if (fb === false) throw new ApiHatasi(400, 'WRONG_PASSWORD', 'Mevcut şifre hatalı');
      if (fb === undefined) throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Şifre şu anda değiştirilemiyor. Lütfen daha sonra tekrar deneyin.');
    }
    await db.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?').run(await sifreOzetleAsenkron(yeni), simdi(), ctx.kullanici.id);
    await oturumlariIptal(db, ctx.kullanici.id, 'PASSWORD_CHANGED', ctx.kOturum.id);
    // Firebase'deki diğer cihaz oturumları da kapanır (yeni sunucu oturumu açamaz).
    await firebaseOturumlariniKapat(db, u);
    return undefined;
  }));

  r.post('/api/v1/auth/forgot/complete', async (ctx) => {
    const tel = telefon(ctx.body.phone);
    const yeni = sifreKurali(ctx.body.newPassword);
    await telefonKaniti(db, ctx.body, tel, ['FORGOT']);
    const u = await db.prepare('SELECT * FROM users WHERE phone = ? AND deleted_at IS NULL').get(tel);
    if (!u) throw new ApiHatasi(400, 'OTP_INVALID', 'Doğrulama kodu hatalı');
    // ── ⚠ FIREBASE ŞİFRESİ DE SIFIRLANIR (15 Eki güvenlik denetimi) ──
    // Firebase'e bağlı hesapta giriş şifreyi Firebase'den doğrular
    // (`sifreDogruMu`, aynı koşul). Yalnız yerel özet değişirse yeni şifre
    // reddedilir, ESKİ şifre çalışmaya devam ederdi. Firebase güncellenemezse
    // yerel şifre de DEĞİŞMEZ (iki kaynak ayrışmaz; şifre değiştirmeyle aynı).
    // Aynı Firebase çağrısı yenileme belirteçlerini de iptal eder (validSince).
    const gecerlilikSn = Math.floor(Date.now() / 1000);
    let firebaseYazildi = false;
    if (u.firebase_uid && u.email && config.firebaseWebApiKey) {
      try {
        await firebaseSifreAyarla(u.firebase_uid, yeni, { gecerlilikSn });
        firebaseYazildi = true;
      } catch {
        throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Şifre şu anda sıfırlanamıyor. Lütfen daha sonra tekrar deneyin.');
      }
    }
    await db.prepare('UPDATE users SET password_hash = ?, failed_logins = 0, locked_until = NULL, updated_at = ? WHERE id = ?').run(await sifreOzetleAsenkron(yeni), simdi(), u.id);
    await oturumlariIptal(db, u.id, 'PASSWORD_RESET');
    await firebaseOturumlariniKapat(db, u, gecerlilikSn, { firebaseYazildi });
    return undefined;
  });

  r.post('/api/v1/auth/verify-password', korumali(async (ctx) => {
    await kritikIslemSiniri.denetle(db, ctx.kullanici.id);
    if (!(await sifreDogruMu(db, ctx.kullanici, String(ctx.body.password ?? '')))) throw new ApiHatasi(400, 'WRONG_PASSWORD', 'Şifre hatalı');
    return undefined;
  }));

  r.post('/api/v1/auth/roles/add', korumali(async (ctx) => {
    // Kullanıcı başına hız sınırı (şifre denemesi dahil): şifre ve kanıt
    // denetiminden ÖNCE sayılır; çok örnekte ortak (rate_limits tablosu).
    await rolEklemeSiniri.denetle(db, ctx.kullanici.id);
    const rol = rolDogrula(ctx.body.role);
    if (!(await sifreDogruMu(db, ctx.kullanici, String(ctx.body.password ?? '')))) throw new ApiHatasi(400, 'WRONG_PASSWORD', 'Şifre hatalı');
    // ⚠ 21 Eki (kullanıcı kararı): rol eklerken telefon/SMS doğrulaması
    // İSTENMEZ. Oturum açık + mevcut şifre + kullanıcı başına hız sınırı
    // yeterli sayıldı. Eski uygulamaların gönderdiği kanıt/kod yok sayılır.
    const mevcut = roller(ctx.kullanici);
    if (mevcut.includes(rol)) throw hata.cakisma('Bu rol hesabınızda zaten var');
    await db.prepare('UPDATE users SET roles = ?, active_role = ?, updated_at = ? WHERE id = ?').run([...mevcut, rol].join(','), rol, simdi(), ctx.kullanici.id);
    return undefined;
  }));

  r.get('/api/v1/auth/sessions', korumali(async (ctx) =>
    (await db.prepare(`SELECT * FROM user_sessions WHERE user_id = ? AND revoked_at IS NULL AND expires_at > ? ORDER BY last_used DESC`)
      .all(ctx.kullanici.id, simdi()))
      .map((o) => ({ jti: o.id, createdAt: o.created_at, lastUsedAt: o.last_used, userAgent: o.user_agent, current: o.id === ctx.kOturum.id })),
  ));

  r.post('/api/v1/auth/sessions/:jti/revoke', korumali(async (ctx) => {
    const n = await db.prepare(`UPDATE user_sessions SET revoked_at = ?, revoke_reason = 'USER_REVOKED' WHERE id = ? AND user_id = ? AND revoked_at IS NULL`)
      .run(simdi(), ctx.params.jti, ctx.kullanici.id);
    if (!n.changes) throw hata.bulunamadi('Oturum bulunamadı');
    // Sonlandırılan oturumun açık soketi mesaj almaya devam etmesin.
    await olaylar.yayinla('user.sessions.revoked', { userId: ctx.kullanici.id, oturumId: ctx.params.jti });
    return undefined;
  }));

  // ── PROFİL ──
  r.get('/api/v1/users/me', korumali(async (ctx) => kullaniciGorunumu(ctx.kullanici, await saglayiciProfili(db, ctx.kullanici.id), await profilFotograflari(db, ctx.kullanici))));

  // ── BİLDİRİM TERCİHLERİ ──
  // Hesap Ayarları › Bildirim Tercihleri. Yalnız PUSH'u etkiler: kapatılan
  // türde uygulama içi kayıt yine yazılır, cihaza bildirim gitmez.
  // Gönderilmeyen alan değişmez. Değer yalnız boolean kabul edilir.
  r.patch('/api/v1/profiles/me/notifications', korumali(async (ctx) => {
    const alanlar = { offer: 'notif_offer', message: 'notif_message', announcement: 'notif_announcement', email: 'notif_email' };
    const set = [];
    const deger = [];
    for (const [anahtar, sutun] of Object.entries(alanlar)) {
      if (ctx.body[anahtar] === undefined) continue;
      if (typeof ctx.body[anahtar] !== 'boolean') throw hata.dogrulama('Bildirim tercihi açık/kapalı olmalıdır');
      set.push(`${sutun} = ?`);
      deger.push(ctx.body[anahtar] ? 1 : 0);
    }
    if (set.length) {
      await db.prepare(`UPDATE users SET ${set.join(', ')}, updated_at = ? WHERE id = ?`).run(...deger, simdi(), ctx.kullanici.id);
    }
    const u = await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.kullanici.id);
    return kullaniciGorunumu(u).notificationPrefs;
  }));

  r.post('/api/v1/users/me/active-role', korumali(async (ctx) => {
    const rol = rolDogrula(ctx.body.role);
    if (!roller(ctx.kullanici).includes(rol)) throw hata.yetki('Bu rol hesabınızda yok');
    await db.prepare('UPDATE users SET active_role = ?, updated_at = ? WHERE id = ?').run(rol, simdi(), ctx.kullanici.id);
    const u = await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.kullanici.id);
    return kullaniciGorunumu(u, await saglayiciProfili(db, u.id));
  }));

  r.patch('/api/v1/profiles/me', korumali(async (ctx) => {
    const d = {};
    if (ctx.body.name !== undefined) d.name = adSoyad(ctx.body.name);
    // ⚠ GÜVENLİK (12 Eki denetimi): e-posta bu uçla DEĞİŞTİRİLEMEZ. Önceden
    // doğrulamasız değişime (ve başkasının adresini sahiplenmeye) izin
    // veriyordu; karar gereği e-posta yalnız Firebase'de doğrulanmış olarak
    // POST /profiles/me/email/change ile değişir. Flutter bu alanı zaten
    // göndermiyor (api_ports.dart: updateProfile).
    if (ctx.body.email !== undefined) {
      throw hata.dogrulama('E-posta bu yolla değiştirilemez; e-posta değiştirme akışını kullanın');
    }
    if (Object.keys(d).length) {
      const a = Object.keys(d);
      await db.prepare(`UPDATE users SET ${a.map((k) => `${k} = ?`).join(', ')}, updated_at = ? WHERE id = ?`).run(...a.map((k) => d[k]), simdi(), ctx.kullanici.id);
    }
    // ── PROFİL FOTOĞRAFI (rol bazlı) ──
    // photoRef: depoya YÜKLENMİŞ 'profile-photo' referansı (sahibi bu
    // kullanıcı; sunucuda doğrulanır) ya da null/'' (kaldır). photoRole:
    // fotoğrafın ait olduğu rol; kullanıcının o rolü olmalı. Eski fotoğraf
    // silme kuyruğuna girer (başka canlı kayıtta kullanılmıyorsa).
    if (ctx.body.photoRef !== undefined) {
      const u0 = ctx.kullanici;
      const rol = ctx.body.photoRole;
      if (!['CUSTOMER', 'PROVIDER'].includes(rol) || !u0.roles.split(',').includes(rol)) throw hata.dogrulama('Geçersiz fotoğraf rolü');
      const yeni = ctx.body.photoRef === null || ctx.body.photoRef === '' ? null : String(ctx.body.photoRef);
      if (yeni !== null && !/^[A-Za-z0-9/_.-]{1,200}$/.test(yeni)) throw hata.dogrulama('Geçersiz fotoğraf');
      if (yeni) await dosyalariDogrula(db, [yeni], u0.id, 'profile-photo'); // işlem DIŞINDA
      const sutun = rol === 'PROVIDER' ? 'photo_provider_ref' : 'photo_customer_ref';
      let eski = null;
      await db.tx(async () => {
        eski = (await db.prepare(`SELECT ${sutun} r FROM users WHERE id = ?`).get(u0.id)).r;
        if (yeni) await dosyalariBagla(db, [yeni], u0.id);
        await db.prepare(`UPDATE users SET ${sutun} = ?, updated_at = ? WHERE id = ?`).run(yeni, simdi(), u0.id);
      });
      // Eski fotoğraf: artık hiçbir canlı kayıt kullanmıyorsa silme kuyruğuna.
      if (eski && eski !== yeni) await silinmekUzereIsaretle(db, [eski], u0.id);
    }
    const u = await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.kullanici.id);
    return kullaniciGorunumu(u, await saglayiciProfili(db, u.id), await profilFotograflari(db, u));
  }));

  r.post('/api/v1/profiles/me/phone/change', korumali(async (ctx) => {
    // ── ⚠ YARIM KALAN DEĞİŞİKLİĞİN KURTARILMASI (15 Eki) ──
    // İstemci Firebase'deki numarayı istekten ÖNCE değiştirir
    // (`updatePhoneNumber`); sunucu da bazı yollarda Firebase'e yazar. İstek
    // bundan sonra herhangi bir nedenle başarısız olursa (yanlış şifre,
    // kayıtlı numara, veritabanı hatası) Firebase'deki numara yeni, hesaptaki
    // eski kalırdı. Firebase'e bağlı hesapta her sonuçta SYNC_PHONE kuyruğa
    // yazılır: Firebase numarası hesabın GÜNCEL numarasına eşitlenir (zaten
    // eşitse dokunulmaz). Başarıda da yazılır: istemcinin yeniden denemesiyle
    // kuyruğun yarışında bile iki sistem hesap kaydında birleşir.
    const u0 = ctx.kullanici;
    try {
      return await telefonDegistir(ctx);
    } finally {
      if (u0.firebase_uid) await firebaseIslemiKuyrugaEkle(db, u0.id, 'SYNC_PHONE').catch(() => {});
    }
  }));
  async function telefonDegistir(ctx) {
    const yeni = telefon(ctx.body.newPhone);
    // ── ⚠ YENİDEN KİMLİK DOĞRULAMA (15 Eki güvenlik denetimi, karar 2) ──
    // Yalnız oturum + yeni numaraya gelen kod yetmez: çalınmış bir oturumla
    // numara değiştirilip "şifremi unuttum" ile hesap ele geçirilebilirdi.
    // Mevcut şifre, telefon kanıtı TÜKETİLMEDEN önce denetlenir (yanlış
    // şifre kodu harcamaz). Mevcut kontroller (kanıt, benzersizlik) aynen.
    await kritikIslemSiniri.denetle(db, ctx.kullanici.id);
    if (!(await sifreDogruMu(db, ctx.kullanici, String(ctx.body.currentPassword ?? '')))) {
      throw new ApiHatasi(400, 'WRONG_PASSWORD', 'Mevcut şifre hatalı');
    }
    const u0 = ctx.kullanici;
    const kanit = await telefonKaniti(db, ctx.body, yeni, ['PHONE_CHANGE']);
    // ── ⚠ FIREBASE TELEFONU DA GÜNCEL OLMALI (15 Eki güvenlik denetimi) ──
    // Firebase'e bağlı hesapta kanıt AYNI Firebase kullanıcısından gelmeli:
    // Google imzalı belgede `sub` = hesabın uid'si ve `phone_number` = yeni
    // numara ise numara Firebase Auth'ta o kullanıcıya bağlanmıştır
    // (istemci `updatePhoneNumber`). Önceden başka bir Firebase kullanıcısının
    // belgesi de kabul ediliyordu — yerel numara değişir, Firebase'deki
    // numara eskisi kalırdı. Sunucu OTP yolunda numara Firebase'e sunucu
    // yazar; yazılamazsa yerel numara da DEĞİŞMEZ (şifredeki kuralla aynı).
    //
    // İstemcide Firebase oturumu yoksa (telefon + şifreyle giriş) doğrulama
    // yeni numarayla AYRI bir Firebase kullanıcısı açar. Bu kullanıcı hiçbir
    // HizmetCep hesabına bağlı değilse ve yalnız telefon kimliği taşıyorsa
    // sunucu onu siler ve numarayı hesabın Firebase kaydına yazar; değilse
    // belge reddedilir.
    const ayriFirebaseKaydi = kanit.yuk && u0.firebase_uid && kanit.uid !== u0.firebase_uid;
    if (ayriFirebaseKaydi) {
      const ret = () => new ApiHatasi(400, 'PHONE_PROOF_INVALID', 'Telefon doğrulaması bu hesaba ait değil. Yeni kod isteyin.');
      if (!firebaseYonetimiHazir()) throw ret();
      if (await db.prepare('SELECT 1 FROM users WHERE firebase_uid = ?').get(kanit.uid)) throw ret();
      let ayri;
      try { ayri = await firebaseKullaniciBilgisi(kanit.uid); } catch { ayri = undefined; }
      if (ayri === undefined) throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Telefon numarası şu anda değiştirilemiyor. Lütfen daha sonra tekrar deneyin.');
      if (ayri && (ayri.email || ayri.saglayicilar.some((p) => p !== 'phone'))) throw ret();
    }
    if (kanit.yuk) await firebaseBelgesiIptalDenetimi(db, u0, kanit.yuk, { durum: 400 });
    if (await db.prepare('SELECT 1 FROM users WHERE phone = ? AND deleted_at IS NULL').get(yeni)) throw hata.cakisma('Bu telefon numarası kayıtlı');
    if (ayriFirebaseKaydi) {
      try {
        await firebaseKullaniciSil(kanit.uid);
        await firebaseTelefonAyarla(u0.firebase_uid, `+90${yeni}`);
      } catch {
        throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Telefon numarası şu anda değiştirilemiyor. Lütfen daha sonra tekrar deneyin.');
      }
    } else if (!kanit.yuk && u0.firebase_uid) {
      if (!firebaseYonetimiHazir()) throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Telefon numarası şu anda değiştirilemiyor. Lütfen daha sonra tekrar deneyin.');
      try {
        await firebaseTelefonAyarla(u0.firebase_uid, `+90${yeni}`);
      } catch {
        throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Telefon numarası şu anda değiştirilemiyor. Lütfen daha sonra tekrar deneyin.');
      }
    }
    await db.prepare('UPDATE users SET phone = ?, phone_verified = TRUE, updated_at = ? WHERE id = ?').run(yeni, simdi(), ctx.kullanici.id);
    // Diğer cihazlardaki oturumlar kapanır (bu oturum açık kalır); Firebase
    // yenileme belirteçleri de iptal edilir.
    await oturumlariIptal(db, ctx.kullanici.id, 'PHONE_CHANGED', ctx.kOturum.id);
    await firebaseOturumlariniKapat(db, u0);
    const u = await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.kullanici.id);
    // ── İŞLEMİ YAPAN CİHAZIN FIREBASE OTURUMU (15 Eki) ──
    // İptal bu cihazın Firebase oturumunu da kapattı. İptal sınırından SONRA
    // üretilen kısa ömürlü özel belgeyle (Admin SDK createCustomToken ile
    // aynı biçim) istemci yeniden bağlanır; eski oturumlar açılamaz.
    const ozel = u0.firebase_uid ? firebaseOzelBelge(u0.firebase_uid) : null;
    return { ...kullaniciGorunumu(u, await saglayiciProfili(db, u.id)), ...(ozel ? { firebaseCustomToken: ozel } : {}) };
  }

  // ── E-POSTA DEĞİŞTİRME (Firebase kaynaklı, karar: 6 Eki) ──
  //
  // Doğrulama e-postasını FIREBASE gönderir (`verifyBeforeUpdateEmail`);
  // backend kendi doğrulama e-postası GÖNDERMEZ. Bu uç yalnız, kullanıcı
  // bağlantıyı tıkladıktan sonra Firebase'de DOĞRULANMIŞ yeni adresi
  // hesaba işler. Koşullar:
  //   · geçerli Firebase ID token (imza, proje, süre — firebaseTokenDogrula)
  //   · token bu hesaba bağlı Firebase kimliğine ait (firebase_uid eşleşmesi)
  //   · token'daki e-posta doğrulanmış (email_verified === true)
  //   · istenen adres verildiyse token'daki adresle aynı
  //   · adres başka bir hesapta kayıtlı değil
  // Firebase oturum ucu da sonraki girişte aynı eşitlemeyi yapar.
  // ── FIREBASE OTURUM BAĞLANTISI (21 Eki, kullanıcı bulgusu) ──
  // Web'de Firebase oturumu tarayıcıda saklanmaz (Persistence.NONE); sayfa
  // yenilenince HizmetCep oturumu sürer ama Firebase oturumu yoktur. E-posta
  // doğrulama bağlantısını Firebase'in kendisi gönderdiği için oturum gerekir;
  // yoksa "Güvenlik için lütfen yeniden giriş yapın" hatası çıkıyordu. Bu uç,
  // oturum açmış kullanıcıya YALNIZ KENDİ Firebase kimliği için 5 dakikalık
  // özel belge verir (telefon değişikliğindeki yöntemle aynı). Kritik işlem
  // hız sınırına tabidir.
  r.post('/api/v1/auth/firebase/baglanti', korumali(async (ctx) => {
    await kritikIslemSiniri.denetle(db, ctx.kullanici.id);
    const u = await db.prepare('SELECT firebase_uid FROM users WHERE id = ?').get(ctx.kullanici.id);
    if (!u?.firebase_uid) throw hata.durum('Hesabınız e-posta doğrulaması için henüz hazır değil. Çıkış yapıp yeniden giriş yapın.');
    const belge = firebaseOzelBelge(u.firebase_uid);
    if (!belge) throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'E-posta doğrulaması şu anda başlatılamıyor. Lütfen daha sonra tekrar deneyin.');
    return { firebaseCustomToken: belge };
  }));

  // ── ⚠ KURUMSAL DOĞRULAMA E-POSTASI (21 Eki, kullanıcı isteği) ──
  //
  // Bağlantıyı Firebase üretir (göndermez); e-posta HizmetCep
  // tasarımıyla sunucudan gider. E-posta kanalı (admin entegrasyonu)
  // ya da Firebase servis hesabı yoksa HİÇBİR değişiklik yapılmadan
  // { sent:false } döner; istemci o zaman Firebase'in kendi gönderimini
  // kullanır (eski davranış). Bağlantı kayda düz yazılmaz.
  // ── ⚠ E-POSTA ONAYI EŞİTLEME (21 Eki, kullanıcı bulgusu) ──
  //
  // Bağlantıya tıklanınca doğrulama Firebase'de olur; sunucu bunu ancak
  // bir sonraki Firebase girişinde öğreniyordu. Kullanıcı e-postasını
  // doğruladığı hâlde "onaylanmadı" görüyor ve düğme açık kalıyordu.
  // Artık onaysız hesapta Firebase kaydı okunur: doğrulanmış adres
  // profil adresiyle aynıysa onay işlenir; "doğrula ve değiştir"
  // tamamlanmışsa (Firebase'de YENİ adres doğrulanmış) adres de güncellenir.
  // Firebase okunamazsa sessizce eski durum korunur.
  //
  // ⚠ 21 Eki (ikinci kullanıcı bulgusu): ONAYLI hesapta da çalışır. Onaylı
  // adresini değiştiren kullanıcı yeni adresteki bağlantıya tıkladığında
  // Firebase'de adres değişiyordu ama profil eski adresi gösteriyordu;
  // eşitleme yalnız onaysız hesaplarda yapılıyordu.
  const epostaOnayiniEsitle = async (u) => {
    if (!u.firebase_uid || !firebaseYonetimiHazir()) return u;
    let fb;
    try { fb = await firebaseKullaniciBilgisi(u.firebase_uid); } catch { return u; }
    const fbEposta = String(fb?.email || '').trim().toLowerCase();
    if (!fb?.epostaDogrulandi || !fbEposta) return u;
    const mevcut = String(u.email || '').trim().toLowerCase();
    if (fbEposta === mevcut) {
      if (u.email_verified) return u;
      await db.prepare('UPDATE users SET email_verified = TRUE, updated_at = ? WHERE id = ?').run(simdi(), u.id);
    } else {
      if (await db.prepare('SELECT 1 FROM users WHERE lower(email) = ? AND id <> ? AND deleted_at IS NULL').get(fbEposta, u.id)) return u;
      await db.prepare('UPDATE users SET email = ?, email_verified = TRUE, updated_at = ? WHERE id = ?').run(fbEposta, simdi(), u.id);
    }
    return db.prepare('SELECT * FROM users WHERE id = ?').get(u.id);
  };

  r.post('/api/v1/profiles/me/email/sync', korumali(async (ctx) => {
    const u = await epostaOnayiniEsitle(await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.kullanici.id));
    return kullaniciGorunumu(u, await saglayiciProfili(db, u.id), await profilFotograflari(db, u));
  }));

  const epostaBaglantisiGonder = async (ctx, yeni) => {
    await kritikIslemSiniri.denetle(db, ctx.kullanici.id);
    let u = await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.kullanici.id);
    // Kullanıcı bağlantıya zaten tıkladıysa yeniden e-posta gönderilmez.
    if (!yeni && !u.email_verified) {
      u = await epostaOnayiniEsitle(u);
      if (u.email_verified) return { sent: false, reason: 'ALREADY_VERIFIED' };
    }
    const mevcut = String(u.email || '').trim().toLowerCase();
    if (!yeni) {
      if (!mevcut) throw hata.durum('Hesabınızda kayıtlı e-posta adresi yok');
      if (u.email_verified) throw hata.durum('E-posta adresiniz zaten doğrulanmış');
    } else {
      if (yeni === mevcut) throw hata.durum('Yeni adres mevcut adresinizle aynı');
      if (await db.prepare('SELECT 1 FROM users WHERE lower(email) = ? AND id <> ? AND deleted_at IS NULL').get(yeni, u.id)) {
        throw hata.cakisma('Bu e-posta adresi başka bir hesapta kayıtlı');
      }
    }
    if (!u.firebase_uid) throw hata.durum('Hesabınız e-posta doğrulaması için henüz hazır değil. Çıkış yapıp yeniden giriş yapın.');
    if (!firebaseYonetimiHazir() || !(await kanalHazir(db, 'EMAIL'))) return { sent: false, reason: 'CHANNEL_UNAVAILABLE' };

    const baslatilamadi = () => new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'E-posta doğrulaması şu anda başlatılamıyor. Lütfen daha sonra tekrar deneyin.');
    let baglanti;
    try {
      const fb = await firebaseKullaniciBilgisi(u.firebase_uid);
      if (!fb) throw hata.durum('Hesabınız e-posta doğrulaması için henüz hazır değil. Çıkış yapıp yeniden giriş yapın.');
      const fbEposta = String(fb.email || '').trim().toLowerCase();
      if (!yeni) {
        if (fbEposta && fbEposta !== mevcut) {
          throw hata.durum('Firebase hesabındaki e-posta profil adresiyle eşleşmiyor. Önce e-posta değişikliği akışını tamamlayın.');
        }
        if (!fbEposta) await firebaseEpostaAyarla(u.firebase_uid, mevcut);
        baglanti = await firebaseEpostaBaglantisi(mevcut);
      } else {
        // Telefonla açılmış Firebase hesabında e-posta boş olabilir: önce
        // mevcut adres (doğrulanmamış) yazılır; yeni adres yine yalnız
        // bağlantı tıklanınca geçerli olur.
        let kaynak = fbEposta;
        if (!kaynak && mevcut) {
          await firebaseEpostaAyarla(u.firebase_uid, mevcut);
          kaynak = mevcut;
        }
        baglanti = kaynak
          ? await firebaseEpostaBaglantisi(kaynak, yeni)
          : (await firebaseEpostaAyarla(u.firebase_uid, yeni), await firebaseEpostaBaglantisi(yeni));
      }
    } catch (e) {
      if (e instanceof ApiHatasi) throw e;
      if (e?.kod === 'EMAIL_EXISTS') throw hata.cakisma('Bu e-posta adresi başka bir hesapta kayıtlı');
      throw baslatilamadi();
    }
    const hedef = yeni || mevcut;
    const g = await gonder(db, {
      kullaniciId: u.id, kanal: 'EMAIL', hedef,
      sablon: yeni ? 'EPOSTA_DEGISIKLIGI' : 'EPOSTA_DOGRULAMA',
      degerler: { AD: u.name, EPOSTA: hedef, BAGLANTI: baglanti },
      gizliGovde: true,
    });
    if (g.status !== 'SENT') throw new ApiHatasi(502, 'EXTERNAL_SERVICE_ERROR', 'Doğrulama e-postası gönderilemedi. Lütfen daha sonra tekrar deneyin.');
    return { sent: true, email: hedef };
  };

  r.post('/api/v1/profiles/me/email/verification', korumali((ctx) => epostaBaglantisiGonder(ctx, null)));

  r.post('/api/v1/profiles/me/email/change-request', korumali((ctx) => epostaBaglantisiGonder(ctx, eposta(ctx.body.newEmail))));

  r.post('/api/v1/profiles/me/email/change', korumali(async (ctx) => {
    const token = String(ctx.body.firebaseIdToken ?? '').trim();
    if (!token) throw hata.dogrulama('E-posta değişikliği Firebase doğrulaması gerektirir');
    const yuk = await firebaseTokenDogrula(token).catch(() => null);
    if (!yuk) throw new ApiHatasi(401, 'AUTH_FAILED', 'Doğrulama geçersiz ya da süresi dolmuş');
    const u = await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.kullanici.id);
    if (!u.firebase_uid || u.firebase_uid !== yuk.sub) {
      throw new ApiHatasi(403, 'FORBIDDEN', 'Bu doğrulama hesabınıza ait değil');
    }
    await firebaseBelgesiIptalDenetimi(db, u, yuk, { durum: 400 });
    const yeni = String(yuk.email || '').trim().toLowerCase();
    if (!yeni || yuk.email_verified !== true) {
      throw hata.durum('Yeni e-posta adresi henüz doğrulanmadı; e-postanızdaki bağlantıya tıklayın');
    }
    const istenen = String(ctx.body.newEmail ?? '').trim().toLowerCase();
    if (istenen && istenen !== yeni) throw hata.durum('Doğrulanan adres istenen adresle aynı değil');
    if (yeni === String(u.email || '').toLowerCase()) {
      // Aynı adres Firebase'de doğrulanmışsa backend durumunu da eşitle.
      if (!u.email_verified) {
        await db.prepare('UPDATE users SET email_verified = TRUE, updated_at = ? WHERE id = ?').run(simdi(), u.id);
        const g = await db.prepare('SELECT * FROM users WHERE id = ?').get(u.id);
        return kullaniciGorunumu(g, await saglayiciProfili(db, g.id));
      }
      return kullaniciGorunumu(u, await saglayiciProfili(db, u.id));
    }
    if (await db.prepare('SELECT 1 FROM users WHERE lower(email) = ? AND id <> ? AND deleted_at IS NULL').get(yeni, u.id)) {
      throw hata.cakisma('Bu e-posta adresi başka bir hesapta kayıtlı');
    }
    await db.prepare('UPDATE users SET email = ?, email_verified = TRUE, updated_at = ? WHERE id = ?').run(yeni, simdi(), u.id);
    const g = await db.prepare('SELECT * FROM users WHERE id = ?').get(u.id);
    return kullaniciGorunumu(g, await saglayiciProfili(db, g.id));
  }));

  r.get('/api/v1/profiles/me/address', korumali(async (ctx) => {
    const a = await db.prepare('SELECT * FROM addresses WHERE user_id = ?').get(ctx.kullanici.id);
    return a ? { id: a.user_id, city: a.city, district: a.district, neighborhood: a.neighborhood } : undefined;
  }));

  r.put('/api/v1/profiles/me/address', korumali(async (ctx) => {
    const [il, ilce, mah] = ['city', 'district', 'neighborhood'].map((k) => String(ctx.body[k] ?? '').trim());
    // Adres YALNIZ admin'in tanımladığı ve AKTİF bölgelerden seçilebilir.
    const gecerli = await db.prepare(
      `SELECT 1 FROM cities c JOIN districts d ON d.city_id = c.id JOIN neighborhoods n ON n.district_id = d.id
        WHERE c.name = ? AND d.name = ? AND n.name = ?
          AND c.active = TRUE AND d.active = TRUE AND n.active = TRUE
          AND c.deleted_at IS NULL AND d.deleted_at IS NULL AND n.deleted_at IS NULL`,
    ).get(il, ilce, mah);
    if (!gecerli) throw hata.dogrulama('Geçerli bir il, ilçe ve mahalle seçiniz');
    await db.prepare(
      `INSERT INTO addresses (user_id, city, district, neighborhood, updated_at) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET city = excluded.city, district = excluded.district,
         neighborhood = excluded.neighborhood, updated_at = excluded.updated_at`,
    ).run(ctx.kullanici.id, il, ilce, mah, simdi());
    return { id: ctx.kullanici.id, city: il, district: ilce, neighborhood: mah };
  }));

  r.get('/api/v1/profiles/me/provider', korumali(async (ctx) => {
    if (!roller(ctx.kullanici).includes('PROVIDER')) throw hata.yetki('Hizmet veren rolünüz yok');
    return (await saglayiciProfili(db, ctx.kullanici.id)) ?? { categories: [], districts: [] };
  }));

  r.put('/api/v1/profiles/me/provider', korumali(async (ctx) => {
    if (!roller(ctx.kullanici).includes('PROVIDER')) throw hata.yetki('Hizmet veren rolünüz yok');
    const kat = ctx.body.categories;
    const ilc = ctx.body.districts;
    if (!Array.isArray(kat) || !Array.isArray(ilc) || kat.length > 200 || ilc.length > 200) throw hata.dogrulama('Geçersiz liste');
    // Kategori ya da hizmet adı katalogda AKTİF olmalı (istemci ikisini de gönderebilir).
    for (const k of kat) {
      const ok = await db.prepare(
        `SELECT 1 FROM categories WHERE name = ? AND active = TRUE AND deleted_at IS NULL
         UNION SELECT 1 FROM services s JOIN categories c ON c.id = s.category_id
          WHERE s.name = ? AND s.active = TRUE AND s.deleted_at IS NULL AND c.active = TRUE AND c.deleted_at IS NULL`,
      ).get(String(k), String(k));
      if (!ok) throw hata.dogrulama(`Geçersiz hizmet: ${k}`);
    }
    for (const d of ilc) {
      const ok = await db.prepare('SELECT 1 FROM districts WHERE name = ? AND active = TRUE AND deleted_at IS NULL').get(String(d));
      if (!ok) throw hata.dogrulama(`Geçersiz ilçe: ${d}`);
    }
    await db.prepare(
      `INSERT INTO provider_profiles (user_id, categories_json, districts_json, updated_at) VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET categories_json = excluded.categories_json,
         districts_json = excluded.districts_json, updated_at = excluded.updated_at`,
    ).run(ctx.kullanici.id, JSON.stringify(kat), JSON.stringify(ilc), simdi());
    return { categories: kat, districts: ilc };
  }));

  // HİZMET VEREN ONAYI YOK (ürün kararı): rolü olan herkes onaylıdır.
  // Askıya alınmış/banlı kullanıcı buraya zaten ulaşamaz (durum kapısı).
  r.get('/api/v1/profiles/me/provider/approval', korumali(async (ctx) => {
    if (!roller(ctx.kullanici).includes('PROVIDER')) throw hata.yetki('Hizmet veren rolünüz yok');
    return { status: 'APPROVED', message: '' };
  }));
}
