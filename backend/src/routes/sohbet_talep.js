// ═══════════════════════════════════════════════════════════════
// SOHBET · TEKLİF TALEBİ · HESAP TALEPLERİ · YASAL KABUL (+ admin okuma)
//
// Sohbet (ilan teklifi): Flutter `chat_api.dart` biçimi. Yalnız teklifin
// iki tarafı; mesaj yalnız İLETİŞİM AÇIKKEN yazılır (Flutter kuralı).
//
// Teklif talebi: Flutter'da yalnız mock vardı (`MockTeklifTalebiPort`);
// bu, onun SUNUCU KARŞILIĞIDIR — durum makinesi depodaki kurallarla
// birebir:
//   BEKLEMEDE ─teklifVer(usta)→ TEKLIF_GELDI ─sec(alan)→ SECILDI ─tamamla→ TAMAMLANDI
//   BEKLEMEDE/TEKLIF_GELDI ─reddet→ REDDEDILDI
//   TEKLIF_GELDI + 30 saat → SURESI_DOLDU
// Mesaj yalnız teklif verildikten sonra ve yalnız iki taraf arasında.
//
// Admin mesaj OKUR (müdahale etmez — Flutter'da silinmiş/gizlenmiş mesaj
// durumu yoktur); her okuma denetim kaydına yazılır (KVKK).
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { yetkiIste } from '../auth.js';
import { denetimYaz } from '../audit.js';
import { simdi } from '../db.js';
import { ApiHatasi, hata } from '../http.js';
import { olaylar } from '../olaylar.js';
import { uygulamaIciBildir } from './ilan.js';
import { kullaniciCoz, oturumlariIptal } from './kullanici.js';
import { dosyalariBagla } from './depolama_entegrasyon.js';

const TALEP_TEKLIF_OMRU = 30 * 60 * 60 * 1000;
const SILME_SURESI_GUN = 30; // Flutter metni: "30 gün içinde kalıcı olarak silinecektir"
const kural = (kod, m) => new ApiHatasi(409, kod, m);

const mesajGorunumu = (m) => ({
  id: m.id, offerId: m.offer_id, senderId: m.sender_id, text: m.text, storageRef: m.storage_ref,
  status: m.read_at ? 'READ' : 'DELIVERED', createdAt: m.created_at,
});

export function talepGorunumu(t, mesajlar = []) {
  return {
    id: t.id, talepNo: t.talep_no, hizmetAlanId: t.hizmet_alan_id, saglayiciId: t.saglayici_id,
    saglayiciAdi: t.saglayici_adi, kategori: t.kategori, hizmet: t.hizmet, aciklama: t.aciklama,
    fotograflar: JSON.parse(t.fotograflar_json), iletisimTercihi: t.iletisim_tercihi, isZamani: t.is_zamani,
    durum: t.durum, teklifFiyati: t.teklif_fiyati, teklifAciklamasi: t.teklif_aciklamasi,
    teklifTarihi: t.teklif_tarihi, redGerekcesi: t.red_gerekcesi, createdAt: t.created_at,
    mesajlar: mesajlar.map((m) => ({ id: m.id, gonderenId: m.gonderen_id, metin: m.metin, fotografRef: m.fotograf_ref, createdAt: m.created_at, okundu: !!m.read_at })),
  };
}

export async function talepSureleriniIsle(db) {
  const sinir = new Date(Date.now() - TALEP_TEKLIF_OMRU).toISOString();
  return (await db.prepare(
    `UPDATE teklif_talepleri SET durum = 'SURESI_DOLDU', updated_at = ? WHERE durum = 'TEKLIF_GELDI' AND teklif_tarihi < ?`,
  ).run(simdi(), sinir)).changes;
}

export function sohbetTalepRotalar(r, db) {
  const korumali = (f) => async (ctx) => {
    const { u, oturum } = await kullaniciCoz(db, ctx.req);
    ctx.kullanici = u;
    ctx.kOturum = oturum;
    return f(ctx);
  };

  // ════ İLAN SOHBETİ ════
  const sohbetTarafi = async (offerId, u) => {
    const o = await db.prepare('SELECT * FROM offers WHERE id = ?').get(offerId);
    if (!o) throw hata.bulunamadi('Sohbet bulunamadı');
    const l = await db.prepare('SELECT * FROM listings WHERE id = ?').get(o.listing_id);
    if (u.id !== o.provider_id && u.id !== l.owner_id) throw hata.bulunamadi('Sohbet bulunamadı');
    return { o, l };
  };

  r.get('/api/v1/messages/conversations', korumali(async (ctx) => {
    const id = ctx.kullanici.id;
    const satirlar = await db.prepare(
      `SELECT o.*, l.title listing_title, l.owner_id, c.opened_at
         FROM offers o JOIN listings l ON l.id = o.listing_id JOIN contacts c ON c.offer_id = o.id
        WHERE o.provider_id = ? OR l.owner_id = ? ORDER BY c.opened_at DESC`,
    ).all(id, id);
    const out = [];
    for (const s of satirlar) {
      const karsiId = s.provider_id === id ? s.owner_id : s.provider_id;
      const karsi = await db.prepare('SELECT name, phone FROM users WHERE id = ?').get(karsiId);
      const son = await db.prepare('SELECT * FROM messages WHERE offer_id = ? ORDER BY created_at DESC LIMIT 1').get(s.id);
      const okunmamis = (await db.prepare('SELECT COUNT(*) n FROM messages WHERE offer_id = ? AND sender_id <> ? AND read_at IS NULL').get(s.id, id)).n;
      out.push({
        offer: { id: s.id, listingId: s.listing_id, providerId: s.provider_id, amountTl: s.amount_tl, note: s.note, status: s.status, createdAt: s.created_at },
        listingTitle: s.listing_title, counterpart: { id: karsiId, name: karsi?.name ?? '', phone: karsi?.phone ?? '' },
        lastMessage: son ? mesajGorunumu(son) : null, unread: okunmamis,
      });
    }
    return out;
  }));

  r.get('/api/v1/messages/:offerId', korumali(async (ctx) => {
    const { o } = await sohbetTarafi(ctx.params.offerId, ctx.kullanici);
    const once = ctx.query.get('before');
    const liste = once
      ? await db.prepare('SELECT * FROM messages WHERE offer_id = ? AND created_at < ? ORDER BY created_at DESC LIMIT 50').all(o.id, once)
      : await db.prepare('SELECT * FROM messages WHERE offer_id = ? ORDER BY created_at DESC LIMIT 50').all(o.id);
    return liste.reverse().map(mesajGorunumu);
  }));

  r.post('/api/v1/messages', korumali(async (ctx) => {
    const { o, l } = await sohbetTarafi(String(ctx.body.offerId ?? ''), ctx.kullanici);
    if (!(await db.prepare('SELECT 1 FROM contacts WHERE offer_id = ?').get(o.id))) throw kural('INVALID_STATE', 'Mesaj göndermek için önce iletişim açılmalıdır');
    if (l.status === 'ADMIN_REMOVED') throw kural('LISTING_REMOVED', 'İlan yayından kaldırılmış');
    const metin = ctx.body.text == null ? null : String(ctx.body.text).trim();
    const ref = ctx.body.storageRef == null ? null : String(ctx.body.storageRef);
    if (!metin && !ref) throw hata.dogrulama('Boş mesaj gönderilemez');
    if (metin && metin.length > 2000) throw hata.dogrulama('Mesaj en fazla 2000 karakter olabilir');
    if (ref && !/^[A-Za-z0-9/_.-]{1,200}$/.test(ref)) throw hata.dogrulama('Geçersiz dosya');
    const anahtar = String(ctx.body.idempotencyKey ?? ctx.req.headers['idempotency-key'] ?? '').slice(0, 100) || null;
    if (anahtar) {
      const var_ = await db.prepare('SELECT * FROM messages WHERE sender_id = ? AND idempotency_key = ?').get(ctx.kullanici.id, anahtar);
      if (var_) return mesajGorunumu(var_);
    }
    const id = randomUUID();
    const z = simdi();
    const karsi = ctx.kullanici.id === o.provider_id ? l.owner_id : o.provider_id;
    await db.tx(async () => {
      if (ref) await dosyalariBagla(db, [ref], ctx.kullanici.id);
      await db.prepare('INSERT INTO messages (id, offer_id, sender_id, text, storage_ref, idempotency_key, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
        .run(id, o.id, ctx.kullanici.id, metin, ref, anahtar, z);
      await uygulamaIciBildir(db, karsi, 'NEW_MESSAGE', 'Yeni mesaj', `"${l.title}" ilanı için yeni bir mesajınız var.`, o.id);
    });
    const m = mesajGorunumu(await db.prepare('SELECT * FROM messages WHERE id = ?').get(id));
    await olaylar.yayinla('message.new', { offerId: o.id, messageId: m.id });
    return m;
  }));

  r.post('/api/v1/messages/:offerId/read', korumali(async (ctx) => {
    const { o } = await sohbetTarafi(ctx.params.offerId, ctx.kullanici);
    const n = await db.prepare('UPDATE messages SET read_at = ? WHERE offer_id = ? AND sender_id <> ? AND read_at IS NULL').run(simdi(), o.id, ctx.kullanici.id);
    if (n.changes) await olaylar.yayinla('message.read', { offerId: o.id, readerId: ctx.kullanici.id });
    return { ok: true, changed: n.changes };
  }));

  // ════ TEKLİF TALEBİ ════
  const talepGetir = async (id, u) => {
    await talepSureleriniIsle(db);
    const t = await db.prepare(
      `SELECT t.*, s.name saglayici_adi FROM teklif_talepleri t JOIN users s ON s.id = t.saglayici_id WHERE t.id = ?`,
    ).get(id);
    // Taraf olmayana kayıt YOK sayılır (varlığı da sızmaz).
    if (!t || (u.id !== t.hizmet_alan_id && u.id !== t.saglayici_id)) throw hata.bulunamadi('Talep bulunamadı');
    return t;
  };
  const talepTam = async (t) => talepGorunumu(t, await db.prepare('SELECT * FROM teklif_mesajlari WHERE talep_id = ? ORDER BY created_at').all(t.id));
  const aktifRolIste = (u, rol, m) => {
    if (u.active_role !== rol) throw hata.yetki(m);
  };

  r.get('/api/v1/teklif-talepleri', korumali(async (ctx) => {
    await talepSureleriniIsle(db);
    const u = ctx.kullanici;
    // Kullanıcının İKİ rolündeki talepleri de döner; istemci (Flutter
    // `ApiTeklifTalebiPort`) role göre süzer — rol değişince yeniden çekmez.
    const liste = await db.prepare(
      `SELECT t.*, s.name saglayici_adi FROM teklif_talepleri t JOIN users s ON s.id = t.saglayici_id
        WHERE t.hizmet_alan_id = ? OR t.saglayici_id = ? ORDER BY t.created_at DESC`,
    ).all(u.id, u.id);
    const out = [];
    for (const t of liste) out.push(await talepTam(t));
    return out;
  }));

  r.get('/api/v1/teklif-talepleri/:id', korumali(async (ctx) => talepTam(await talepGetir(ctx.params.id, ctx.kullanici))));

  r.post('/api/v1/teklif-talepleri', korumali(async (ctx) => {
    const u = ctx.kullanici;
    aktifRolIste(u, 'CUSTOMER', 'Teklif talebini yalnız hizmet alan rolüyle gönderebilirsiniz');
    const s = await db.prepare(`SELECT * FROM users WHERE id = ? AND deleted_at IS NULL AND status = 'ACTIVE'`).get(String(ctx.body.saglayiciId ?? ''));
    if (!s || !s.roles.split(',').includes('PROVIDER')) throw hata.bulunamadi('Hizmet veren bulunamadı');
    if (s.id === u.id) throw kural('OWN_LISTING_OFFER', 'Kendinize teklif talebi gönderemezsiniz');
    const kategori = String(ctx.body.kategori ?? '').trim();
    const hizmet = String(ctx.body.hizmet ?? '').trim();
    const katalogda = await db.prepare(
      `SELECT 1 FROM services sv JOIN categories c ON c.id = sv.category_id
        WHERE c.name = ? AND sv.name = ? AND sv.active = TRUE AND c.active = TRUE AND sv.deleted_at IS NULL AND c.deleted_at IS NULL`,
    ).get(kategori, hizmet);
    if (!katalogda) throw hata.dogrulama('Geçerli bir hizmet seçiniz');
    const aciklama = String(ctx.body.aciklama ?? '').trim();
    if (aciklama.split(/\s+/).filter(Boolean).length < 3 || aciklama.length > 2000) throw hata.dogrulama('Açıklamanız en az 3 kelime olmalıdır');
    const tercih = ctx.body.iletisimTercihi;
    if (!['telefonGoster', 'yalnizMesaj'].includes(tercih)) throw hata.dogrulama('Geçersiz iletişim tercihi');
    const foto = ctx.body.fotograflar ?? [];
    if (!Array.isArray(foto) || foto.length > 10 || foto.some((f) => typeof f !== 'string' || !/^[A-Za-z0-9/_.-]{1,200}$/.test(f))) throw hata.dogrulama('Geçersiz fotoğraf listesi');
    const zaman = ctx.body.isZamani ?? null;
    if (zaman !== null && !['NOW', 'THIS_WEEK', 'FLEXIBLE'].includes(zaman)) throw hata.dogrulama('Geçersiz iş zamanı');
    const id = randomUUID();
    const z = simdi();
    await db.tx(async () => {
      await dosyalariBagla(db, foto, u.id);
      const no = await db.prepare(`UPDATE counters SET value = value + 1 WHERE name = 'talep_no' RETURNING value`).get();
      await db.prepare(
        `INSERT INTO teklif_talepleri (id, talep_no, hizmet_alan_id, saglayici_id, kategori, hizmet, aciklama, fotograflar_json,
                                       iletisim_tercihi, is_zamani, durum, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'BEKLEMEDE', ?, ?)`,
      ).run(id, String(no.value), u.id, s.id, kategori, hizmet, aciklama, JSON.stringify(foto), tercih, zaman, z, z);
      await uygulamaIciBildir(db, s.id, 'NEW_OFFER', 'Yeni teklif talebi', `"${hizmet}" için size teklif talebi geldi.`, id);
    });
    return talepTam(await talepGetir(id, u));
  }));

  r.post('/api/v1/teklif-talepleri/:id/teklif', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    if (ctx.kullanici.id !== t.saglayici_id) throw hata.yetki('Teklifi yalnız hizmet veren verebilir');
    aktifRolIste(ctx.kullanici, 'PROVIDER', 'Teklifi hizmet veren rolüyle verebilirsiniz');
    if (t.durum !== 'BEKLEMEDE') throw kural('INVALID_STATE', 'Bu talebe teklif verilemez');
    const fiyat = ctx.body.fiyat;
    const ac = String(ctx.body.aciklama ?? '').trim();
    if (!Number.isInteger(fiyat) || fiyat < 1 || fiyat > 10_000_000) throw hata.dogrulama('Geçerli bir tutar giriniz');
    if (ac.length > 1000) throw hata.dogrulama('Açıklama en fazla 1000 karakter olabilir');
    const z = simdi();
    await db.prepare(`UPDATE teklif_talepleri SET durum = 'TEKLIF_GELDI', teklif_fiyati = ?, teklif_aciklamasi = ?, teklif_tarihi = ?, updated_at = ? WHERE id = ?`)
      .run(fiyat, ac, z, z, t.id);
    await uygulamaIciBildir(db, t.hizmet_alan_id, 'NEW_OFFER', 'Teklif geldi', `"${t.hizmet}" talebinize teklif geldi.`, t.id);
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  r.post('/api/v1/teklif-talepleri/:id/sec', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    if (ctx.kullanici.id !== t.hizmet_alan_id) throw hata.yetki('Teklifi yalnız talep sahibi seçebilir');
    if (t.durum === 'SECILDI') return talepTam(t);
    if (t.durum !== 'TEKLIF_GELDI') throw kural('INVALID_STATE', 'Bu teklif seçilemez');
    await db.prepare(`UPDATE teklif_talepleri SET durum = 'SECILDI', updated_at = ? WHERE id = ?`).run(simdi(), t.id);
    await uygulamaIciBildir(db, t.saglayici_id, 'OFFER_SELECTED', 'Teklifiniz kabul edildi', `"${t.hizmet}" teklifiniz kabul edildi.`, t.id);
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  r.post('/api/v1/teklif-talepleri/:id/reddet', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    const alan = ctx.kullanici.id === t.hizmet_alan_id;
    const izinli = alan ? ['BEKLEMEDE', 'TEKLIF_GELDI'] : ['BEKLEMEDE'];
    if (!izinli.includes(t.durum)) throw kural('INVALID_STATE', 'Bu talep artık reddedilemez');
    const g = ctx.body.gerekce ? String(ctx.body.gerekce).trim().slice(0, 500) : null;
    await db.prepare(`UPDATE teklif_talepleri SET durum = 'REDDEDILDI', red_gerekcesi = ?, reddeden_id = ?, updated_at = ? WHERE id = ?`)
      .run(g, ctx.kullanici.id, simdi(), t.id);
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  r.post('/api/v1/teklif-talepleri/:id/tamamla', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    if (t.durum === 'TAMAMLANDI') return talepTam(t);
    if (t.durum !== 'SECILDI') throw kural('INVALID_STATE', 'Yalnız kabul edilmiş iş tamamlanabilir');
    await db.prepare(`UPDATE teklif_talepleri SET durum = 'TAMAMLANDI', updated_at = ? WHERE id = ?`).run(simdi(), t.id);
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  r.post('/api/v1/teklif-talepleri/:id/mesajlar', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    if (!t.teklif_tarihi) throw kural('INVALID_STATE', 'Mesaj için önce teklif verilmelidir');
    const metin = ctx.body.metin == null ? null : String(ctx.body.metin).trim();
    const ref = ctx.body.fotografRef == null ? null : String(ctx.body.fotografRef);
    if (!metin && !ref) throw hata.dogrulama('Boş mesaj gönderilemez');
    if (metin && metin.length > 2000) throw hata.dogrulama('Mesaj en fazla 2000 karakter olabilir');
    if (ref && !/^[A-Za-z0-9/_.-]{1,200}$/.test(ref)) throw hata.dogrulama('Geçersiz dosya');
    const karsi = ctx.kullanici.id === t.hizmet_alan_id ? t.saglayici_id : t.hizmet_alan_id;
    await db.tx(async () => {
      if (ref) await dosyalariBagla(db, [ref], ctx.kullanici.id);
      await db.prepare('INSERT INTO teklif_mesajlari (id, talep_id, gonderen_id, metin, fotograf_ref, created_at) VALUES (?, ?, ?, ?, ?, ?)')
        .run(randomUUID(), t.id, ctx.kullanici.id, metin, ref, simdi());
      await uygulamaIciBildir(db, karsi, 'NEW_MESSAGE', 'Yeni mesaj', `"${t.hizmet}" talebi için yeni bir mesajınız var.`, t.id);
    });
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  r.post('/api/v1/teklif-talepleri/:id/okundu', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    await db.prepare('UPDATE teklif_mesajlari SET read_at = ? WHERE talep_id = ? AND gonderen_id <> ? AND read_at IS NULL').run(simdi(), t.id, ctx.kullanici.id);
    return { ok: true };
  }));

  r.post('/api/v1/teklif-talepleri/:id/review', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    if (ctx.kullanici.id !== t.hizmet_alan_id) throw hata.yetki('Değerlendirmeyi yalnız talep sahibi yapabilir');
    if (t.durum !== 'TAMAMLANDI') throw kural('INVALID_STATE', 'Değerlendirme için iş tamamlanmış olmalı');
    if (await db.prepare('SELECT 1 FROM reviews WHERE talep_id = ?').get(t.id)) throw kural('INVALID_STATE', 'Bu iş için değerlendirme zaten yapıldı');
    const y = ctx.body.stars;
    const metin = String(ctx.body.text ?? '').trim();
    if (!Number.isInteger(y) || y < 1 || y > 5) throw hata.dogrulama('Lütfen 1-5 arası bir puan seçin');
    if (metin.length > 1000) throw hata.dogrulama('Yorum en fazla 1000 karakter olabilir');
    const id = randomUUID();
    const z = simdi();
    await db.prepare(
      `INSERT INTO reviews (id, talep_id, provider_id, author_id, stars, text, status, created_at, published_at) VALUES (?, ?, ?, ?, ?, ?, 'PUBLISHED', ?, ?)`,
    ).run(id, t.id, t.saglayici_id, ctx.kullanici.id, y, metin, z, z);
    return { id, talepId: t.id, stars: y, text: metin, status: 'PUBLISHED', createdAt: z };
  }));

  // ════ HESAP TALEPLERİ (dondurma / silme) ════
  const talepGorunum = (a) => ({ id: a.id, type: a.type, status: a.status, reason: a.reason, createdAt: a.created_at, scheduledFor: a.scheduled_for, completedAt: a.completed_at });

  r.post('/api/v1/profiles/me/freeze', korumali(async (ctx) => {
    const id = randomUUID();
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`INSERT INTO account_requests (id, user_id, type, status, reason, created_at, completed_at) VALUES (?, ?, 'FREEZE', 'COMPLETED', ?, ?, ?)`)
        .run(id, ctx.kullanici.id, ctx.body.reason ? String(ctx.body.reason).slice(0, 500) : null, z, z);
      await oturumlariIptal(db, ctx.kullanici.id, 'FROZEN');
    });
    return talepGorunum(await db.prepare('SELECT * FROM account_requests WHERE id = ?').get(id));
  }));

  r.post('/api/v1/profiles/me/deletion-request', korumali(async (ctx) => {
    if (await db.prepare(`SELECT 1 FROM account_requests WHERE user_id = ? AND type = 'DELETION' AND status = 'PENDING'`).get(ctx.kullanici.id)) {
      throw kural('CONFLICT', 'Bekleyen bir silme talebiniz zaten var');
    }
    const id = randomUUID();
    const z = new Date();
    await db.prepare(`INSERT INTO account_requests (id, user_id, type, status, reason, created_at, scheduled_for) VALUES (?, ?, 'DELETION', 'PENDING', ?, ?, ?)`)
      .run(id, ctx.kullanici.id, ctx.body.reason ? String(ctx.body.reason).slice(0, 500) : null, z.toISOString(),
        new Date(z.getTime() + SILME_SURESI_GUN * 86_400_000).toISOString());
    return talepGorunum(await db.prepare('SELECT * FROM account_requests WHERE id = ?').get(id));
  }));

  r.delete('/api/v1/profiles/me/deletion-request', korumali(async (ctx) => {
    const n = await db.prepare(`UPDATE account_requests SET status = 'CANCELLED', completed_at = ? WHERE user_id = ? AND type = 'DELETION' AND status = 'PENDING'`)
      .run(simdi(), ctx.kullanici.id);
    if (!n.changes) throw hata.bulunamadi('Bekleyen silme talebi yok');
    return { ok: true };
  }));

  r.get('/api/v1/profiles/me/account-requests', korumali(async (ctx) =>
    (await db.prepare('SELECT * FROM account_requests WHERE user_id = ? ORDER BY created_at DESC').all(ctx.kullanici.id)).map(talepGorunum),
  ));

  // ════ PUSH JETONU (FCM) ════
  // Kayıt/silme. Aynı jeton başka hesaba geçtiyse (aynı cihazda farklı
  // kullanıcı) yeni sahibine taşınır. Gönderim tarafı henüz yok.
  r.post('/api/v1/devices/push-token', korumali(async (ctx) => {
    const t = String(ctx.body.token ?? '');
    const pl = String(ctx.body.platform ?? '');
    if (!/^[A-Za-z0-9_:\-.]{20,4096}$/.test(t)) throw hata.dogrulama('Geçersiz jeton');
    if (!['android', 'ios', 'web'].includes(pl)) throw hata.dogrulama('Geçersiz platform');
    const z = simdi();
    await db.prepare(
      `INSERT INTO push_tokens (token, user_id, platform, created_at, last_seen) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id, platform = excluded.platform, last_seen = excluded.last_seen`,
    ).run(t, ctx.kullanici.id, pl, z, z);
    return undefined;
  }));

  r.delete('/api/v1/devices/push-token', korumali(async (ctx) => {
    await db.prepare('DELETE FROM push_tokens WHERE token = ? AND user_id = ?').run(String(ctx.body.token ?? ''), ctx.kullanici.id);
    return undefined;
  }));

  // ════ YASAL BELGE KABULÜ ════
  // Kabul isteyen ve yayında olan belgelerin, kullanıcının henüz kabul
  // etmediği SÜRÜMLERİ. Flutter açılışta bunu sorar → "Görüntüle → Kabul Et".
  r.get('/api/v1/legal/pending-acceptances', korumali(async (ctx) =>
    (await db.prepare(
      `SELECT d.slug, d.title, v.id version_id, v.version, v.sha256, v.effective_date
         FROM legal_documents d JOIN legal_versions v ON v.slug = d.slug AND v.status = 'PUBLISHED'
        WHERE d.active = TRUE AND d.requires_acceptance = TRUE
          AND NOT EXISTS (SELECT 1 FROM legal_acceptances a WHERE a.user_id = ? AND a.version_id = v.id)
        ORDER BY d.slug`,
    ).all(ctx.kullanici.id)).map((x) => ({ slug: x.slug, title: x.title, version: String(x.version), sha256: x.sha256, effectiveDate: x.effective_date })),
  ));

  r.post('/api/v1/legal/:slug/accept', korumali(async (ctx) => {
    const v = await db.prepare(
      `SELECT v.* FROM legal_versions v JOIN legal_documents d ON d.slug = v.slug WHERE v.slug = ? AND v.status = 'PUBLISHED' AND d.active = TRUE`,
    ).get(ctx.params.slug);
    if (!v) throw hata.bulunamadi('Belge bulunamadı');
    // İstemci hangi sürümü gördüğünü bildirir; yayındaki sürümle aynı olmalı
    // (arada yeni sürüm yayınlandıysa kabul geçersiz, yenisi gösterilir).
    if (String(ctx.body.version ?? '') !== String(v.version) || ctx.body.sha256 !== v.sha256) {
      throw kural('STATE_CONFLICT', 'Belgenin yeni bir sürümü yayınlandı');
    }
    const pl = ['android', 'ios', 'web'].includes(ctx.body.platform) ? ctx.body.platform : null;
    if (!(await db.prepare('SELECT 1 FROM legal_acceptances WHERE user_id = ? AND version_id = ?').get(ctx.kullanici.id, v.id))) {
      await db.prepare('INSERT INTO legal_acceptances (id, user_id, slug, version_id, version, sha256, platform, accepted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        .run(randomUUID(), ctx.kullanici.id, v.slug, v.id, v.version, v.sha256, pl, simdi());
    }
    return { ok: true };
  }));

  // ════ ADMİN (salt okuma) ════
  r.get('/admin/v1/teklif-talepleri', async (ctx) => {
    yetkiIste(ctx.admin, 'content.read');
    await talepSureleriniIsle(db);
    const p = [];
    const kosul = ['1 = 1'];
    for (const [q, s] of [['durum', 't.durum'], ['hizmetAlanId', 't.hizmet_alan_id'], ['saglayiciId', 't.saglayici_id']]) {
      const v = ctx.query.get(q);
      if (v) { kosul.push(`${s} = ?`); p.push(v); }
    }
    return (await db.prepare(
      `SELECT t.*, s.name saglayici_adi FROM teklif_talepleri t JOIN users s ON s.id = t.saglayici_id WHERE ${kosul.join(' AND ')} ORDER BY t.created_at DESC LIMIT 200`,
    ).all(...p)).map((t) => talepGorunumu(t));
  });

  r.get('/admin/v1/teklif-talepleri/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'messages.read');
    const t = await db.prepare(`SELECT t.*, s.name saglayici_adi FROM teklif_talepleri t JOIN users s ON s.id = t.saglayici_id WHERE t.id = ?`).get(ctx.params.id);
    if (!t) throw hata.bulunamadi('Talep bulunamadı');
    await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'talep.messages.view', hedefTur: 'teklif_talebi', hedefId: t.id });
    return talepGorunumu(t, await db.prepare('SELECT * FROM teklif_mesajlari WHERE talep_id = ? ORDER BY created_at').all(t.id));
  });

  r.get('/admin/v1/chats/:offerId/messages', async (ctx) => {
    yetkiIste(ctx.admin, 'messages.read');
    const o = await db.prepare('SELECT * FROM offers WHERE id = ?').get(ctx.params.offerId);
    if (!o) throw hata.bulunamadi('Sohbet bulunamadı');
    await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'chat.messages.view', hedefTur: 'offer', hedefId: o.id });
    return (await db.prepare('SELECT * FROM messages WHERE offer_id = ? ORDER BY created_at').all(o.id)).map(mesajGorunumu);
  });

  r.get('/admin/v1/account-requests', async (ctx) => {
    yetkiIste(ctx.admin, 'users.read');
    const durum = ctx.query.get('status');
    const satir = durum
      ? await db.prepare(`SELECT r.*, u.name FROM account_requests r JOIN users u ON u.id = r.user_id WHERE r.status = ? ORDER BY r.created_at DESC LIMIT 500`).all(durum)
      : await db.prepare(`SELECT r.*, u.name FROM account_requests r JOIN users u ON u.id = r.user_id ORDER BY r.created_at DESC LIMIT 500`).all();
    return satir.map((a) => ({ ...talepGorunum(a), userId: a.user_id, name: a.name }));
  });

  r.get('/admin/v1/users/:id/legal-acceptances', async (ctx) => {
    yetkiIste(ctx.admin, 'users.read');
    return (await db.prepare('SELECT * FROM legal_acceptances WHERE user_id = ? ORDER BY accepted_at DESC').all(ctx.params.id))
      .map((a) => ({ slug: a.slug, version: a.version, sha256: a.sha256, platform: a.platform, acceptedAt: a.accepted_at }));
  });
}

/**
 * Süresi gelen hesap silme taleplerini uygular: kişisel veri ANONİMLEŞTİRİLİR
 * (ad, telefon, e-posta, şifre), oturumlar kapanır, kayıt silinmiş işaretlenir.
 * İlan/teklif/yorum geçmişi bütünlük için kalır, kişiye bağlanamaz.
 */
export async function silmeTalepleriniIsle(db) {
  const z = simdi();
  const bekleyen = await db.prepare(
    `SELECT * FROM account_requests WHERE type = 'DELETION' AND status = 'PENDING' AND scheduled_for < ?`,
  ).all(z);
  for (const a of bekleyen) {
    await db.tx(async () => {
      await db.prepare(
        `UPDATE users SET name = 'Silinmiş Kullanıcı', phone = ?, email = NULL, password_hash = ?,
                          phone_verified = FALSE, email_verified = FALSE, deleted_at = ?, updated_at = ? WHERE id = ?`,
      ).run(`silindi-${a.user_id}`, `silindi$${randomUUID()}`, z, z, a.user_id);
      await db.prepare('DELETE FROM addresses WHERE user_id = ?').run(a.user_id);
      await db.prepare('DELETE FROM provider_profiles WHERE user_id = ?').run(a.user_id);
      await db.prepare('DELETE FROM push_tokens WHERE user_id = ?').run(a.user_id);
      await oturumlariIptal(db, a.user_id, 'DELETED');
      await db.prepare(`UPDATE account_requests SET status = 'COMPLETED', completed_at = ? WHERE id = ?`).run(z, a.id);
    });
  }
  return bekleyen.length;
}
