// ═══════════════════════════════════════════════════════════════
// HizmetCep Yönetim — ÇEKİRDEK
//
// ⚠ XSS: kullanıcı verisi DOM'a YALNIZ textContent ile girer; innerHTML
//    hiç kullanılmaz. CSP: script/style yalnız 'self', satır içi yok.
// ⚠ Oturum HttpOnly çerezde (JS göremez). Yazma isteklerinde
//    `X-HC-Admin: 1` (CSRF) gönderilir.
// ⚠ Yetki denetimi SUNUCUDADIR; menüde gizlemek yalnız kolaylıktır.
// ═══════════════════════════════════════════════════════════════

/** Güvenli öğe üretici: h('div', {class:'x', onclick:f}, 'metin', çocuk) */
export function h(etiket, nit = {}, ...cocuklar) {
  const e = document.createElement(etiket);
  for (const [k, v] of Object.entries(nit || {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith('on') && typeof v === 'function') e.addEventListener(k.slice(2), v);
    else if (k === 'class') e.className = v;
    else if (k === 'value') e.value = v;
    else e.setAttribute(k, v === true ? '' : String(v));
  }
  for (const c of cocuklar.flat(Infinity)) {
    if (c === null || c === undefined || c === false) continue;
    e.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return e;
}

export const tarih = (s) => (s ? new Date(s).toLocaleString('tr-TR') : '—');
const DURUM_ADI = {
  ACTIVE: 'Aktif', EXPIRED: 'Süresi doldu', USER_DELETED: 'Sahibi sildi', ADMIN_REMOVED: 'Yönetim kaldırdı',
  SELECTED: 'Seçildi', CLOSED: 'Kapandı', PUBLISHED: 'Yayında', ADMIN_DELETED: 'Yönetim kaldırdı',
  DRAFT: 'Taslak', ARCHIVED: 'Arşiv', PENDING: 'Bekliyor', SENT: 'Gönderildi', FAILED: 'Başarısız',
  COMPLETED: 'Tamamlandı', CANCELLED: 'İptal', BEKLEMEDE: 'Beklemede', TEKLIF_GELDI: 'Teklif geldi',
  SECILDI: 'Seçildi', REDDEDILDI: 'Reddedildi', SURESI_DOLDU: 'Süresi doldu', TAMAMLANDI: 'Tamamlandı',
  aktif: 'Aktif', pasif: 'Pasif',
};
export const rozet = (v, ek) => h('span', { class: `rozet ${ek ?? v}`, title: v }, DURUM_ADI[v] ?? v);

export function bildir(metin, hataMi = false) {
  const e = h('div', { class: `bildirim${hataMi ? ' hata' : ''}`, role: 'status' }, metin);
  document.body.append(e);
  setTimeout(() => e.remove(), 3500);
}

export class ApiHata extends Error {
  constructor(durum, kod, mesaj) { super(mesaj); this.durum = durum; this.kod = kod; }
}

let oturumDustu = () => {};
export function oturumDusunce(f) { oturumDustu = f; }

// ── HAREKETSİZLİK KİLİDİ (21 Eki) ──
// Sunucu oturumu son istekten `idleTimeoutSeconds` (5 dk) sonra kapatır.
// Panel de son başarılı istekten itibaren aynı süreyi sayar; dolunca
// ekrandaki veriyi bırakmadan giriş sayfasına döner.
let sonIstek = Date.now();
let bekci = null;
export function hareketsizlikKilidi(sureSn, kilitle) {
  clearInterval(bekci);
  bekci = null;
  if (!sureSn) return;
  sonIstek = Date.now();
  bekci = setInterval(() => {
    if (Date.now() - sonIstek >= sureSn * 1000) { clearInterval(bekci); bekci = null; kilitle(); }
  }, 5000);
}

/**
 * API çağrısı. ⚠ Her değişiklik (GET dışı) sunucuda şifre + doğrulama kodu
 * ister (tek kullanımlık): REAUTH_REQUIRED gelince ikisi sorulur ve istek
 * bir kez tekrarlanır. Görüntüleme hiç sormaz.
 */
export async function api(yol, { yontem = 'GET', govde, tekrar = true, basliklar = {} } = {}) {
  const r = await fetch(`/admin/v1${yol}`, {
    method: yontem,
    credentials: 'same-origin',
    headers: { ...(govde !== undefined ? { 'Content-Type': 'application/json' } : {}), ...(yontem !== 'GET' ? { 'X-HC-Admin': '1' } : {}), ...basliklar },
    body: govde !== undefined ? JSON.stringify(govde) : undefined,
  });
  if (r.ok) sonIstek = Date.now();
  if (r.status === 204) return null;
  const j = await r.json().catch(() => null);
  if (r.ok) return j;
  const kod = j?.error?.code ?? 'HATA';
  if (kod === 'REAUTH_REQUIRED' && tekrar) {
    const kodGirildi = await yenidenDogrula();
    if (kodGirildi) return api(yol, { yontem, govde, tekrar: false, basliklar });
  }
  if (r.status === 401 && !yol.startsWith('/auth/')) oturumDustu();
  throw new ApiHata(r.status, kod, j?.error?.message ?? 'İşlem başarısız');
}

/** Mevcut şifre + 6 haneli kod sorar ve sunucuda doğrular. */
export const SIFRE_ALANI = { ad: 'password', etiket: 'Mevcut şifreniz', tur: 'password', zorunlu: true, ham: true };
export const KOD_ALANI = { ad: 'code', etiket: 'Doğrulama uygulamasındaki 6 haneli kod', tur: 'text', zorunlu: true, desen: '^\\d{6}$' };
async function yenidenDogrula() {
  const d = await form('Değişikliği onaylayın', [SIFRE_ALANI, KOD_ALANI], 'Onayla',
    { aciklama: 'Güvenliğiniz için her değişiklikte şifreniz ve doğrulama kodunuz istenir.' });
  if (!d) return false;
  try {
    await api('/auth/reauth', { yontem: 'POST', govde: { password: d.password, code: d.code }, tekrar: false });
    return true;
  } catch (e) {
    bildir(e.message, true);
    return false;
  }
}

/** Modal form. alanlar: [{ad, etiket, tur:'text'|'textarea'|'select'|'number'|'checkbox'|'password'|'email', secenekler, deger, zorunlu, desen, ham}] (ham: boşluk kırpılmaz — şifreler) */
export function form(baslik, alanlar, onay = 'Kaydet', { tehlike = false, aciklama } = {}) {
  return new Promise((coz) => {
    const girdiler = {};
    const hataAlani = h('div', { class: 'hata' });
    const kapat = (sonuc) => { perde.remove(); coz(sonuc); };
    const govde = alanlar.map((a) => {
      let g;
      if (a.tur === 'textarea') g = h('textarea', { class: 'genis' }, a.deger ?? '');
      else if (a.tur === 'select') g = h('select', { class: 'genis' }, a.secenekler.map(([v, e]) => h('option', { value: v, ...(String(a.deger) === String(v) ? { selected: true } : {}) }, e)));
      else if (a.tur === 'checkbox') g = h('input', { type: 'checkbox', ...(a.deger ? { checked: true } : {}) });
      else g = h('input', { class: 'genis', type: a.tur ?? 'text', value: a.deger ?? '', autocomplete: 'off' });
      girdiler[a.ad] = g;
      return [h('label', {}, a.etiket), g];
    });
    const gonder = () => {
      const sonuc = {};
      for (const a of alanlar) {
        const g = girdiler[a.ad];
        let v = a.tur === 'checkbox' ? g.checked : g.value;
        if (a.tur === 'number') v = v === '' ? undefined : Number(v);
        if (typeof v === 'string' && !a.ham) v = v.trim();
        if (a.zorunlu && (v === '' || v === undefined)) return (hataAlani.textContent = `${a.etiket} zorunludur`);
        if (a.desen && v && !new RegExp(a.desen).test(v)) return (hataAlani.textContent = `${a.etiket} biçimi geçersiz`);
        sonuc[a.ad] = v;
      }
      kapat(sonuc);
    };
    const perde = h('div', { class: 'perde', role: 'dialog', 'aria-modal': 'true' },
      h('div', { class: 'pencere' },
        h('h3', {}, baslik),
        aciklama ? h('p', { class: 'not' }, aciklama) : null,
        govde, hataAlani,
        h('div', { class: 'tuslar' },
          h('button', { class: 'btn ikincil', onclick: () => kapat(null) }, 'Vazgeç'),
          h('button', { class: `btn${tehlike ? ' tehlike' : ''}`, onclick: gonder }, onay))));
    perde.addEventListener('keydown', (e) => { if (e.key === 'Escape') kapat(null); });
    document.body.append(perde);
    girdiler[alanlar[0]?.ad]?.focus();
  });
}

/** Gerekçe zorunlu işlem onayı. */
export async function gerekceIle(baslik, onay, aciklama) {
  const d = await form(baslik, [{ ad: 'reason', etiket: 'İşlem nedeni (zorunlu, en az 5 karakter)', tur: 'textarea', zorunlu: true }], onay, { tehlike: true, aciklama });
  return d?.reason ?? null;
}

export function bilgiPenceresi(baslik, ...icerik) {
  const perde = h('div', { class: 'perde' },
    h('div', { class: 'pencere' }, h('h3', {}, baslik), ...icerik,
      h('div', { class: 'tuslar' }, h('button', { class: 'btn', onclick: () => perde.remove() }, 'Kapat'))));
  document.body.append(perde);
}

/** Tablo: kolonlar [{baslik, deger: (satir) => metin|Node}], satıra tıklama isteğe bağlı. */
export function tablo(kolonlar, satirlar, tikla) {
  if (!satirlar?.length) return h('p', { class: 'not' }, 'Kayıt yok.');
  return h('div', { class: 'kart' }, h('table', {},
    h('thead', {}, h('tr', {}, kolonlar.map((k) => h('th', {}, k.baslik)))),
    h('tbody', {}, satirlar.map((s) => h('tr', { class: tikla ? 'tikla' : '', onclick: tikla ? () => tikla(s) : null },
      kolonlar.map((k) => h('td', {}, k.deger(s))))))));
}

export function alanlarListesi(ciftler) {
  return h('dl', { class: 'alanlar' }, ciftler.flatMap(([a, d]) => [h('dt', {}, a), h('dd', {}, d ?? '—')]));
}

export async function guvenli(f) {
  try {
    return await f();
  } catch (e) {
    bildir(e.message || 'İşlem başarısız', true);
    return undefined;
  }
}
