// ═══════════════════════════════════════════════════════════════
// YÖNETİCİ UYARILARI (23 Eki, kullanıcı isteği)
//
// Panel açık olmasa da işletme adresine (config.yoneticiUyariEposta,
// varsayılan onur@hizmetcep.com) e-posta gider:
//   1) Yeni gelen talep (uygulamadan ya da e-postayla) ve kullanıcının açık
//      talebe e-postayla yanıtı — dakikada bir taranır, tek e-postada toplanır.
//   2) Yönetici girişi — her başarılı girişte (saat, hesap, IP).
//   3) Şüpheli yönetici girişi — 15 dakikada 5 ya da daha fazla hatalı
//      şifre/kod denemesi.
//   4) Sistem sorunu — Sistem Durumu'nun genel durumu "Sorun var" olduğunda
//      (aynı kurallar: genel_durum.js); düzelince "düzeldi" e-postası.
//   5) Yavaşlama — sistem_izleme.js › yavaslama kuralı; düzelince bildirilir.
// 4 ve 5 15 dakikada bir kontrol edilir. Aynı durum sürdükçe tekrar e-posta
// GİTMEZ; durum değişirse güncelleme, 24 saat sürerse hatırlatma gider.
//
// ⚠ E-postada kullanıcının mesaj metni, telefonu ya da e-postası YAZMAZ:
// talep numarası, kaynak ve konu yeter; ayrıntı panelde.
// ⚠ Döngü yok: uyarılar bildirim adresinden (Resend "from") gider;
// gelen_eposta.js kendi gönderen adresinden gelen e-postayı talep açmaz.
// ═══════════════════════════════════════════════════════════════
import { gonder } from './bildirim.js';
import { config } from './config.js';
import { simdi } from './db.js';
import { genelDurumGirdileri } from './genel_durum.js';
import { yavaslama } from './sistem_izleme.js';

const DAKIKA = 60_000;
export const SISTEM_KONTROL_ARALIGI = 15 * DAKIKA;
const HATIRLATMA = 24 * 60 * DAKIKA;
export const HATALI_GIRIS = { pencereDk: 15, esik: 5 };
const KAYNAK_ADI = { APP: 'uygulama', EMAIL: 'e-posta' };
const zamanTr = (v) => new Date(v).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
const evet = (v) => v === 1 || v === true;

let testGenelDurum = null;
/** Yalnız testler: genel durum girdileri yerine sabit sonuç. */
export function genelDurumTestKaynagi(f) { testGenelDurum = f; }

async function durumGetir(db, anahtar) {
  const x = await db.prepare('SELECT * FROM admin_alerts WHERE key = ?').get(anahtar);
  return x ? { ...x, active: evet(x.active) } : null;
}
async function durumYaz(db, anahtar, alanlar) {
  const mevcut = await durumGetir(db, anahtar);
  const d = { active: false, since: null, last_sent_at: null, cursor_at: null, detail: null, ...(mevcut ?? {}), ...alanlar };
  await db.prepare(`INSERT INTO admin_alerts (key, active, since, last_sent_at, cursor_at, detail) VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT (key) DO UPDATE SET active = excluded.active, since = excluded.since, last_sent_at = excluded.last_sent_at,
      cursor_at = excluded.cursor_at, detail = excluded.detail`)
    .run(anahtar, d.active ? 1 : 0, d.since, d.last_sent_at, d.cursor_at, d.detail);
}

/** İşletme adresine tek uyarı e-postası (gonder: kaydeder, hiç fırlatmaz). */
export async function uyariGonder(db, konu, paragraflar) {
  const panel = `${config.epostaVarlikKoku.replace(/\/$/, '')}/admin/`;
  return gonder(db, {
    kullaniciId: null, kanal: 'EMAIL', hedef: config.yoneticiUyariEposta, sablon: 'YONETICI_UYARISI',
    degerler: { KONU: konu, METIN: paragraflar.join('\n\n'), PANEL: panel },
  });
}

// ── 1) Yeni talepler ve kullanıcı yanıtları ──
async function talepleriTara(db) {
  const d = await durumGetir(db, 'talepler');
  // İlk çalışma: geçmiş talepler için uyarı gönderilmez; bundan sonrası izlenir.
  if (!d?.cursor_at) return durumYaz(db, 'talepler', { cursor_at: simdi() });
  const imlec = d.cursor_at;
  const yeni = await db.prepare(
    `SELECT ticket_no, subject, source, created_at FROM support_tickets WHERE created_at > ? ORDER BY created_at LIMIT 50`,
  ).all(imlec);
  const yanit = await db.prepare(
    `SELECT t.ticket_no, t.subject, r.created_at FROM support_ticket_replies r JOIN support_tickets t ON t.id = r.ticket_id
      WHERE r.author = 'USER' AND r.created_at > ? ORDER BY r.created_at LIMIT 50`,
  ).all(imlec);
  if (!yeni.length && !yanit.length) return;
  const satirlar = [
    ...yeni.map((t) => `Yeni talep · No ${t.ticket_no} · ${KAYNAK_ADI[t.source] ?? 'uygulama'} · "${t.subject}"`),
    ...yanit.map((t) => `Kullanıcı yanıt yazdı · No ${t.ticket_no} · "${t.subject}"`),
  ];
  const sonZaman = [...yeni, ...yanit].map((x) => String(x.created_at instanceof Date ? x.created_at.toISOString() : x.created_at)).sort().at(-1);
  const konu = yeni.length && !yanit.length
    ? (yeni.length === 1 ? `Yeni talep (No ${yeni[0].ticket_no})` : `${yeni.length} yeni talep`)
    : `Gelen Talepler: ${satirlar.length} yeni hareket`;
  await uyariGonder(db, konu, [...satirlar, 'Talepleri panelde Gelen Talepler bölümünden açabilirsiniz.']);
  await durumYaz(db, 'talepler', { cursor_at: sonZaman, last_sent_at: simdi() });
}

// ── 2) Başarılı yönetici girişleri ──
async function girisleriTara(db) {
  const d = await durumGetir(db, 'giris');
  if (!d?.cursor_at) return durumYaz(db, 'giris', { cursor_at: simdi() });
  const girisler = await db.prepare(
    `SELECT a.created_at, a.ip, ad.email FROM audit_log a LEFT JOIN admins ad ON ad.id = a.admin_id
      WHERE a.action = 'auth.login' AND a.created_at > ? ORDER BY a.created_at LIMIT 20`,
  ).all(d.cursor_at);
  if (!girisler.length) return;
  for (const g of girisler) {
    await uyariGonder(db, 'Yönetim paneline giriş yapıldı', [
      `Yönetim paneline giriş yapıldı: ${g.email ?? 'bilinmeyen hesap'}`,
      `Zaman: ${zamanTr(g.created_at)} · IP: ${g.ip ?? 'bilinmiyor'}`,
      'Bu girişi siz yapmadıysanız hemen panelden şifrenizi değiştirin ve Yöneticiler bölümünden oturumları kontrol edin.',
    ]);
  }
  const son = girisler.at(-1).created_at;
  await durumYaz(db, 'giris', { cursor_at: son instanceof Date ? son.toISOString() : son, last_sent_at: simdi() });
}

// ── 3) Hatalı giriş denemeleri ──
async function hataliGirisleriTara(db) {
  const bas = new Date(Date.now() - HATALI_GIRIS.pencereDk * DAKIKA).toISOString();
  const n = Number((await db.prepare(
    `SELECT COUNT(*) n FROM audit_log WHERE action IN ('auth.login_failed', 'auth.mfa_failed', 'auth.reauth_failed') AND created_at > ?`,
  ).get(bas)).n);
  const d = await durumGetir(db, 'hatali_giris');
  if (n >= HATALI_GIRIS.esik && !d?.active) {
    await uyariGonder(db, 'Şüpheli yönetici girişi denemesi', [
      `Son ${HATALI_GIRIS.pencereDk} dakikada yönetim paneline ${n} hatalı şifre/doğrulama kodu denemesi yapıldı.`,
      'Siz değilseniz panelde Özet › Sistem Durumu › "Yönetici güvenlik olayları" bölümünden denemelerin zamanını ve IP adreslerini görebilirsiniz.',
    ]);
    await durumYaz(db, 'hatali_giris', { active: true, since: simdi(), last_sent_at: simdi(), detail: String(n) });
  } else if (n < HATALI_GIRIS.esik && d?.active) {
    await durumYaz(db, 'hatali_giris', { active: false, since: null, detail: null });
  }
}

// ── 4–5) Sistem sorunu ve yavaşlama (durum makinesi) ──
async function durumUyarisi(db, anahtar, { var: sorunVar, ozet, konuSorun, konuDuzeldi, paragraflar }) {
  const d = await durumGetir(db, anahtar);
  const an = Date.now();
  if (sorunVar) {
    const yeniBasladi = !d?.active;
    const degisti = d?.active && d.detail !== ozet;
    const hatirlat = d?.active && d.last_sent_at && an - Date.parse(d.last_sent_at) >= HATIRLATMA;
    if (yeniBasladi || degisti || hatirlat) {
      const ek = yeniBasladi ? '' : degisti ? ' (güncelleme)' : ' (sürüyor)';
      await uyariGonder(db, konuSorun + ek, paragraflar);
      await durumYaz(db, anahtar, { active: true, since: yeniBasladi ? simdi() : d.since, last_sent_at: simdi(), detail: ozet });
    }
  } else if (d?.active) {
    await uyariGonder(db, konuDuzeldi, [`Düzeldi. Durum ${zamanTr(d.since)} tarihinden beri sürüyordu.`]);
    await durumYaz(db, anahtar, { active: false, since: null, last_sent_at: simdi(), detail: null });
  }
}

async function sistemiKontrolEt(db) {
  const k = await durumGetir(db, 'kontrol');
  if (k?.cursor_at && Date.now() - Date.parse(k.cursor_at) < SISTEM_KONTROL_ARALIGI) return;
  await durumYaz(db, 'kontrol', { cursor_at: simdi() });
  const g = testGenelDurum ? await testGenelDurum() : await genelDurumGirdileri(db);
  const sorunlar = g.overall.status === 'PROBLEM' ? g.overall.problems : [];
  await durumUyarisi(db, 'sistem', {
    var: sorunlar.length > 0, ozet: sorunlar.join(' | '),
    konuSorun: 'Sistemde sorun var', konuDuzeldi: 'Sistem sorunu düzeldi',
    paragraflar: ['Sistem Durumu "Sorun var" gösteriyor:', ...sorunlar.map((s) => `• ${s}`), 'Ayrıntı: panelde Özet › Sistem Durumu.'],
  });
  const yv = yavaslama(g.apiOlcum?.last15m);
  const s15 = g.apiOlcum?.last15m;
  await durumUyarisi(db, 'yavaslama', {
    var: yv.yavas, ozet: 'yavas',
    konuSorun: 'Uygulamada yavaşlama', konuDuzeldi: 'Yavaşlama düzeldi',
    paragraflar: [
      `Son 15 dakikada ${s15?.requests ?? 0} isteğin %${yv.oran}'i 1 saniyeden uzun sürdü (ortalama ${s15?.avgMs ?? '—'} ms, en uzun ${s15?.maxMs ?? '—'} ms).`,
      'Ayrıntı: panelde Özet › Sistem Durumu › "Hata oranları ve yanıt süreleri".',
    ],
  });
}

/** Arka plan işi (server.js, dakikada bir; kilitle yalnız bir örnek çalıştırır). */
export async function yoneticiUyarilariniIsle(db) {
  // Biri hata verirse diğerleri yine çalışır.
  for (const [ad, f] of [['talepler', talepleriTara], ['giris', girisleriTara], ['hatali_giris', hataliGirisleriTara], ['sistem', sistemiKontrolEt]]) {
    try { await f(db); } catch (e) { console.error(`yonetici_uyarisi:${ad}`, e?.message); }
  }
}
