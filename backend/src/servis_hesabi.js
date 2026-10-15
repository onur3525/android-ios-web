// ═══════════════════════════════════════════════════════════════
// FIREBASE SERVİS HESABI OKUYUCU — TEK KAYNAK (config.js + fcm.js)
//
// İki kaynaktan YALNIZ BİRİ kullanılır:
//   HC_FCM_SERVICE_ACCOUNT       — servis hesabı JSON'u (düz ya da base64)
//   HC_FCM_SERVICE_ACCOUNT_FILE  — JSON dosyasının yolu
//                                  (ör. Render Secret File: /etc/secrets/<ad>)
// İkisi birden verilirse açıkça reddedilir (hangisinin geçerli olduğu
// belirsiz kalmasın).
//
// ⚠ Hata mesajlarına ve günlüğe dosya İÇERİĞİ / anahtar YAZILMAZ; yalnız
// değişken adı, dosya yolu ve eksik alan adı yazılır.
// ═══════════════════════════════════════════════════════════════
import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';

const ALANLAR = ['project_id', 'client_email', 'private_key'];

/** Ham metni (düz JSON ya da base64 JSON) çözer ve alanları doğrular. */
export function servisHesabiCoz(ham, kaynak) {
  const metin = String(ham).replace(/^﻿/, '').trim();
  let j;
  try {
    j = JSON.parse(metin.startsWith('{') ? metin : Buffer.from(metin, 'base64').toString('utf8'));
  } catch {
    throw new Error(`${kaynak} geçerli bir servis hesabı JSON değeri (düz ya da base64) değil.`);
  }
  if (!j || typeof j !== 'object' || Array.isArray(j)) {
    throw new Error(`${kaynak} geçerli bir servis hesabı JSON değeri (düz ya da base64) değil.`);
  }
  if (j.type !== undefined && j.type !== 'service_account') {
    throw new Error(`${kaynak} bir servis hesabı anahtarı değil (type=service_account bekleniyor).`);
  }
  for (const k of ALANLAR) {
    if (!j[k]) throw new Error(`${kaynak} içinde ${k} eksik.`);
  }
  if (!String(j.private_key).includes('PRIVATE KEY')) throw new Error(`${kaynak} private_key PEM biçiminde değil.`);
  return j;
}

/**
 * Ortamdan servis hesabını okur.
 * @returns {{ hesap: object, kaynak: string } | null} tanımlı değilse null
 * @throws yapılandırma hatalıysa (içerik sızdırmadan)
 */
export function servisHesabiOku(env = process.env) {
  const deger = (env.HC_FCM_SERVICE_ACCOUNT || '').trim();
  const yol = (env.HC_FCM_SERVICE_ACCOUNT_FILE || '').trim();
  if (deger && yol) {
    throw new Error('HC_FCM_SERVICE_ACCOUNT ve HC_FCM_SERVICE_ACCOUNT_FILE birlikte tanımlanamaz; yalnız birini kullanın.');
  }
  if (yol) {
    let icerik;
    try { icerik = readFileSync(yol, 'utf8'); } catch (e) {
      throw new Error(`HC_FCM_SERVICE_ACCOUNT_FILE okunamadı (${yol}): ${e.code || 'okuma hatası'}.`);
    }
    if (!icerik.trim()) throw new Error(`HC_FCM_SERVICE_ACCOUNT_FILE boş (${yol}).`);
    return { hesap: servisHesabiCoz(icerik, 'HC_FCM_SERVICE_ACCOUNT_FILE'), kaynak: 'dosya' };
  }
  if (!deger) return null;
  // Sık yapılan hata: dosya YOLU içerik değişkenine yazılmış.
  if (/^(\/|\.\/|[A-Za-z]:\\)/.test(deger) || /\.json$/i.test(deger)) {
    throw new Error('HC_FCM_SERVICE_ACCOUNT bir dosya yolu gibi görünüyor; dosya için HC_FCM_SERVICE_ACCOUNT_FILE kullanın.');
  }
  return { hesap: servisHesabiCoz(deger, 'HC_FCM_SERVICE_ACCOUNT'), kaynak: 'ortam' };
}

// ── ORTAK: ORTAMDAKİ SERVİS HESABI + GOOGLE ERİŞİM ANAHTARI ──
// FCM ve Firebase kimlik yönetimi (şifre sıfırlama, hesap silme) AYNI servis
// hesabını kullanır; okuma ve anahtar alma tek yerde (önceden fcm.js içindeydi).

let hesapOnbellegi = null; // { anahtar, hesap }
/** Ortamdaki servis hesabı (önbellekli); tanımsızsa null, hatalıysa fırlatır. */
export function ortamServisHesabi() {
  const anahtar = `${process.env.HC_FCM_SERVICE_ACCOUNT || ''}\u0000${process.env.HC_FCM_SERVICE_ACCOUNT_FILE || ''}`;
  if (hesapOnbellegi && hesapOnbellegi.anahtar === anahtar) return hesapOnbellegi.hesap;
  const s = servisHesabiOku(process.env);
  hesapOnbellegi = { anahtar, hesap: s ? s.hesap : null };
  return hesapOnbellegi.hesap;
}

const jetonOnbellegi = new Map(); // kapsam → { jeton, bitis }
/** Önbellekteki erişim anahtarını atar (401: anahtar geçersiz/iptal edilmiş). */
export function googleErisimJetonunuAt(kapsam) {
  for (const k of jetonOnbellegi.keys()) if (k.endsWith(`|${kapsam}`)) jetonOnbellegi.delete(k);
}

/** Servis hesabıyla OAuth2 erişim anahtarı (JWT bearer). Kapsam başına önbellekli. */
export async function googleErisimJetonu(sh, kapsam) {
  const k = `${sh.client_email}|${kapsam}`;
  const o = jetonOnbellegi.get(k);
  if (o && o.bitis > Date.now() + 60_000) return o.jeton;
  const an = Math.floor(Date.now() / 1000);
  const b64 = (x) => Buffer.from(JSON.stringify(x)).toString('base64url');
  const govde = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({ iss: sh.client_email, scope: kapsam, aud: 'https://oauth2.googleapis.com/token', iat: an, exp: an + 3600 })}`;
  const imza = createSign('RSA-SHA256').update(govde).sign(sh.private_key).toString('base64url');
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${govde}.${imza}` }),
    signal: AbortSignal.timeout(10000),
  });
  if (!r.ok) throw new Error(`Google erişim anahtarı alınamadı (HTTP ${r.status})`);
  const j = await r.json();
  jetonOnbellegi.set(k, { jeton: j.access_token, bitis: Date.now() + (j.expires_in ?? 3600) * 1000 });
  return j.access_token;
}
