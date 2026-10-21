// ═══════════════════════════════════════════════════════════════
// HESABINI SİLENLER VE DONDURANLAR — tek kaynak (21 Eki)
//
// Özet kartı ve Silme Kuyrukları sayfası AYNI listeyi ve AYNI ayrıntı
// penceresini kullanır. Kaynak: /account-closures (backend kuralları):
//   · Dondurulmuş   — hesap şu an dondurulmuş; kişi yeniden giriş yapıp
//                     etkinleştirince listeden kendiliğinden çıkar.
//   · Silinecek     — silme talebi; yasal süre dolunca otomatik silinir
//                     (kişi iptal ederse listeden çıkar).
//   · Silindi       — kişisel bilgiler silindi; yalnız hesabın silindiği ve
//                     tarihleri görünür (ad gösterilmez).
// ═══════════════════════════════════════════════════════════════
import { alanlarListesi, bilgiPenceresi, h } from './cekirdek.js';

const gun = (v) => (v ? new Date(v).toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—');
const zaman = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');

const DURUM = {
  FROZEN: ['Dondurulmuş', 'askida'],
  DELETION_PENDING: ['Silinecek', 'beklemede'],
  DELETED: ['Silindi', 'silindi'],
};
export const kapatmaDurumu = (k) => h('span', { class: `rozet hk-${k.state}` }, DURUM[k.state]?.[0] ?? k.state);
export const kapatmaAdi = (k) => (k.state === 'DELETED' ? 'Silinmiş hesap' : (k.name || '—'));
/** Listede gösterilen tarih: silinene silinme, silinecek/dondurulana talep tarihi. */
export const kapatmaTarihi = (k) => gun(k.deletedAt ?? k.frozenAt ?? k.requestedAt);

/** Satıra tıklanınca: talep tarihleri ve ayrıntılar. */
export function kapatmaDetayi(k) {
  const satirlar = [
    ['Hesap', kapatmaAdi(k)],
    ['Durum', kapatmaDurumu(k)],
    ['İşlem', k.type === 'FREEZE' ? 'Hesap dondurma' : 'Hesap silme'],
  ];
  if (k.type === 'FREEZE') {
    satirlar.push(['Dondurulma tarihi', zaman(k.frozenAt ?? k.requestedAt)]);
  } else {
    satirlar.push(['Silme talebi tarihi', zaman(k.requestedAt)]);
    satirlar.push([k.state === 'DELETED' ? 'Planlanan silme' : 'Silinecek tarih', zaman(k.scheduledFor)]);
    if (k.state === 'DELETED') satirlar.push(['Silinme tarihi', zaman(k.deletedAt)]);
  }
  if (k.reason) satirlar.push(['Kullanıcının belirttiği neden', k.reason]);
  const aciklama = {
    FROZEN: 'Hesap şu an dondurulmuş: kişi oturum açamaz, aramada görünmez. Yeniden giriş yaptığında hesap etkinleşir ve bu listeden çıkar.',
    DELETION_PENDING: 'Silme talebi yasal sürenin sonunda otomatik uygulanır. Kişi bu süre içinde talebi iptal ederse listeden çıkar.',
    DELETED: 'Kişisel bilgiler (ad, telefon, e-posta, adres, yazdığı içerikler) silindi. Kayıt yalnız hesabın silindiğini ve tarihlerini gösterir.',
  }[k.state];
  bilgiPenceresi(k.type === 'FREEZE' ? 'Hesap dondurma ayrıntısı' : 'Hesap silme ayrıntısı',
    alanlarListesi(satirlar),
    aciklama ? h('p', { class: 'not' }, aciklama) : null,
    k.state !== 'DELETED' ? h('p', {}, h('a', { href: `#/kullanici/${k.userId}`, onclick: () => document.querySelector('.perde')?.remove() }, 'Kullanıcı profiline git ›')) : null);
}
