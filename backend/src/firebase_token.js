// ═══════════════════════════════════════════════════════════════
// FIREBASE ID TOKEN DOĞRULAMA — Admin SDK / servis hesabı GEREKMEZ
//
// Firebase ID token'ı RS256 imzalı bir JWT'dir. Google'ın AÇIK
// sertifikalarıyla (securetoken@system.gserviceaccount.com) doğrulanır;
// hiçbir gizli anahtar gerekmez (Firebase'in resmî "üçüncü taraf JWT
// kitaplığıyla doğrulama" yöntemi). Denetlenenler:
//   alg=RS256 · kid bilinen sertifika · imza · aud=proje · iss=securetoken
//   · exp gelecekte · iat/auth_time geçmişte · sub boş değil
// Sertifikalar Cache-Control süresi kadar önbelleğe alınır.
// ═══════════════════════════════════════════════════════════════
import { createVerify } from 'node:crypto';
import { config } from './config.js';
import { googleErisimJetonu, ortamServisHesabi } from './servis_hesabi.js';

const SERTIFIKA_ADRESI = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
let onbellek = { sertifikalar: null, bitis: 0 };
let sertifikaGetirici = async () => {
  const r = await fetch(SERTIFIKA_ADRESI, { signal: AbortSignal.timeout(8000) });
  if (!r.ok) throw new Error(`Firebase sertifikaları alınamadı (${r.status})`);
  const yas = Number(/max-age=(\d+)/.exec(r.headers.get('cache-control') || '')?.[1] || 3600);
  return { sertifikalar: await r.json(), sureSn: yas };
};

/** Yalnız testler: sertifika kaynağını değiştirir. */
export function testSertifikaGetiricisi(f) {
  sertifikaGetirici = f;
  onbellek = { sertifikalar: null, bitis: 0 };
}

async function sertifikalar() {
  if (onbellek.sertifikalar && Date.now() < onbellek.bitis) return onbellek.sertifikalar;
  const { sertifikalar: s, sureSn } = await sertifikaGetirici();
  onbellek = { sertifikalar: s, bitis: Date.now() + Math.max(60, sureSn) * 1000 };
  return s;
}

const b64json = (s) => JSON.parse(Buffer.from(s, 'base64url').toString('utf8'));

/** Geçerliyse token yükü (uid=sub, phone_number, email, email_verified), değilse null. */
export async function firebaseTokenDogrula(token) {
  const p = String(token || '').split('.');
  if (p.length !== 3) return null;
  let bas, yuk;
  try {
    bas = b64json(p[0]);
    yuk = b64json(p[1]);
  } catch {
    return null;
  }
  if (bas.alg !== 'RS256' || typeof bas.kid !== 'string') return null;
  let sert = (await sertifikalar())[bas.kid];
  if (!sert) {
    onbellek.bitis = 0; // anahtar dönüşü olmuş olabilir: bir kez tazele
    sert = (await sertifikalar())[bas.kid];
    if (!sert) return null;
  }
  const dogrulayici = createVerify('RSA-SHA256');
  dogrulayici.update(`${p[0]}.${p[1]}`);
  if (!dogrulayici.verify(sert, Buffer.from(p[2], 'base64url'))) return null;
  const proje = config.firebaseProjeId;
  const an = Math.floor(Date.now() / 1000);
  const tolerans = 60;
  if (yuk.aud !== proje || yuk.iss !== `https://securetoken.google.com/${proje}`) return null;
  if (typeof yuk.exp !== 'number' || yuk.exp <= an - tolerans) return null;
  if (typeof yuk.iat !== 'number' || yuk.iat > an + tolerans) return null;
  if (typeof yuk.auth_time !== 'number' || yuk.auth_time > an + tolerans) return null;
  if (typeof yuk.sub !== 'string' || !yuk.sub || yuk.sub.length > 128) return null;
  return yuk;
}

/**
 * E-posta/şifreyi Firebase'e SUNUCUDAN doğrulatır (Identity Toolkit REST;
 * AÇIK web API anahtarı yeterli). Şifre Firebase'de olduğu için (e-postayla
 * sıfırlama sonrası da) telefon+şifre girişi tek kaynaktan doğrulanır.
 * Yapılandırılmamışsa null döner (çağıran yerel özete düşer).
 */
export async function firebaseSifreDogrula(email, sifre) {
  if (!config.firebaseWebApiKey) return null;
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(config.firebaseWebApiKey)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: sifre, returnSecureToken: false }),
    signal: AbortSignal.timeout(8000),
  });
  if (r.ok) return true;
  return false;
}

/**
 * Firebase e-posta/şifre hesabının şifresini SUNUCUDAN değiştirir
 * (Identity Toolkit REST; AÇIK web API anahtarı yeterli, gizli anahtar yok):
 * mevcut şifreyle oturum açılıp alınan ID token ile `accounts:update`.
 *   null  → Firebase şifre doğrulaması yapılandırılmamış (yalnız yerel özet)
 *   false → mevcut şifre Firebase'de doğrulanmadı
 *   true  → Firebase şifresi değişti
 * Ağ/sağlayıcı hatasında fırlatır (çağıran yerel şifreyi DEĞİŞTİRMEZ; iki
 * kaynak ayrışmaz).
 */
export async function firebaseSifreDegistir(email, mevcut, yeni) {
  if (!config.firebaseWebApiKey) return null;
  const anahtar = encodeURIComponent(config.firebaseWebApiKey);
  const g = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${anahtar}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: mevcut, returnSecureToken: true }),
    signal: AbortSignal.timeout(8000),
  });
  if (!g.ok) return false;
  const { idToken } = await g.json();
  if (!idToken) throw new Error('Firebase oturum anahtarı alınamadı');
  const d = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:update?key=${anahtar}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken, password: yeni, returnSecureToken: false }),
    signal: AbortSignal.timeout(8000),
  });
  if (!d.ok) throw new Error(`Firebase şifresi güncellenemedi (HTTP ${d.status})`);
  return true;
}

// ── FIREBASE KİMLİK YÖNETİMİ (servis hesabıyla, 15 Eki güvenlik denetimi) ──
//
// İki iş için gerekir ve ikisi de kullanıcının mevcut Firebase şifresini
// BİLMEDEN yapılmak zorundadır:
//   · Telefonla şifre sıfırlama: Firebase'e bağlı hesapta giriş şifreyi
//     Firebase'den doğrular. Sıfırlama yalnız yerel özeti değiştirirse YENİ
//     şifre reddedilir, ESKİ şifre çalışmaya devam eder (ele geçirilmiş
//     hesabı kurtarmak için yapılan sıfırlama işe yaramaz).
//   · Hesap silme: Firebase'deki kimlik (telefon, e-posta) üçüncü taraf
//     kopyasıdır; yerelde anonimleştirilen hesabın Firebase kaydı da silinir.
const KIMLIK_KAPSAMI = 'https://www.googleapis.com/auth/identitytoolkit';
let yonetimTestGondericisi = null;
/** Yalnız testler: Identity Toolkit yönetim çağrısını değiştirir. */
export function firebaseYonetimTestGondericisi(f) { yonetimTestGondericisi = f; }

async function yonetimIstegi(islem, govde) {
  if (yonetimTestGondericisi) return yonetimTestGondericisi(islem, govde);
  const sh = ortamServisHesabi();
  if (!sh) throw new Error('Firebase servis hesabı yapılandırılmamış');
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${encodeURIComponent(config.firebaseProjeId)}/accounts:${islem}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${await googleErisimJetonu(sh, KIMLIK_KAPSAMI)}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(govde),
    signal: AbortSignal.timeout(10000),
  });
  const j = await r.json().catch(() => ({}));
  return { ok: r.ok, durum: r.status, kod: String(j?.error?.message ?? '') };
}

/** Firebase kullanıcısının şifresini (mevcut şifre olmadan) ayarlar; başarısızsa fırlatır. */
export async function firebaseSifreAyarla(uid, yeni) {
  const r = await yonetimIstegi('update', { localId: uid, password: yeni });
  if (!r.ok) throw new Error(`Firebase şifresi ayarlanamadı (HTTP ${r.durum})`);
}

/** Firebase kullanıcısını siler. Zaten yoksa başarı sayılır; başka hatada fırlatır. */
export async function firebaseKullaniciSil(uid) {
  const r = await yonetimIstegi('delete', { localId: uid });
  if (r.ok || r.kod.startsWith('USER_NOT_FOUND')) return;
  throw new Error(`Firebase kullanıcısı silinemedi (HTTP ${r.durum}${r.kod ? ` ${r.kod.slice(0, 60)}` : ''})`);
}
