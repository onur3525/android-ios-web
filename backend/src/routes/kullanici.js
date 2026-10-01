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
import { sifreDogrula, sifreOzetle } from '../auth.js';
import { gonder } from '../bildirim.js';
import { config, uretim } from '../config.js';
import { simdi } from '../db.js';
import { ApiHatasi, HizSiniri, hata } from '../http.js';
import { jwtDogrula, jwtImzala } from '../jwt.js';
import { olaylar } from '../olaylar.js';

const OTP_SURESI = 3 * 60 * 1000;
const OTP_DENEME = 5;
const GIRIS_KILIT_ESIGI = 5;
const GIRIS_KILIT_SURESI = 15 * 60 * 1000;
const otpIpSiniri = new HizSiniri('otp_ip', 20, 60 * 60 * 1000);
const girisIpSiniri = new HizSiniri('giris_ip', 30, 15 * 60 * 1000);

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
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e) || e.length > 254) throw hata.dogrulama('Geçerli bir e-posta giriniz');
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

export function kullaniciGorunumu(u, saglayici) {
  return {
    id: u.id, name: u.name, email: u.email ?? '', phone: u.phone,
    phoneVerified: u.phone_verified === 1, emailVerified: u.email_verified === 1,
    roles: roller(u), activeRole: u.active_role, createdAt: u.created_at,
    ...(saglayici ? { providerProfile: saglayici } : {}),
  };
}

// ── OTP ─────────────────────────────────────────────────────
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
  await gonder(db, { kanal: 'SMS', hedef: `+90${tel}`, sablon: 'OTP', degerler: { KOD: kod }, gizliGovde: true });
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
  await db.prepare('UPDATE otp_codes SET consumed_at = ? WHERE id = ?').run(simdi(), k.id);
}

// ── Oturum ──────────────────────────────────────────────────
async function oturumVer(db, kullaniciId, req) {
  const jti = randomUUID();
  const yenileme = randomBytes(32).toString('base64url');
  const z = simdi();
  await db.prepare(
    `INSERT INTO user_sessions (id, user_id, refresh_hash, created_at, last_used, expires_at, ip, user_agent)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(jti, kullaniciId, ozet(yenileme), z, z, new Date(Date.now() + config.yenilemeSuresi).toISOString(),
    req.socket?.remoteAddress ?? null, String(req.headers['user-agent'] ?? '').slice(0, 200));
  return { accessToken: erisimTokeni(kullaniciId, jti), refreshToken: yenileme };
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
  return { u, oturum: o };
}

async function saglayiciProfili(db, kullaniciId) {
  const p = await db.prepare('SELECT * FROM provider_profiles WHERE user_id = ?').get(kullaniciId);
  return p ? { categories: JSON.parse(p.categories_json), districts: JSON.parse(p.districts_json) } : null;
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
    await otpTuket(db, tel, ['REGISTER'], ctx.body.otpCode);
    if (await db.prepare('SELECT 1 FROM users WHERE phone = ? AND deleted_at IS NULL').get(tel)) throw hata.cakisma('Bu telefon numarası kayıtlı');
    if (await db.prepare('SELECT 1 FROM users WHERE lower(email) = ? AND deleted_at IS NULL').get(mail)) throw hata.cakisma('Bu e-posta adresi kayıtlı');
    const id = randomUUID();
    const z = simdi();
    await db.prepare(
      `INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role,
                          status, terms_accepted, failed_logins, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, TRUE, FALSE, ?, ?, 'ACTIVE', TRUE, 0, ?, ?)`,
    ).run(id, tel, mail, isim, sifreOzetle(sifre), rol, rol, z, z);
    return oturumVer(db, id, ctx.req);
  });

  // ── GİRİŞ ──
  r.post('/api/v1/auth/login', async (ctx) => {
    await girisIpSiniri.denetle(db, ctx.ip);
    const tel = telefon(ctx.body.phone);
    const u = await db.prepare('SELECT * FROM users WHERE phone = ? AND deleted_at IS NULL').get(tel);
    const genel = () => new ApiHatasi(401, 'WRONG_PASSWORD', 'Telefon numarası ya da şifre hatalı');
    if (!u) {
      sifreOzetle('zamanlama-esitleme');
      throw genel();
    }
    if (u.locked_until && Date.parse(u.locked_until) > Date.now()) throw hata.hiz('Çok fazla hatalı deneme. Lütfen 15 dakika sonra tekrar deneyin.');
    if (!sifreDogrula(String(ctx.body.password ?? ''), u.password_hash)) {
      const n = u.failed_logins + 1;
      await db.prepare('UPDATE users SET failed_logins = ?, locked_until = ? WHERE id = ?').run(
        n >= GIRIS_KILIT_ESIGI ? 0 : n,
        n >= GIRIS_KILIT_ESIGI ? new Date(Date.now() + GIRIS_KILIT_SURESI).toISOString() : null, u.id);
      throw genel();
    }
    durumKapisi(u);
    await db.prepare('UPDATE users SET failed_logins = 0, locked_until = NULL WHERE id = ?').run(u.id);
    return oturumVer(db, u.id, ctx.req);
  });

  // ── YENİLEME (rotasyon + yeniden kullanım tespiti) ──
  r.post('/api/v1/auth/refresh', async (ctx) => {
    const rt = String(ctx.body.refreshToken ?? '');
    const o = rt ? await db.prepare('SELECT * FROM user_sessions WHERE refresh_hash = ?').get(ozet(rt)) : null;
    if (!o) throw hata.kimlik();
    if (o.revoked_at) {
      // İptal edilmiş yenileme token'ı tekrar kullanıldı → çalınmış olabilir:
      // kullanıcının BÜTÜN oturumları kapatılır.
      if (o.revoke_reason === 'ROTATED') await oturumlariIptal(db, o.user_id, 'REUSE_DETECTED');
      throw hata.kimlik();
    }
    if (Date.parse(o.expires_at) < Date.now()) throw hata.kimlik('Oturum süresi doldu');
    const u = await db.prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').get(o.user_id);
    if (!u) throw hata.kimlik();
    durumKapisi(u);
    const yeniJti = randomUUID();
    const yeni = randomBytes(32).toString('base64url');
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`UPDATE user_sessions SET revoked_at = ?, revoke_reason = 'ROTATED' WHERE id = ?`).run(z, o.id);
      await db.prepare(
        `INSERT INTO user_sessions (id, user_id, refresh_hash, created_at, last_used, expires_at, ip, user_agent)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      ).run(yeniJti, u.id, ozet(yeni), o.created_at, z, o.expires_at, ctx.ip, o.user_agent);
    });
    return { accessToken: erisimTokeni(u.id, yeniJti), refreshToken: yeni };
  });

  r.post('/api/v1/auth/logout', korumali(async (ctx) => {
    await db.prepare(`UPDATE user_sessions SET revoked_at = ?, revoke_reason = 'LOGOUT' WHERE id = ?`).run(simdi(), ctx.kOturum.id);
    return undefined;
  }));

  r.post('/api/v1/auth/password/change', korumali(async (ctx) => {
    const yeni = sifreKurali(ctx.body.newPassword);
    if (!sifreDogrula(String(ctx.body.currentPassword ?? ''), ctx.kullanici.password_hash)) throw new ApiHatasi(400, 'WRONG_PASSWORD', 'Mevcut şifre hatalı');
    await db.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?').run(sifreOzetle(yeni), simdi(), ctx.kullanici.id);
    await oturumlariIptal(db, ctx.kullanici.id, 'PASSWORD_CHANGED', ctx.kOturum.id);
    return undefined;
  }));

  r.post('/api/v1/auth/forgot/complete', async (ctx) => {
    const tel = telefon(ctx.body.phone);
    const yeni = sifreKurali(ctx.body.newPassword);
    await otpTuket(db, tel, ['FORGOT'], ctx.body.otpCode);
    const u = await db.prepare('SELECT * FROM users WHERE phone = ? AND deleted_at IS NULL').get(tel);
    if (!u) throw new ApiHatasi(400, 'OTP_INVALID', 'Doğrulama kodu hatalı');
    await db.prepare('UPDATE users SET password_hash = ?, failed_logins = 0, locked_until = NULL, updated_at = ? WHERE id = ?').run(sifreOzetle(yeni), simdi(), u.id);
    await oturumlariIptal(db, u.id, 'PASSWORD_RESET');
    return undefined;
  });

  r.post('/api/v1/auth/verify-password', korumali(async (ctx) => {
    if (!sifreDogrula(String(ctx.body.password ?? ''), ctx.kullanici.password_hash)) throw new ApiHatasi(400, 'WRONG_PASSWORD', 'Şifre hatalı');
    return undefined;
  }));

  r.post('/api/v1/auth/roles/add', korumali(async (ctx) => {
    const rol = rolDogrula(ctx.body.role);
    if (!sifreDogrula(String(ctx.body.password ?? ''), ctx.kullanici.password_hash)) throw new ApiHatasi(400, 'WRONG_PASSWORD', 'Şifre hatalı');
    await otpTuket(db, ctx.kullanici.phone, ['ROLE_ADD', 'LOGIN'], ctx.body.otpCode);
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
    return undefined;
  }));

  // ── PROFİL ──
  r.get('/api/v1/users/me', korumali(async (ctx) => kullaniciGorunumu(ctx.kullanici, await saglayiciProfili(db, ctx.kullanici.id))));

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
    if (ctx.body.email !== undefined) {
      const mail = eposta(ctx.body.email);
      if (mail !== (ctx.kullanici.email ?? '').toLowerCase()) {
        if (await db.prepare('SELECT 1 FROM users WHERE lower(email) = ? AND id <> ? AND deleted_at IS NULL').get(mail, ctx.kullanici.id)) throw hata.cakisma('Bu e-posta adresi kayıtlı');
        d.email = mail;
        d.email_verified = 0;
      }
    }
    if (Object.keys(d).length) {
      const a = Object.keys(d);
      await db.prepare(`UPDATE users SET ${a.map((k) => `${k} = ?`).join(', ')}, updated_at = ? WHERE id = ?`).run(...a.map((k) => d[k]), simdi(), ctx.kullanici.id);
    }
    const u = await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.kullanici.id);
    return kullaniciGorunumu(u, await saglayiciProfili(db, u.id));
  }));

  r.post('/api/v1/profiles/me/phone/change', korumali(async (ctx) => {
    const yeni = telefon(ctx.body.newPhone);
    await otpTuket(db, yeni, ['PHONE_CHANGE'], ctx.body.otpCode);
    if (await db.prepare('SELECT 1 FROM users WHERE phone = ? AND deleted_at IS NULL').get(yeni)) throw hata.cakisma('Bu telefon numarası kayıtlı');
    await db.prepare('UPDATE users SET phone = ?, phone_verified = TRUE, updated_at = ? WHERE id = ?').run(yeni, simdi(), ctx.kullanici.id);
    const u = await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.kullanici.id);
    return kullaniciGorunumu(u, await saglayiciProfili(db, u.id));
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
