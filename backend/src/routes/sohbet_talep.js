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
import { simdi, tekilIhlaliMi } from '../db.js';
import { dosyalariDogrula } from '../depo_dogrulama.js';
import { govdeOzeti, idemAnahtari, idemOlustur, oncekiKayit } from '../idempotency.js';
import { ApiHatasi, HizSiniri, hata } from '../http.js';

// Kötüye kullanım sınırları (kullanıcı başına, çok örnekte ortak). Mesaj
// sınırı ilan sohbeti ve teklif talebi sohbetinde ORTAKTIR.
const mesajSiniri = new HizSiniri('mesaj', 60, 60 * 1000);
const talepOlusturSiniri = new HizSiniri('teklif_talebi', 30, 60 * 60 * 1000);
import { olaylar } from '../olaylar.js';
import { uygulamaIciBildir } from './ilan.js';
import { kritikIslemSiniri, kullaniciCoz, oturumlariIptal, sifreDogruMu } from './kullanici.js';
import { hesapDosyalariniIsaretle } from '../dosya_temizligi.js';
import { firebaseSilmeKuyrugunaEkle } from '../firebase_silme.js';
import { yoneticiKayitlariniAnonimlestir } from '../denetim_anonimlestirme.js';
import { dosyalariBagla } from './depolama_entegrasyon.js';
import { ilanTelefonuGorunur } from './kisi_ozeti.js';
import { kimlikArsivle } from '../trafik_kaydi.js';

const TALEP_TEKLIF_OMRU = 30 * 60 * 60 * 1000;
// Silme talebinden sonraki bekleme (talep bu sürede geri çekilebilir). Süre
// dolunca silme, zamanlayıcının bir sonraki turunda uygulanır; zamanlayıcı
// yalnız sunucu ayaktayken çalışır (Render ücretsiz planında sunucu uyurken
// iş de bekler, ilk uyanışta yetişir). Uygulama ekranı gün sayısı vaat ETMEZ
// ("Silme talebiniz değerlendirmede"); gecikmeler Admin → Silme Kuyrukları'nda.
const SILME_SURESI_GUN = 30;
const kural = (kod, m) => new ApiHatasi(409, kod, m);

/**
 * Yönetici özel yazışmayı GEREKÇEYLE açar (15 Eki güvenlik denetimi, karar 6):
 * yetki (messages.read) tek başına yetmez; her görüntülemenin nedeni (en az
 * 5 karakter) denetim kaydına yazılır. Gerekçe `X-HC-Reason` başlığında
 * (URI kodlu) gelir — adres satırında giderse erişim günlüklerine düşerdi.
 */
function goruntulemeGerekcesi(ctx) {
  let v = '';
  try { v = decodeURIComponent(String(ctx.req.headers['x-hc-reason'] ?? '')).trim(); } catch { v = ''; }
  if (v.length < 5) throw hata.dogrulama('Görüntüleme gerekçesi en az 5 karakter olmalıdır');
  return v.slice(0, 500);
}

const mesajGorunumu = (m) => ({
  id: m.id, offerId: m.offer_id, senderId: m.sender_id, text: m.text, storageRef: m.storage_ref,
  status: m.read_at ? 'READ' : 'DELIVERED', createdAt: m.created_at,
});

export function talepGorunumu(t, mesajlar = [], degerlendirme = null) {
  return {
    id: t.id, talepNo: t.talep_no, hizmetAlanId: t.hizmet_alan_id, saglayiciId: t.saglayici_id,
    saglayiciAdi: t.saglayici_adi, kategori: t.kategori, hizmet: t.hizmet, aciklama: t.aciklama,
    fotograflar: JSON.parse(t.fotograflar_json), iletisimTercihi: t.iletisim_tercihi, isZamani: t.is_zamani,
    durum: t.durum, teklifFiyati: t.teklif_fiyati, teklifAciklamasi: t.teklif_aciklamasi,
    teklifTarihi: t.teklif_tarihi, redGerekcesi: t.red_gerekcesi, createdAt: t.created_at,
    // Hizmet alan talebi sildiyse dolu (15 Eki); hizmet veren "iptal edildi" görür.
    silindiAt: t.silindi_at ?? null,
    // 22 Eki: talebi HİZMET VEREN reddetti (teklif vermeden). Hizmet alan
    // talebi pasif görür ("Hizmet veren reddetti"); hizmet verenin
    // listesinden kalkar.
    saglayiciReddetti: t.durum === 'REDDEDILDI' && t.reddeden_id != null && t.reddeden_id === t.saglayici_id,
    mesajlar: mesajlar.map((m) => ({ id: m.id, gonderenId: m.gonderen_id, metin: m.metin, fotografRef: m.fotograf_ref, createdAt: m.created_at, okundu: !!m.read_at })),
    // Talebin değerlendirmesi (yoksa null): istemci "Değerlendirme Yapıldı"
    // durumunu yeniden girişten sonra da doğru gösterir.
    degerlendirme: degerlendirme
      ? { id: degerlendirme.id, stars: degerlendirme.stars, text: degerlendirme.text, createdAt: degerlendirme.created_at }
      : null,
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
      `SELECT o.*, l.title listing_title, l.owner_id, l.iletisim_tercihi, c.opened_at
         FROM offers o JOIN listings l ON l.id = o.listing_id JOIN contacts c ON c.offer_id = o.id
        WHERE o.provider_id = ? OR l.owner_id = ? ORDER BY c.opened_at DESC`,
    ).all(id, id);
    if (!satirlar.length) return [];
    // TOPLU okuma (N+1 yok): karşı taraflar, son mesajlar ve okunmamış
    // sayıları üç sorguda. Önceden sohbet başına üç sorgu vardı.
    const teklifler = satirlar.map((s) => s.id);
    const yer = teklifler.map(() => '?').join(', ');
    const karsiIdleri = [...new Set(satirlar.map((s) => (s.provider_id === id ? s.owner_id : s.provider_id)))];
    const kullanicilar = new Map((await db.prepare(`SELECT id, name, phone FROM users WHERE id IN (${karsiIdleri.map(() => '?').join(', ')})`)
      .all(...karsiIdleri)).map((u) => [u.id, u]));
    const sonlar = new Map((await db.prepare(
      `SELECT * FROM (SELECT m.*, ROW_NUMBER() OVER (PARTITION BY m.offer_id ORDER BY m.created_at DESC, m.id DESC) sira
                        FROM messages m WHERE m.offer_id IN (${yer})) x WHERE x.sira = 1`,
    ).all(...teklifler)).map((m) => [m.offer_id, m]));
    const okunmamislar = new Map((await db.prepare(
      `SELECT offer_id, COUNT(*) n FROM messages WHERE offer_id IN (${yer}) AND sender_id <> ? AND read_at IS NULL GROUP BY offer_id`,
    ).all(...teklifler, id)).map((r) => [r.offer_id, r.n]));
    const out = [];
    for (const s of satirlar) {
      const karsiId = s.provider_id === id ? s.owner_id : s.provider_id;
      const karsi = kullanicilar.get(karsiId);
      const son = sonlar.get(s.id);
      const okunmamis = okunmamislar.get(s.id) ?? 0;
      // ⚠ E1 (22 Eki): telefon tek kuralla (kisi_ozeti.js); sohbet yalnız
      // iletişim açıkken listelenir (JOIN contacts).
      const telefonGorunur = ilanTelefonuGorunur({ iletisimAcik: true, karsiIlanSahibi: karsiId === s.owner_id, tercih: s.iletisim_tercihi });
      out.push({
        offer: { id: s.id, listingId: s.listing_id, providerId: s.provider_id, amountTl: s.amount_tl, note: s.note, status: s.status, createdAt: s.created_at },
        listingTitle: s.listing_title, counterpart: { id: karsiId, name: karsi?.name ?? '', phone: telefonGorunur ? (karsi?.phone ?? '') : null },
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
    await mesajSiniri.denetle(db, ctx.kullanici.id);
    if (!(await db.prepare('SELECT 1 FROM contacts WHERE offer_id = ?').get(o.id))) throw kural('INVALID_STATE', 'Mesaj göndermek için önce iletişim açılmalıdır');
    if (l.status === 'ADMIN_REMOVED') throw kural('LISTING_REMOVED', 'İlan yayından kaldırılmış');
    const metin = ctx.body.text == null ? null : String(ctx.body.text).trim();
    const ref = ctx.body.storageRef == null ? null : String(ctx.body.storageRef);
    if (!metin && !ref) throw hata.dogrulama('Boş mesaj gönderilemez');
    if (metin && metin.length > 2000) throw hata.dogrulama('Mesaj en fazla 2000 karakter olabilir');
    if (ref && !/^[A-Za-z0-9/_.-]{1,200}$/.test(ref)) throw hata.dogrulama('Geçersiz dosya');
    const MESAJ_IDEM = { tablo: 'messages', sahipSutun: 'sender_id' };
    const anahtar = idemAnahtari(ctx, 'idempotencyKey');
    const ozet = govdeOzeti({ offerId: o.id, text: metin, storageRef: ref });
    const onceki = await oncekiKayit(db, MESAJ_IDEM, ctx.kullanici.id, anahtar, ozet);
    if (onceki) return mesajGorunumu(onceki);
    if (ref) await dosyalariDogrula(db, [ref], ctx.kullanici.id, 'listing-photo'); // işlem DIŞINDA
    const id = randomUUID();
    const z = simdi();
    const karsi = ctx.kullanici.id === o.provider_id ? l.owner_id : o.provider_id;
    const { yeni, kayit } = await idemOlustur(db, MESAJ_IDEM, ctx.kullanici.id, anahtar, ozet, () => db.tx(async () => {
      if (ref) await dosyalariBagla(db, [ref], ctx.kullanici.id);
      await db.prepare('INSERT INTO messages (id, offer_id, sender_id, text, storage_ref, idempotency_key, idem_hash, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        .run(id, o.id, ctx.kullanici.id, metin, ref, anahtar, anahtar ? ozet : null, z);
      await uygulamaIciBildir(db, karsi, 'NEW_MESSAGE', 'Yeni mesaj', `"${l.title}" ilanı için yeni bir mesajınız var.`, o.id, 'mesaj');
      return db.prepare('SELECT * FROM messages WHERE id = ?').get(id);
    }));
    const m = mesajGorunumu(kayit);
    if (yeni) await olaylar.yayinla('message.new', { offerId: o.id, messageId: m.id });
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
  const talepTam = async (t) => talepGorunumu(
    t,
    await db.prepare('SELECT * FROM teklif_mesajlari WHERE talep_id = ? ORDER BY created_at').all(t.id),
    await db.prepare(`SELECT * FROM reviews WHERE talep_id = ? AND status = 'PUBLISHED'`).get(t.id),
  );
  /** Liste için TOPLU okuma (N+1 yok): mesajlar ve değerlendirmeler tek sorguda. */
  const talepleriTopluTamamla = async (liste) => {
    if (!liste.length) return [];
    const kimlikler = liste.map((t) => t.id);
    const yer = kimlikler.map(() => '?').join(', ');
    const mesajlar = await db.prepare(`SELECT * FROM teklif_mesajlari WHERE talep_id IN (${yer}) ORDER BY created_at`).all(...kimlikler);
    const yorumlar = await db.prepare(`SELECT * FROM reviews WHERE status = 'PUBLISHED' AND talep_id IN (${yer})`).all(...kimlikler);
    const mesajHaritasi = new Map();
    for (const m of mesajlar) {
      if (!mesajHaritasi.has(m.talep_id)) mesajHaritasi.set(m.talep_id, []);
      mesajHaritasi.get(m.talep_id).push(m);
    }
    const yorumHaritasi = new Map(yorumlar.map((y) => [y.talep_id, y]));
    return liste.map((t) => talepGorunumu(t, mesajHaritasi.get(t.id) ?? [], yorumHaritasi.get(t.id) ?? null));
  };
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
        WHERE (t.hizmet_alan_id = ? OR t.saglayici_id = ?)
          AND NOT (t.hizmet_alan_id = ? AND t.silindi_at IS NOT NULL)
          AND NOT (t.saglayici_id = ? AND t.durum = 'REDDEDILDI' AND t.reddeden_id = t.saglayici_id)
        ORDER BY t.created_at DESC`,
    ).all(u.id, u.id, u.id, u.id); // ⚠ hizmet alanın SİLDİĞİ / hizmet verenin REDDETTİĞİ talep o tarafın listesine dönmez
    const out = await talepleriTopluTamamla(liste);
    return out;
  }));

  r.get('/api/v1/teklif-talepleri/:id', korumali(async (ctx) => talepTam(await talepGetir(ctx.params.id, ctx.kullanici))));

  r.post('/api/v1/teklif-talepleri', korumali(async (ctx) => {
    const u = ctx.kullanici;
    aktifRolIste(u, 'CUSTOMER', 'Teklif talebini yalnız hizmet alan rolüyle gönderebilirsiniz');
    const TALEP_IDEM = { tablo: 'teklif_talepleri', sahipSutun: 'hizmet_alan_id' };
    const talepAnahtari = idemAnahtari(ctx);
    const talepOzeti = govdeOzeti({
      saglayiciId: String(ctx.body.saglayiciId ?? ''), kategori: String(ctx.body.kategori ?? '').trim(), hizmet: String(ctx.body.hizmet ?? '').trim(),
      aciklama: String(ctx.body.aciklama ?? '').trim(), iletisimTercihi: ctx.body.iletisimTercihi ?? null, fotograflar: ctx.body.fotograflar ?? [], isZamani: ctx.body.isZamani ?? null,
    });
    const oncekiTalep = await oncekiKayit(db, TALEP_IDEM, u.id, talepAnahtari, talepOzeti);
    if (oncekiTalep) return talepTam(await talepGetir(oncekiTalep.id, u));
    await talepOlusturSiniri.denetle(db, u.id);
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
    await dosyalariDogrula(db, foto, u.id, 'listing-photo'); // işlem DIŞINDA
    const id = randomUUID();
    const z = simdi();
    const { kayit } = await idemOlustur(db, TALEP_IDEM, u.id, talepAnahtari, talepOzeti, () => db.tx(async () => {
      await dosyalariBagla(db, foto, u.id);
      const no = await db.prepare(`UPDATE counters SET value = value + 1 WHERE name = 'talep_no' RETURNING value`).get();
      await db.prepare(
        `INSERT INTO teklif_talepleri (id, talep_no, hizmet_alan_id, saglayici_id, kategori, hizmet, aciklama, fotograflar_json,
                                       iletisim_tercihi, is_zamani, durum, created_at, updated_at, idempotency_key, idem_hash)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'BEKLEMEDE', ?, ?, ?, ?)`,
      ).run(id, String(no.value), u.id, s.id, kategori, hizmet, aciklama, JSON.stringify(foto), tercih, zaman, z, z,
        talepAnahtari, talepAnahtari ? talepOzeti : null);
      await uygulamaIciBildir(db, s.id, 'TALEP_REQUEST', 'Yeni teklif talebi', `"${hizmet}" için size teklif talebi geldi.`, id, 'talep');
      return { id };
    }));
    return talepTam(await talepGetir(kayit.id, u));
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
    // ⚠ KOŞULLU GEÇİŞLER (bu dosyadaki bütün durum değişikliklerinde): okunan
    // durum hâlâ geçerliyse yazılır. Eşzamanlı iki işlemde (ör. hizmet alan
    // reddederken hizmet veren teklif verir) ikincisi eski durumun üzerine
    // yazamaz; çakışan istek INVALID_STATE alır.
    const g1 = await db.prepare(`UPDATE teklif_talepleri SET durum = 'TEKLIF_GELDI', teklif_fiyati = ?, teklif_aciklamasi = ?, teklif_tarihi = ?, updated_at = ? WHERE id = ? AND durum = 'BEKLEMEDE'`)
      .run(fiyat, ac, z, z, t.id);
    if (g1.changes !== 1) throw kural('INVALID_STATE', 'Bu talebe teklif verilemez');
    await uygulamaIciBildir(db, t.hizmet_alan_id, 'TALEP_OFFER', 'Teklif geldi', `"${t.hizmet}" talebinize teklif geldi.`, t.id, 'talep');
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  r.post('/api/v1/teklif-talepleri/:id/sec', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    if (ctx.kullanici.id !== t.hizmet_alan_id) throw hata.yetki('Teklifi yalnız talep sahibi seçebilir');
    if (t.durum === 'SECILDI') return talepTam(t);
    if (t.durum !== 'TEKLIF_GELDI') throw kural('INVALID_STATE', 'Bu teklif seçilemez');
    // secildi_at: kabul anı (Özet'teki seçilen teklif tutarı bu tarihe göre).
    const secim = simdi();
    const g2 = await db.prepare(`UPDATE teklif_talepleri SET durum = 'SECILDI', secildi_at = ?, updated_at = ? WHERE id = ? AND durum = 'TEKLIF_GELDI'`).run(secim, secim, t.id);
    if (g2.changes !== 1) throw kural('INVALID_STATE', 'Bu teklif seçilemez');
    await uygulamaIciBildir(db, t.saglayici_id, 'TALEP_ACCEPTED', 'Teklifiniz kabul edildi', `"${t.hizmet}" teklifiniz kabul edildi.`, t.id, 'talep');
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  r.post('/api/v1/teklif-talepleri/:id/reddet', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    const alan = ctx.kullanici.id === t.hizmet_alan_id;
    const izinli = alan ? ['BEKLEMEDE', 'TEKLIF_GELDI'] : ['BEKLEMEDE'];
    if (!izinli.includes(t.durum)) throw kural('INVALID_STATE', 'Bu talep artık reddedilemez');
    const g = ctx.body.gerekce ? String(ctx.body.gerekce).trim().slice(0, 500) : null;
    const g3 = await db.prepare(`UPDATE teklif_talepleri SET durum = 'REDDEDILDI', red_gerekcesi = ?, reddeden_id = ?, updated_at = ? WHERE id = ? AND durum IN (${izinli.map(() => '?').join(', ')})`)
      .run(g, ctx.kullanici.id, simdi(), t.id, ...izinli);
    if (g3.changes !== 1) throw kural('INVALID_STATE', 'Bu talep artık reddedilemez');
    // 22 Eki: hizmet veren reddettiyse hizmet alan bilgilendirilir (talep
    // onun listesinde pasif kalır; kendisi silebilir).
    if (!alan) {
      await uygulamaIciBildir(db, t.hizmet_alan_id, 'TALEP_DECLINED', 'Teklif talebiniz reddedildi',
        `"${t.hizmet}" talebinizi hizmet veren reddetti.`, t.id, 'talep');
    }
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  // ── HİZMET ALAN TALEBİ SİLER (15 Eki, kullanıcı bulgusu) ──
  // "Talebi Sil" eskiden /reddet çağırıyordu: talep "Reddedildi" olarak
  // listede kalıyordu ve gelen teklifi reddetmekten ayırt edilemiyordu.
  // Silme hangi gerekçeyle olursa olsun talebi hizmet alanın listesinden
  // kaldırır. Kayıt kalıcı silinmez (hizmet verenin geçmişi, mesajlar);
  // açıksa (BEKLEMEDE/TEKLIF_GELDI) kapanır, mesajlaşma kapanır.
  // Kabul edilmiş/tamamlanmış iş silinemez.
  r.post('/api/v1/teklif-talepleri/:id/sil', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    if (ctx.kullanici.id !== t.hizmet_alan_id) throw hata.yetki('Talebi yalnız hizmet alan silebilir');
    const g = ctx.body.gerekce ? String(ctx.body.gerekce).trim().slice(0, 500) : null;
    const z = simdi();
    const s = await db.prepare(
      `UPDATE teklif_talepleri
          SET durum = CASE WHEN durum IN ('BEKLEMEDE', 'TEKLIF_GELDI') THEN 'REDDEDILDI' ELSE durum END,
              reddeden_id = CASE WHEN durum IN ('BEKLEMEDE', 'TEKLIF_GELDI') THEN ? ELSE reddeden_id END,
              red_gerekcesi = COALESCE(?, red_gerekcesi),
              silindi_at = COALESCE(silindi_at, ?),
              updated_at = ?
        WHERE id = ? AND durum NOT IN ('SECILDI', 'TAMAMLANDI')`,
    ).run(ctx.kullanici.id, g, z, z, t.id);
    if (s.changes !== 1) throw kural('INVALID_STATE', 'Kabul edilmiş iş silinemez');
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  r.post('/api/v1/teklif-talepleri/:id/tamamla', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    if (t.durum === 'TAMAMLANDI') return talepTam(t);
    if (t.durum !== 'SECILDI') throw kural('INVALID_STATE', 'Yalnız kabul edilmiş iş tamamlanabilir');
    const g4 = await db.prepare(`UPDATE teklif_talepleri SET durum = 'TAMAMLANDI', updated_at = ? WHERE id = ? AND durum = 'SECILDI'`).run(simdi(), t.id);
    if (g4.changes !== 1 && (await talepGetir(t.id, ctx.kullanici)).durum !== 'TAMAMLANDI') throw kural('INVALID_STATE', 'Yalnız kabul edilmiş iş tamamlanabilir');
    return talepTam(await talepGetir(t.id, ctx.kullanici));
  }));

  r.post('/api/v1/teklif-talepleri/:id/mesajlar', korumali(async (ctx) => {
    const t = await talepGetir(ctx.params.id, ctx.kullanici);
    await mesajSiniri.denetle(db, ctx.kullanici.id);
    if (!t.teklif_tarihi) throw kural('INVALID_STATE', 'Mesaj için önce teklif verilmelidir');
    // Teklifin süresi dolunca iletişim kapanır (ürün kararı, 11 Eki);
    // `talepGetir` süre taramasını önce yaptığı için durum günceldir.
    if (t.durum === 'SURESI_DOLDU') throw kural('INVALID_STATE', 'Teklifin süresi doldu; mesajlaşma kapandı.');
    if (t.silindi_at) throw kural('INVALID_STATE', 'Talep silindi; mesajlaşma kapandı.');
    const metin = ctx.body.metin == null ? null : String(ctx.body.metin).trim();
    const ref = ctx.body.fotografRef == null ? null : String(ctx.body.fotografRef);
    if (!metin && !ref) throw hata.dogrulama('Boş mesaj gönderilemez');
    if (metin && metin.length > 2000) throw hata.dogrulama('Mesaj en fazla 2000 karakter olabilir');
    if (ref && !/^[A-Za-z0-9/_.-]{1,200}$/.test(ref)) throw hata.dogrulama('Geçersiz dosya');
    const karsi = ctx.kullanici.id === t.hizmet_alan_id ? t.saglayici_id : t.hizmet_alan_id;
    const TMESAJ_IDEM = { tablo: 'teklif_mesajlari', sahipSutun: 'gonderen_id' };
    const anahtar = idemAnahtari(ctx);
    const ozet = govdeOzeti({ talepId: t.id, metin, fotografRef: ref });
    if (await oncekiKayit(db, TMESAJ_IDEM, ctx.kullanici.id, anahtar, ozet)) return talepTam(await talepGetir(t.id, ctx.kullanici));
    if (ref) await dosyalariDogrula(db, [ref], ctx.kullanici.id, 'listing-photo');
    await idemOlustur(db, TMESAJ_IDEM, ctx.kullanici.id, anahtar, ozet, () => db.tx(async () => {
      if (ref) await dosyalariBagla(db, [ref], ctx.kullanici.id);
      await db.prepare('INSERT INTO teklif_mesajlari (id, talep_id, gonderen_id, metin, fotograf_ref, created_at, idempotency_key, idem_hash) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        .run(randomUUID(), t.id, ctx.kullanici.id, metin, ref, simdi(), anahtar, anahtar ? ozet : null);
      await uygulamaIciBildir(db, karsi, 'TALEP_MESSAGE', 'Yeni mesaj', `"${t.hizmet}" talebi için yeni bir mesajınız var.`, t.id, 'talep');
      return {};
    }));
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
    try {
      await db.prepare(
        `INSERT INTO reviews (id, talep_id, provider_id, author_id, stars, text, status, created_at, published_at) VALUES (?, ?, ?, ?, ?, ?, 'PUBLISHED', ?, ?)`,
      ).run(id, t.id, t.saglayici_id, ctx.kullanici.id, y, metin, z, z);
    } catch (e) {
      // Eşzamanlı çift değerlendirme: talep başına tekil (reviews.talep_id UNIQUE).
      if (tekilIhlaliMi(e)) throw kural('INVALID_STATE', 'Bu iş için değerlendirme zaten yapıldı');
      throw e;
    }
    return { id, talepId: t.id, providerId: t.saglayici_id, authorId: ctx.kullanici.id, stars: y, text: metin, status: 'PUBLISHED', createdAt: z };
  }));

  // ════ HESAP TALEPLERİ (dondurma / silme) ════
  const talepGorunum = (a) => ({ id: a.id, type: a.type, status: a.status, reason: a.reason, createdAt: a.created_at, scheduledFor: a.scheduled_for, completedAt: a.completed_at });

  r.post('/api/v1/profiles/me/freeze', korumali(async (ctx) => {
    const id = randomUUID();
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`INSERT INTO account_requests (id, user_id, type, status, reason, created_at, completed_at) VALUES (?, ?, 'FREEZE', 'COMPLETED', ?, ?, ?)`)
        .run(id, ctx.kullanici.id, ctx.body.reason ? String(ctx.body.reason).slice(0, 500) : null, z, z);
      // GERÇEK DONDURMA: hesap durumu işaretlenir (yalnız çıkış DEĞİL).
      // Dondurulmuş hesap: oturum kullanamaz, aramada görünmez, push almaz.
      // Veri SİLİNMEZ. Yeniden giriş etkinleştirir (uygulamadaki metin).
      await db.prepare('UPDATE users SET frozen_at = ?, updated_at = ? WHERE id = ?').run(z, z, ctx.kullanici.id);
      await oturumlariIptal(db, ctx.kullanici.id, 'FROZEN');
    });
    return talepGorunum(await db.prepare('SELECT * FROM account_requests WHERE id = ?').get(id));
  }));

  r.post('/api/v1/profiles/me/deletion-request', korumali(async (ctx) => {
    // ⚠ ATOMİK: "önce SELECT sonra INSERT" eşzamanlı iki istekte İKİ bekleyen
    // talep üretebiliyordu. Kısmi TEKİL dizin (account_requests_tek_silme)
    // ikinciyi veritabanında reddeder; yanıt eskisiyle aynı (CONFLICT).
    //
    // ⚠ ŞİFRE SUNUCUDA DA DOĞRULANIR (15 Eki güvenlik denetimi): önceden
    // şifre yalnız istemcide ayrı bir uçla soruluyordu; doğrudan bu uca
    // gelen istek (çalınmış oturum) şifresiz silme talebi açabiliyordu.
    await kritikIslemSiniri.denetle(db, ctx.kullanici.id);
    if (!(await sifreDogruMu(db, ctx.kullanici, String(ctx.body.password ?? '')))) {
      throw new ApiHatasi(400, 'WRONG_PASSWORD', 'Şifre hatalı');
    }
    const id = randomUUID();
    const z = new Date();
    try {
      await db.prepare(`INSERT INTO account_requests (id, user_id, type, status, reason, created_at, scheduled_for) VALUES (?, ?, 'DELETION', 'PENDING', ?, ?, ?)`)
        .run(id, ctx.kullanici.id, ctx.body.reason ? String(ctx.body.reason).slice(0, 500) : null, z.toISOString(),
          new Date(z.getTime() + SILME_SURESI_GUN * 86_400_000).toISOString());
    } catch (e) {
      if (tekilIhlaliMi(e)) throw kural('CONFLICT', 'Bekleyen bir silme talebiniz zaten var');
      throw e;
    }
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
      `INSERT INTO push_tokens (token, user_id, platform, created_at, last_seen, soy_id) VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id, platform = excluded.platform,
         last_seen = excluded.last_seen, soy_id = excluded.soy_id`,
      // 28 Eki: kayıt oturum SOYUNA bağlanır (tek cihaz kuralında o soy kapanınca silinir).
    ).run(t, ctx.kullanici.id, pl, z, z, ctx.kOturum.soy_id ?? ctx.kOturum.id);
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
      `SELECT d.slug, d.title, v.id version_id, v.version, v.sha256, v.effective_date, v.summary, v.pdf_ref,
              EXISTS (SELECT 1 FROM legal_acceptances o WHERE o.user_id = ? AND o.slug = d.slug) onceki
         FROM legal_documents d JOIN legal_versions v ON v.slug = d.slug AND v.status = 'PUBLISHED'
        WHERE d.active = TRUE AND d.requires_acceptance = TRUE
          AND NOT EXISTS (SELECT 1 FROM legal_acceptances a WHERE a.user_id = ? AND a.version_id = v.id)
        ORDER BY d.slug`,
    ).all(ctx.kullanici.id, ctx.kullanici.id)).map((x) => ({ slug: x.slug, title: x.title, version: String(x.version), sha256: x.sha256, effectiveDate: x.effective_date,
      // 22 Eki: kullanıcı bu belgenin HİÇBİR sürümünü onaylamadıysa true —
      // uygulama "güncellendi" yerine "onayınız gerekiyor" der.
      firstTime: !x.onceki,
      // 031: PDF'li sürüm — uygulama kısa özeti gösterir, isteyene PDF'in tamamını açar.
      ...(x.pdf_ref ? { summary: x.summary, pdfUrl: `/api/v1/legal/${x.slug}/pdf/${x.version}` } : {}) })),
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
    const neden = goruntulemeGerekcesi(ctx);
    const t = await db.prepare(`SELECT t.*, s.name saglayici_adi FROM teklif_talepleri t JOIN users s ON s.id = t.saglayici_id WHERE t.id = ?`).get(ctx.params.id);
    if (!t) throw hata.bulunamadi('Talep bulunamadı');
    await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'talep.messages.view', hedefTur: 'teklif_talebi', hedefId: t.id, gerekce: neden });
    return talepGorunumu(t, await db.prepare('SELECT * FROM teklif_mesajlari WHERE talep_id = ? ORDER BY created_at').all(t.id));
  });

  r.get('/admin/v1/chats/:offerId/messages', async (ctx) => {
    yetkiIste(ctx.admin, 'messages.read');
    const neden = goruntulemeGerekcesi(ctx);
    const o = await db.prepare('SELECT * FROM offers WHERE id = ?').get(ctx.params.offerId);
    if (!o) throw hata.bulunamadi('Sohbet bulunamadı');
    await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'chat.messages.view', hedefTur: 'offer', hedefId: o.id, gerekce: neden });
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

  // ── HESABINI SİLENLER VE DONDURANLAR (21 Eki, kullanıcı kararı) ──
  //
  // Özet ve Silme Kuyrukları'ndaki liste (tek kaynak). Yalnız şu an anlamlı
  // olanlar:
  //   · FROZEN           — hesap ŞU AN dondurulmuş (en son dondurma kaydı).
  //                        Kişi yeniden giriş yapıp hesabı etkinleştirince
  //                        (users.frozen_at = NULL) listeden kendiliğinden çıkar.
  //   · DELETION_PENDING — silme talebi, yasal süre dolmadı (kişi iptal
  //                        ederse CANCELLED olur ve listeden çıkar).
  //   · DELETED          — süre doldu, silindi. Kişisel veri (ad, telefon,
  //                        e-posta, adres…) zaten anonimleştirildi
  //                        (silmeTalepleriniIsle); kayıt yalnız hesabın
  //                        silindiğini ve tarihlerini gösterir — ad DÖNMEZ.
  // Tüm zamanlar: türe göre TOPLAM sayılar + sayfalı liste (state ile süzülür).
  const KAPATMA_DURUMU = `CASE WHEN r.type = 'FREEZE' THEN 'FROZEN' WHEN r.status = 'COMPLETED' THEN 'DELETED' ELSE 'DELETION_PENDING' END`;
  const KAPATMA_KOSULU = `((r.type = 'DELETION' AND r.status IN ('PENDING', 'COMPLETED'))
           OR (r.type = 'FREEZE' AND u.frozen_at IS NOT NULL AND u.deleted_at IS NULL
               AND NOT EXISTS (SELECT 1 FROM account_requests r2 WHERE r2.user_id = r.user_id AND r2.type = 'FREEZE' AND r2.created_at > r.created_at)))`;
  r.get('/admin/v1/account-closures', async (ctx) => {
    yetkiIste(ctx.admin, 'users.read');
    const sayac = { FROZEN: 0, DELETION_PENDING: 0, DELETED: 0 };
    for (const x of await db.prepare(
      `SELECT ${KAPATMA_DURUMU} durum, COUNT(*) n FROM account_requests r JOIN users u ON u.id = r.user_id WHERE ${KAPATMA_KOSULU} GROUP BY 1`,
    ).all()) sayac[x.durum] = Number(x.n);
    const durum = ctx.query.get('state');
    if (durum && !(durum in sayac)) throw hata.dogrulama('Geçersiz durum');
    const limit = Math.min(Math.max(Number(ctx.query.get('limit') ?? 100) || 100, 1), 500);
    const ofset = Math.min(Math.max(Number(ctx.query.get('offset') ?? 0) || 0, 0), 1_000_000);
    const satir = await db.prepare(
      `SELECT r.*, u.name, u.frozen_at, u.deleted_at
         FROM account_requests r JOIN users u ON u.id = r.user_id
        WHERE ${KAPATMA_KOSULU}${durum ? ` AND ${KAPATMA_DURUMU} = ?` : ''}
        ORDER BY r.created_at DESC, r.id DESC LIMIT ? OFFSET ?`,
    ).all(...(durum ? [durum] : []), limit, ofset);
    const items = satir.map((a) => {
      const d = a.type === 'FREEZE' ? 'FROZEN' : a.status === 'COMPLETED' ? 'DELETED' : 'DELETION_PENDING';
      return {
        id: a.id, userId: a.user_id, type: a.type, state: d,
        name: d === 'DELETED' ? null : a.name,
        reason: d === 'DELETED' ? null : (a.reason ?? null),
        requestedAt: a.created_at,
        frozenAt: d === 'FROZEN' ? a.frozen_at : null,
        scheduledFor: a.scheduled_for ?? null,
        deletedAt: d === 'DELETED' ? (a.completed_at ?? a.deleted_at) : null,
      };
    });
    return { counts: sayac, total: sayac.FROZEN + sayac.DELETION_PENDING + sayac.DELETED, items };
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
 *
 * ── ⚠ İLİŞKİLİ SİSTEMLERDEKİ KİŞİSEL VERİ (15 Eki güvenlik denetimi, karar 4) ──
 * Önceden yalnız hesap satırı, adres, profil, push jetonu ve destek talebi
 * temizleniyordu; kişinin yazdığı mesajlar, ilan açıklaması/konumu, teklif
 * notları, talepler, yorumlar, bildirimler ve oturum IP'leri kalıyordu.
 * Artık kişinin YAZDIĞI serbest metin ve dosya başvuruları kaldırılır.
 * Satırlar (kimlik numaraları, tarihler, yıldız puanı, durum) karşı tarafın
 * geçmişi ve sayaç bütünlüğü için kalır; kişiye bağlanamaz (kullanıcı satırı
 * anonim). KASITLI OLARAK SAKLANANLAR (yasal/güvenlik gerekçesi):
 *   · legal_acceptances — sözleşme/aydınlatma onayının ispatı
 *   · audit_log, user_status_history — yönetici işlemlerinin hesap
 *     verebilirliği (silinemez). İçlerindeki kişisel değerler maskelenir
 *     (denetim_anonimlestirme.js); işlem, zaman, yönetici, hedef kalır.
 *     Saklama süresi henüz belirlenmedi (işletmeci/hukuk kararı).
 *   · account_requests satırı — silme talebinin ne zaman alınıp
 *     uygulandığının kaydı (gerekçe metni silinir)
 * Karşı tarafın KENDİ yazdığı mesajlar onun verisidir, silinmez.
 */
export async function silmeTalepleriniIsle(db) {
  const z = simdi();
  const bekleyen = await db.prepare(
    `SELECT * FROM account_requests WHERE type = 'DELETION' AND status = 'PENDING' AND scheduled_for < ?`,
  ).all(z);
  for (const a of bekleyen) {
    await db.tx(async () => {
      // Firebase kimlik kaydı (telefon/e-posta kopyası) da silinir — uid
      // aşağıda NULL yapılmadan önce kuyruğa yazılır (bkz. firebase_silme.js).
      const fb = await db.prepare('SELECT firebase_uid, phone, name, email, created_at FROM users WHERE id = ?').get(a.user_id);
      // 29 Eki (5651): trafik kayıtları 365 gün kalır; yetkili merci
      // talebinde eşleştirilebilmeleri için kimlik, anonimleşmeden ÖNCE
      // ayrı yasal arşive (365 gün) alınır. Bkz. trafik_kaydi.js.
      await kimlikArsivle(db, { id: a.user_id, ad: fb?.name, telefon: fb?.phone, eposta: fb?.email, kayitTarihi: fb?.created_at }, z);
      await firebaseSilmeKuyrugunaEkle(db, fb?.firebase_uid);
      // Yönetici kayıtlarındaki kişisel değerler (ad/telefon/e-posta/metin)
      // kullanıcı satırı anonimleşmeden ÖNCE, bilinen değerlerle maskelenir.
      await yoneticiKayitlariniAnonimlestir(db, { id: a.user_id, ad: fb?.name, telefon: fb?.phone, eposta: fb?.email }, z);
      await kisiselIcerigiTemizle(db, a.user_id, fb?.phone, z);
      await db.prepare(
        // firebase_uid de SİLİNİR: kişiye bağlanabilen bir kimliktir ve
        // tekil dizinde (deleted_at'tan bağımsız) tutulduğu için kalırsa
        // aynı kişinin yeni kaydı çakışmayla (500) düşerdi.
        `UPDATE users SET name = 'Silinmiş Kullanıcı', phone = ?, email = NULL, password_hash = ?, firebase_uid = NULL, photo_customer_ref = NULL, photo_provider_ref = NULL, frozen_at = NULL, pending_email = NULL, pending_email_at = NULL,
                          phone_verified = FALSE, email_verified = FALSE, maintenance_bypass = FALSE, deleted_at = ?, updated_at = ? WHERE id = ?`,
      ).run(`silindi-${a.user_id}`, `silindi$${randomUUID()}`, z, z, a.user_id);
      await db.prepare('DELETE FROM addresses WHERE user_id = ?').run(a.user_id);
      await db.prepare('DELETE FROM provider_profiles WHERE user_id = ?').run(a.user_id);
      await db.prepare('DELETE FROM push_tokens WHERE user_id = ?').run(a.user_id);
      // Destek talepleri yalnız kişi ile destek ekibi arasındadır ve serbest
      // metin kişisel veri içerir: konu/mesaj anonimleştirilir, açık
      // talepler kapanır. Kayıt (numara, tarih, admin yanıtları) denetim
      // için kalır.
      await db.prepare(
        `UPDATE support_tickets SET subject = 'Silinmiş hesap', message = '[Hesap silindiği için içerik kaldırıldı]',
                                    sender_email = NULL, sender_name = NULL,
                                    status = 'CLOSED', closed_at = COALESCE(closed_at, ?), updated_at = ? WHERE user_id = ?`,
      ).run(z, z, a.user_id);
      // ⚠ E2 (KVKK takip denetimi, 22 Eki): e-postayla açılan talepte
      // gönderen adresi/adı da kişisel veridir; yukarıda NULL yapılır.
      // Yalnız bu hesaba BAĞLI (user_id) talepler; hesaba bağlanmamış
      // e-posta talepleri başka bir kişiye ait olabileceği için dokunulmaz.
      // ⚠ B12: bakım test hesabı işareti ve tanınmış cihaz kayıtları
      // (cihaz kimliği özeti, platform, zamanlar) hesapla birlikte silinir.
      await db.prepare('DELETE FROM maintenance_devices WHERE user_id = ?').run(a.user_id);
      // Hesabın bütün kullanıcı dosyaları fiziksel silme kuyruğuna.
      await hesapDosyalariniIsaretle(db, a.user_id);
      await oturumlariIptal(db, a.user_id, 'DELETED');
      // Oturum satırları IP ve cihaz bilgisi taşır: iptalden sonra silinir.
      await db.prepare('DELETE FROM user_sessions WHERE user_id = ?').run(a.user_id);
      await db.prepare(`UPDATE account_requests SET status = 'COMPLETED', completed_at = ? WHERE id = ?`).run(z, a.id);
    });
  }
  return bekleyen.length;
}

const KALDIRILDI = '[Hesap silindiği için içerik kaldırıldı]';

/**
 * Silinen hesabın ilişkili tablolardaki kişisel içeriği (bkz.
 * silmeTalepleriniIsle). Aynı işlem (tx) içinde çağrılır.
 */
async function kisiselIcerigiTemizle(db, id, eskiTelefon, z) {
  const c = (sql, ...p) => db.prepare(sql).run(...p);
  // İlan mesajları ve talep mesajları: kişinin yazdığı metin ve ek dosya.
  await c('UPDATE messages SET text = ?, storage_ref = NULL WHERE sender_id = ?', KALDIRILDI, id);
  await c('UPDATE teklif_mesajlari SET metin = ?, fotograf_ref = NULL WHERE gonderen_id = ?', KALDIRILDI, id);
  // 29 Eki: şikâyet açıklaması kişinin yazdığı metindir (kayıt kalır).
  await c('UPDATE reports SET note = NULL WHERE reporter_id = ?', id);
  // İlanlar: açıklama, konum ve fotoğraflar kaldırılır; açık ilan kapanır.
  await c(
    `UPDATE listings SET description = ?, location = '-', photo_refs_json = '[]',
            status = CASE WHEN status = 'ACTIVE' THEN 'USER_DELETED' ELSE status END,
            delete_reason = CASE WHEN status = 'ACTIVE' THEN 'ACCOUNT_DELETED' ELSE delete_reason END,
            updated_at = ? WHERE owner_id = ?`, KALDIRILDI, z, id);
  // Teklifler: not kaldırılır; açık teklif kapanır.
  await c(`UPDATE offers SET note = ?, status = CASE WHEN status = 'ACTIVE' THEN 'CLOSED' ELSE status END, updated_at = ? WHERE provider_id = ?`, KALDIRILDI, z, id);
  // Teklif talepleri (iki taraf da olabilir): kişinin yazdığı alanlar
  // kaldırılır; mesajlaşma kapanır (silindi_at).
  await c(`UPDATE teklif_talepleri SET aciklama = ?, fotograflar_json = '[]', silindi_at = COALESCE(silindi_at, ?), updated_at = ? WHERE hizmet_alan_id = ?`, KALDIRILDI, z, z, id);
  await c('UPDATE teklif_talepleri SET teklif_aciklamasi = ? WHERE saglayici_id = ? AND teklif_aciklamasi IS NOT NULL', KALDIRILDI, id);
  await c('UPDATE teklif_talepleri SET silindi_at = COALESCE(silindi_at, ?), updated_at = ? WHERE saglayici_id = ?', z, z, id);
  await c('UPDATE teklif_talepleri SET red_gerekcesi = NULL WHERE reddeden_id = ?', id);
  // Yorumlar: kişinin yazdığı metin kaldırılır (yıldız, hizmet verenin puan
  // bütünlüğü için anonim kalır); silinen hizmet veren HAKKINDAKİ yorumlar
  // da yayından kalkar.
  await c('UPDATE reviews SET text = ? WHERE author_id = ?', KALDIRILDI, id);
  await c(`UPDATE reviews SET text = ?, status = 'ADMIN_DELETED', removed_reason = COALESCE(removed_reason, 'ACCOUNT_DELETED'), removed_at = COALESCE(removed_at, ?) WHERE provider_id = ?`, KALDIRILDI, z, id);
  // Bildirimler, uygulama geri bildirimi, OTP kayıtları: tümüyle silinir.
  await c('DELETE FROM notifications WHERE user_id = ?', id);
  await c('DELETE FROM app_feedback WHERE user_id = ?', id);
  if (eskiTelefon) await c('DELETE FROM otp_codes WHERE phone = ?', eskiTelefon);
  // Destek yanıtları (kişiye yazılmış, adını içerebilir) ve giden ileti
  // kayıtları (telefon/e-posta adresi ve içerik).
  await c(`UPDATE support_ticket_replies SET body = ? WHERE ticket_id IN (SELECT id FROM support_tickets WHERE user_id = ?)`, KALDIRILDI, id);
  await c(`UPDATE outbound_messages SET target = '-', subject = NULL, body = ? WHERE user_id = ?`, KALDIRILDI, id);
  // Hesap taleplerinin serbest metin gerekçesi.
  await c('UPDATE account_requests SET reason = NULL WHERE user_id = ?', id);
}
