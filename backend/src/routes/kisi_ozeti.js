// ═══════════════════════════════════════════════════════════════
// KARŞI TARAF ÖZETİ — GET /api/v1/users/:id/summary
//
// Sorun (15 Eki): API modunda istemci başka kullanıcıların adını, konumunu,
// fotoğrafını, tamamlanan iş sayısını ve telefonunu hiçbir uçtan alamıyordu;
// teklif talebi, ilan, teklif, sohbet ve yorum ekranları "Hizmet Alan",
// "Belirtilmemiş", "—" gösteriyordu.
//
// ⚠ YETKİ: özet YALNIZ İLİŞKİSİ OLAN kullanıcıya döner; aksi hâlde 404
// (kullanıcının var olup olmadığı da sızdırılmaz). İlişkiler ve gösterilen
// alanlar istemcideki MEVCUT kurallarla aynıdır (kurallar gevşetilmedi):
//
//   · İLAN–TEKLİF (iki taraf): ad tam yalnız iletişim açıldıysa (contacts
//     kaydı); telefon da yalnız o zaman. Hizmet verenin adı müşteriye her
//     zaman tam görünür (ilan detayında zaten öyle).
//   · AÇIK İLAN AKIŞI: hizmet veren, teklif alabilen açık ilanın sahibini
//     maskeli ad + konumla görür (telefon yok).
//   · TEKLİF TALEBİ: hizmet alanın adı teklif verilince açılır; telefon
//     yalnız iletişim açıkken (teklif verilmiş ve süresi dolmamış) VE
//     hizmet alan "telefonumu göster" seçtiyse. Hizmet verenin telefonu
//     hizmet alana iletişim açıkken görünür (`talepIletisimAcikMi`).
//   · HİZMET VEREN (Bul): etkin her hizmet veren, oturum açmış herkese ad,
//     il/ilçe, fotoğraf ve iş sayısıyla görünür (/providers/search ile aynı:
//     telefon ve mahalle YOK).
//   · YORUM YAZARI: yayımlanmış yorumun yazarı kısa adla ("Ad S.") görünür.
//
// Ad biçimleri: TAM > KISA ("Ad S.") > MASKELİ ("A** S****"). İlişkilerden
// en açık olanı uygulanır; istemcinin kendi maskelemesi bu biçimlerde
// değişmeden kalır (maskeli/kısa ad yeniden maskelenince aynı çıkar).
// ═══════════════════════════════════════════════════════════════
import { simdi } from '../db.js';
import { imzaliGorselAdresi } from '../depo_dogrulama.js';
import { depolamaAyari } from '../entegrasyon.js';
import { HizSiniri, hata } from '../http.js';
import { kullaniciCoz } from './kullanici.js';
import { talepSureleriniIsle } from './sohbet_talep.js';

const ozetSiniri = new HizSiniri('kisi_ozeti', 1200, 15 * 60 * 1000);

const AD_MASKELI = 0;
const AD_KISA = 1;
const AD_TAM = 2;

/** "Gönül Bütün" → "G**** B****" (istemci `maskeliAd` ile aynı). */
export function maskeliAd(ad) {
  const p = String(ad ?? '').trim().split(/\s+/).filter(Boolean);
  if (!p.length) return 'K*** K******';
  return p.map((k) => { const h = [...k]; return h[0] + '*'.repeat(h.length - 1); }).join(' ');
}

/** "Gönül Bütün" → "Gönül B." (istemci `kisaYazarAdi` ile aynı). */
export function kisaAd(ad) {
  const p = String(ad ?? '').trim().split(/\s+/).filter(Boolean);
  if (!p.length) return '';
  if (p.length === 1) return p[0];
  const soyad = p.pop();
  return `${p.join(' ')} ${[...soyad][0]}.`;
}

/**
 * İsteyen (u) ile hedef (x) arasındaki ilişkiler → görünürlük.
 * Dönüş null ise ilişki yok (404).
 */
/**
 * Hizmet verenin TAMAMLADIĞI İŞ SAYISI — TEK KAYNAK (kişi özeti ve
 * "Müşteri Yorumları" aynı sayıyı gösterir): seçilen teklifler +
 * tamamlanan teklif talepleri.
 */
export async function saglayiciTamamlananIs(db, id) {
  return (await db.prepare(`SELECT COUNT(*) n FROM offers WHERE status = 'SELECTED' AND provider_id = ?`).get(id)).n
    + (await db.prepare(`SELECT COUNT(*) n FROM teklif_talepleri WHERE durum = 'TAMAMLANDI' AND saglayici_id = ?`).get(id)).n;
}

async function gorunurluk(db, u, x) {
  let ad = -1;
  let musteri = false; // x, u'ya HİZMET ALAN olarak görünüyor
  let saglayici = false; // x, u'ya HİZMET VEREN olarak görünüyor
  let mahalle = false;
  let telefon = false;
  const yukselt = (d) => { if (d > ad) ad = d; };

  // 1) İlan–teklif: u hizmet veren, x ilan sahibi.
  for (const r of await db.prepare(
    `SELECT c.offer_id acik FROM offers o JOIN listings l ON l.id = o.listing_id
       LEFT JOIN contacts c ON c.offer_id = o.id
      WHERE o.provider_id = ? AND l.owner_id = ?`,
  ).all(u.id, x.id)) {
    musteri = true;
    mahalle = true;
    yukselt(r.acik ? AD_TAM : AD_MASKELI);
    if (r.acik) telefon = true;
  }
  // 2) İlan–teklif: u ilan sahibi, x hizmet veren.
  for (const r of await db.prepare(
    `SELECT c.offer_id acik FROM offers o JOIN listings l ON l.id = o.listing_id
       LEFT JOIN contacts c ON c.offer_id = o.id
      WHERE o.provider_id = ? AND l.owner_id = ?`,
  ).all(x.id, u.id)) {
    saglayici = true;
    yukselt(AD_TAM);
    if (r.acik) telefon = true;
  }
  // 3) Açık ilan akışı: u hizmet veren, x'in teklif alabilen ilanı var.
  if (u.roles.split(',').includes('PROVIDER') && await db.prepare(
    `SELECT 1 FROM listings WHERE owner_id = ? AND status = 'ACTIVE' AND selected_offer_id IS NULL AND expires_at > ?`,
  ).get(x.id, simdi())) {
    musteri = true;
    mahalle = true;
    yukselt(AD_MASKELI);
  }
  // 4) Teklif talebi (iletişim kuralı istemcideki `talepIletisimAcikMi` ile aynı).
  await talepSureleriniIsle(db);
  for (const t of await db.prepare(
    `SELECT hizmet_alan_id, saglayici_id, teklif_tarihi, durum, iletisim_tercihi, silindi_at FROM teklif_talepleri
      WHERE (hizmet_alan_id = ? AND saglayici_id = ?) OR (hizmet_alan_id = ? AND saglayici_id = ?)`,
  ).all(x.id, u.id, u.id, x.id)) {
    const iletisim = t.teklif_tarihi != null && t.durum !== 'SURESI_DOLDU' && !t.silindi_at;
    if (t.hizmet_alan_id === x.id) {
      musteri = true;
      mahalle = true;
      yukselt(t.teklif_tarihi != null ? AD_TAM : AD_MASKELI);
      if (iletisim && t.iletisim_tercihi === 'telefonGoster') telefon = true;
    } else {
      saglayici = true;
      yukselt(AD_TAM);
      if (iletisim) telefon = true;
    }
  }
  // 5) Etkin hizmet veren: herkese açık profil (Bul ile aynı alanlar).
  if (x.roles.split(',').includes('PROVIDER') && x.status === 'ACTIVE' && !x.frozen_at) {
    saglayici = true;
    yukselt(AD_TAM);
  }
  // 6) Yayımlanmış yorum yazarı: kısa ad.
  if (await db.prepare(`SELECT 1 FROM reviews WHERE author_id = ? AND status = 'PUBLISHED'`).get(x.id)) {
    musteri = true;
    yukselt(AD_KISA);
  }
  if (ad < 0) return null;
  return { ad, musteri, saglayici, mahalle, telefon };
}

export function kisiOzetiRotalar(r, db) {
  r.get('/api/v1/users/:id/summary', async (ctx) => {
    const { u } = await kullaniciCoz(db, ctx.req);
    await ozetSiniri.denetle(db, u.id);
    const id = String(ctx.params.id ?? '');
    if (id === u.id) throw hata.bulunamadi('Kullanıcı bulunamadı'); // kendi bilgisi /users/me'de
    const x = /^[0-9a-f-]{36}$/i.test(id)
      ? await db.prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').get(id)
      : null;
    if (!x) throw hata.bulunamadi('Kullanıcı bulunamadı');
    const g = await gorunurluk(db, u, x);
    if (!g) throw hata.bulunamadi('Kullanıcı bulunamadı');

    const adres = await db.prepare('SELECT city, district, neighborhood FROM addresses WHERE user_id = ?').get(x.id);
    const ayar = await depolamaAyari(db);
    const isSaglayici = g.saglayici ? await saglayiciTamamlananIs(db, x.id) : 0;
    const isMusteri = g.musteri
      ? ((await db.prepare(`SELECT COUNT(*) n FROM listings WHERE owner_id = ? AND selected_offer_id IS NOT NULL`).get(x.id)).n
        + (await db.prepare(`SELECT COUNT(*) n FROM teklif_talepleri WHERE durum = 'TAMAMLANDI' AND hizmet_alan_id = ?`).get(x.id)).n)
      : 0;
    return {
      id: x.id,
      name: g.ad === AD_TAM ? x.name : g.ad === AD_KISA ? kisaAd(x.name) : maskeliAd(x.name),
      nameMasked: g.ad !== AD_TAM,
      createdAt: x.created_at,
      address: adres ? { city: adres.city, district: adres.district, neighborhood: g.mahalle ? adres.neighborhood : '' } : null,
      photos: {
        customer: g.musteri ? await imzaliGorselAdresi(db, x.photo_customer_ref, ayar) : null,
        provider: g.saglayici ? await imzaliGorselAdresi(db, x.photo_provider_ref, ayar) : null,
      },
      completedJobsAsProvider: isSaglayici,
      completedJobsAsCustomer: isMusteri,
      phone: g.telefon ? x.phone : null,
    };
  });
}
