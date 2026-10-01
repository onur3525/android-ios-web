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
