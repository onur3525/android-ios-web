// ═══════════════════════════════════════════════════════════════
// ADMİN API'Sİ (/admin/v1) — 1. ARTIM
//   kimlik (şifre + TOTP), yöneticiler, katalog, bölge, yasal
//   sürümler, destek, uygulama ayarları, denetim kaydı
//
// Her yazma işlemi: yetki denetimi → doğrulama → tek işlem (transaction)
// → denetim kaydı (önceki/yeni değer, gerekçe).
// ═══════════════════════════════════════════════════════════════
import { createHash, randomUUID } from 'node:crypto';
import {
  OTURUM_CEREZI, ROLLER, base32Uret, oturumAc, oturumKapat, oturumYukselt,
  sifreDogrula, sifreKurali, sifreOzetle, sirCoz, sirSifrele, totpDogrula,
  yenidenDogrulamaIste, yenidenDogrulandi, yetkiIste,
} from '../auth.js';
import { denetimYaz } from '../audit.js';
import { config } from '../config.js';
import { simdi } from '../db.js';
import { ApiHatasi, HizSiniri, cerez, hata } from '../http.js';

const girisSiniri = new HizSiniri('admin_giris', 10, 15 * 60 * 1000);
const KILIT_ESIGI = 5;
const KILIT_SURESI = 15 * 60 * 1000;

// ── Doğrulama yardımcıları ───────────────────────────────────
function ad(v, alan = 'Ad', min = 2, max = 120) {
  if (typeof v !== 'string') throw hata.dogrulama(`${alan} zorunludur`);
  const t = v.trim().replace(/\s+/g, ' ');
  if (t.length < min || t.length > max) throw hata.dogrulama(`${alan} ${min}-${max} karakter olmalıdır`);
  return t;
}
function gerekce(v) {
  if (typeof v !== 'string' || v.trim().length < 5) throw hata.dogrulama('İşlem nedeni en az 5 karakter olmalıdır');
  if (v.length > 1000) throw hata.dogrulama('İşlem nedeni en fazla 1000 karakter olabilir');
  return v.trim();
}
function bool(v, alan) {
  if (typeof v !== 'boolean') throw hata.dogrulama(`${alan} true/false olmalıdır`);
  return v;
}
function tamsayi(v, alan) {
  if (!Number.isInteger(v) || v < 0 || v > 1_000_000) throw hata.dogrulama(`${alan} geçerli bir sayı olmalıdır`);
  return v;
}
function surum(v, alan) {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v !== 'string' || !/^\d+\.\d+\.\d+$/.test(v)) throw hata.dogrulama(`${alan} 1.2.3 biçiminde olmalıdır`);
  return v;
}
function tarihVeyaBos(v, alan) {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v !== 'string' || Number.isNaN(Date.parse(v))) throw hata.dogrulama(`${alan} ISO-8601 tarih olmalıdır`);
  return new Date(v).toISOString();
}
const etkinlik = (x) => ({ ...x, active: x.active === 1 });

function adminGorunumu(a) {
  return { id: a.id, email: a.email, name: a.name, role: a.role, active: a.active === 1, mfa: !!a.totp_secret_enc, createdAt: a.created_at };
}

export function adminRotalar(r, db) {
  const yaz = (ctx, d) => denetimYaz(db, { adminId: ctx.admin?.id, ip: ctx.ip, ...d });

  // ── KİMLİK ────────────────────────────────────────────────
  r.post('/admin/v1/auth/login', async (ctx) => {
    await girisSiniri.denetle(db, `ip:${ctx.ip}`);
    const email = String(ctx.body.email || '').trim().toLowerCase();
    const sifre = String(ctx.body.password || '');
    const a = await db.prepare('SELECT * FROM admins WHERE email = ?').get(email);
    // Hesap var/yok bilgisi sızmasın: hata metni her durumda AYNI.
    const genelHata = () => new ApiHatasi(401, 'AUTH_FAILED', 'E-posta ya da şifre hatalı');
    if (!a || a.active !== 1) {
      sifreOzetle('zamanlama-esitleme'); // var/yok zamanlama farkını azalt
      throw genelHata();
    }
    if (a.locked_until && Date.parse(a.locked_until) > Date.now()) throw hata.hiz('Hesap geçici olarak kilitli');
    if (!sifreDogrula(sifre, a.password_hash)) {
      const n = a.failed_count + 1;
      await db.prepare('UPDATE admins SET failed_count = ?, locked_until = ? WHERE id = ?').run(
        n >= KILIT_ESIGI ? 0 : n,
        n >= KILIT_ESIGI ? new Date(Date.now() + KILIT_SURESI).toISOString() : null,
        a.id,
      );
      await denetimYaz(db, { adminId: a.id, islem: 'auth.login_failed', ip: ctx.ip });
      throw genelHata();
    }
    if (!a.totp_secret_enc) throw hata.durum('Bu hesapta MFA kurulmamış; yöneticinize başvurun');
    await db.prepare('UPDATE admins SET failed_count = 0, locked_until = NULL WHERE id = ?').run(a.id);
    const token = await oturumAc(db, a.id, 'mfa', ctx.req);
    ctx.cerezEkle(cerez(OTURUM_CEREZI, token, { secure: config.cerezSecure, maxAgeSn: 300 }));
    return { mfaRequired: true };
  });

  r.post('/admin/v1/auth/mfa', async (ctx) => {
    await girisSiniri.denetle(db, `mfa:${ctx.ip}`);
    const c = await ctx.oturumAsamasi('mfa');
    if (!c) throw hata.kimlik();
    if (!totpDogrula(sirCoz(c.admin.totp_secret_enc), ctx.body.code)) {
      await denetimYaz(db, { adminId: c.admin.id, islem: 'auth.mfa_failed', ip: ctx.ip });
      throw new ApiHatasi(401, 'AUTH_FAILED', 'Doğrulama kodu hatalı');
    }
    await oturumYukselt(db, ctx.token);
    ctx.cerezEkle(cerez(OTURUM_CEREZI, ctx.token, {
      secure: config.cerezSecure, maxAgeSn: Math.floor(config.adminOturumMutlak / 1000),
    }));
    await denetimYaz(db, { adminId: c.admin.id, islem: 'auth.login', ip: ctx.ip });
    return adminGorunumu(c.admin);
  });

  r.post('/admin/v1/auth/reauth', async (ctx) => {
    await girisSiniri.denetle(db, `reauth:${ctx.ip}`);
    if (!totpDogrula(sirCoz(ctx.admin.totp_secret_enc), ctx.body.code)) {
      throw new ApiHatasi(401, 'AUTH_FAILED', 'Doğrulama kodu hatalı');
    }
    await yenidenDogrulandi(db, ctx.token);
    return { ok: true };
  });

  r.post('/admin/v1/auth/logout', async (ctx) => {
    await oturumKapat(db, ctx.token);
    ctx.cerezEkle(cerez(OTURUM_CEREZI, '', { secure: config.cerezSecure, maxAgeSn: 0 }));
    await yaz(ctx, { islem: 'auth.logout' });
    return { ok: true };
  });

  r.get('/admin/v1/auth/me', (ctx) => adminGorunumu(ctx.admin));

  // ── YÖNETİCİLER ──────────────────────────────────────────
  r.get('/admin/v1/admins', async (ctx) => {
    yetkiIste(ctx.admin, 'admins.manage');
    return (await db.prepare('SELECT * FROM admins ORDER BY created_at').all()).map(adminGorunumu);
  });

  r.post('/admin/v1/admins', async (ctx) => {
    yetkiIste(ctx.admin, 'admins.manage');
    yenidenDogrulamaIste(ctx.oturum);
    const email = String(ctx.body.email || '').trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw hata.dogrulama('Geçerli bir e-posta giriniz');
    const isim = ad(ctx.body.name, 'Ad');
    if (!ROLLER.includes(ctx.body.role)) throw hata.dogrulama('Geçersiz rol');
    const kural = sifreKurali(ctx.body.password);
    if (kural) throw hata.dogrulama(kural);
    if (await db.prepare('SELECT 1 FROM admins WHERE email = ?').get(email)) throw hata.cakisma('Bu e-posta kayıtlı');
    const sir = base32Uret();
    const id = randomUUID();
    await db.prepare(
      `INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ).run(id, email, isim, ctx.body.role, sifreOzetle(ctx.body.password), sirSifrele(sir), simdi());
    await yaz(ctx, { islem: 'admin.create', hedefTur: 'admin', hedefId: id, sonra: { email, name: isim, role: ctx.body.role } });
    // TOTP sırrı YALNIZ bu yanıtta bir kez gösterilir.
    return { id, totpSecret: sir, otpauth: `otpauth://totp/HizmetCep%20Admin:${encodeURIComponent(email)}?secret=${sir}&issuer=HizmetCep%20Admin` };
  });

  r.patch('/admin/v1/admins/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'admins.manage');
    yenidenDogrulamaIste(ctx.oturum);
    const a = await db.prepare('SELECT * FROM admins WHERE id = ?').get(ctx.params.id);
    if (!a) throw hata.bulunamadi();
    if (a.id === ctx.admin.id) throw hata.durum('Kendi hesabınızın rolünü/durumunu değiştiremezsiniz');
    const yeni = { role: a.role, active: a.active };
    if (ctx.body.role !== undefined) {
      if (!ROLLER.includes(ctx.body.role)) throw hata.dogrulama('Geçersiz rol');
      yeni.role = ctx.body.role;
    }
    if (ctx.body.active !== undefined) yeni.active = bool(ctx.body.active, 'active') ? 1 : 0;
    await db.tx(async () => {
      await db.prepare('UPDATE admins SET role = ?, active = ? WHERE id = ?').run(yeni.role, yeni.active, a.id);
      if (yeni.active === 0) await db.prepare('DELETE FROM admin_sessions WHERE admin_id = ?').run(a.id);
      await yaz(ctx, { islem: 'admin.update', hedefTur: 'admin', hedefId: a.id, once: { role: a.role, active: a.active === 1 }, sonra: { role: yeni.role, active: yeni.active === 1 } });
    });
    return adminGorunumu(await db.prepare('SELECT * FROM admins WHERE id = ?').get(a.id));
  });

  // ── KATALOG ──────────────────────────────────────────────
  const kategoriGetir = async (id) => {
    const k = await db.prepare('SELECT * FROM categories WHERE id = ? AND deleted_at IS NULL').get(id);
    if (!k) throw hata.bulunamadi('Kategori bulunamadı');
    return k;
  };
  const kategoriGorunumu = async (k) => ({
    id: k.id, name: k.name, active: k.active === 1, sort: k.sort, icon: k.icon, photo: k.photo,
    kartDisi: k.kart_disi === 1, updatedAt: k.updated_at,
    serviceCount: (await db.prepare('SELECT COUNT(*) n FROM services WHERE category_id = ? AND deleted_at IS NULL').get(k.id)).n,
  });
  const hizmetGorunumu = (h) => ({ id: h.id, categoryId: h.category_id, name: h.name, active: h.active === 1, sort: h.sort, lider: h.lider === 1, updatedAt: h.updated_at });

  r.get('/admin/v1/catalog/categories', async (ctx) => {
    yetkiIste(ctx.admin, 'catalog.read');
    return Promise.all((await db.prepare('SELECT * FROM categories WHERE deleted_at IS NULL ORDER BY sort, name').all()).map(kategoriGorunumu));
  });

  // Uygulama paketindeki ikonlar (Flutter yalnız bunları çizer; bilinmeyen
  // yol istemcide yok sayılır). Başlangıç verisi gömülü eşlemeden gelir.
  r.get('/admin/v1/catalog/icons', async (ctx) => {
    yetkiIste(ctx.admin, 'catalog.read');
    return (await db.prepare('SELECT DISTINCT icon FROM categories WHERE icon IS NOT NULL ORDER BY icon').all()).map((x) => x.icon);
  });

  r.post('/admin/v1/catalog/categories', async (ctx) => {
    yetkiIste(ctx.admin, 'catalog.write');
    const isim = ad(ctx.body.name, 'Kategori adı');
    if (await db.prepare('SELECT 1 FROM categories WHERE name = ? AND deleted_at IS NULL').get(isim)) throw hata.cakisma('Bu kategori zaten var');
    const sira = ctx.body.sort === undefined
      ? (await db.prepare('SELECT COALESCE(MAX(sort), -1) + 1 s FROM categories').get()).s
      : tamsayi(ctx.body.sort, 'Sıra');
    const id = randomUUID();
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(
        `INSERT INTO categories (id, name, active, sort, icon, photo, kart_disi, created_at, updated_at)
         VALUES (?, ?, TRUE, ?, ?, NULL, FALSE, ?, ?)`,
      ).run(id, isim, sira, ctx.body.icon ? ad(ctx.body.icon, 'İkon', 3, 200) : null, z, z);
      await yaz(ctx, { islem: 'catalog.category.create', hedefTur: 'category', hedefId: id, sonra: { name: isim, sort: sira } });
    });
    return kategoriGorunumu(await kategoriGetir(id));
  });

  r.patch('/admin/v1/catalog/categories/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'catalog.write');
    const k = await kategoriGetir(ctx.params.id);
    const d = {};
    if (ctx.body.name !== undefined) {
      d.name = ad(ctx.body.name, 'Kategori adı');
      if (d.name !== k.name && await db.prepare('SELECT 1 FROM categories WHERE name = ? AND deleted_at IS NULL').get(d.name)) throw hata.cakisma('Bu kategori zaten var');
    }
    if (ctx.body.active !== undefined) d.active = bool(ctx.body.active, 'active') ? 1 : 0;
    if (ctx.body.sort !== undefined) d.sort = tamsayi(ctx.body.sort, 'Sıra');
    if (ctx.body.icon !== undefined) d.icon = ctx.body.icon === null ? null : ad(ctx.body.icon, 'İkon', 3, 200);
    if (ctx.body.kartDisi !== undefined) d.kart_disi = bool(ctx.body.kartDisi, 'kartDisi') ? 1 : 0;
    if (!Object.keys(d).length) throw hata.dogrulama('Değişiklik yok');
    await db.tx(async () => {
      const alanlar = Object.keys(d);
      await db.prepare(`UPDATE categories SET ${alanlar.map((a) => `${a} = ?`).join(', ')}, updated_at = ? WHERE id = ?`)
        .run(...alanlar.map((a) => d[a]), simdi(), k.id);
      await yaz(ctx, { islem: 'catalog.category.update', hedefTur: 'category', hedefId: k.id, once: Object.fromEntries(alanlar.map((a) => [a, k[a]])), sonra: d, gerekce: ctx.body.reason });
    });
    return kategoriGorunumu(await kategoriGetir(k.id));
  });

  r.delete('/admin/v1/catalog/categories/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'catalog.write');
    const k = await kategoriGetir(ctx.params.id);
    const neden = gerekce(ctx.body.reason);
    const z = simdi();
    await db.tx(async () => {
      await db.prepare('UPDATE services SET deleted_at = ?, updated_at = ? WHERE category_id = ? AND deleted_at IS NULL').run(z, z, k.id);
      await db.prepare('UPDATE categories SET deleted_at = ?, updated_at = ? WHERE id = ?').run(z, z, k.id);
      await yaz(ctx, { islem: 'catalog.category.delete', hedefTur: 'category', hedefId: k.id, once: { name: k.name }, gerekce: neden });
    });
    return undefined;
  });

  r.get('/admin/v1/catalog/categories/:id/services', async (ctx) => {
    yetkiIste(ctx.admin, 'catalog.read');
    await kategoriGetir(ctx.params.id);
    return (await db.prepare('SELECT * FROM services WHERE category_id = ? AND deleted_at IS NULL ORDER BY sort, name').all(ctx.params.id)).map(hizmetGorunumu);
  });

  r.post('/admin/v1/catalog/categories/:id/services', async (ctx) => {
    yetkiIste(ctx.admin, 'catalog.write');
    const k = await kategoriGetir(ctx.params.id);
    const isim = ad(ctx.body.name, 'Hizmet adı');
    if (await db.prepare('SELECT 1 FROM services WHERE category_id = ? AND name = ? AND deleted_at IS NULL').get(k.id, isim)) throw hata.cakisma('Bu hizmet bu kategoride zaten var');
    const sira = ctx.body.sort === undefined
      ? (await db.prepare('SELECT COALESCE(MAX(sort), -1) + 1 s FROM services WHERE category_id = ?').get(k.id)).s
      : tamsayi(ctx.body.sort, 'Sıra');
    const id = randomUUID();
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`INSERT INTO services (id, category_id, name, active, sort, lider, created_at, updated_at) VALUES (?, ?, ?, TRUE, ?, FALSE, ?, ?)`)
        .run(id, k.id, isim, sira, z, z);
      await yaz(ctx, { islem: 'catalog.service.create', hedefTur: 'service', hedefId: id, sonra: { category: k.name, name: isim } });
    });
    return hizmetGorunumu(await db.prepare('SELECT * FROM services WHERE id = ?').get(id));
  });

  const hizmetGetir = async (id) => {
    const h = await db.prepare('SELECT * FROM services WHERE id = ? AND deleted_at IS NULL').get(id);
    if (!h) throw hata.bulunamadi('Hizmet bulunamadı');
    return h;
  };

  r.patch('/admin/v1/catalog/services/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'catalog.write');
    const h = await hizmetGetir(ctx.params.id);
    const d = {};
    if (ctx.body.name !== undefined) {
      d.name = ad(ctx.body.name, 'Hizmet adı');
      if (d.name !== h.name && await db.prepare('SELECT 1 FROM services WHERE category_id = ? AND name = ? AND deleted_at IS NULL').get(h.category_id, d.name)) throw hata.cakisma('Bu hizmet bu kategoride zaten var');
    }
    if (ctx.body.active !== undefined) d.active = bool(ctx.body.active, 'active') ? 1 : 0;
    if (ctx.body.sort !== undefined) d.sort = tamsayi(ctx.body.sort, 'Sıra');
    if (ctx.body.lider !== undefined) d.lider = bool(ctx.body.lider, 'lider') ? 1 : 0;
    if (ctx.body.categoryId !== undefined) {
      const hedef = await kategoriGetir(String(ctx.body.categoryId));
      if (await db.prepare('SELECT 1 FROM services WHERE category_id = ? AND name = ? AND deleted_at IS NULL AND id <> ?').get(hedef.id, d.name || h.name, h.id)) throw hata.cakisma('Hedef kategoride aynı adlı hizmet var');
      d.category_id = hedef.id;
    }
    if (!Object.keys(d).length) throw hata.dogrulama('Değişiklik yok');
    await db.tx(async () => {
      const alanlar = Object.keys(d);
      await db.prepare(`UPDATE services SET ${alanlar.map((a) => `${a} = ?`).join(', ')}, updated_at = ? WHERE id = ?`)
        .run(...alanlar.map((a) => d[a]), simdi(), h.id);
      await yaz(ctx, { islem: 'catalog.service.update', hedefTur: 'service', hedefId: h.id, once: Object.fromEntries(alanlar.map((a) => [a, h[a]])), sonra: d, gerekce: ctx.body.reason });
    });
    return hizmetGorunumu(await hizmetGetir(h.id));
  });

  r.delete('/admin/v1/catalog/services/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'catalog.write');
    const h = await hizmetGetir(ctx.params.id);
    const neden = gerekce(ctx.body.reason);
    await db.tx(async () => {
      const z = simdi();
      await db.prepare('UPDATE services SET deleted_at = ?, updated_at = ? WHERE id = ?').run(z, z, h.id);
      await yaz(ctx, { islem: 'catalog.service.delete', hedefTur: 'service', hedefId: h.id, once: { name: h.name }, gerekce: neden });
    });
    return undefined;
  });

  // ── BÖLGE ────────────────────────────────────────────────
  const BOLGE = {
    cities: { tablo: 'cities', ust: null, tur: 'city' },
    districts: { tablo: 'districts', ust: { alan: 'city_id', tablo: 'cities', param: 'cityId' }, tur: 'district' },
    neighborhoods: { tablo: 'neighborhoods', ust: { alan: 'district_id', tablo: 'districts', param: 'districtId' }, tur: 'neighborhood' },
  };
  const bolgeGorunumu = (x) => ({
    id: x.id, name: x.name, active: x.active === 1, updatedAt: x.updated_at,
    ...(x.city_id ? { cityId: x.city_id, allDistrictsSupported: x.all_supported === 1 } : {}),
    ...(x.district_id ? { districtId: x.district_id, postalCode: x.postal_code } : {}),
  });

  for (const [yol, b] of Object.entries(BOLGE)) {
    r.get(`/admin/v1/regions/${yol}`, async (ctx) => {
      yetkiIste(ctx.admin, 'regions.read');
      if (b.ust) {
        const ust = ctx.query.get(b.ust.param);
        if (!ust) throw hata.dogrulama(`${b.ust.param} zorunludur`);
        return (await db.prepare(`SELECT * FROM ${b.tablo} WHERE ${b.ust.alan} = ? AND deleted_at IS NULL ORDER BY name`).all(ust)).map(bolgeGorunumu);
      }
      return (await db.prepare(`SELECT * FROM ${b.tablo} WHERE deleted_at IS NULL ORDER BY name`).all()).map(bolgeGorunumu);
    });

    r.post(`/admin/v1/regions/${yol}`, async (ctx) => {
      yetkiIste(ctx.admin, 'regions.write');
      const isim = ad(ctx.body.name, 'Ad');
      let ustId = null;
      if (b.ust) {
        ustId = String(ctx.body[b.ust.param] || '');
        if (!await db.prepare(`SELECT 1 FROM ${b.ust.tablo} WHERE id = ? AND deleted_at IS NULL`).get(ustId)) throw hata.dogrulama('Üst bölge bulunamadı');
        if (await db.prepare(`SELECT 1 FROM ${b.tablo} WHERE ${b.ust.alan} = ? AND name = ? AND deleted_at IS NULL`).get(ustId, isim)) throw hata.cakisma('Bu ad zaten var');
      } else if (await db.prepare('SELECT 1 FROM cities WHERE name = ? AND deleted_at IS NULL').get(isim)) {
        throw hata.cakisma('Bu il zaten var');
      }
      const id = randomUUID();
      const z = simdi();
      await db.tx(async () => {
        if (b.tablo === 'cities') {
          await db.prepare('INSERT INTO cities (id, name, active, created_at, updated_at) VALUES (?, ?, TRUE, ?, ?)').run(id, isim, z, z);
        } else if (b.tablo === 'districts') {
          await db.prepare('INSERT INTO districts (id, city_id, name, active, all_supported, created_at, updated_at) VALUES (?, ?, ?, TRUE, FALSE, ?, ?)').run(id, ustId, isim, z, z);
        } else {
          const pk = ctx.body.postalCode ? String(ctx.body.postalCode).trim() : null;
          if (pk && !/^\d{5}$/.test(pk)) throw hata.dogrulama('Posta kodu 5 haneli olmalıdır');
          await db.prepare('INSERT INTO neighborhoods (id, district_id, name, active, postal_code, created_at, updated_at) VALUES (?, ?, ?, TRUE, ?, ?, ?)').run(id, ustId, isim, pk, z, z);
        }
        await yaz(ctx, { islem: `region.${b.tur}.create`, hedefTur: b.tur, hedefId: id, sonra: { name: isim, parent: ustId } });
      });
      return bolgeGorunumu(await db.prepare(`SELECT * FROM ${b.tablo} WHERE id = ?`).get(id));
    });

    r.patch(`/admin/v1/regions/${yol}/:id`, async (ctx) => {
      yetkiIste(ctx.admin, 'regions.write');
      const x = await db.prepare(`SELECT * FROM ${b.tablo} WHERE id = ? AND deleted_at IS NULL`).get(ctx.params.id);
      if (!x) throw hata.bulunamadi();
      const d = {};
      if (ctx.body.name !== undefined) d.name = ad(ctx.body.name, 'Ad');
      if (ctx.body.active !== undefined) d.active = bool(ctx.body.active, 'active') ? 1 : 0;
      if (b.tablo === 'districts' && ctx.body.allDistrictsSupported !== undefined) d.all_supported = bool(ctx.body.allDistrictsSupported, 'allDistrictsSupported') ? 1 : 0;
      if (b.tablo === 'neighborhoods' && ctx.body.postalCode !== undefined) {
        const pk = ctx.body.postalCode ? String(ctx.body.postalCode).trim() : null;
        if (pk && !/^\d{5}$/.test(pk)) throw hata.dogrulama('Posta kodu 5 haneli olmalıdır');
        d.postal_code = pk;
      }
      if (!Object.keys(d).length) throw hata.dogrulama('Değişiklik yok');
      await db.tx(async () => {
        const alanlar = Object.keys(d);
        await db.prepare(`UPDATE ${b.tablo} SET ${alanlar.map((a) => `${a} = ?`).join(', ')}, updated_at = ? WHERE id = ?`)
          .run(...alanlar.map((a) => d[a]), simdi(), x.id);
        await yaz(ctx, { islem: `region.${b.tur}.update`, hedefTur: b.tur, hedefId: x.id, once: Object.fromEntries(alanlar.map((a) => [a, x[a]])), sonra: d, gerekce: ctx.body.reason });
      });
      return bolgeGorunumu(await db.prepare(`SELECT * FROM ${b.tablo} WHERE id = ?`).get(x.id));
    });

    r.delete(`/admin/v1/regions/${yol}/:id`, async (ctx) => {
      yetkiIste(ctx.admin, 'regions.write');
      const x = await db.prepare(`SELECT * FROM ${b.tablo} WHERE id = ? AND deleted_at IS NULL`).get(ctx.params.id);
      if (!x) throw hata.bulunamadi();
      const neden = gerekce(ctx.body.reason);
      await db.tx(async () => {
        const z = simdi();
        if (b.tablo === 'cities') {
          await db.prepare(`UPDATE neighborhoods SET deleted_at = ?, updated_at = ? WHERE deleted_at IS NULL AND district_id IN (SELECT id FROM districts WHERE city_id = ?)`).run(z, z, x.id);
          await db.prepare('UPDATE districts SET deleted_at = ?, updated_at = ? WHERE city_id = ? AND deleted_at IS NULL').run(z, z, x.id);
        }
        if (b.tablo === 'districts') {
          await db.prepare('UPDATE neighborhoods SET deleted_at = ?, updated_at = ? WHERE district_id = ? AND deleted_at IS NULL').run(z, z, x.id);
        }
        await db.prepare(`UPDATE ${b.tablo} SET deleted_at = ?, updated_at = ? WHERE id = ?`).run(z, z, x.id);
        await yaz(ctx, { islem: `region.${b.tur}.delete`, hedefTur: b.tur, hedefId: x.id, once: { name: x.name }, gerekce: neden });
      });
      return undefined;
    });
  }

  // ── YASAL BELGELER ───────────────────────────────────────
  const belgeGetir = async (slug) => {
    const d = await db.prepare('SELECT * FROM legal_documents WHERE slug = ?').get(slug);
    if (!d) throw hata.bulunamadi('Belge bulunamadı');
    return d;
  };
  const surumGorunumu = (v, govdeli = false) => ({
    id: v.id, slug: v.slug, version: v.version, sha256: v.sha256, effectiveDate: v.effective_date,
    status: v.status, createdAt: v.created_at, publishedAt: v.published_at,
    ...(govdeli ? { body: v.body } : {}),
  });

  r.get('/admin/v1/legal', async (ctx) => {
    yetkiIste(ctx.admin, 'legal.read');
    return Promise.all((await db.prepare('SELECT * FROM legal_documents ORDER BY slug').all()).map(async (d) => {
      const yayin = await db.prepare(`SELECT version FROM legal_versions WHERE slug = ? AND status = 'PUBLISHED'`).get(d.slug);
      return { slug: d.slug, title: d.title, active: d.active === 1, requiresAcceptance: d.requires_acceptance === 1, publishedVersion: yayin?.version ?? null };
    }));
  });

  r.post('/admin/v1/legal', async (ctx) => {
    yetkiIste(ctx.admin, 'legal.write');
    const slug = String(ctx.body.slug || '').trim();
    if (!/^[a-z][a-z0-9-]{1,40}$/.test(slug) || slug === 'support') throw hata.dogrulama('Geçersiz belge kimliği (slug)');
    if (await db.prepare('SELECT 1 FROM legal_documents WHERE slug = ?').get(slug)) throw hata.cakisma('Bu belge zaten var');
    const baslik = ad(ctx.body.title, 'Başlık');
    const kabul = ctx.body.requiresAcceptance === undefined ? false : bool(ctx.body.requiresAcceptance, 'requiresAcceptance');
    await db.tx(async () => {
      await db.prepare('INSERT INTO legal_documents (slug, title, active, requires_acceptance, created_at) VALUES (?, ?, TRUE, ?, ?)').run(slug, baslik, kabul ? 1 : 0, simdi());
      await yaz(ctx, { islem: 'legal.document.create', hedefTur: 'legal_document', hedefId: slug, sonra: { title: baslik, requiresAcceptance: kabul } });
    });
    return { slug, title: baslik, active: true, requiresAcceptance: kabul, publishedVersion: null };
  });

  r.patch('/admin/v1/legal/:slug', async (ctx) => {
    yetkiIste(ctx.admin, 'legal.write');
    const d = await belgeGetir(ctx.params.slug);
    const yeni = {};
    if (ctx.body.title !== undefined) yeni.title = ad(ctx.body.title, 'Başlık');
    if (ctx.body.active !== undefined) yeni.active = bool(ctx.body.active, 'active') ? 1 : 0;
    if (ctx.body.requiresAcceptance !== undefined) yeni.requires_acceptance = bool(ctx.body.requiresAcceptance, 'requiresAcceptance') ? 1 : 0;
    if (!Object.keys(yeni).length) throw hata.dogrulama('Değişiklik yok');
    await db.tx(async () => {
      const alanlar = Object.keys(yeni);
      await db.prepare(`UPDATE legal_documents SET ${alanlar.map((a) => `${a} = ?`).join(', ')} WHERE slug = ?`).run(...alanlar.map((a) => yeni[a]), d.slug);
      await yaz(ctx, { islem: 'legal.document.update', hedefTur: 'legal_document', hedefId: d.slug, once: Object.fromEntries(alanlar.map((a) => [a, d[a]])), sonra: yeni, gerekce: ctx.body.reason });
    });
    return { ok: true };
  });

  r.get('/admin/v1/legal/:slug/versions', async (ctx) => {
    yetkiIste(ctx.admin, 'legal.read');
    await belgeGetir(ctx.params.slug);
    return (await db.prepare('SELECT * FROM legal_versions WHERE slug = ? ORDER BY version DESC').all(ctx.params.slug)).map((v) => surumGorunumu(v));
  });

  r.get('/admin/v1/legal/:slug/versions/:version', async (ctx) => {
    yetkiIste(ctx.admin, 'legal.read');
    const v = await db.prepare('SELECT * FROM legal_versions WHERE slug = ? AND version = ?').get(ctx.params.slug, Number(ctx.params.version));
    if (!v) throw hata.bulunamadi('Sürüm bulunamadı');
    return surumGorunumu(v, true);
  });

  r.post('/admin/v1/legal/:slug/versions', async (ctx) => {
    yetkiIste(ctx.admin, 'legal.write');
    const d = await belgeGetir(ctx.params.slug);
    const govde = typeof ctx.body.body === 'string' ? ctx.body.body.trim() : '';
    if (govde.length < 20) throw hata.dogrulama('Belge metni en az 20 karakter olmalıdır');
    if (govde.length > 500_000) throw hata.dogrulama('Belge metni çok uzun');
    const yururluk = tarihVeyaBos(ctx.body.effectiveDate, 'Yürürlük tarihi') || simdi();
    const v = (await db.prepare('SELECT COALESCE(MAX(version), 0) + 1 n FROM legal_versions WHERE slug = ?').get(d.slug)).n;
    const id = randomUUID();
    const ozet = createHash('sha256').update(govde, 'utf8').digest('hex');
    await db.tx(async () => {
      await db.prepare(
        `INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, 'DRAFT', ?, ?)`,
      ).run(id, d.slug, v, govde, ozet, yururluk.slice(0, 10), ctx.admin.id, simdi());
      await yaz(ctx, { islem: 'legal.version.create', hedefTur: 'legal_version', hedefId: id, sonra: { slug: d.slug, version: v, sha256: ozet } });
    });
    return surumGorunumu(await db.prepare('SELECT * FROM legal_versions WHERE id = ?').get(id), true);
  });

  r.post('/admin/v1/legal/:slug/versions/:version/publish', async (ctx) => {
    yetkiIste(ctx.admin, 'legal.write');
    yenidenDogrulamaIste(ctx.oturum);
    const d = await belgeGetir(ctx.params.slug);
    const v = await db.prepare('SELECT * FROM legal_versions WHERE slug = ? AND version = ?').get(d.slug, Number(ctx.params.version));
    if (!v) throw hata.bulunamadi('Sürüm bulunamadı');
    if (v.status !== 'DRAFT') throw hata.durum('Yalnız taslak sürüm yayınlanabilir');
    const onceki = await db.prepare(`SELECT * FROM legal_versions WHERE slug = ? AND status = 'PUBLISHED'`).get(d.slug);
    await db.tx(async () => {
      if (onceki) await db.prepare(`UPDATE legal_versions SET status = 'ARCHIVED' WHERE id = ?`).run(onceki.id);
      await db.prepare(`UPDATE legal_versions SET status = 'PUBLISHED', published_by = ?, published_at = ? WHERE id = ?`).run(ctx.admin.id, simdi(), v.id);
      await yaz(ctx, { islem: 'legal.version.publish', hedefTur: 'legal_version', hedefId: v.id, once: onceki ? { version: onceki.version } : null, sonra: { version: v.version, sha256: v.sha256 }, gerekce: ctx.body.reason });
    });
    return surumGorunumu(await db.prepare('SELECT * FROM legal_versions WHERE id = ?').get(v.id));
  });

  r.post('/admin/v1/legal/:slug/versions/:version/archive', async (ctx) => {
    yetkiIste(ctx.admin, 'legal.write');
    yenidenDogrulamaIste(ctx.oturum);
    const v = await db.prepare('SELECT * FROM legal_versions WHERE slug = ? AND version = ?').get(ctx.params.slug, Number(ctx.params.version));
    if (!v) throw hata.bulunamadi('Sürüm bulunamadı');
    if (v.status === 'ARCHIVED') throw hata.durum('Sürüm zaten arşivde');
    const neden = gerekce(ctx.body.reason);
    await db.tx(async () => {
      await db.prepare(`UPDATE legal_versions SET status = 'ARCHIVED' WHERE id = ?`).run(v.id);
      await yaz(ctx, { islem: 'legal.version.archive', hedefTur: 'legal_version', hedefId: v.id, once: { status: v.status }, sonra: { status: 'ARCHIVED' }, gerekce: neden });
    });
    return surumGorunumu(await db.prepare('SELECT * FROM legal_versions WHERE id = ?').get(v.id));
  });

  // ── DESTEK ───────────────────────────────────────────────
  r.get('/admin/v1/support', async (ctx) => {
    yetkiIste(ctx.admin, 'legal.read');
    return await db.prepare('SELECT description, email, updated_at updatedAt FROM support_info WHERE id = 1').get() || null;
  });

  r.put('/admin/v1/support', async (ctx) => {
    yetkiIste(ctx.admin, 'support.write');
    const aciklama = ad(ctx.body.description, 'Açıklama', 10, 1000);
    const email = String(ctx.body.email || '').trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw hata.dogrulama('Geçerli bir e-posta giriniz');
    const once = await db.prepare('SELECT description, email FROM support_info WHERE id = 1').get();
    await db.tx(async () => {
      await db.prepare(`INSERT INTO support_info (id, description, email, updated_at) VALUES (1, ?, ?, ?)
                  ON CONFLICT(id) DO UPDATE SET description = excluded.description, email = excluded.email, updated_at = excluded.updated_at`)
        .run(aciklama, email, simdi());
      await yaz(ctx, { islem: 'support.update', hedefTur: 'support', hedefId: '1', once, sonra: { description: aciklama, email } });
    });
    return { description: aciklama, email };
  });

  // ── UYGULAMA AYARLARI ────────────────────────────────────
  const ayarGorunumu = (c, p) => ({
    platform: p,
    maintenanceActive: c ? c.maintenance_active === 1 : false,
    maintenanceMessage: c?.maintenance_message ?? null,
    maintenanceEndAt: c?.maintenance_end_at ?? null,
    minSupportedVersion: c?.min_version ?? null,
    latestVersion: c?.latest_version ?? null,
    updatedAt: c?.updated_at ?? null,
  });

  r.get('/admin/v1/config/app', async (ctx) => {
    yetkiIste(ctx.admin, 'config.read');
    return Promise.all(['android', 'ios', 'web'].map(async (p) => ayarGorunumu(await db.prepare('SELECT * FROM app_config WHERE platform = ?').get(p), p)));
  });

  r.put('/admin/v1/config/app/:platform', async (ctx) => {
    yetkiIste(ctx.admin, 'config.write');
    const p = ctx.params.platform;
    if (!['android', 'ios', 'web'].includes(p)) throw hata.dogrulama('Geçersiz platform');
    const bakim = bool(ctx.body.maintenanceActive, 'maintenanceActive');
    // Bakım modunu açmak tüm kullanıcıları etkiler → yeniden doğrulama.
    if (bakim) yenidenDogrulamaIste(ctx.oturum);
    const mesaj = ctx.body.maintenanceMessage ? ad(ctx.body.maintenanceMessage, 'Bakım mesajı', 5, 500) : null;
    if (bakim && !mesaj) throw hata.dogrulama('Bakım modunda mesaj zorunludur');
    const bitis = tarihVeyaBos(ctx.body.maintenanceEndAt, 'Bakım bitiş zamanı');
    const minS = surum(ctx.body.minSupportedVersion, 'Minimum sürüm');
    const gunS = surum(ctx.body.latestVersion, 'Güncel sürüm');
    const once = await db.prepare('SELECT * FROM app_config WHERE platform = ?').get(p);
    await db.tx(async () => {
      await db.prepare(
        `INSERT INTO app_config (platform, maintenance_active, maintenance_message, maintenance_end_at, min_version, latest_version, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(platform) DO UPDATE SET maintenance_active = excluded.maintenance_active,
           maintenance_message = excluded.maintenance_message, maintenance_end_at = excluded.maintenance_end_at,
           min_version = excluded.min_version, latest_version = excluded.latest_version, updated_at = excluded.updated_at`,
      ).run(p, bakim ? 1 : 0, mesaj, bitis, minS, gunS, simdi());
      await yaz(ctx, { islem: 'config.app.update', hedefTur: 'app_config', hedefId: p, once: once ? ayarGorunumu(once, p) : null, sonra: { maintenanceActive: bakim, maintenanceMessage: mesaj, maintenanceEndAt: bitis, minSupportedVersion: minS, latestVersion: gunS }, gerekce: ctx.body.reason });
    });
    return ayarGorunumu(await db.prepare('SELECT * FROM app_config WHERE platform = ?').get(p), p);
  });

  // ── DENETİM KAYDI ────────────────────────────────────────
  r.get('/admin/v1/audit-log', async (ctx) => {
    yetkiIste(ctx.admin, 'audit.read');
    const limit = Math.min(Number(ctx.query.get('limit') || 100), 500);
    const once = Number(ctx.query.get('before') || Number.MAX_SAFE_INTEGER);
    return (await db.prepare(
      `SELECT l.*, a.email admin_email FROM audit_log l LEFT JOIN admins a ON a.id = l.admin_id
        WHERE l.id < ? ORDER BY l.id DESC LIMIT ?`,
    ).all(once, limit)).map((x) => ({
      id: x.id, admin: x.admin_email, action: x.action, targetType: x.target_type, targetId: x.target_id,
      before: x.before_json ? JSON.parse(x.before_json) : null, after: x.after_json ? JSON.parse(x.after_json) : null,
      reason: x.reason, ip: x.ip, createdAt: x.created_at,
    }));
  });
}
