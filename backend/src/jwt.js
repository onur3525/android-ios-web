// ═══════════════════════════════════════════════════════════════
// ERİŞİM TOKEN'I — JWT (HS256), kısa ömürlü (15 dk)
//
// Token yalnız kimlik taşır (sub = kullanıcı, jti = oturum). Yetki ve
// HESAP DURUMU (askı/ban) her istekte VERİTABANINDAN okunur; token
// geçerli olsa bile askıya alınmış/banlı kullanıcı içeri giremez.
// ═══════════════════════════════════════════════════════════════
import { createHmac, timingSafeEqual } from 'node:crypto';
import { config } from './config.js';

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');

export function jwtImzala(yuk) {
  const bas = b64({ alg: 'HS256', typ: 'JWT' });
  const govde = b64(yuk);
  const imza = createHmac('sha256', config.jwtSirri).update(`${bas}.${govde}`).digest('base64url');
  return `${bas}.${govde}.${imza}`;
}

/** Geçerliyse yük, değilse null. Algoritma sabit: 'none'/RS saldırısı yok. */
export function jwtDogrula(token) {
  const p = String(token || '').split('.');
  if (p.length !== 3) return null;
  let bas;
  try {
    bas = JSON.parse(Buffer.from(p[0], 'base64url').toString());
  } catch {
    return null;
  }
  if (bas.alg !== 'HS256') return null;
  const beklenen = Buffer.from(createHmac('sha256', config.jwtSirri).update(`${p[0]}.${p[1]}`).digest('base64url'));
  const gelen = Buffer.from(p[2]);
  if (beklenen.length !== gelen.length || !timingSafeEqual(beklenen, gelen)) return null;
  try {
    const yuk = JSON.parse(Buffer.from(p[1], 'base64url').toString());
    if (typeof yuk.exp !== 'number' || yuk.exp * 1000 < Date.now()) return null;
    return yuk;
  } catch {
    return null;
  }
}
