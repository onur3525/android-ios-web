// ═══════════════════════════════════════════════════════════════
// MESAJ DURUMU — TEK KAYNAK (29 Eki, kullanıcı bulgusu)
//
// "Mesaj karşı tarafa ulaşmadan iki tik olmamalı; okunanların hepsi mavi
// olmalı." Durum üç aşamalıdır:
//   SENT      — sunucuya ulaştı (tek tik)
//   DELIVERED — alıcının AÇIK uygulamasına ulaştı (iki gri tik):
//               · alıcı sohbet odasındayken anlık bağlantıyla iletildi,
//               · alıcı sohbet listesini / sohbeti / talep listesini çekti
//   READ      — alıcı sohbeti açtı ya da açıkken gördü (iki mavi tik)
// İlan sohbeti (`messages`) ve teklif talebi sohbeti (`teklif_mesajlari`)
// aynı kuralı kullanır. Gönderene değişiklik anında haber verilir:
//   ilan sohbeti  → oda olayı `message.delivered` / `message.read`
//   talep sohbeti → anlık haber `TALEP_DURUM` (uygulama talebi yeniler)
// ═══════════════════════════════════════════════════════════════
import { simdi } from './db.js';
import { olaylar } from './olaylar.js';
import { anlikHaberEkle } from './anlik_haber.js';

/** İlan sohbeti mesajının durumu (HTTP ve anlık bağlantı aynı kural). */
export const mesajDurumu = (m) => (m.read_at ? 'READ' : m.delivered_at ? 'DELIVERED' : 'SENT');

const parcala = (dizi, n = 500) => {
  const out = [];
  for (let i = 0; i < dizi.length; i += n) out.push(dizi.slice(i, i + n));
  return out;
};

/**
 * [aliciId]'ye gelen ve henüz iletilmemiş ilan sohbeti mesajlarını
 * "iletildi" yapar; değişen her sohbet için gönderene oda olayı yayınlar.
 * @returns {Promise<string[]>} değişen teklif (sohbet) kimlikleri
 */
export async function ilanMesajlariIletildi(db, teklifIdleri, aliciId) {
  const degisen = [];
  for (const parca of parcala([...new Set(teklifIdleri)])) {
    if (!parca.length) continue;
    const yer = parca.map(() => '?').join(', ');
    const bekleyen = await db.prepare(
      `SELECT DISTINCT offer_id FROM messages WHERE offer_id IN (${yer}) AND sender_id <> ? AND delivered_at IS NULL`,
    ).all(...parca, aliciId);
    if (!bekleyen.length) continue;
    const ids = bekleyen.map((x) => x.offer_id);
    await db.prepare(
      `UPDATE messages SET delivered_at = ? WHERE offer_id IN (${ids.map(() => '?').join(', ')}) AND sender_id <> ? AND delivered_at IS NULL`,
    ).run(simdi(), ...ids, aliciId);
    degisen.push(...ids);
  }
  for (const offerId of degisen) await olaylar.yayinla('message.delivered', { offerId, aliciId });
  return degisen;
}

/**
 * Teklif talebi mesajları: [aliciId]'ye gelen ve iletilmemiş olanlar
 * "iletildi" olur; mesajı gönderenlere `TALEP_DURUM` anlık haberi gider.
 */
export async function talepMesajlariIletildi(db, talepIdleri, aliciId) {
  const gonderenler = new Set();
  for (const parca of parcala([...new Set(talepIdleri)])) {
    if (!parca.length) continue;
    const yer = parca.map(() => '?').join(', ');
    const bekleyen = await db.prepare(
      `SELECT DISTINCT gonderen_id FROM teklif_mesajlari WHERE talep_id IN (${yer}) AND gonderen_id <> ? AND delivered_at IS NULL`,
    ).all(...parca, aliciId);
    if (!bekleyen.length) continue;
    await db.prepare(
      `UPDATE teklif_mesajlari SET delivered_at = ? WHERE talep_id IN (${yer}) AND gonderen_id <> ? AND delivered_at IS NULL`,
    ).run(simdi(), ...parca, aliciId);
    for (const x of bekleyen) gonderenler.add(x.gonderen_id);
  }
  for (const g of gonderenler) anlikHaberEkle(g, 'TALEP_DURUM');
  return [...gonderenler];
}
