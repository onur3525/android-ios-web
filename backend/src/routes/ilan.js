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
import { yenidenDogrulamaIste, yetkiIste, yetkiliMi } from '../auth.js';
import { denetimYaz } from '../audit.js';
import { kullaniciyaBildir } from '../bildirim.js';
import { simdi, tekilIhlaliMi } from '../db.js';
import { dosyalariDogrula, imzaliGorselAdresi } from '../depo_dogrulama.js';
import { depolamaAyari } from '../entegrasyon.js';
import { govdeOzeti, idemAnahtari, idemOlustur, oncekiKayit } from '../idempotency.js';
import { ApiHatasi, HizSiniri, hata } from '../http.js';

// Kötüye kullanım sınırları (kullanıcı başına; çok örnekte ORTAK — DB'de tutulur).
// Gerçek kullanımın çok üstünde seçildi: yalnız otomatik/sel saldırısını keser.
const ilanSiniri = new HizSiniri('ilan_olustur', 30, 60 * 60 * 1000);
const teklifSiniri = new HizSiniri('teklif_ver', 120, 60 * 60 * 1000);
// Hizmet veren dizini toplu kazınmasın diye (kullanıcı başına).
const saglayiciAramaSiniri = new HizSiniri('saglayici_ara', 60, 60 * 1000);
import { kullaniciCoz } from './kullanici.js';
import { kisaAd } from './kisi_ozeti.js';
import { silinmekUzereIsaretle } from '../dosya_temizligi.js';
import { fcmEtkin, pushKuyrugunuIsle } from '../fcm.js';
import { dosyalariBagla } from './depolama_entegrasyon.js';
import { silmeKuyruguSorunlari } from './silme_kuyruklari.js';
import { apiOlcumleri, genelDurum, kaynakKullanimi, olcumleriYaz, sonSunucuHatalari, yedekDurumu, yoneticiGuvenlikOlaylari } from '../sistem_izleme.js';

export const ILAN_OMRU_MS = 30 * 60 * 60 * 1000;
const kural = (kod, mesaj) => new ApiHatasi(409, kod, mesaj);

/**
 * Sayfa → o sayfa açılınca okunmuş sayılan bildirim türleri (TEK KAYNAK).
 * Her tür, bildirime dokununca açılan sayfayla aynıdır
 * (lib/screens/notifications_screen.dart → hedefeGit):
 *   ilan         hizmet alanın ilan sayfası (ref = ilan)
 *   is           hizmet verenin iş sayfası (ref = ilan)
 *   sohbet       ilan sohbeti (ref = teklif)
 *   talep        doğrudan teklif talebi detayı (ref = talep)
 *   talep-sohbet teklif talebi sohbeti (ref = talep)
 */
export const SAYFA_BILDIRIMLERI = Object.freeze({
  ilan: { turler: ['NEW_OFFER', 'LISTING_EXPIRED'], teklifUzerinden: ['CONTACT_OPENED'] },
  is: { turler: ['NEW_LISTING', 'OFFER_SELECTED'], teklifUzerinden: ['CONTACT_OPENED'] },
  sohbet: { turler: ['NEW_MESSAGE'] },
  talep: { turler: ['TALEP_REQUEST', 'TALEP_OFFER', 'TALEP_ACCEPTED', 'TALEP_DECLINED'] },
  'talep-sohbet': { turler: ['TALEP_MESSAGE'] },
});
/** Sağlayıcı yanıtındaki olası alıcıyı (e-posta / telefon) gizler. */
const yanitMaskele = (t) => t.replace(/[^\s"'<>@]+@[^\s"'<>]+/g, '***@***').replace(/\+?\d[\d\s-]{6,}\d/g, '***');
const UUID_DESENI = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// ── Görünümler (Flutter mappers.dart ile birebir alan adları) ──
export const ilanGorunumu = (l) => ({
  id: l.id, ilanNo: l.ilan_no, ownerId: l.owner_id, title: l.title, location: l.location,
  description: l.description, status: l.status, photoPaths: JSON.parse(l.photo_refs_json),
  workTiming: l.work_timing, createdAt: l.created_at, expiresAt: l.expires_at,
  selectedOfferId: l.selected_offer_id,
  // 16 Eki: ilan sahibinin iletişim tercihi (telefonGoster | yalnizMesaj).
  iletisimTercihi: l.iletisim_tercihi ?? 'telefonGoster',
});
export const teklifGorunumu = (o) => ({
  id: o.id, listingId: o.listing_id, providerId: o.provider_id, amountTl: o.amount_tl,
  note: o.note, status: o.status, createdAt: o.created_at,
});
/** İlanların teklifleri (ilan kimliği → teklif görünümleri); YALNIZ ilan sahibine verilir. */
async function ilanTeklifleri(db, ilanIdleri) {
  const m = new Map();
  if (!ilanIdleri.length) return m;
  for (let i = 0; i < ilanIdleri.length; i += 500) {
    const parca = ilanIdleri.slice(i, i + 500);
    for (const o of await db.prepare(
      `SELECT * FROM offers WHERE listing_id IN (${parca.map(() => '?').join(', ')}) ORDER BY created_at`,
    ).all(...parca)) {
      if (!m.has(o.listing_id)) m.set(o.listing_id, []);
      m.get(o.listing_id).push(teklifGorunumu(o));
    }
  }
  return m;
}

const yorumGorunumu = (y) => ({
  id: y.id, listingId: y.listing_id ?? '', offerId: y.offer_id ?? '', talepId: y.talep_id,
  providerId: y.provider_id, authorId: y.author_id, stars: y.stars, text: y.text,
  status: y.status, createdAt: y.created_at, publishedAt: y.published_at,
});

/** Uygulama içi bildirim (Bildirimler sekmesi). */
/**
 * `tur`: ilan akışı NEW_OFFER · OFFER_SELECTED · CONTACT_OPENED · NEW_MESSAGE ·
 * LISTING_EXPIRED · ANNOUNCEMENT; Bul (teklif talebi) akışı AYRI kodlarla:
 * TALEP_REQUEST (hizmet verene talep) · TALEP_OFFER (hizmet alana teklif) ·
 * TALEP_ACCEPTED (hizmet verene kabul) · TALEP_DECLINED (hizmet alana: hizmet veren reddetti) · TALEP_MESSAGE. ⚠ Eskiden talep
 * bildirimleri ilan kodlarıyla (NEW_OFFER…) yazılıyordu; istemci onları
 * İLAN bildirimi sanıp talep kimliğiyle ilan ekranını açıyordu.
 * `pushHedef`: telefona giden bildirimin açacağı ekran (Flutter
 * `kPushHedefleri`: ilan/is/teklif/talep/mesaj). Verilmezse Bildirimler açılır.
 * Push gönderimi ayrı yürür (fcm.js); hatası bu işlemi etkilemez.
 */
export async function uygulamaIciBildir(db, kullaniciId, tur, baslik, govde, refId, pushHedef = null) {
  await db.prepare(
    `INSERT INTO notifications (id, user_id, type, title, body, ref_id, push_target, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(randomUUID(), kullaniciId, tur, baslik, govde, refId ?? null, pushHedef, simdi());
  // Push işi isteğin işlemi COMMIT edildikten SONRA ve işlem bağlamının
  // DIŞINDA tetiklenir (bkz. db.commitSonrasi). Böylece yeni satır görünür
  // olur ve iş isteğin bağlantısını kullanmaz.
  if (fcmEtkin()) db.commitSonrasi(() => { pushKuyrugunuIsle(db, { sureMs: 5_000 }).catch(() => {}); });
}

// ── ⚠ YENİ İLAN → EŞLEŞEN HİZMET VERENLERE BİLDİRİM (15 Eki, kullanıcı isteği) ──
//
// Önceden yeni ilan için hiçbir bildirim üretilmiyordu; hizmet veren ilanı
// ancak listeyi kendisi yenileyince görüyordu. Eşleşme kuralı istemcinin
// "doğrudan" eşleşmesiyle (`eslestirme.dart` dogrudanEslesir) AYNI:
//   · seçim = ilan başlığı, ya da ikisi aynı ana kategoride ve biri ana
//     kategorinin kendisi (kategori seçen o kategorinin hizmet ilanlarını,
//     hizmet seçen kategori başlıklı ilanları alır);
//   · hizmet bölgesi seçilmemişse ya da ilçelerinden biri konumda geçiyorsa.
// Kategori seçimi yapılmamış (kurulumu bitmemiş) hizmet verene gönderilmez.
// İlan sahibi, askıdaki/banlı/dondurulmuş/silinmiş hesaplar hariç. Push
// tercihi "Yeni teklifler" anahtarına bağlıdır (fcm.js pushIzniVar).
const YENI_ILAN_AZAMI_ALICI = 1000;
export async function yeniIlaniBildir(db, l) {
  const katalog = await db.prepare(
    `SELECT s.name hizmet, c.name kategori FROM services s JOIN categories c ON c.id = s.category_id
      WHERE s.deleted_at IS NULL AND c.deleted_at IS NULL`,
  ).all();
  const kategoriler = new Set((await db.prepare('SELECT name FROM categories WHERE deleted_at IS NULL').all()).map((k) => k.name));
  const hizmetKategorisi = new Map(katalog.map((r) => [r.hizmet, r.kategori]));
  const ana = (ad) => (kategoriler.has(ad) ? ad : hizmetKategorisi.get(ad) ?? ad);
  const eslesir = (secim) => secim === l.title
    || (ana(secim) === ana(l.title) && (kategoriler.has(secim) || kategoriler.has(l.title)));
  const adaylar = await db.prepare(
    `SELECT u.id, p.categories_json, p.districts_json FROM users u JOIN provider_profiles p ON p.user_id = u.id
      WHERE u.roles LIKE '%PROVIDER%' AND u.status = 'ACTIVE' AND u.deleted_at IS NULL AND u.frozen_at IS NULL AND u.id <> ?`,
  ).all(l.owner_id);
  const liste = (v) => { try { const x = JSON.parse(v); return Array.isArray(x) ? x.filter((y) => typeof y === 'string') : []; } catch { return []; } };
  let n = 0;
  for (const a of adaylar) {
    if (n >= YENI_ILAN_AZAMI_ALICI) break;
    const kat = liste(a.categories_json);
    if (!kat.length || !kat.some(eslesir)) continue;
    const ilceler = liste(a.districts_json);
    if (ilceler.length && !ilceler.some((d) => d && l.location.includes(d))) continue;
    // 16 Eki (kullanıcı isteği): bildirim metni örnekteki gibi; ADRES
    // BİLGİSİ bildirimde PAYLAŞILMAZ (kilit ekranında da görünür).
    await uygulamaIciBildir(db, a.id, 'NEW_LISTING', 'Yeni bir hizmet talebi var!', `"${l.title}" için yeni bir ilan yayınlandı. Hemen göz at!`, l.id, 'is');
    n++;
  }
  return n;
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
        await uygulamaIciBildir(db, l.owner_id, 'LISTING_EXPIRED', 'İlanınızın süresi doldu', `"${l.title}" ilanınızın yayın süresi sona erdi.`, l.id, 'ilan');
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
    // 16 Eki: "numaramı gizle" seçimi — yoksa telefon görünür (önceki davranış).
    const tercih = ctx.body.iletisimTercihi ?? 'telefonGoster';
    // Idempotency: aynı anahtarla yeniden deneme ilk ilanı döndürür (sınır harcanmaz).
    const ILAN_IDEM = { tablo: 'listings', sahipSutun: 'owner_id' };
    const anahtar = idemAnahtari(ctx);
    const ozet = govdeOzeti({ baslik, konum, aciklama, foto, zaman, tercih });
    const onceki = await oncekiKayit(db, ILAN_IDEM, ctx.kullanici.id, anahtar, ozet);
    if (onceki) return ilanGorunumu(onceki);
    await ilanSiniri.denetle(db, ctx.kullanici.id);
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
    if (!['telefonGoster', 'yalnizMesaj'].includes(tercih)) throw hata.dogrulama('Geçersiz iletişim tercihi');
    // Dosyalar İŞLEM DIŞINDA doğrulanır (depo okuması uzun işlem açmasın).
    await dosyalariDogrula(db, foto, ctx.kullanici.id, 'listing-photo');
    const id = randomUUID();
    const z = new Date();
    const { kayit, yeni: yeniIlan } = await idemOlustur(db, ILAN_IDEM, ctx.kullanici.id, anahtar, ozet, () => db.tx(async () => {
      await dosyalariBagla(db, foto, ctx.kullanici.id);
      const no = await db.prepare(`UPDATE counters SET value = value + 1 WHERE name = 'ilan_no' RETURNING value`).get();
      await db.prepare(
        `INSERT INTO listings (id, ilan_no, owner_id, title, location, description, photo_refs_json, work_timing,
                               status, expiry_notified, created_at, expires_at, updated_at, idempotency_key, idem_hash, iletisim_tercihi)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVE', FALSE, ?, ?, ?, ?, ?, ?)`,
      ).run(id, String(no.value), ctx.kullanici.id, baslik, konum, aciklama, JSON.stringify(foto), zaman,
        z.toISOString(), new Date(z.getTime() + ILAN_OMRU_MS).toISOString(), z.toISOString(), anahtar, anahtar ? ozet : null, tercih);
      return db.prepare('SELECT * FROM listings WHERE id = ?').get(id);
    }));
    // Eşleşen hizmet verenlere bildirim (uygulama içi + push; uygulama
    // kapalıyken de telefona düşer). Hatası ilanı geri almaz.
    if (yeniIlan) await yeniIlaniBildir(db, kayit).catch((e) => console.error('yeni_ilan_bildirimi', e?.message));
    return ilanGorunumu(kayit);
  }));

  r.get('/api/v1/listings/my', korumali(async (ctx) => {
    await suresiDolanlariIsle(db);
    const ilanlar = await db.prepare(`SELECT * FROM listings WHERE owner_id = ? ORDER BY created_at DESC`).all(ctx.kullanici.id);
    // İlanlarım listesindeki teklif sayıları ve rozetler için (tek sorgu).
    const teklifler = await ilanTeklifleri(db, ilanlar.map((l) => l.id));
    return ilanlar.map((l) => ({ ...ilanGorunumu(l), offers: teklifler.get(l.id) ?? [] }));
  }));

  r.get('/api/v1/listings/available', korumali(async (ctx) => {
    rolIste(ctx.kullanici, 'PROVIDER', 'Bu liste hizmet veren rolüne aittir');
    await suresiDolanlariIsle(db);
    const kosul = [`status = 'ACTIVE'`, 'selected_offer_id IS NULL', 'expires_at > ?', 'owner_id <> ?'];
    const p = [simdi(), ctx.kullanici.id];
    const kat = ctx.query.get('category');
    const ilce = ctx.query.get('district');
    if (kat) { kosul.push('title = ?'); p.push(kat); }
    if (ilce) { kosul.push(`location LIKE ? ESCAPE '!'`); p.push(`%${String(ilce).replace(/[!%_]/g, (c) => `!${c}`)}%`); }
    // Sıralama/öncelik (kendi kategorisi önce, aile sonra) istemcide
    // `eslestirme.dart` ile yapılır.
    //
    // ⚠ KESME SORUNU GİDERİLDİ: önceden yalnız EN YENİ 500 açık ilan
    // dönüyordu; açık ilan 500'ü aşınca hizmet verenin KENDİ hizmetindeki
    // ilanlar listeye hiç girmeyebiliyordu. Artık önce hizmet verenin
    // doğrudan eşleşen ilanları (kendi seçtiği kategori/hizmetler, bu
    // kategorilerin hizmetleri ve seçtiği hizmetlerin kategorisi — Flutter
    // `dogrudanEslesir` ile aynı kural) en çok 2000, ardından geri kalan en
    // yeni ilanlar en çok 500 döner. Yanıt biçimi AYNI (tek dizi).
    const prof = await db.prepare('SELECT categories_json FROM provider_profiles WHERE user_id = ?').get(ctx.kullanici.id);
    let secilen = [];
    try { secilen = prof ? JSON.parse(prof.categories_json) : []; } catch { secilen = []; }
    secilen = Array.isArray(secilen) ? secilen.filter((x) => typeof x === 'string').slice(0, 200) : [];
    let eslesen = [];
    if (secilen.length) {
      const yerS = secilen.map(() => '?').join(', ');
      const adlar = new Set(secilen);
      for (const r of await db.prepare(
        `SELECT s.name hizmet, c.name kategori FROM services s JOIN categories c ON c.id = s.category_id
          WHERE s.deleted_at IS NULL AND (c.name IN (${yerS}) OR s.name IN (${yerS}))`,
      ).all(...secilen, ...secilen)) {
        if (adlar.has(r.kategori)) adlar.add(r.hizmet); // kategorisini seçmiş → bütün hizmetleri
        if (adlar.has(r.hizmet)) adlar.add(r.kategori); // hizmetini seçmiş → kategori başlıklı ilan
      }
      const liste = [...adlar];
      eslesen = await db.prepare(
        `SELECT * FROM listings WHERE ${kosul.join(' AND ')} AND title IN (${liste.map(() => '?').join(', ')})
          ORDER BY created_at DESC LIMIT 2000`,
      ).all(...p, ...liste);
    }
    const goruldu = new Set(eslesen.map((l) => l.id));
    const diger = (await db.prepare(`SELECT * FROM listings WHERE ${kosul.join(' AND ')} ORDER BY created_at DESC LIMIT 500`).all(...p))
      .filter((l) => !goruldu.has(l.id));
    return [...eslesen, ...diger].map(ilanGorunumu);
  }));

  r.get('/api/v1/listings/:id', korumali(async (ctx) => {
    const l = await ilanGetir(ctx.params.id);
    const u = ctx.kullanici;
    // ⚠ İLAN SAHİBİ TEKLİFLERİ DE ALIR (15 Eki): istemci teklifleri ilan
    // detayından okur (`lastDetailOffers`), ama sunucu göndermiyordu; API
    // modunda hizmet alan gelen teklifleri hiç göremiyordu (web ve mobil).
    if (l.owner_id === u.id) return { ...ilanGorunumu(l), offers: await ilanTeklifleri(db, [l.id]).then((m) => m.get(l.id) ?? []) };
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
    // ⚠ 16 Eki (kullanıcı kuralı): teklifi seçilmiş ilan SİLİNMEZ — iş
    // tamamlanmıştır; hizmet verenin kazandığı iş, yorum ve geçmiş ona bağlı.
    if (l.selected_offer_id) throw kural('INVALID_STATE', 'Teklif seçilen ilan silinemez');
    const neden = ctx.body.reason ? String(ctx.body.reason).trim().slice(0, 500) : null;
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`UPDATE listings SET status = 'USER_DELETED', delete_reason = ?, updated_at = ? WHERE id = ?`).run(neden, z, l.id);
      await db.prepare(`UPDATE offers SET status = 'CLOSED', updated_at = ? WHERE listing_id = ? AND status = 'ACTIVE'`).run(z, l.id);
      // İlanın fotoğrafları fiziksel silme kuyruğuna (yalnız ilan sahibinin dosyaları;
      // başka canlı kayıtta kullanılıyorsa iş silmeden geri alır).
      await silinmekUzereIsaretle(db, JSON.parse(l.photo_refs_json || '[]'), l.owner_id);
    });
    return undefined;
  }));

  // ── TEKLİF ──
  r.post('/api/v1/offers', korumali(async (ctx) => {
    rolIste(ctx.kullanici, 'PROVIDER', 'Teklifi yalnız hizmet veren rolüyle verebilirsiniz');
    const TEKLIF_IDEM = { tablo: 'offers', sahipSutun: 'provider_id' };
    const anahtar = idemAnahtari(ctx);
    const teklifOzeti = govdeOzeti({ listingId: String(ctx.body.listingId ?? ''), amountTl: ctx.body.amountTl, note: String(ctx.body.note ?? '').trim() });
    const once = await oncekiKayit(db, TEKLIF_IDEM, ctx.kullanici.id, anahtar, teklifOzeti);
    if (once) return teklifGorunumu(once);
    await teklifSiniri.denetle(db, ctx.kullanici.id); // idempotent tekrar sayılmaz
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
    try {
      await db.tx(async () => {
        await db.prepare(
          `INSERT INTO offers (id, listing_id, provider_id, amount_tl, note, status, idempotency_key, idem_hash, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, 'ACTIVE', ?, ?, ?, ?)`,
        ).run(id, l.id, ctx.kullanici.id, tutar, not, anahtar, anahtar ? teklifOzeti : null, z, z);
        await uygulamaIciBildir(db, l.owner_id, 'NEW_OFFER', 'Yeni teklif', `"${l.title}" ilanınıza yeni bir teklif geldi.`, l.id, 'ilan');
      });
    } catch (e) {
      // Eşzamanlı çift gönderim: (ilan, hizmet veren) tekil kısıtı → 500 değil, anlamlı yanıt.
      if (tekilIhlaliMi(e)) {
        // Aynı anahtarlı eşzamanlı tekrar: ilk teklif döner.
        const ilk = await oncekiKayit(db, TEKLIF_IDEM, ctx.kullanici.id, anahtar, teklifOzeti);
        if (ilk) return teklifGorunumu(ilk);
        throw kural('DUPLICATE_OFFER', 'Bu ilana zaten teklif verdiniz');
      }
      throw e;
    }
    return teklifGorunumu(await db.prepare('SELECT * FROM offers WHERE id = ?').get(id));
  }));

  // ── ⚠ TEKLİFLERİM İLANIYLA BİRLİKTE (16 Eki, kullanıcı bulgusu) ──
  // Hizmet verenin ilan listesi yalnız AÇIK ilanlardan (/listings/available)
  // geliyordu; teklifi SEÇİLEN ilan oradan düştüğü için Kazandığım
  // kartında "İlan kaldırıldı" yazıyor, ilan açılamıyordu. Her teklif
  // kendi ilanının görünümünü (`listing`) taşır — hizmet veren teklif
  // verdiği ilanı her durumda görebilir (GET /listings/:id ile aynı kural).
  r.get('/api/v1/offers/my', korumali(async (ctx) => {
    const teklifler = await db.prepare('SELECT * FROM offers WHERE provider_id = ? ORDER BY created_at DESC').all(ctx.kullanici.id);
    const ilanlar = new Map();
    const kimlikler = [...new Set(teklifler.map((o) => o.listing_id))];
    for (let i = 0; i < kimlikler.length; i += 500) {
      const parca = kimlikler.slice(i, i + 500);
      for (const l of await db.prepare(`SELECT * FROM listings WHERE id IN (${parca.map(() => '?').join(', ')})`).all(...parca)) ilanlar.set(l.id, l);
    }
    return teklifler.map((o) => {
      const l = ilanlar.get(o.listing_id);
      return { ...teklifGorunumu(o), ...(l ? { listing: ilanGorunumu(l) } : {}) };
    });
  }));

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
      // ⚠ KOŞULLU GÜNCELLEME: iki cihazdan eşzamanlı iki farklı teklif
      // seçilirse yalnız İLKİ geçer; aksi hâlde iki teklif birden SELECTED
      // kalabiliyordu (önceki denetim tx dışındaydı).
      const sec = await db.prepare(
        `UPDATE listings SET selected_offer_id = ?, updated_at = ? WHERE id = ? AND selected_offer_id IS NULL AND status = 'ACTIVE'`,
      ).run(o.id, z, l.id);
      if (sec.changes !== 1) throw kural('INVALID_STATE', 'Bu ilan için teklif zaten seçilmiş');
      // selected_at: seçim anı (Özet'teki seçilen teklif tutarı bu tarihe göre).
      const t = await db.prepare(`UPDATE offers SET status = 'SELECTED', selected_at = ?, updated_at = ? WHERE id = ? AND status = 'ACTIVE'`).run(z, z, o.id);
      if (t.changes !== 1) throw kural('INVALID_STATE', 'Bu teklif artık geçerli değil');
      await db.prepare(`UPDATE offers SET status = 'CLOSED', updated_at = ? WHERE listing_id = ? AND id <> ? AND status = 'ACTIVE'`).run(z, l.id, o.id);
      await uygulamaIciBildir(db, o.provider_id, 'OFFER_SELECTED', 'Teklifiniz seçildi', `"${l.title}" ilanında teklifiniz seçildi.`, l.id, 'is');
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
    // 16 Eki: iletişimi kim açarsa açsın iki taraf birbirinin bilgisini
    // görür; YALNIZ ilan sahibi "Sadece Uygulama İçi Mesaj" seçtiyse onun
    // telefonu hizmet verene gösterilmez (mesajlaşma açık kalır).
    const telefonGizli = karsiId === l.owner_id && l.iletisim_tercihi === 'yalnizMesaj';
    return { open: true, contactOpenAt: c.opened_at, counterpart: { name: k.name, phone: telefonGizli ? null : k.phone } };
  }));

  r.post('/api/v1/offers/:offerId/communication', korumali(async (ctx) => {
    const { o, l } = await tarafKontrol(ctx.params.offerId, ctx.kullanici);
    if (l.status === 'ADMIN_REMOVED' || l.status === 'USER_DELETED') throw kural('LISTING_REMOVED', 'İlan yayından kaldırılmış');
    const var_ = await db.prepare('SELECT * FROM contacts WHERE offer_id = ?').get(o.id);
    if (var_) return { open: true, contactOpenAt: var_.opened_at };
    // ── ⚠ İKİ TARAF DA AÇABİLİR (16 Eki, kullanıcı kararı) ──
    // 15 Eki'de yalnız ilan sahibi açabiliyordu; kullanıcı iki tarafın da
    // açabilmesini istedi. Hizmet alanın telefonu, ilanda "Sadece Uygulama
    // İçi Mesaj" seçtiyse paylaşılmaz (GET /contact). Açan tarafın KARŞISINA
    // bildirim gider.
    const karsiTaraf = ctx.kullanici.id === l.owner_id ? o.provider_id : l.owner_id;
    const z = simdi();
    let eklendi = false;
    await db.tx(async () => {
      // Eşzamanlı iki açma isteği: ikincisi hata (500) vermez, idempotent döner;
      // karşı tarafa bildirim YALNIZ BİR KEZ gider.
      const ek = await db.prepare('INSERT INTO contacts (offer_id, opened_by, opened_at) VALUES (?, ?, ?) ON CONFLICT (offer_id) DO NOTHING').run(o.id, ctx.kullanici.id, z);
      eklendi = ek.changes === 1;
      if (!eklendi) return;
      await uygulamaIciBildir(db, karsiTaraf, 'CONTACT_OPENED', 'İletişim açıldı', `"${l.title}" ilanı için iletişim bilgileri paylaşıldı.`, o.id, 'mesaj');
    });
    if (!eklendi) {
      const c = await db.prepare('SELECT opened_at FROM contacts WHERE offer_id = ?').get(o.id);
      return { open: true, contactOpenAt: c?.opened_at ?? z };
    }
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
    try {
      await db.prepare(
        `INSERT INTO reviews (id, listing_id, offer_id, provider_id, author_id, stars, text, status, created_at, published_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'PUBLISHED', ?, ?)`,
      ).run(id, l.id, o.id, o.provider_id, ctx.kullanici.id, yildiz, metin, z, z);
    } catch (e) {
      // Eşzamanlı çift değerlendirme: teklif başına tekil → 500 değil, anlamlı yanıt.
      if (tekilIhlaliMi(e)) throw kural('INVALID_STATE', 'Bu iş için değerlendirme zaten yapıldı');
      throw e;
    }
    return yorumGorunumu(await db.prepare('SELECT * FROM reviews WHERE id = ?').get(id));
  }));

  // ── "BUL" — HİZMET VEREN ARAMA ──
  // Hizmet alan, seçtiği hizmet/kategori için kayıtlı hizmet verenleri görür.
  // Eşleşme kuralı Flutter ile AYNI (AuthRepository.saglayicilarKimSunuyor):
  // hizmet verenin KENDİ seçtiği kategoriler kümesinde kategori ya da hizmet
  // adı varsa eşleşir. Kendisi, askıdaki/banlı/dondurulmuş/silinmiş hesaplar
  // dönmez. GİZLİLİK: telefon, e-posta, mahalle ve açık adres DÖNMEZ;
  // yalnız ad, il/ilçe, hizmet bölgeleri, puan, yorum ve tamamlanan iş sayısı.
  // Nihai sıralama istemcide (mevcut yakınlık + ölçüt mantığı); sunucu
  // müşterinin ilçesine hizmet verenleri öne alıp en çok 50 kayıt döndürür.
  r.get('/api/v1/providers/search', korumali(async (ctx) => {
    await saglayiciAramaSiniri.denetle(db, ctx.kullanici.id);
    const kategori = String(ctx.query.get('category') ?? '').trim();
    const hizmet = String(ctx.query.get('service') ?? '').trim();
    const ilce = String(ctx.query.get('district') ?? '').trim();
    if (!kategori && !hizmet) throw hata.dogrulama('Hizmet seçiniz');
    if (kategori.length > 120 || hizmet.length > 120 || ilce.length > 80) throw hata.dogrulama('Geçersiz arama');
    const adaylar = [kategori, hizmet].filter(Boolean);
    // LIKE yalnız ön elemedir (joker karakterler '!' ile kaçırılır); kesin eşleşme JSON ile.
    const kacir = (v) => v.replace(/[!%_]/g, (c) => `!${c}`);
    const kosul = adaylar.map(() => `p.categories_json LIKE ? ESCAPE '!'`).join(' OR ');
    const satir = await db.prepare(
      `SELECT u.id, u.name, u.roles, u.photo_provider_ref, a.city, a.district, p.categories_json, p.districts_json
         FROM users u JOIN provider_profiles p ON p.user_id = u.id LEFT JOIN addresses a ON a.user_id = u.id
        WHERE u.deleted_at IS NULL AND u.status = 'ACTIVE' AND u.frozen_at IS NULL AND u.id <> ? AND (${kosul})
        LIMIT 500`,
    ).all(ctx.kullanici.id, ...adaylar.map((x) => `%${kacir(JSON.stringify(x))}%`));
    const uygun = satir.filter((x) => {
      if (!x.roles.split(',').includes('PROVIDER')) return false;
      let k = [];
      try { k = JSON.parse(x.categories_json); } catch { return false; }
      return Array.isArray(k) && adaylar.some((a) => k.includes(a));
    });
    if (!uygun.length) return [];
    const kimlik = uygun.map((x) => x.id);
    const yer = kimlik.map(() => '?').join(', ');
    // Toplu sayımlar (N+1 yok).
    const puanlar = new Map((await db.prepare(
      `SELECT provider_id, AVG(stars) a, COUNT(*) n FROM reviews WHERE status = 'PUBLISHED' AND provider_id IN (${yer}) GROUP BY provider_id`,
    ).all(...kimlik)).map((r) => [r.provider_id, r]));
    const isler = new Map((await db.prepare(
      `SELECT provider_id, COUNT(*) n FROM offers WHERE status = 'SELECTED' AND provider_id IN (${yer}) GROUP BY provider_id`,
    ).all(...kimlik)).map((r) => [r.provider_id, r.n]));
    const talepIsleri = new Map((await db.prepare(
      `SELECT saglayici_id, COUNT(*) n FROM teklif_talepleri WHERE durum = 'TAMAMLANDI' AND saglayici_id IN (${yer}) GROUP BY saglayici_id`,
    ).all(...kimlik)).map((r) => [r.saglayici_id, r.n]));
    const ayar = await depolamaAyari(db);
    const liste = uygun.map((x) => {
      let bolgeler = [];
      try { bolgeler = JSON.parse(x.districts_json); } catch { /* boş */ }
      const p = puanlar.get(x.id);
      return {
        id: x.id, name: x.name,
        address: x.city || x.district ? { city: x.city ?? '', district: x.district ?? '' } : null,
        serviceDistricts: Array.isArray(bolgeler) ? bolgeler : [],
        rating: p?.n ? Number(Number(p.a).toFixed(2)) : null,
        reviewCount: p?.n ?? 0,
        completedJobs: (isler.get(x.id) ?? 0) + (talepIsleri.get(x.id) ?? 0),
        photoRef: x.photo_provider_ref ?? null,
      };
    });
    liste.sort((a, b) => (Number(b.serviceDistricts.includes(ilce)) - Number(a.serviceDistricts.includes(ilce)))
      || ((b.rating ?? 0) - (a.rating ?? 0)) || (b.reviewCount - a.reviewCount) || (b.completedJobs - a.completedJobs)
      || a.id.localeCompare(b.id));
    const ilk = liste.slice(0, 50);
    for (const x of ilk) {
      x.photoUrl = await imzaliGorselAdresi(db, x.photoRef, ayar);
      delete x.photoRef;
    }
    return ilk;
  }));

  // ── HİZMET VERENİN YORUMLARI ──
  //
  // ⚠ SÖZLEŞME (15 Eki): "Müşteri Yorumları" ekranı OpenAPI'deki biçimi
  // (`distribution`, `items`, `nextCursor`) bekliyordu; uç yalnız
  // `average`, `count`, `reviews` döndürdüğü için ekranda ortalama
  // görünüyor, dağılım sıfır ve liste boş kalıyordu. Alanlar EKLENDİ;
  // `reviews` (yorum deposu kullanır) aynen korunur.
  //
  // ⚠ YAZAR ADI KISA ("Ad S.") gider — tam soyad ağda da açılmaz; istemci
  // aynı kısaltmayı uyguladığı için görünüm değişmez.
  // ⚠ `limit` verilmezse eskisi gibi 100 kayıt döner (yorum deposu
  // sayfalamasız okur); sayfalama `cursor` + `limit` ile yapılır.
  r.get('/api/v1/providers/:id/reviews', korumali(async (ctx) => {
    const ham = ctx.query.get('limit');
    const limit = ham == null ? 100 : Number(ham);
    if (!Number.isInteger(limit) || limit < 1 || limit > 100) throw hata.dogrulama('limit 1–100 arasında olmalı');
    let imlec = null;
    const imlecHam = ctx.query.get('cursor');
    if (imlecHam != null) {
      try { imlec = JSON.parse(Buffer.from(imlecHam, 'base64url').toString('utf8')); } catch { imlec = null; }
      if (!Array.isArray(imlec) || imlec.length !== 2 || imlec.some((v) => typeof v !== 'string')) {
        throw hata.dogrulama('Geçersiz cursor');
      }
    }
    const satirlar = await db.prepare(
      `SELECT r.*, a.name yazar_adi, l.title ilan_basligi, t.hizmet talep_hizmeti, t.kategori talep_kategorisi
         FROM reviews r
         LEFT JOIN users a ON a.id = r.author_id
         LEFT JOIN listings l ON l.id = r.listing_id
         LEFT JOIN teklif_talepleri t ON t.id = r.talep_id
        WHERE r.provider_id = ? AND r.status = 'PUBLISHED'
          ${imlec ? 'AND (r.created_at < ? OR (r.created_at = ? AND r.id < ?))' : ''}
        ORDER BY r.created_at DESC, r.id DESC LIMIT ?`,
    ).all(ctx.params.id, ...(imlec ? [imlec[0], imlec[0], imlec[1]] : []), limit + 1);
    const devam = satirlar.length > limit;
    const liste = devam ? satirlar.slice(0, limit) : satirlar;
    const son = liste[liste.length - 1];
    const ort = await db.prepare(`SELECT AVG(stars) a, COUNT(*) n FROM reviews WHERE provider_id = ? AND status = 'PUBLISHED'`).get(ctx.params.id);
    const dagilim = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    for (const d of await db.prepare(
      `SELECT stars, COUNT(*) n FROM reviews WHERE provider_id = ? AND status = 'PUBLISHED' GROUP BY stars`,
    ).all(ctx.params.id)) dagilim[d.stars] = d.n;
    return {
      average: ort.n ? Number(Number(ort.a).toFixed(2)) : null,
      count: ort.n,
      distribution: dagilim,
      items: liste.map((y) => {
        const baslik = y.ilan_basligi ?? y.talep_hizmeti ?? '';
        return {
          ...yorumGorunumu(y),
          reviewId: y.id,
          author: { name: kisaAd(y.yazar_adi ?? '') },
          listing: { title: baslik, category: y.ilan_basligi != null ? baslik : (y.talep_kategorisi ?? baslik) },
        };
      }),
      nextCursor: devam ? Buffer.from(JSON.stringify([son.created_at, son.id])).toString('base64url') : null,
      reviews: liste.map(yorumGorunumu),
    };
  }));

  // ── BİLDİRİMLER ──
  r.get('/api/v1/notifications', korumali(async (ctx) =>
    (await db.prepare('SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 200').all(ctx.kullanici.id))
      .map((n) => ({ id: n.id, userId: n.user_id, type: n.type, title: n.title, body: n.body, refId: n.ref_id, target: n.push_target ?? null, createdAt: n.created_at, readAt: n.read_at })),
  ));
  r.get('/api/v1/notifications/unread-count', korumali(async (ctx) => ({
    count: (await db.prepare('SELECT COUNT(*) n FROM notifications WHERE user_id = ? AND read_at IS NULL').get(ctx.kullanici.id)).n,
  })));
  r.post('/api/v1/notifications/:id/read', korumali(async (ctx) => {
    const n = await db.prepare('UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ? AND read_at IS NULL').run(simdi(), ctx.params.id, ctx.kullanici.id);
    return { ok: true, changed: n.changes };
  }));
  // ── SAYFA GÖRÜLDÜ → O SAYFANIN BİLDİRİMLERİ OKUNDU (21 Eki) ──
  //
  // Kullanıcı bildirime dokunmadan ilgili sayfayı başka yoldan açtığında
  // (ör. İlanlarım → ilan → teklifler) bildirim okunmamış kalıyordu.
  // Sayfa açılınca istemci bunu çağırır; hangi sayfanın hangi bildirim
  // türlerini "gördüğü" YALNIZ burada tanımlıdır (tek kaynak) ve her
  // tür, bildirime dokununca açılan sayfayla eşleşir
  // (NotificationsScreen.hedefeGit). Yalnız oturum sahibinin kendi
  // bildirimleri değişir; türler role özgü olduğu için karşı rolün
  // bildirimleri etkilenmez.
  r.post('/api/v1/notifications/read-for-page', korumali(async (ctx) => {
    const sayfa = SAYFA_BILDIRIMLERI[typeof ctx.body?.page === 'string' ? ctx.body.page : ''];
    const ref = typeof ctx.body?.refId === 'string' ? ctx.body.refId.trim() : '';
    if (!sayfa || !Object.hasOwn(SAYFA_BILDIRIMLERI, ctx.body.page)) throw hata.dogrulama('Geçersiz sayfa');
    if (!/^[A-Za-z0-9-]{1,64}$/.test(ref)) throw hata.dogrulama('Geçersiz kimlik');
    const an = simdi();
    const yer = sayfa.turler.map(() => '?').join(', ');
    let degisen = (await db.prepare(
      `UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL AND ref_id = ? AND type IN (${yer})`,
    ).run(an, ctx.kullanici.id, ref, ...sayfa.turler)).changes;
    // "İletişim açıldı" teklif kimliği taşır; ilan/iş sayfası o ilanın
    // tekliflerine ait olanları da görmüş sayılır.
    if (sayfa.teklifUzerinden && UUID_DESENI.test(ref)) {
      const teklifler = (await db.prepare('SELECT id FROM offers WHERE listing_id = ?').all(ref)).map((o) => String(o.id));
      if (teklifler.length) {
        const ty = sayfa.teklifUzerinden.map(() => '?').join(', ');
        const iy = teklifler.map(() => '?').join(', ');
        degisen += (await db.prepare(
          `UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL AND type IN (${ty}) AND ref_id IN (${iy})`,
        ).run(an, ctx.kullanici.id, ...sayfa.teklifUzerinden, ...teklifler)).changes;
      }
    }
    return { ok: true, changed: degisen };
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

  // ── ÖZET: SEÇİLEN TARİH ARALIĞI (21 Eki) ──
  //
  // Özet ekranındaki tarih seçimi (Bugün / Bu hafta / Bu ay / aralık)
  // için GÜNLÜK sayılar. Liste uçlarının 200 kayıt sınırına takılmadan
  // doğrudan veritabanından sayılır; sayı uydurulmaz.
  //   from — panelin yerel gün başlangıcı (ISO), days — gün sayısı,
  //   unit=hour (yalnız days=1) — tek günün 24 saatlik dilimleri (grafik).
  // Günler `from`dan itibaren 24 saatlik dilimlerdir (Türkiye'de yaz
  // saati yok). Kullanıcı ve dondurma/silme sayıları `users.read`, Gelen
  // Talepler sayısı `support.tickets.read` yetkisi ister; yetki yoksa null.
  r.get('/admin/v1/stats/period', async (ctx) => {
    yetkiIste(ctx.admin, 'content.read');
    const bas = Date.parse(String(ctx.query.get('from') ?? ''));
    const gun = Number(ctx.query.get('days'));
    if (!Number.isFinite(bas) || !Number.isInteger(gun) || gun < 1 || gun > 800) throw hata.dogrulama('Geçersiz tarih aralığı');
    const GUN_MS = 86_400_000;
    const saatlik = ctx.query.get('unit') === 'hour';
    if (saatlik && gun !== 1) throw hata.dogrulama('Saatlik dilim yalnız tek gün için');
    const dilim = saatlik ? 3_600_000 : GUN_MS;
    const adet = saatlik ? 24 : gun;
    const ilk = new Date(bas).toISOString();
    const son = new Date(bas + gun * GUN_MS).toISOString();
    const seri = async (tablo, ek = '') => {
      const sayac = Array(adet).fill(0);
      const satirlar = await db.prepare(`SELECT created_at t FROM ${tablo} WHERE created_at >= ? AND created_at < ?${ek}`).all(ilk, son);
      for (const { t } of satirlar) {
        const i = Math.floor(((t instanceof Date ? t.getTime() : Date.parse(t)) - bas) / dilim);
        if (i >= 0 && i < adet) sayac[i]++;
      }
      return sayac;
    };
    const kullaniciYetkisi = yetkiliMi(ctx.admin.role, 'users.read');
    return {
      from: ilk,
      days: gun,
      unit: saatlik ? 'hour' : 'day',
      users: kullaniciYetkisi ? await seri('users', ' AND deleted_at IS NULL') : null,
      listings: await seri('listings'),
      offers: await seri('offers'),
      teklifTalepleri: await seri('teklif_talepleri'),
      accountRequests: kullaniciYetkisi ? await seri('account_requests') : null,
      // Gelen Talepler (destek e-postaları + uygulama formu).
      supportTickets: yetkiliMi(ctx.admin.role, 'support.tickets.read') ? await seri('support_tickets') : null,
    };
  });

  // ── ÖZET: TEKLİF TALEPLERİ VE SEÇİLEN TEKLİF TUTARI (21 Eki) ──
  //
  // Özet'teki tarih seçimine göre (from + days, panelin yerel gün başı):
  //   · Teklif talepleri: dönemde AÇILAN taleplerin bugünkü durumlarına
  //     göre sayısı; "iptal" = hizmet alanın talebi kaldırması (silindi_at).
  //   · Seçilen teklif tutarı: dönemde SEÇİLEN tekliflerin toplamı — ilan
  //     teklifleri (offers.selected_at) + kabul edilen teklif talepleri
  //     (teklif_talepleri.secildi_at). Her seçim bir kez, seçildiği gün
  //     sayılır; HizmetCep'in aracılık ettiği iş hacmini gösterir.
  r.get('/admin/v1/stats/market', async (ctx) => {
    yetkiIste(ctx.admin, 'content.read');
    const bas = Date.parse(String(ctx.query.get('from') ?? ''));
    const gun = Number(ctx.query.get('days'));
    if (!Number.isFinite(bas) || !Number.isInteger(gun) || gun < 1 || gun > 800) throw hata.dogrulama('Geçersiz tarih aralığı');
    const ilk = new Date(bas).toISOString();
    const son = new Date(bas + gun * 86_400_000).toISOString();
    const durumlar = { BEKLEMEDE: 0, TEKLIF_GELDI: 0, SECILDI: 0, TAMAMLANDI: 0, REDDEDILDI: 0, SURESI_DOLDU: 0 };
    let iptal = 0; let toplam = 0;
    for (const x of await db.prepare(
      `SELECT durum, CASE WHEN silindi_at IS NULL THEN 0 ELSE 1 END iptal, COUNT(*) n FROM teklif_talepleri
        WHERE created_at >= ? AND created_at < ? GROUP BY durum, CASE WHEN silindi_at IS NULL THEN 0 ELSE 1 END`,
    ).all(ilk, son)) {
      const n = Number(x.n);
      toplam += n;
      if (Number(x.iptal) === 1) iptal += n; else if (x.durum in durumlar) durumlar[x.durum] += n;
    }
    const ilanT = await db.prepare('SELECT COUNT(*) n, COALESCE(SUM(amount_tl), 0) tl FROM offers WHERE selected_at >= ? AND selected_at < ?').get(ilk, son);
    const talepT = await db.prepare('SELECT COUNT(*) n, COALESCE(SUM(teklif_fiyati), 0) tl FROM teklif_talepleri WHERE secildi_at >= ? AND secildi_at < ? AND teklif_fiyati IS NOT NULL').get(ilk, son);
    const ilanTl = Number(ilanT.tl); const talepTl = Number(talepT.tl);
    // 22 Eki: Seçilen Toplam Teklif Tutarı kartında yıl seçimi — ilk seçimin yılı.
    const ilkSecim = [
      (await db.prepare('SELECT MIN(selected_at) t FROM offers WHERE selected_at IS NOT NULL').get())?.t,
      (await db.prepare('SELECT MIN(secildi_at) t FROM teklif_talepleri WHERE secildi_at IS NOT NULL').get())?.t,
    ].filter(Boolean).map((t) => new Date(t).getFullYear()).filter(Number.isFinite);
    return {
      from: ilk, days: gun,
      firstSelectedYear: ilkSecim.length ? Math.min(...ilkSecim) : null,
      teklifTalepleri: { total: toplam, byStatus: durumlar, cancelled: iptal },
      selectedOffers: {
        totalTl: ilanTl + talepTl,
        count: Number(ilanT.n) + Number(talepT.n),
        listingOffers: { count: Number(ilanT.n), totalTl: ilanTl },
        teklifTalepleri: { count: Number(talepT.n), totalTl: talepTl },
      },
    };
  });

  // ── SİSTEM DURUMU DETAYI (21 Eki) ──
  //
  // Özet'teki "Sistem Durumu" kartının ayrıntısı. Yalnız backend'in
  // gerçekten bildiği değerler: sunucu çalışma süresi, veritabanı türü ve
  // yanıt süresi, son veritabanı güncellemesi, son 7 günün gönderim
  // sayıları ve son başarısız gönderimler. Alıcı (telefon/e-posta) ve
  // ileti içeriği DÖNMEZ. Entegrasyon ayrıntısı `integrations.read`, son
  // hatalar `notifications.read` yetkisi ister; yetki yoksa null.
  r.get('/admin/v1/system/status', async (ctx) => {
    yetkiIste(ctx.admin, 'content.read');
    const t0 = performance.now();
    await db.prepare('SELECT 1 AS n').get();
    const dbMs = Math.round((performance.now() - t0) * 10) / 10;
    const goc = await db.prepare('SELECT id, applied_at FROM schema_migrations ORDER BY id DESC LIMIT 1').get();
    const gocSayisi = Number((await db.prepare('SELECT COUNT(*) n FROM schema_migrations').get()).n);
    const yediGun = new Date(Date.now() - 7 * 86_400_000).toISOString();
    const kanal = { SMS: { SENT: 0, FAILED: 0, PENDING: 0 }, EMAIL: { SENT: 0, FAILED: 0, PENDING: 0 } };
    for (const x of await db.prepare('SELECT channel, status, COUNT(*) n FROM outbound_messages WHERE created_at > ? GROUP BY channel, status').all(yediGun)) {
      if (kanal[x.channel] && x.status in kanal[x.channel]) kanal[x.channel][x.status] = Number(x.n);
    }
    const push = { SENT: 0, FAILED: 0, PENDING: 0, NO_TOKEN: 0, SKIPPED: 0 };
    for (const x of await db.prepare('SELECT push_status s, COUNT(*) n FROM notifications WHERE created_at > ? GROUP BY push_status').all(yediGun)) {
      const k = x.s === null || x.s === 'SENDING' ? 'PENDING' : x.s;
      if (k in push) push[k] += Number(x.n);
    }
    const entegrasyon = yetkiliMi(ctx.admin.role, 'integrations.read')
      ? (await db.prepare('SELECT type, provider, active, last_test_at, last_test_ok, last_test_message FROM integrations WHERE deleted_at IS NULL ORDER BY type, created_at').all())
        .map((x) => ({ type: x.type, provider: x.provider, active: x.active === 1 || x.active === true, lastTestAt: x.last_test_at,
          lastTestOk: x.last_test_ok === null ? null : x.last_test_ok === 1 || x.last_test_ok === true, lastTestMessage: x.last_test_message }))
      : null;
    const sonHatalar = yetkiliMi(ctx.admin.role, 'notifications.read')
      ? (await db.prepare(`SELECT channel, template, provider, provider_response, attempts, created_at FROM outbound_messages WHERE status = 'FAILED' ORDER BY created_at DESC LIMIT 10`).all())
        .map((m) => ({ channel: m.channel, template: m.template, provider: m.provider, providerResponse: m.provider_response ? yanitMaskele(String(m.provider_response)).slice(0, 200) : null, attempts: m.attempts, createdAt: m.created_at }))
      : null;
    // ── 22 Eki: kaynak kullanımı, API ölçümleri, yedekleme, kritik olaylar ──
    // Bu örneğin biriken ölçümleri önce yazılır (gösterilen sayı güncel olsun).
    await olcumleriYaz(db).catch((e) => console.error('olcum_yazma', e?.message));
    const kaynak = await kaynakKullanimi(db);
    const apiOlcum = await apiOlcumleri(db);
    const yedek = await yedekDurumu(db, { yenile: ctx.query.get('refreshBackup') === '1' && yetkiliMi(ctx.admin.role, 'integrations.read') });
    const silme = await silmeKuyruguSorunlari(db);
    const silmeTukenen = silme.filesExhausted + silme.firebaseLongFailure + silme.firebaseOpsLongFailure;
    const tumEntegrasyon = (await db.prepare('SELECT type, active, last_test_ok FROM integrations WHERE deleted_at IS NULL').all())
      .map((x) => ({ type: x.type, active: x.active === 1 || x.active === true, lastTestOk: x.last_test_ok === null ? null : x.last_test_ok === 1 || x.last_test_ok === true }));
    return {
      checkedAt: new Date().toISOString(),
      overall: genelDurum({ veritabaniOk: true, api: apiOlcum, kaynak, yedek, entegrasyonlar: tumEntegrasyon, silmeTukenen }),
      api: { status: 'OK', uptimeSeconds: Math.round(process.uptime()), serverTime: new Date().toISOString() },
      database: { status: 'OK', driver: db.surucu, responseMs: dbMs, lastMigration: goc?.id ?? null, lastMigrationAt: goc?.applied_at ?? null, migrations: gocSayisi },
      resources: kaynak,
      apiMetrics: apiOlcum,
      backup: yetkiliMi(ctx.admin.role, 'integrations.read') ? yedek : null,
      delivery: { since: yediGun, sms: kanal.SMS, email: kanal.EMAIL, push: { ...push, configured: fcmEtkin() } },
      integrations: entegrasyon,
      recentFailures: sonHatalar,
      serverErrors: yetkiliMi(ctx.admin.role, 'notifications.read') ? await sonSunucuHatalari(db) : null,
      deletionIssues: yetkiliMi(ctx.admin.role, 'deletion.queues.read') ? silme : null,
      adminSecurityEvents: yetkiliMi(ctx.admin.role, 'audit.read') ? await yoneticiGuvenlikOlaylari(db) : null,
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
      `SELECT o.*, u.name provider_name, c.opened_at iletisim_acilis, c.opened_by iletisim_acan
         FROM offers o JOIN users u ON u.id = o.provider_id
         LEFT JOIN contacts c ON c.offer_id = o.id
        WHERE o.listing_id = ? ORDER BY o.created_at`,
    ).all(l.id);
    const yorum = await db.prepare('SELECT * FROM reviews WHERE listing_id = ?').get(l.id);
    return {
      ...ilanGorunumu(l), removedReason: l.removed_reason, removedAt: l.removed_at, deleteReason: l.delete_reason,
      owner: sahip,
      // 16 Eki: iletişim iki taraftan açılabildiği için panel kimin açtığını gösterir.
      offers: teklifler.map((o) => ({
        ...teklifGorunumu(o), providerName: o.provider_name,
        contactOpenedAt: o.iletisim_acilis ?? null,
        contactOpenedBy: !o.iletisim_acan ? null : (o.iletisim_acan === l.owner_id ? 'OWNER' : (o.iletisim_acan === o.provider_id ? 'PROVIDER' : 'OTHER')),
      })),
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
