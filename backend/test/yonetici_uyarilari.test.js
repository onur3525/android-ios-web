// YÖNETİCİ UYARILARI (23 Eki, kullanıcı isteği): yeni talep, yönetici girişi,
// şüpheli giriş denemesi, sistem sorunu ve yavaşlama işletme adresine
// (onur@hizmetcep.com) e-postayla bildirilir; aynı durum için tekrar
// gönderilmez; kullanıcının mesaj metni e-postaya yazılmaz. Panelin bekleyen
// talep sorgusu hareketsizlik süresini uzatmaz.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { simdi } = await import('../src/db.js');
const { denetimYaz } = await import('../src/audit.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { yoneticiUyarilariniIsle, genelDurumTestKaynagi } = await import('../src/yonetici_uyarilari.js');
const { yavaslama, genelDurum } = await import('../src/sistem_izleme.js');

let db;
const ileri = (sn) => new Date(Date.now() + sn * 1000).toISOString();
const uyarilar = () => db.prepare(`SELECT target, subject, body FROM outbound_messages WHERE template = 'YONETICI_UYARISI' ORDER BY created_at, id`).all();
// Aynı milisaniyede yazılan iki e-postanın sırası `id`ye (rastgele) kalır;
// "son e-posta" yerine bir adımda YENİ eklenen konular karşılaştırılır.
/** `once`tan sonra eklenen, konusu `konu` olan e-posta (sıradan bağımsız). */
const konuyla = (u, once, konu) => u.slice(once).find((x) => x.subject === konu);
function yeniKonular(onceki, simdi) {
  const kalan = onceki.map((x) => x.subject);
  return simdi.map((x) => x.subject).filter((k) => {
    const i = kalan.indexOf(k);
    if (i < 0) return true;
    kalan.splice(i, 1);
    return false;
  });
}
async function talepEkle({ no, konu, mesaj, kaynak = 'EMAIL', zaman = ileri(1) }) {
  const id = randomUUID();
  await db.prepare(`INSERT INTO support_tickets (id, ticket_no, user_id, subject, message, status, created_at, updated_at, source, sender_email)
    VALUES (?, ?, NULL, ?, ?, 'OPEN', ?, ?, ?, ?)`).run(id, no, konu, mesaj, zaman, zaman, kaynak, 'gonderen@ornek.com');
  return id;
}
const sistemiYenidenKontrolEttir = () => db.prepare(`DELETE FROM admin_alerts WHERE key = 'kontrol'`).run();

before(async () => { db = await testDb(); });
after(async () => { genelDurumTestKaynagi(null); await db?.close(); });

test('yeni talep: ilk turda geçmiş için uyarı yok; yeni talep tek e-postada; mesaj metni ve gönderen yazmaz; tekrar yok', async () => {
  genelDurumTestKaynagi(async () => ({ overall: { status: 'OK', problems: [] }, apiOlcum: { last15m: { requests: 0 } } }));
  await talepEkle({ no: '900001', konu: 'Eski talep', mesaj: 'eski', zaman: new Date(Date.now() - 60_000).toISOString() });
  await yoneticiUyarilariniIsle(db);
  assert.equal((await uyarilar()).length, 0, 'geçmiş talepler için uyarı gönderilmez');

  await talepEkle({ no: '900002', konu: 'Fatura sorusu', mesaj: 'GİZLİ MESAJ METNİ 05321112233' });
  await yoneticiUyarilariniIsle(db);
  const u = await uyarilar();
  assert.equal(u.length, 1);
  assert.equal(u[0].target, 'onur@hizmetcep.com');
  assert.equal(u[0].subject, 'HizmetCep uyarısı: Yeni talep (No 900002)');
  assert.ok(u[0].body.includes('No 900002') && u[0].body.includes('Fatura sorusu') && u[0].body.includes('e-posta'));
  for (const yasak of ['GİZLİ MESAJ', '05321112233', 'gonderen@ornek.com']) assert.equal(u[0].body.includes(yasak), false, yasak);

  await yoneticiUyarilariniIsle(db);
  assert.equal((await uyarilar()).length, 1, 'aynı talep için ikinci e-posta gitmez');

  // Kullanıcının e-postayla yanıtı da bildirilir.
  const t = await db.prepare(`SELECT id FROM support_tickets WHERE ticket_no = '900002'`).get();
  await db.prepare(`INSERT INTO support_ticket_replies (id, ticket_id, admin_id, body, created_at, author) VALUES (?, ?, NULL, ?, ?, 'USER')`)
    .run(randomUUID(), t.id, 'yanıt metni', ileri(2));
  await yoneticiUyarilariniIsle(db);
  const y = await uyarilar();
  assert.equal(y.length, 2);
  assert.ok(y[1].body.includes('Kullanıcı yanıt yazdı · No 900002'));
  assert.equal(y[1].body.includes('yanıt metni'), false);
});

test('yönetici girişi: her başarılı giriş bildirilir; 15 dakikada 5 hatalı deneme bir kez bildirilir', async () => {
  const once = (await uyarilar()).length;
  await denetimYaz(db, { adminId: null, islem: 'auth.login', ip: '203.0.113.7' });
  await yoneticiUyarilariniIsle(db);
  let u = await uyarilar();
  assert.equal(u.length, once + 1);
  assert.ok(konuyla(u, once, 'HizmetCep uyarısı: Yönetim paneline giriş yapıldı'), 'HizmetCep uyarısı: Yönetim paneline giriş yapıldı');
  assert.ok(konuyla(u, once, 'HizmetCep uyarısı: Yönetim paneline giriş yapıldı').body.includes('203.0.113.7'));
  await yoneticiUyarilariniIsle(db);
  assert.equal((await uyarilar()).length, once + 1, 'aynı giriş ikinci kez bildirilmez');

  for (let i = 0; i < 4; i += 1) await denetimYaz(db, { adminId: null, islem: 'auth.login_failed', ip: '198.51.100.1' });
  await yoneticiUyarilariniIsle(db);
  assert.equal((await uyarilar()).length, once + 1, '4 hatalı deneme eşiğin altında');
  await denetimYaz(db, { adminId: null, islem: 'auth.mfa_failed', ip: '198.51.100.1' });
  await yoneticiUyarilariniIsle(db);
  u = await uyarilar();
  assert.equal(u.length, once + 2);
  assert.ok(konuyla(u, once, 'HizmetCep uyarısı: Şüpheli yönetici girişi denemesi'), 'HizmetCep uyarısı: Şüpheli yönetici girişi denemesi');
  assert.ok(konuyla(u, once, 'HizmetCep uyarısı: Şüpheli yönetici girişi denemesi').body.includes('5 hatalı'));
  await denetimYaz(db, { adminId: null, islem: 'auth.login_failed', ip: '198.51.100.1' });
  await yoneticiUyarilariniIsle(db);
  assert.equal((await uyarilar()).length, once + 2, 'sürdükçe tekrar gönderilmez');
});

test('sistem sorunu: başlayınca, değişince ve düzelince birer e-posta; 15 dakika dolmadan tekrar kontrol edilmez', async () => {
  const once = (await uyarilar()).length;
  let sonuc = { overall: { status: 'PROBLEM', problems: ['Dosya depolamaya erişilemiyor (otomatik kontrol başarısız)'] }, apiOlcum: { last15m: { requests: 0 } } };
  genelDurumTestKaynagi(async () => sonuc);
  await sistemiYenidenKontrolEttir();
  await yoneticiUyarilariniIsle(db);
  let u = await uyarilar();
  assert.equal(u.length, once + 1);
  assert.ok(konuyla(u, once, 'HizmetCep uyarısı: Sistemde sorun var'), 'HizmetCep uyarısı: Sistemde sorun var');
  assert.ok(konuyla(u, once, 'HizmetCep uyarısı: Sistemde sorun var').body.includes('Dosya depolamaya erişilemiyor'));

  // 15 dakika dolmadan kontrol yapılmaz (durum değişse bile).
  sonuc = { overall: { status: 'OK', problems: [] }, apiOlcum: { last15m: { requests: 0 } } };
  await yoneticiUyarilariniIsle(db);
  assert.equal((await uyarilar()).length, once + 1);

  // Aynı sorun sürüyor → e-posta yok; sorun değişti → güncelleme.
  sonuc = { overall: { status: 'PROBLEM', problems: ['Dosya depolamaya erişilemiyor (otomatik kontrol başarısız)'] }, apiOlcum: { last15m: { requests: 0 } } };
  await sistemiYenidenKontrolEttir();
  await yoneticiUyarilariniIsle(db);
  assert.equal((await uyarilar()).length, once + 1);
  sonuc = { overall: { status: 'PROBLEM', problems: ['Dosya depolamaya erişilemiyor (otomatik kontrol başarısız)', 'Bellek kullanımı %95'] }, apiOlcum: { last15m: { requests: 0 } } };
  await sistemiYenidenKontrolEttir();
  await yoneticiUyarilariniIsle(db);
  let onceki = u;
  u = await uyarilar();
  assert.deepEqual(yeniKonular(onceki, u), ['HizmetCep uyarısı: Sistemde sorun var (güncelleme)']);

  // Düzeldi.
  sonuc = { overall: { status: 'WARNING', problems: [] }, apiOlcum: { last15m: { requests: 0 } } };
  await sistemiYenidenKontrolEttir();
  await yoneticiUyarilariniIsle(db);
  onceki = u;
  u = await uyarilar();
  assert.deepEqual(yeniKonular(onceki, u), ['HizmetCep uyarısı: Sistem sorunu düzeldi']);
  const say = u.length;
  await sistemiYenidenKontrolEttir();
  await yoneticiUyarilariniIsle(db);
  assert.equal((await uyarilar()).length, say, 'uyarı (WARNING) durumu e-posta göndermez');
});

test('yavaşlama: ≥20 istekte %20 üstü 1 sn\'den uzun → e-posta; düzelince bildirim; az istekte karar yok', async () => {
  assert.deepEqual(yavaslama({ requests: 19, latency: { under3000: 19, over3000: 0 } }), { yavas: false, oran: null });
  assert.deepEqual(yavaslama({ requests: 40, latency: { under3000: 6, over3000: 2 } }), { yavas: false, oran: 20 });
  assert.deepEqual(yavaslama({ requests: 40, latency: { under3000: 6, over3000: 3 } }), { yavas: true, oran: 22.5 });
  const temel = { veritabaniOk: true, kaynak: { cpu: {}, memory: { percent: 10 } }, yedek: { configured: true, checkOk: true, status: 'AVAILABLE' }, entegrasyonlar: [], silmeTukenen: 0 };
  assert.ok(genelDurum({ ...temel, api: { last15m: { requests: 40, errors5xx: 0, latency: { under3000: 10, over3000: 0 } } } }).warnings
    .includes("Yavaşlama: son 15 dakikada isteklerin %25'i 1 saniyeden uzun sürdü"));

  const once = (await uyarilar()).length;
  let s15 = { requests: 40, avgMs: 900, maxMs: 4200, latency: { under3000: 10, over3000: 2 } };
  genelDurumTestKaynagi(async () => ({ overall: { status: 'WARNING', problems: [] }, apiOlcum: { last15m: s15 } }));
  await sistemiYenidenKontrolEttir();
  await yoneticiUyarilariniIsle(db);
  let u = await uyarilar();
  assert.equal(u.length, once + 1);
  assert.ok(konuyla(u, once, 'HizmetCep uyarısı: Uygulamada yavaşlama'), 'HizmetCep uyarısı: Uygulamada yavaşlama');
  assert.ok(konuyla(u, once, 'HizmetCep uyarısı: Uygulamada yavaşlama').body.includes("%30'i 1 saniyeden uzun"));
  s15 = { requests: 40, avgMs: 120, maxMs: 600, latency: { under3000: 0, over3000: 0 } };
  await sistemiYenidenKontrolEttir();
  await yoneticiUyarilariniIsle(db);
  u = await uyarilar();
  assert.ok(konuyla(u, once, 'HizmetCep uyarısı: Yavaşlama düzeldi'), 'HizmetCep uyarısı: Yavaşlama düzeldi');
});

test('panel sayacı: bekleyen talep sayısı döner; sorgu hareketsizlik süresini UZATMAZ, normal istek uzatır', async () => {
  const sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  const taban = `http://127.0.0.1:${sunucu.address().port}`;
  try {
    const sir = base32Uret();
    await db.prepare('INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .run(randomUUID(), 'sayac@uyari.test', 'Sayaç', 'readonly', sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
    const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 'sayac@uyari.test', password: 'GucluSifre12345' }) });
    const cerez = g.headers.get('set-cookie').split(';')[0];
    assert.equal((await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: cerez, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) })).status, 200);
    const eski = '2000-01-01T00:00:00.000Z';
    const sonGorulme = async () => String((await db.prepare(`SELECT s.last_seen FROM admin_sessions s JOIN admins a ON a.id = s.admin_id WHERE a.email = 'sayac@uyari.test'`).get()).last_seen);
    // Oturum az önce açıldı; last_seen'i bilinen bir değere çekip ölçeriz (süresi dolmasın diye yakın geçmiş).
    const yakin = new Date(Date.now() - 60_000).toISOString();
    await db.prepare(`UPDATE admin_sessions SET last_seen = ? WHERE admin_id = (SELECT id FROM admins WHERE email = 'sayac@uyari.test')`).run(yakin);
    const r = await fetch(`${taban}/admin/v1/support/pending-count`, { headers: { Cookie: cerez } });
    assert.equal(r.status, 200);
    const j = await r.json();
    assert.equal(typeof j.open, 'number');
    assert.ok(j.open >= 2, 'açık talepler sayılır');
    assert.equal(new Date(await sonGorulme()).toISOString(), yakin, 'sayaç sorgusu süreyi uzatmaz');
    assert.equal((await fetch(`${taban}/admin/v1/auth/me`, { headers: { Cookie: cerez } })).status, 200);
    assert.notEqual(new Date(await sonGorulme()).toISOString(), yakin, 'normal istek süreyi uzatır');
    // Süresi dolmuş oturumda sayaç da reddedilir (kilit etkisiz kalmaz).
    await db.prepare(`UPDATE admin_sessions SET last_seen = ? WHERE admin_id = (SELECT id FROM admins WHERE email = 'sayac@uyari.test')`).run(eski);
    assert.equal((await fetch(`${taban}/admin/v1/support/pending-count`, { headers: { Cookie: cerez } })).status, 401);
  } finally {
    sunucu.closeAllConnections?.(); sunucu.close();
  }
});
