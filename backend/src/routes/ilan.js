// ═══════════════════════════════════════════════════════════════
// İLAN · TEKLİF · İLETİŞİM · DEĞERLENDİRME · BİLDİRİM (+ admin moderasyonu)
//
// İş kuralları Flutter mock katmanıyla (mock_ports.dart) aynıdır ve
// burada SUNUCUDA zorlanır (istemci değiştirilse de atlanamaz):
//   · İlan yalnız hizmet alan rolüyle; ömür 30 saat; numara 10458231'den artar.
//   · Teklif yalnız hizmet veren rolüyle; kendi ilanına teklif yok;
//     ilan başına hizmet veren tek teklif; yalnız açık ve süresi dolmamış ilana.
//   · Seçimi yalnız ilan sahibi yapar; seçilince diğer teklifler kapanır.
//   · İletişim ÜCRETSİZ; yalnız teklifin iki tarafı açar/görür.
//   · Değerlendirme yalnız ilan sahibi, seçilmiş teklif için, teklif başına bir.
// HizmetCep ücretsizdir: ödeme/bakiye/komisyon YOK; teklif tutarı yalnız
// hizmet verenin müşteriye sunduğu bedeldir.
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { yenidenDogrulamaIste, yetkiIste } from '../auth.js';
import { denetimYaz } from '../audit.js';
import { kullaniciyaBildir } from '../bildirim.js';
import { simdi } from '../db.js';
import { ApiHatasi, hata } from '../http.js';
import { kullaniciCoz } from './kullanici.js';
import { dosyalariBagla } from './depolama_entegrasyon.js';

export const ILAN_OMRU_MS = 30 * 60 * 60 * 1000;
const kural = (kod, mesaj) => new ApiHatasi(409, kod, mesaj);

// ── Görünümler (Flutter mappers.dart ile birebir alan adları) ──
export const ilanGorunumu = (l) => ({
  id: l.id, ilanNo: l.ilan_no, ownerId: l.owner_id, title: l.title, location: l.location,
  description: l.description, status: l.status, photoPaths: JSON.parse(l.photo_refs_json),
  workTiming: l.work_timing, createdAt: l.created_at, expiresAt: l.expires_at,
  selectedOfferId: l.selected_offer_id,
});
export const teklifGorunumu = (o) => ({
  id: o.id, listingId: o.listing_id, providerId: o.provider_id, amountTl: o.amount_tl,
  note: o.note, status: o.status, createdAt: o.created_at,
});
const yorumGorunumu = (y) => ({
  id: y.id, listingId: y.listing_id ?? '', offerId: y.offer_id ?? '', talepId: y.talep_id,
  providerId: y.provider_id, authorId: y.author_id, stars: y.stars, text: y.text,
  status: y.status, createdAt: y.created_at, publishedAt: y.published_at,
});

/** Uygulama içi bildirim (Bildirimler sekmesi). */
export async function uygulamaIciBildir(db, kullaniciId, tur, baslik, govde, refId) {
  await db.prepare(
    `INSERT INTO notifications (id, user_id, type, title, body, ref_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(randomUUID(), kullaniciId, tur, baslik, govde, refId ?? null, simdi());
}

/** Süresi dolan açık ilanları kapatır; sahibine bir kez bildirir (idempotent). */
export async function suresiDolanlariIsle(db) {
  const z = simdi();
  const dolan = await db.prepare(
    `SELECT * FROM listings WHERE status = 'ACTIVE' AND selected_offer_id IS NULL AND expires_at < ?`,
  ).all(z);
  for (const l of dolan) {
    await db.tx(async () => {
      const n = await db.prepare(`UPDATE listings SET status = 'EXPIRED', updated_at = ? WHERE id = ? AND status = 'ACTIVE'`).run(z, l.id);
      if (!n.changes) return;
      await db.prepare(`UPDATE offers SET status = 'EXPIRED', updated_at = ? WHERE listing_id = ? AND status = 'ACTIVE'`).run(z, l.id);
      if (l.expiry_notified !== 1) {
        await uygulamaIciBildir(db, l.owner_id, 'LISTING_EXPIRED', 'İlanınızın süresi doldu', `"${l.title}" ilanınızın yayın süresi sona erdi.`, l.id);
        await db.prepare('UPDATE listings SET expiry_notified = TRUE WHERE id = ?').run(l.id);
      }
    });
  }
  return dolan.length;
}

function kelimeSayisi(s) {
  return String(s).trim().split(/\s+/).filter(Boolean).length;
}

export function ilanRotalar(r, db) {
  const korumali = (f) => async (ctx) => {
    const { u, oturum } = await kullaniciCoz(db, ctx.req);
    ctx.kullanici = u;
    ctx.kOturum = oturum;
    return f(ctx);
  };
  const rolIste = (u, rol, mesaj) => {
    if (u.active_role !== rol || !u.roles.split(',').includes(rol)) throw hata.yetki(mesaj);
  };
  const ilanGetir = async (id) => {
    await suresiDolanlariIsle(db);
    const l = await db.prepare('SELECT * FROM listings WHERE id = ?').get(id);
    if (!l) throw hata.bulunamadi('İlan bulunamadı');
    return l;
  };

  // ── İLAN ──
  r.post('/api/v1/listings', korumali(async (ctx) => {
    rolIste(ctx.kullanici, 'CUSTOMER', 'İlanı yalnız hizmet alan rolüyle verebilirsiniz');
    const baslik = String(ctx.body.title ?? '').trim();
    const konum = String(ctx.body.location ?? '').trim();
    const aciklama = String(ctx.body.description ?? '').trim();
    const foto = ctx.body.photoRefs ?? [];
    const zaman = ctx.body.workTiming ?? null;
    // Başlık = katalogda AKTİF bir hizmet ya da kategori adı.
    const katalogda = await db.prepare(
      `SELECT 1 FROM services s JOIN categories c ON c.id = s.category_id
        WHERE s.name = ? AND s.active = TRUE AND s.deleted_at IS NULL AND c.active = TRUE AND c.deleted_at IS NULL
       UNION SELECT 1 FROM categories WHERE name = ? AND active = TRUE AND deleted_at IS NULL`,
    ).get(baslik, baslik);
    if (!katalogda) throw hata.dogrulama('Geçerli bir hizmet seçiniz');
    if (konum.length < 2 || konum.length > 200) throw hata.dogrulama('Konum zorunludur');
    if (kelimeSayisi(aciklama) < 3) throw hata.dogrulama('Açıklamanız en az 3 kelime olmalıdır');
    if (aciklama.length > 2000) throw hata.dogrulama('Açıklama en fazla 2000 karakter olabilir');
    if (!Array.isArray(foto) || foto.length > 10 || foto.some((f) => typeof f !== 'string' || !/^[A-Za-z0-9/_.-]{1,200}$/.test(f))) throw hata.dogrulama('Geçersiz fotoğraf listesi');
    if (zaman !== null && !['NOW', 'THIS_WEEK', 'FLEXIBLE'].includes(zaman)) throw hata.dogrulama('Geçersiz iş zamanı');
    const id = randomUUID();
    const z = new Date();
    const kayit = await db.tx(async () => {
      await dosyalariBagla(db, foto, ctx.kullanici.id);
      const no = await db.prepare(`UPDATE counters SET value = value + 1 WHERE name = 'ilan_no' RETURNING value`).get();
      await db.prepare(
        `INSERT INTO listings (id, ilan_no, owner_id, title, location, description, photo_refs_json, work_timing,
                               status, expiry_notified, created_at, expires_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVE', FALSE, ?, ?, ?)`,
      ).run(id, String(no.value), ctx.kullanici.id, baslik, konum, aciklama, JSON.stringify(foto), zaman,
        z.toISOString(), new Date(z.getTime() + ILAN_OMRU_MS).toISOString(), z.toISOString());
      return db.prepare('SELECT * FROM listings WHERE id = ?').get(id);
    });
    return ilanGorunumu(kayit);
  }));

  r.get('/api/v1/listings/my', korumali(async (ctx) => {
    await suresiDolanlariIsle(db);
    return (await db.prepare(`SELECT * FROM listings WHERE owner_id = ? ORDER BY created_at DESC`).all(ctx.kullanici.id)).map(ilanGorunumu);
  }));

  r.get('/api/v1/listings/available', korumali(async (ctx) => {
    rolIste(ctx.kullanici, 'PROVIDER', 'Bu liste hizmet veren rolüne aittir');
    await suresiDolanlariIsle(db);
    const kosul = [`status = 'ACTIVE'`, 'selected_offer_id IS NULL', 'expires_at > ?', 'owner_id <> ?'];
    const p = [simdi(), ctx.kullanici.id];
    const kat = ctx.query.get('category');
    const ilce = ctx.query.get('district');
    if (kat) { kosul.push('title = ?'); p.push(kat); }
    if (ilce) { kosul.push('location LIKE ?'); p.push(`%${ilce}%`); }
    // Sıralama/öncelik (kendi kategorisi önce, aile sonra) istemcide
    // `eslestirme.dart` ile yapılır; sunucu uygun ilanların tamamını verir.
    return (await db.prepare(`SELECT * FROM listings WHERE ${kosul.join(' AND ')} ORDER BY created_at DESC LIMIT 500`).all(...p)).map(ilanGorunumu);
  }));

  r.get('/api/v1/listings/:id', korumali(async (ctx) => {
    const l = await ilanGetir(ctx.params.id);
    const u = ctx.kullanici;
    if (l.owner_id === u.id) return ilanGorunumu(l);
    // Hizmet veren: açık ilanı görür; teklif verdiği ilanı her durumda görür.
    if (u.roles.split(',').includes('PROVIDER')) {
      const teklifi = await db.prepare('SELECT 1 FROM offers WHERE listing_id = ? AND provider_id = ?').get(l.id, u.id);
      if (teklifi || (l.status === 'ACTIVE' && !l.selected_offer_id)) return ilanGorunumu(l);
    }
    throw hata.bulunamadi('İlan bulunamadı');
  }));

  r.patch('/api/v1/listings/:id', korumali(async (ctx) => {
    const l = await ilanGetir(ctx.params.id);
    if (l.owner_id !== ctx.kullanici.id) throw hata.bulunamadi('İlan bulunamadı');
    if (l.status !== 'ACTIVE' || l.selected_offer_id) throw kural('INVALID_STATE', 'Bu ilan artık düzenlenemez');
    const d = {};
    if (ctx.body.description !== undefined) {
      const a = String(ctx.body.description).trim();
      if (kelimeSayisi(a) < 3 || a.length > 2000) throw hata.dogrulama('Açıklamanız en az 3 kelime olmalıdır');
      d.description = a;
    }
    if (ctx.body.title !== undefined) throw hata.dogrulama('Hizmet ilan verildikten sonra değiştirilemez');
    if (Object.keys(d).length) {
      await db.prepare('UPDATE listings SET description = ?, updated_at = ? WHERE id = ?').run(d.description, simdi(), l.id);
    }
    return ilanGorunumu(await db.prepare('SELECT * FROM listings WHERE id = ?').get(l.id));
  }));

  r.delete('/api/v1/listings/:id', korumali(async (ctx) => {
    const l = await ilanGetir(ctx.params.id);
    if (l.owner_id !== ctx.kullanici.id) throw hata.bulunamadi('İlan bulunamadı');
    if (l.status !== 'ACTIVE') throw kural('INVALID_STATE', 'Bu ilan zaten kapalı');
    const neden = ctx.body.reason ? String(ctx.body.reason).trim().slice(0, 500) : null;
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`UPDATE listings SET status = 'USER_DELETED', delete_reason = ?, updated_at = ? WHERE id = ?`).run(neden, z, l.id);
      await db.prepare(`UPDATE offers SET status = 'CLOSED', updated_at = ? WHERE listing_id = ? AND status = 'ACTIVE'`).run(z, l.id);
    });
    return undefined;
  }));

  // ── TEKLİF ──
  r.post('/api/v1/offers', korumali(async (ctx) => {
    rolIste(ctx.kullanici, 'PROVIDER', 'Teklifi yalnız hizmet veren rolüyle verebilirsiniz');
    const anahtar = String(ctx.req.headers['idempotency-key'] ?? '').slice(0, 100) || null;
    if (anahtar) {
      const once = await db.prepare('SELECT * FROM offers WHERE provider_id = ? AND idempotency_key = ?').get(ctx.kullanici.id, anahtar);
      if (once) return teklifGorunumu(once);
    }
    const l = await ilanGetir(String(ctx.body.listingId ?? ''));
    const tutar = ctx.body.amountTl;
    const not = String(ctx.body.note ?? '').trim();
    if (!Number.isInteger(tutar) || tutar < 1 || tutar > 10_000_000) throw hata.dogrulama('Geçerli bir tutar giriniz');
    if (not.length > 1000) throw hata.dogrulama('Not en fazla 1000 karakter olabilir');
    if (l.owner_id === ctx.kullanici.id) throw kural('OWN_LISTING_OFFER', 'Kendi ilanınıza teklif veremezsiniz');
    if (l.status === 'EXPIRED' || Date.parse(l.expires_at) < Date.now()) throw kural('LISTING_EXPIRED', 'İlanın süresi doldu');
    if (l.status !== 'ACTIVE' || l.selected_offer_id) throw kural('LISTING_CLOSED', 'Bu ilan teklife kapalı');
    if (await db.prepare('SELECT 1 FROM offers WHERE listing_id = ? AND provider_id = ?').get(l.id, ctx.kullanici.id)) {
      throw kural('DUPLICATE_OFFER', 'Bu ilana zaten teklif verdiniz');
    }
    const id = randomUUID();
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(
        `INSERT INTO offers (id, listing_id, provider_id, amount_tl, note, status, idempotency_key, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, 'ACTIVE', ?, ?, ?)`,
      ).run(id, l.id, ctx.kullanici.id, tutar, not, anahtar, z, z);
      await uygulamaIciBildir(db, l.owner_id, 'NEW_OFFER', 'Yeni teklif', `"${l.title}" ilanınıza yeni bir teklif geldi.`, l.id);
    });
    return teklifGorunumu(await db.prepare('SELECT * FROM offers WHERE id = ?').get(id));
  }));

  r.get('/api/v1/offers/my', korumali(async (ctx) =>
    (await db.prepare('SELECT * FROM offers WHERE provider_id = ? ORDER BY created_at DESC').all(ctx.kullanici.id)).map(teklifGorunumu),
  ));

  r.put('/api/v1/listings/:id/selected-offer', korumali(async (ctx) => {
    const l = await ilanGetir(ctx.params.id);
    const o = await db.prepare('SELECT * FROM offers WHERE id = ? AND listing_id = ?').get(String(ctx.body.offerId ?? ''), l.id);
    if (!o) throw hata.bulunamadi('Teklif bulunamadı');
    if (l.owner_id !== ctx.kullanici.id) throw hata.yetki('Teklifi yalnızca ilan sahibi seçebilir');
    if (l.selected_offer_id === o.id) return ilanGorunumu(l); // idempotent tekrar
    if (l.status !== 'ACTIVE') throw kural('INVALID_STATE', 'Bu ilan için seçim yapılamaz');
    if (l.selected_offer_id) throw kural('INVALID_STATE', 'Bu ilan için teklif zaten seçilmiş');
    if (o.status !== 'ACTIVE') throw kural('INVALID_STATE', 'Bu teklif artık geçerli değil');
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`UPDATE offers SET status = 'SELECTED', updated_at = ? WHERE id = ?`).run(z, o.id);
      await db.prepare(`UPDATE offers SET status = 'CLOSED', updated_at = ? WHERE listing_id = ? AND id <> ? AND status = 'ACTIVE'`).run(z, l.id, o.id);
      await db.prepare('UPDATE listings SET selected_offer_id = ?, updated_at = ? WHERE id = ?').run(o.id, z, l.id);
      await uygulamaIciBildir(db, o.provider_id, 'OFFER_SELECTED', 'Teklifiniz seçildi', `"${l.title}" ilanında teklifiniz seçildi.`, l.id);
    });
    return ilanGorunumu(await db.prepare('SELECT * FROM listings WHERE id = ?').get(l.id));
  }));

  // ── İLETİŞİM (ücretsiz; yalnız teklifin iki tarafı) ──
  const tarafKontrol = async (offerId, u) => {
    const o = await db.prepare('SELECT * FROM offers WHERE id = ?').get(offerId);
    if (!o) throw hata.bulunamadi('Teklif bulunamadı');
    const l = await db.prepare('SELECT * FROM listings WHERE id = ?').get(o.listing_id);
    if (u.id !== o.provider_id && u.id !== l.owner_id) throw hata.bulunamadi('Teklif bulunamadı');
    return { o, l };
  };

  r.get('/api/v1/contact/:offerId', korumali(async (ctx) => {
    const { o, l } = await tarafKontrol(ctx.params.offerId, ctx.kullanici);
    const c = await db.prepare('SELECT * FROM contacts WHERE offer_id = ?').get(o.id);
    if (!c) return { contactOpenAt: null };
    const karsiId = ctx.kullanici.id === o.provider_id ? l.owner_id : o.provider_id;
    const k = await db.prepare('SELECT name, phone FROM users WHERE id = ?').get(karsiId);
    return { open: true, contactOpenAt: c.opened_at, counterpart: { name: k.name, phone: k.phone } };
  }));

  r.post('/api/v1/offers/:offerId/communication', korumali(async (ctx) => {
    const { o, l } = await tarafKontrol(ctx.params.offerId, ctx.kullanici);
    if (l.status === 'ADMIN_REMOVED' || l.status === 'USER_DELETED') throw kural('LISTING_REMOVED', 'İlan yayından kaldırılmış');
    const var_ = await db.prepare('SELECT * FROM contacts WHERE offer_id = ?').get(o.id);
    if (var_) return { open: true, contactOpenAt: var_.opened_at };
    const z = simdi();
    await db.tx(async () => {
      await db.prepare('INSERT INTO contacts (offer_id, opened_by, opened_at) VALUES (?, ?, ?)').run(o.id, ctx.kullanici.id, z);
      const karsi = ctx.kullanici.id === o.provider_id ? l.owner_id : o.provider_id;
      await uygulamaIciBildir(db, karsi, 'CONTACT_OPENED', 'İletişim açıldı', `"${l.title}" ilanı için iletişim bilgileri paylaşıldı.`, o.id);
    });
    return { open: true, contactOpenAt: z };
  }));

  // ── DEĞERLENDİRME ──
  r.post('/api/v1/listings/:id/review', korumali(async (ctx) => {
    const l = await ilanGetir(ctx.params.id);
    if (l.owner_id !== ctx.kullanici.id) throw hata.yetki('Değerlendirmeyi yalnızca ilan sahibi yapabilir');
    if (!l.selected_offer_id) throw kural('INVALID_STATE', 'Değerlendirme için seçilmiş bir teklif gerekir');
    const yildiz = ctx.body.stars;
    const metin = String(ctx.body.text ?? '').trim();
    if (!Number.isInteger(yildiz) || yildiz < 1 || yildiz > 5) throw hata.dogrulama('Lütfen 1-5 arası bir puan seçin');
    if (metin.length > 1000) throw hata.dogrulama('Yorum en fazla 1000 karakter olabilir');
    const o = await db.prepare('SELECT * FROM offers WHERE id = ?').get(l.selected_offer_id);
    if (await db.prepare('SELECT 1 FROM reviews WHERE offer_id = ?').get(o.id)) throw kural('INVALID_STATE', 'Bu iş için değerlendirme zaten yapıldı');
    const id = randomUUID();
    const z = simdi();
    await db.prepare(
      `INSERT INTO reviews (id, listing_id, offer_id, provider_id, author_id, stars, text, status, created_at, published_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'PUBLISHED', ?, ?)`,
    ).run(id, l.id, o.id, o.provider_id, ctx.kullanici.id, yildiz, metin, z, z);
    return yorumGorunumu(await db.prepare('SELECT * FROM reviews WHERE id = ?').get(id));
  }));

  r.get('/api/v1/providers/:id/reviews', korumali(async (ctx) => {
    const liste = await db.prepare(
      `SELECT * FROM reviews WHERE provider_id = ? AND status = 'PUBLISHED' ORDER BY created_at DESC LIMIT ?`,
    ).all(ctx.params.id, Math.min(Number(ctx.query.get('limit') ?? 100), 200));
    const ort = await db.prepare(`SELECT AVG(stars) a, COUNT(*) n FROM reviews WHERE provider_id = ? AND status = 'PUBLISHED'`).get(ctx.params.id);
    return { average: ort.n ? Number(Number(ort.a).toFixed(2)) : null, count: ort.n, reviews: liste.map(yorumGorunumu) };
  }));

  // ── BİLDİRİMLER ──
  r.get('/api/v1/notifications', korumali(async (ctx) =>
    (await db.prepare('SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 200').all(ctx.kullanici.id))
      .map((n) => ({ id: n.id, userId: n.user_id, type: n.type, title: n.title, body: n.body, refId: n.ref_id, createdAt: n.created_at, readAt: n.read_at })),
  ));
  r.get('/api/v1/notifications/unread-count', korumali(async (ctx) => ({
    count: (await db.prepare('SELECT COUNT(*) n FROM notifications WHERE user_id = ? AND read_at IS NULL').get(ctx.kullanici.id)).n,
  })));
  r.post('/api/v1/notifications/:id/read', korumali(async (ctx) => {
    const n = await db.prepare('UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ? AND read_at IS NULL').run(simdi(), ctx.params.id, ctx.kullanici.id);
    return { ok: true, changed: n.changes };
  }));
  r.post('/api/v1/notifications/read-all', korumali(async (ctx) => {
    const n = await db.prepare('UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL').run(simdi(), ctx.kullanici.id);
    return { ok: true, changed: n.changes };
  }));

  // ── UYGULAMA GERİ BİLDİRİMİ ──
  r.get('/api/v1/profiles/me/app-feedback', korumali(async (ctx) => {
    const f = await db.prepare('SELECT * FROM app_feedback WHERE user_id = ?').get(ctx.kullanici.id);
    return f ? { stars: f.stars, comment: f.comment, platform: f.platform, appVersion: f.app_version, updatedAt: f.updated_at } : undefined;
  }));
  r.post('/api/v1/profiles/me/app-feedback', korumali(async (ctx) => {
    const y = ctx.body.stars;
    if (!Number.isInteger(y) || y < 1 || y > 5) throw hata.dogrulama('Lütfen 1-5 arası bir puan seçin');
    const yorum = ctx.body.comment ? String(ctx.body.comment).trim().slice(0, 1000) : null;
    const pl = String(ctx.body.platform ?? '');
    if (!['android', 'ios', 'web'].includes(pl)) throw hata.dogrulama('Geçersiz platform');
    const sur = String(ctx.body.appVersion ?? '').slice(0, 30);
    const z = simdi();
    await db.prepare(
      `INSERT INTO app_feedback (user_id, stars, comment, platform, app_version, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET stars = excluded.stars, comment = excluded.comment, platform = excluded.platform,
         app_version = excluded.app_version, updated_at = excluded.updated_at`,
    ).run(ctx.kullanici.id, y, yorum, pl, sur, z, z);
    return { stars: y, comment: yorum, platform: pl, appVersion: sur, updatedAt: z };
  }));

  // ═════════════════ ADMİN ═════════════════
  r.get('/admin/v1/stats', async (ctx) => {
    yetkiIste(ctx.admin, 'content.read');
    await suresiDolanlariIsle(db);
    const say = async (sql, ...p) => (await db.prepare(sql).get(...p)).n;
    return {
      users: await say('SELECT COUNT(*) n FROM users WHERE deleted_at IS NULL'),
      suspended: await say(`SELECT COUNT(*) n FROM users WHERE status = 'SUSPENDED' AND deleted_at IS NULL`),
      banned: await say(`SELECT COUNT(*) n FROM users WHERE status = 'BANNED' AND deleted_at IS NULL`),
      activeListings: await say(`SELECT COUNT(*) n FROM listings WHERE status = 'ACTIVE'`),
      offersToday: await say('SELECT COUNT(*) n FROM offers WHERE created_at > ?', new Date(Date.now() - 86_400_000).toISOString()),
      openTalepler: await say(`SELECT COUNT(*) n FROM teklif_talepleri WHERE durum IN ('BEKLEMEDE','TEKLIF_GELDI','SECILDI')`),
      pendingDeletions: await say(`SELECT COUNT(*) n FROM account_requests WHERE type = 'DELETION' AND status = 'PENDING'`),
      failedNotifications: await say(`SELECT COUNT(*) n FROM outbound_messages WHERE status = 'FAILED' AND template <> 'OTP' AND created_at > ?`, new Date(Date.now() - 7 * 86_400_000).toISOString()),
    };
  });

  r.get('/admin/v1/listings', async (ctx) => {
    yetkiIste(ctx.admin, 'content.read');
    await suresiDolanlariIsle(db);
    const kosul = ['1 = 1'];
    const p = [];
    const durum = ctx.query.get('status');
    if (durum) { kosul.push('status = ?'); p.push(durum); }
    const ara = String(ctx.query.get('q') ?? '').trim().toLowerCase();
    if (ara) { kosul.push('(lower(title) LIKE ? OR ilan_no = ? OR lower(description) LIKE ?)'); p.push(`%${ara}%`, ara, `%${ara}%`); }
    const sahip = ctx.query.get('ownerId');
    if (sahip) { kosul.push('owner_id = ?'); p.push(sahip); }
    const limit = Math.min(Number(ctx.query.get('limit') ?? 50), 200);
    const ofset = Math.max(Number(ctx.query.get('offset') ?? 0), 0);
    const toplam = (await db.prepare(`SELECT COUNT(*) n FROM listings WHERE ${kosul.join(' AND ')}`).get(...p)).n;
    const liste = await db.prepare(`SELECT * FROM listings WHERE ${kosul.join(' AND ')} ORDER BY created_at DESC LIMIT ? OFFSET ?`).all(...p, limit, ofset);
    return { total: toplam, items: liste.map((l) => ({ ...ilanGorunumu(l), removedReason: l.removed_reason, deleteReason: l.delete_reason })) };
  });

  r.get('/admin/v1/listings/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'content.read');
    const l = await db.prepare('SELECT * FROM listings WHERE id = ?').get(ctx.params.id);
    if (!l) throw hata.bulunamadi('İlan bulunamadı');
    const sahip = await db.prepare('SELECT id, name, status FROM users WHERE id = ?').get(l.owner_id);
    const teklifler = await db.prepare(
      `SELECT o.*, u.name provider_name FROM offers o JOIN users u ON u.id = o.provider_id WHERE o.listing_id = ? ORDER BY o.created_at`,
    ).all(l.id);
    const yorum = await db.prepare('SELECT * FROM reviews WHERE listing_id = ?').get(l.id);
    return {
      ...ilanGorunumu(l), removedReason: l.removed_reason, removedAt: l.removed_at, deleteReason: l.delete_reason,
      owner: sahip, offers: teklifler.map((o) => ({ ...teklifGorunumu(o), providerName: o.provider_name })),
      review: yorum ? yorumGorunumu(yorum) : null,
    };
  });

  r.post('/admin/v1/listings/:id/remove', async (ctx) => {
    yetkiIste(ctx.admin, 'listings.remove');
    yenidenDogrulamaIste(ctx.oturum);
    const neden = String(ctx.body.reason ?? '').trim();
    if (neden.length < 5 || neden.length > 1000) throw hata.dogrulama('İşlem nedeni 5-1000 karakter olmalıdır');
    const l = await db.prepare('SELECT * FROM listings WHERE id = ?').get(ctx.params.id);
    if (!l) throw hata.bulunamadi('İlan bulunamadı');
    if (l.status === 'ADMIN_REMOVED') throw hata.durum('İlan zaten kaldırılmış');
    const z = simdi();
    const ref = randomUUID();
    await db.tx(async () => {
      await db.prepare(`UPDATE listings SET status = 'ADMIN_REMOVED', removed_reason = ?, removed_by = ?, removed_at = ?, updated_at = ? WHERE id = ?`)
        .run(neden, ctx.admin.id, z, z, l.id);
      await db.prepare(`UPDATE offers SET status = 'CLOSED', updated_at = ? WHERE listing_id = ? AND status IN ('ACTIVE','SELECTED')`).run(z, l.id);
      await denetimYaz(db, {
        adminId: ctx.admin.id, ip: ctx.ip, islem: 'listing.remove', hedefTur: 'listing', hedefId: l.id,
        once: { status: l.status, ilanNo: l.ilan_no, ownerId: l.owner_id }, sonra: { status: 'ADMIN_REMOVED', ref }, gerekce: neden,
      });
    });
    const sahip = await db.prepare('SELECT * FROM users WHERE id = ?').get(l.owner_id);
    const bildirim = ctx.body.notify === false ? [] : await kullaniciyaBildir(db, sahip, 'ILAN_KALDIRILDI', { ILAN: `${l.title} (No: ${l.ilan_no})`, NEDEN: neden }, ref);
    return { id: l.id, status: 'ADMIN_REMOVED', notifications: bildirim };
  });

  r.get('/admin/v1/offers', async (ctx) => {
    yetkiIste(ctx.admin, 'content.read');
    const p = [];
    const kosul = ['1 = 1'];
    for (const [q, s] of [['providerId', 'provider_id'], ['listingId', 'listing_id'], ['status', 'status']]) {
      const v = ctx.query.get(q);
      if (v) { kosul.push(`${s} = ?`); p.push(v); }
    }
    return (await db.prepare(`SELECT * FROM offers WHERE ${kosul.join(' AND ')} ORDER BY created_at DESC LIMIT 200`).all(...p)).map(teklifGorunumu);
  });

  r.get('/admin/v1/reviews', async (ctx) => {
    yetkiIste(ctx.admin, 'content.read');
    const p = [];
    const kosul = ['1 = 1'];
    for (const [q, s] of [['providerId', 'provider_id'], ['authorId', 'author_id'], ['status', 'status']]) {
      const v = ctx.query.get(q);
      if (v) { kosul.push(`${s} = ?`); p.push(v); }
    }
    return (await db.prepare(`SELECT * FROM reviews WHERE ${kosul.join(' AND ')} ORDER BY created_at DESC LIMIT 200`).all(...p))
      .map((y) => ({ ...yorumGorunumu(y), removedReason: y.removed_reason, removedAt: y.removed_at }));
  });

  r.post('/admin/v1/reviews/:id/remove', async (ctx) => {
    yetkiIste(ctx.admin, 'reviews.remove');
    yenidenDogrulamaIste(ctx.oturum);
    const neden = String(ctx.body.reason ?? '').trim();
    if (neden.length < 5 || neden.length > 1000) throw hata.dogrulama('İşlem nedeni 5-1000 karakter olmalıdır');
    const y = await db.prepare('SELECT * FROM reviews WHERE id = ?').get(ctx.params.id);
    if (!y) throw hata.bulunamadi('Değerlendirme bulunamadı');
    if (y.status === 'ADMIN_DELETED') throw hata.durum('Değerlendirme zaten kaldırılmış');
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`UPDATE reviews SET status = 'ADMIN_DELETED', removed_reason = ?, removed_by = ?, removed_at = ? WHERE id = ?`).run(neden, ctx.admin.id, z, y.id);
      await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'review.remove', hedefTur: 'review', hedefId: y.id, once: { status: y.status, stars: y.stars, text: y.text }, sonra: { status: 'ADMIN_DELETED' }, gerekce: neden });
    });
    return { id: y.id, status: 'ADMIN_DELETED' };
  });

  r.post('/admin/v1/announcements', async (ctx) => {
    yetkiIste(ctx.admin, 'announcements.write');
    yenidenDogrulamaIste(ctx.oturum);
    const baslik = String(ctx.body.title ?? '').trim();
    const govde = String(ctx.body.body ?? '').trim();
    const hedef = ctx.body.target ?? 'ALL';
    if (baslik.length < 3 || baslik.length > 120) throw hata.dogrulama('Başlık 3-120 karakter olmalıdır');
    if (govde.length < 5 || govde.length > 1000) throw hata.dogrulama('Metin 5-1000 karakter olmalıdır');
    if (!['ALL', 'CUSTOMER', 'PROVIDER'].includes(hedef)) throw hata.dogrulama('Geçersiz hedef');
    const alicilar = await db.prepare(
      `SELECT id FROM users WHERE deleted_at IS NULL AND status = 'ACTIVE' ${hedef === 'ALL' ? '' : 'AND roles LIKE ?'}`,
    ).all(...(hedef === 'ALL' ? [] : [`%${hedef}%`]));
    const id = randomUUID();
    await db.tx(async () => {
      for (const a of alicilar) await uygulamaIciBildir(db, a.id, 'ANNOUNCEMENT', baslik, govde, id);
      await db.prepare('INSERT INTO announcements (id, title, body, target, recipient_count, admin_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
        .run(id, baslik, govde, hedef, alicilar.length, ctx.admin.id, simdi());
      await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'announcement.send', hedefTur: 'announcement', hedefId: id, sonra: { title: baslik, target: hedef, recipients: alicilar.length } });
    });
    return { id, recipients: alicilar.length };
  });

  r.get('/admin/v1/announcements', async (ctx) => {
    yetkiIste(ctx.admin, 'announcements.write');
    return (await db.prepare('SELECT * FROM announcements ORDER BY created_at DESC LIMIT 100').all())
      .map((a) => ({ id: a.id, title: a.title, body: a.body, target: a.target, recipients: a.recipient_count, createdAt: a.created_at }));
  });

  r.get('/admin/v1/feedback', async (ctx) => {
    yetkiIste(ctx.admin, 'feedback.read');
    return (await db.prepare(`SELECT f.*, u.name FROM app_feedback f JOIN users u ON u.id = f.user_id ORDER BY f.updated_at DESC LIMIT 500`).all())
      .map((f) => ({ userId: f.user_id, name: f.name, stars: f.stars, comment: f.comment, platform: f.platform, appVersion: f.app_version, updatedAt: f.updated_at }));
  });
}
