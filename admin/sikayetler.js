// ═══════════════════════════════════════════════════════════════
// ŞİKÂYETLER (29 Eki, TASLAK) — Değerlendirmeler ile aynı dil (.dv/.il)
//
// UÇLAR (backend/src/routes/sikayet.js):
//   GET  /admin/v1/reports?status=&targetType=  → en yeni 200 şikâyet (DİZİ)
//     Alanlar: id, targetType (LISTING|USER|REVIEW), targetId, targetOwnerId,
//              reporterId, reason, note, status, resolvedAt, resolutionNote,
//              createdAt, openCountForTarget, target { kind, title?, ilanNo?,
//              text?, stars?, name? (yalnız ad görebilen rol), status, ownerId }
//   POST /admin/v1/reports/:id/resolve { action, reason }
//     REMOVE  → ilan/yorum "Yönetim kaldırdı" (tek tık + gerekçe)
//     SUSPEND → şikâyet edilen hesap askıya alınır
//     DISMISS → işlem gerekmedi
//   Aynı içeriğin bütün açık şikâyetleri birlikte sonuçlanır.
// ═══════════════════════════════════════════════════════════════
import { api, bildir, gerekceIle, h } from './cekirdek.js';

const SINIR = 200;
const DURUMLAR = [['OPEN', 'İncelenmedi'], ['REMOVED', 'Yönetim kaldırdı'], ['SUSPENDED', 'Hesap askıya alındı'], ['DISMISSED', 'İşlem gerekmedi'], ['', 'Tümü']];
const DURUM_ADI = Object.fromEntries(DURUMLAR.filter(([v]) => v));
const NEDEN = { FRAUD: 'Dolandırıcılık', INSULT: 'Hakaret', MISLEADING: 'Yanıltıcı bilgi', OTHER: 'Diğer' };
const KONU = { LISTING: 'İlan', USER: 'Kullanıcı', REVIEW: 'Yorum' };
const SONUCLANDIRABILIR = ['super_admin', 'moderator']; // backend reports.resolve

const tarihSaat = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');

export async function sikayetlerSayfasi(rol) {
  const sonuclandirabilir = SONUCLANDIRABILIR.includes(rol);
  let durum = 'OPEN';
  let istekNo = 0;

  const sekmeler = h('div', { class: 'ku-sekmeler', role: 'tablist' });
  const govde = h('div', {});
  const altBilgi = h('div', { class: 'ku-sayfalama' });

  function sekmeleriCiz() {
    sekmeler.replaceChildren(...DURUMLAR.map(([v, ad]) => h('button', {
      class: `ku-sekme${durum === v ? ' secili' : ''}`, role: 'tab', 'aria-selected': durum === v ? 'true' : 'false',
      onclick: () => { durum = v; sekmeleriCiz(); yukle(); },
    }, ad)));
  }

  function icerik(s) {
    const t = s.target;
    if (!t) return h('span', { class: 'oz-bos' }, 'Kayıt bulunamadı');
    if (t.kind === 'LISTING') {
      return h('div', {}, h('a', { class: 'oz-tumu', href: `#/ilan/${s.targetId}` }, `${t.title ?? 'İlan'}${t.ilanNo ? ` (No: ${t.ilanNo})` : ''} ›`),
        t.text ? h('div', { class: 'dv-yorum' }, t.text) : null);
    }
    if (t.kind === 'REVIEW') {
      return h('div', {}, h('div', { class: 'dv-yorum' }, t.text || 'Yorum yazılmamış'),
        h('a', { class: 'il-sahip', href: `#/kullanici/${t.ownerId}` }, 'Yorumu yazanı aç ›'));
    }
    return h('a', { class: 'il-sahip', href: `#/kullanici/${s.targetId}` }, t.name ?? 'Kullanıcıyı aç ›');
  }

  async function sonuclandir(s, islem) {
    const metin = {
      REMOVE: ['İçerik kaldırılsın mı?', 'Kaldır', s.targetType === 'LISTING'
        ? 'İlan "Yönetim kaldırdı" olur, açık teklifler kapanır; ilan sahibine gerekçeyle bildirim gider. Bu içeriğin bütün açık şikâyetleri kapanır.'
        : 'Yorum yayından kalkar. Bu içeriğin bütün açık şikâyetleri kapanır.'],
      SUSPEND: ['Hesap askıya alınsın mı?', 'Askıya al', 'Şikâyet edilen kişinin hesabı askıya alınır ve oturumları kapanır; kişiye gerekçeyle bildirim gider.'],
      DISMISS: ['İşlem gerekmedi olarak kapatılsın mı?', 'Kapat', 'İçeriğe dokunulmaz; bu içeriğin bütün açık şikâyetleri kapanır.'],
    }[islem];
    const neden = await gerekceIle(...metin);
    if (!neden) return;
    try {
      const r = await api(`/reports/${s.id}/resolve`, { yontem: 'POST', govde: { action: islem, reason: neden } });
      bildir(`${r.closedReports} şikâyet sonuçlandırıldı`);
      await yukle();
    } catch (e) {
      bildir(e.durum === 403 && e.kod !== 'REAUTH_REQUIRED' ? 'Bu işlem için yetkiniz yok.' : e.message, true);
    }
  }

  function islemler(s) {
    if (!sonuclandirabilir || s.status !== 'OPEN') return null;
    const kaldirilabilir = s.targetType !== 'USER' && s.target && !['ADMIN_REMOVED', 'ADMIN_DELETED'].includes(s.target.status);
    return h('div', { class: 'sk-islemler' },
      kaldirilabilir ? h('button', { class: 'btn tehlike il-kaldir', onclick: () => sonuclandir(s, 'REMOVE') }, 'Yönetim kaldırsın') : null,
      h('button', { class: 'btn ikincil il-kaldir', onclick: () => sonuclandir(s, 'SUSPEND') }, 'Hesabı askıya al'),
      h('button', { class: 'btn ikincil il-kaldir', onclick: () => sonuclandir(s, 'DISMISS') }, 'İşlem gerekmedi'));
  }

  const satir = (s) => h('tr', {},
    h('td', { 'data-baslik': 'Konu' }, KONU[s.targetType] ?? s.targetType,
      s.openCountForTarget > 1 && s.status === 'OPEN' ? h('div', { class: 'ku-eposta' }, `${s.openCountForTarget} açık şikâyet`) : null),
    h('td', { 'data-baslik': 'İçerik' }, icerik(s)),
    h('td', { 'data-baslik': 'Neden' }, NEDEN[s.reason] ?? s.reason,
      s.note ? h('div', { class: 'ku-eposta il-neden', title: s.note }, s.note) : null),
    h('td', { 'data-baslik': 'Şikâyet eden' }, h('a', { class: 'il-sahip', href: `#/kullanici/${s.reporterId}` }, 'Kullanıcıyı aç ›')),
    h('td', { 'data-baslik': 'Durum' }, h('span', { class: `ku-durum dv-rozet ${s.status}` }, DURUM_ADI[s.status] ?? s.status),
      s.resolutionNote ? h('div', { class: 'ku-eposta il-neden', title: s.resolutionNote }, s.resolutionNote) : null),
    h('td', { 'data-baslik': 'Tarih', class: 'ku-tarih' }, tarihSaat(s.createdAt),
      s.resolvedAt ? h('div', { class: 'ku-eposta' }, `Sonuç: ${tarihSaat(s.resolvedAt)}`) : null),
    h('td', { 'data-baslik': 'İşlem', class: 'il-islem' }, islemler(s)));

  async function yukle() {
    const no = ++istekNo;
    govde.replaceChildren(h('div', { class: 'il-yukleniyor', role: 'status' }, 'Şikâyetler yükleniyor…'));
    altBilgi.replaceChildren();
    let liste;
    try {
      liste = await api(`/reports${durum ? `?status=${durum}` : ''}`);
    } catch (e) {
      if (no !== istekNo) return;
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, e.durum === 403 ? 'Yetkiniz yok' : 'Şikâyetler yüklenemedi'),
        h('p', { class: 'oz-bos' }, e.durum === 403 ? 'Şikâyetleri görüntüleme yetkiniz bulunmuyor.' : (e.message || 'Beklenmeyen bir hata oluştu.')),
        e.durum === 403 ? null : h('button', { class: 'btn ikincil', onclick: () => yukle() }, 'Tekrar dene')));
      return;
    }
    if (no !== istekNo) return;
    if (!liste.length) {
      govde.replaceChildren(h('div', { class: 'ku-bos' },
        h('div', { class: 'ku-bos-baslik' }, durum === 'OPEN' ? 'İncelenmeyi bekleyen şikâyet yok' : 'Eşleşen şikâyet bulunamadı')));
      return;
    }
    govde.replaceChildren(h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo ku-tablo il-tablo dv-tablo' },
      h('thead', {}, h('tr', {}, ['Konu', 'İçerik', 'Neden', 'Şikâyet eden', 'Durum', 'Tarih', ''].map((b) => h('th', {}, b)))),
      h('tbody', {}, liste.map(satir)))));
    altBilgi.replaceChildren(h('span', { class: 'oz-bos' },
      liste.length >= SINIR ? `En yeni ${SINIR} şikâyet listeleniyor.` : `${liste.length.toLocaleString('tr-TR')} şikâyet listeleniyor.`));
  }

  sekmeleriCiz();
  await yukle();

  return h('div', { class: 'oz ku il dv sk' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Şikâyetler'), h('p', {}, 'Kullanıcıların ilan, profil ve yorumlar için yaptığı şikâyetler; aykırı içeriği gerekçeyle "Yönetim kaldırdı" durumuna alın'))),
    h('section', { class: 'oz-kart' },
      h('div', { class: 'ku-arac' }, sekmeler),
      govde,
      altBilgi));
}
