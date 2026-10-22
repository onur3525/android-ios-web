// ═══════════════════════════════════════════════════════════════
// BAŞLANGIÇ VERİSİ — Flutter uygulamasının GERÇEK verisinden aktarım
//
// ⚠ Bu veri DEMO DEĞİLDİR. Kaynak, kullanıcı uygulamasının kendi
// dosyalarıdır (kopya yok; her çalıştırmada doğrudan okunur):
//   lib/data/category_tree.dart     kGomuluKatalog, kKartDisiKategoriler,
//                                   kLiderHizmetler, kCategoryImage
//   lib/screens/category_ui.dart    kKategoriIkonu
//   lib/data/izmir.dart             kCity, kIzmirDistricts
//   lib/data/izmir_neighborhoods.dart kIzmirNeighborhoods
//   lib/data/legal_cache.dart       kLegalLinks
//   lib/data/models/support_info.dart varsayılan destek bilgisi
//
// Ad, sıra ve ilişki DEĞİŞTİRİLMEZ; Dart dosyasındaki sıra `sort`
// olarak saklanır. Aktarım YALNIZ boş tablolara yapılır — admin'in
// sonradan yaptığı değişikliklerin üzerine yazmaz (idempotent).
//
// Kullanım: HC_DB_PATH=... node scripts/seed_from_flutter.js
// ═══════════════════════════════════════════════════════════════
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { veritabaniAc, simdi } from '../src/db.js';

const KOK = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const oku = (goreli) => readFileSync(join(KOK, goreli), 'utf8');

// ── Dart sabit çözümleyicisi (yalnız literal alt kümesi) ─────
// Desteklenen: '..' / ".." dizeleri (kaçışlar, yan yana birleştirme),
// [liste], {küme}, {anahtar: değer} haritası, (ad: değer) kaydı,
// // ve /* */ yorumları, sondaki virgüller.
export function dartSabiti(kaynak, ad) {
  const i = kaynak.search(new RegExp(`\\b${ad}\\s*=`));
  if (i < 0) throw new Error(`${ad} bulunamadı`);
  let k = kaynak.indexOf('=', i) + 1;
  const bosluk = () => {
    for (;;) {
      while (/\s/.test(kaynak[k])) k++;
      if (kaynak.startsWith('//', k)) { k = kaynak.indexOf('\n', k); continue; }
      if (kaynak.startsWith('/*', k)) { k = kaynak.indexOf('*/', k) + 2; continue; }
      return;
    }
  };
  const dize = () => {
    let out = '';
    while (kaynak[k] === "'" || kaynak[k] === '"') {
      const q = kaynak[k++];
      while (kaynak[k] !== q) {
        if (kaynak[k] === '\\') {
          const s = kaynak[k + 1];
          out += s === 'n' ? '\n' : s === 't' ? '\t' : s;
          k += 2;
        } else {
          if (kaynak[k] === '$') throw new Error(`${ad}: dize içinde ara değer desteklenmez`);
          out += kaynak[k++];
        }
      }
      k++;
      bosluk();
    }
    return out;
  };
  const deger = () => {
    bosluk();
    const c = kaynak[k];
    if (c === "'" || c === '"') return dize();
    if (c === '[') return dizi(']');
    if (c === '(') return kayit();
    if (c === '{') return haritaVeyaKume();
    throw new Error(`${ad}: beklenmeyen karakter '${c}' (${k})`);
  };
  const dizi = (son) => {
    k++;
    const out = [];
    for (;;) {
      bosluk();
      if (kaynak[k] === son) { k++; return out; }
      out.push(deger());
      bosluk();
      if (kaynak[k] === ',') k++;
    }
  };
  const kayit = () => {
    k++;
    const out = {};
    for (;;) {
      bosluk();
      if (kaynak[k] === ')') { k++; return out; }
      const m = /^[A-Za-z_]\w*/.exec(kaynak.slice(k));
      k += m[0].length;
      bosluk();
      k++; // ':'
      out[m[0]] = deger();
      bosluk();
      if (kaynak[k] === ',') k++;
    }
  };
  const haritaVeyaKume = () => {
    k++;
    const harita = new Map();
    const kume = [];
    for (;;) {
      bosluk();
      if (kaynak[k] === '}') { k++; return harita.size ? harita : kume; }
      const a = deger();
      bosluk();
      if (kaynak[k] === ':') {
        k++;
        harita.set(a, deger());
      } else {
        kume.push(a);
      }
      bosluk();
      if (kaynak[k] === ',') k++;
    }
  };
  // Tür bildirimi `const Map<...> ad = ` sonrası doğrudan değer gelir.
  return deger();
}

export function flutterVerisiniOku() {
  const agac = oku('lib/data/category_tree.dart');
  const ui = oku('lib/screens/category_ui.dart');
  const izmir = oku('lib/data/izmir.dart');
  const mahalle = oku('lib/data/izmir_neighborhoods.dart');
  const yasal = oku('lib/data/legal_cache.dart');
  const destek = oku('lib/data/models/support_info.dart');
  const alanlar = oku('lib/data/hizmet_alanlari.dart');
  const ana = oku('lib/screens/home_screen.dart');

  const destekBlok = destek.slice(destek.indexOf('_varsayilan = SupportInfo('));
  const destekVeri = dartSabiti(destekBlok.replace('_varsayilan = SupportInfo', '_varsayilan = '), '_varsayilan');

  return {
    katalog: dartSabiti(agac, 'kGomuluKatalog'),
    kartDisi: new Set(dartSabiti(agac, 'kKartDisiKategoriler')),
    lider: new Set(dartSabiti(agac, 'kLiderHizmetler')),
    fotograf: dartSabiti(agac, 'kCategoryImage'),
    ikon: dartSabiti(ui, 'kKategoriIkonu'),
    il: dartSabiti(izmir, 'kCity'),
    ilceler: dartSabiti(izmir, 'kIzmirDistricts'),
    mahalleler: dartSabiti(mahalle, 'kIzmirNeighborhoods'),
    yasal: dartSabiti(yasal, 'kLegalLinks'),
    destek: destekVeri,
    // Ana sayfa çatıları (029): `HizmetAlani(...)` kayıt sözdizimine çevrilir.
    catilar: dartSabiti(alanlar.slice(alanlar.indexOf('const List<HizmetAlani> kGomuluHizmetAlanlari')).replace(/HizmetAlani\(/g, '('), 'kGomuluHizmetAlanlari'),
    kartEtiketi: dartSabiti(ana.slice(ana.indexOf('kKartEtiketi =') - 30), 'kKartEtiketi'),
  };
}

/** Çatının kalıcı anahtarı: uygulama paketindeki görsel adı (assets/alanlar/ev.jpg → ev). */
export const catiAnahtari = (gorsel) => String(gorsel).split('/').pop().replace(/\.[a-z]+$/, '');

// Eski ücretli modelden kalan ve ÜRÜNDE AKTİF OLMAYAN belgeler.
const KALINTI_BELGELER = new Set(['refund']);
// Kayıtta onaylanan belgeler (Flutter: `termsAccepted`).
const KABUL_ISTEYEN = new Set(['terms', 'privacy', 'kvkk', 'membership']);

export async function tohumla(db, v = flutterVerisiniOku()) {
  const z = simdi();
  const sayac = { kategori: 0, hizmet: 0, il: 0, ilce: 0, mahalle: 0, belge: 0, destek: 0, cati: 0 };
  await db.tx(async () => {
    if (!await db.prepare('SELECT 1 FROM categories LIMIT 1').get()) {
      const kat = db.prepare(`INSERT INTO categories (id, name, active, sort, icon, photo, kart_disi, created_at, updated_at) VALUES (?, ?, TRUE, ?, ?, ?, ?, ?, ?)`);
      const hiz = db.prepare(`INSERT INTO services (id, category_id, name, active, sort, lider, created_at, updated_at) VALUES (?, ?, ?, TRUE, ?, ?, ?, ?)`);
      let ks = 0;
      for (const [kAd, hizmetler] of v.katalog) {
        const kid = randomUUID();
        await kat.run(kid, kAd, ks++, v.ikon.get(kAd) ?? null, v.fotograf.get(kAd) ?? null, v.kartDisi.has(kAd) ? 1 : 0, z, z);
        sayac.kategori++;
        for (const [hs, h] of hizmetler.entries()) {
          await hiz.run(randomUUID(), kid, h, hs, v.lider.has(h) ? 1 : 0, z, z);
          sayac.hizmet++;
        }
      }
    }
    // ── Çatılar (029): tablo BOŞSA uygulamadaki 24 çatı ve kategori bağları.
    // Kategori bağı yalnız henüz bağlanmamış (roof_key boş) kategorilere yazılır.
    if (v.catilar && !await db.prepare('SELECT 1 FROM catalog_roofs LIMIT 1').get()) {
      const ekle = db.prepare('INSERT INTO catalog_roofs (key, name, description, card_label, sort, bundled_photo, photo_ref, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?)');
      const bagla = db.prepare('UPDATE categories SET roof_key = ? WHERE name = ? AND roof_key IS NULL');
      for (const [i, c] of v.catilar.entries()) {
        const anahtar = catiAnahtari(c.gorsel);
        await ekle.run(anahtar, c.ad, c.aciklama, v.kartEtiketi?.get(c.ad) ?? null, i, c.gorsel, z, z);
        sayac.cati++;
        for (const k of c.kategoriler) await bagla.run(anahtar, k);
      }
    }
    if (!await db.prepare('SELECT 1 FROM cities LIMIT 1').get()) {
      const cid = randomUUID();
      await db.prepare('INSERT INTO cities (id, name, active, created_at, updated_at) VALUES (?, ?, TRUE, ?, ?)').run(cid, v.il, z, z);
      sayac.il++;
      const ilce = db.prepare('INSERT INTO districts (id, city_id, name, active, all_supported, created_at, updated_at) VALUES (?, ?, ?, TRUE, FALSE, ?, ?)');
      const mah = db.prepare('INSERT INTO neighborhoods (id, district_id, name, active, postal_code, created_at, updated_at) VALUES (?, ?, ?, TRUE, NULL, ?, ?)');
      for (const dAd of v.ilceler) {
        const did = randomUUID();
        await ilce.run(did, cid, dAd, z, z);
        sayac.ilce++;
        for (const m of v.mahalleler.get(dAd) || []) {
          await mah.run(randomUUID(), did, m, z, z);
          sayac.mahalle++;
        }
      }
    }
    if (!await db.prepare('SELECT 1 FROM legal_documents LIMIT 1').get()) {
      const ekle = db.prepare('INSERT INTO legal_documents (slug, title, active, requires_acceptance, created_at) VALUES (?, ?, ?, ?, ?)');
      for (const d of v.yasal) {
        if (d.slug === 'support') continue; // destek ayrı tabloda
        await ekle.run(d.slug, d.title, KALINTI_BELGELER.has(d.slug) ? 0 : 1, KABUL_ISTEYEN.has(d.slug) ? 1 : 0, z);
        sayac.belge++;
      }
    }
    if (!await db.prepare('SELECT 1 FROM support_info').get()) {
      await db.prepare('INSERT INTO support_info (id, description, email, updated_at) VALUES (1, ?, ?, ?)').run(v.destek.description, v.destek.email, z);
      sayac.destek++;
    }
  });
  return sayac;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { config } = await import('../src/config.js');
  const db = await veritabaniAc(config.veritabani);
  const s = await tohumla(db);
  await db.close();
  console.log('Aktarıldı:', JSON.stringify(s));
}
