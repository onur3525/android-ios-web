// ═══════════════════════════════════════════════════════════════
// KULLANICI API'Sİ (/api/v1) — katalog, bölge, yasal, destek, ayar
//
// ⚠ BİÇİMLER FLUTTER İSTEMCİSİYLE BİREBİR (değiştirilmez):
//   GET /categories          → CategoryApi.parse: {items:[{category,active,services[]}]}
//   GET /regions/tree        → RegionTree.fromJson: {cities:[{id,name,active,districts:[...]}]}
//   GET /legal/:slug         → LegalDoc: {slug,title,version,effectiveDate,body}
//   GET /legal/support       → SupportInfo: {description,email}
//   GET /config/app?platform → {maintenance:{active,message,endAt},
//                               release:{minSupportedVersion,latestVersion}}
// ═══════════════════════════════════════════════════════════════
import { hata } from '../http.js';
import { DESTEK_BILGISI } from '../destek_bilgisi.js';

export async function katalogYaniti(db) {
  const kat = await db.prepare(
    `SELECT id, name, active, icon, photo_ref, roof_key FROM categories WHERE deleted_at IS NULL ORDER BY sort, name`,
  ).all();
  const hiz = await db.prepare(
    `SELECT category_id, name FROM services
      WHERE deleted_at IS NULL AND active = TRUE ORDER BY sort, name`,
  ).all();
  const gruplu = new Map();
  for (const h of hiz) {
    if (!gruplu.has(h.category_id)) gruplu.set(h.category_id, []);
    gruplu.get(h.category_id).push(h.name);
  }
  // Ana sayfa çatıları (029): ad, açıklama, yüklenen fotoğraf ve kategori
  // adları (katalog sırasıyla). Eski istemciler bu alanı yok sayar.
  const catilar = await db.prepare('SELECT key, name, description, photo_ref FROM catalog_roofs ORDER BY sort, name').all();
  const catiKategorileri = new Map(catilar.map((c) => [c.key, []]));
  for (const k of kat) if (k.roof_key && catiKategorileri.has(k.roof_key)) catiKategorileri.get(k.roof_key).push(k.name);
  return {
    roofs: catilar.map((c) => ({ key: c.key, name: c.name, description: c.description,
      ...(c.photo_ref ? { photoUrl: `/api/v1/categories/photo/${c.photo_ref}` } : {}), categories: catiKategorileri.get(c.key) })),
    items: kat
      .map((k) => ({ category: k.name, active: k.active === 1, ...(k.icon ? { icon: k.icon } : {}),
        // Admin'den yüklenen fotoğraf (göreli yol; yoksa uygulama paket fotoğrafına düşer)
        ...(k.photo_ref ? { photoUrl: `/api/v1/categories/photo/${k.photo_ref}` } : {}), services: gruplu.get(k.id) || [] }))
      // İstemci hizmetsiz kategoriyi zaten atlıyor; pasif HİZMETLER
      // listeye hiç girmez (istemcide hizmet düzeyinde aktif alanı yok).
      .filter((k) => k.services.length > 0),
  };
}

export async function bolgeAgaci(db) {
  const iller = await db.prepare('SELECT * FROM cities WHERE deleted_at IS NULL ORDER BY name').all();
  const ilceler = await db.prepare('SELECT * FROM districts WHERE deleted_at IS NULL ORDER BY name').all();
  const mahalleler = await db.prepare('SELECT * FROM neighborhoods WHERE deleted_at IS NULL ORDER BY name').all();
  const mByD = new Map();
  for (const m of mahalleler) {
    if (!mByD.has(m.district_id)) mByD.set(m.district_id, []);
    mByD.get(m.district_id).push({
      id: m.id, name: m.name, active: m.active === 1,
      ...(m.postal_code ? { postalCode: m.postal_code } : {}),
    });
  }
  const dByC = new Map();
  for (const d of ilceler) {
    if (!dByC.has(d.city_id)) dByC.set(d.city_id, []);
    dByC.get(d.city_id).push({
      id: d.id, name: d.name, active: d.active === 1,
      allDistrictsSupported: d.all_supported === 1,
      neighborhoods: mByD.get(d.id) || [],
    });
  }
  return {
    cities: iller.map((c) => ({ id: c.id, name: c.name, active: c.active === 1, districts: dByC.get(c.id) || [] })),
  };
}

async function yayindakiSurum(db, slug) {
  return await db.prepare(
    `SELECT d.slug, d.title, v.version, v.effective_date, v.body, v.sha256, v.id, v.summary, v.pdf_ref
       FROM legal_documents d JOIN legal_versions v ON v.slug = d.slug
      WHERE d.slug = ? AND d.active = TRUE AND v.status = 'PUBLISHED'`,
  ).get(slug);
}

/** Destek bilgisi koda gömülüdür (destek_bilgisi.js; 22 Eki). */
export async function destekBilgisi() {
  return { description: DESTEK_BILGISI.description, email: DESTEK_BILGISI.email };
}

export function publicRotalar(r, db) {
  r.get('/api/v1/categories', async () => katalogYaniti(db));
  r.get('/api/v1/regions/tree', async () => bolgeAgaci(db));

  r.get('/api/v1/legal', async () =>
    (await db.prepare(
      `SELECT d.slug, d.title, v.version, v.effective_date
         FROM legal_documents d JOIN legal_versions v ON v.slug = d.slug
        WHERE d.active = TRUE AND v.status = 'PUBLISHED' ORDER BY d.slug`,
    ).all()).map((x) => ({ slug: x.slug, title: x.title, version: String(x.version), effectiveDate: x.effective_date })),
  );

  r.get('/api/v1/legal/:slug', async (ctx) => {
    if (ctx.params.slug === 'support') {
      const d = await destekBilgisi();
      if (!d) throw hata.bulunamadi('Destek bilgisi bulunamadı');
      return d;
    }
    const v = await yayindakiSurum(db, ctx.params.slug);
    if (!v) throw hata.bulunamadi('Belge bulunamadı');
    return { slug: v.slug, title: v.title, version: String(v.version), effectiveDate: v.effective_date, body: v.body,
      // 031: PDF'li sürümde kısa özet + PDF adresi (sürüme özgü, değişmez).
      ...(v.pdf_ref ? { summary: v.summary, pdfUrl: `/api/v1/legal/${v.slug}/pdf/${v.version}` } : {}) };
  });

  r.get('/api/v1/config/app', async (ctx) => {
    const p = ctx.query.get('platform');
    if (!['android', 'ios', 'web'].includes(p)) throw hata.dogrulama('platform android, ios ya da web olmalıdır');
    const c = await db.prepare('SELECT * FROM app_config WHERE platform = ?').get(p);
    return {
      maintenance: {
        active: c ? c.maintenance_active === 1 : false,
        message: c?.maintenance_message ?? null,
        endAt: c?.maintenance_end_at ?? null,
      },
      release: {
        minSupportedVersion: c?.min_version ?? null,
        latestVersion: c?.latest_version ?? null,
      },
    };
  });
}
