// Socket.IO v4 protokolüyle gerçek WebSocket bağlantısı: kimlik, oda yetkisi,
// mesaj olayı, askıda bağlantının kapanması.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { veritabaniAc } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur } = await import('../src/gercek_zamanli.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { oturumlariIptal } = await import('../src/routes/kullanici.js');

let db, sunucu, taban, alan, usta, yabanci, offerId, hub;

async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, { method: yontem, headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: govde ? JSON.stringify(govde) : undefined });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kisi(tel, rol) {
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: 'Kişi', email: `k${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  return { token: r.json.accessToken, id: (await istek('/api/v1/users/me', { token: r.json.accessToken })).json.id };
}

/** Küçük Socket.IO istemcisi (yalnız test). */
function sio(token) {
  const ws = new WebSocket(`${taban.replace('http', 'ws')}/socket.io/?EIO=4&transport=websocket`);
  const gelen = [];
  const bekleyen = [];
  ws.onmessage = (e) => {
    const p = String(e.data);
    if (p === '2') return ws.send('3');
    if (p.startsWith('0')) return ws.send(`40/ws,${JSON.stringify({ token })}`);
    gelen.push(p);
    for (const b of bekleyen.splice(0)) b();
  };
  const kapandi = new Promise((ok) => (ws.onclose = ok));
  const bekle = async (kosul, ms = 3000) => {
    const son = Date.now() + ms;
    while (Date.now() < son) {
      const x = gelen.find(kosul);
      if (x) return x;
      await new Promise((ok) => { bekleyen.push(ok); setTimeout(ok, 50); });
    }
    return null;
  };
  return { ws, gelen, bekle, kapandi, emit: (ad, veri) => ws.send(`42/ws,${JSON.stringify([ad, veri])}`) };
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  hub = gercekZamanliKur(sunucu, db);
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const hiz = (await db.prepare('SELECT name FROM services LIMIT 1').get()).name;
  alan = await kisi('5320000001', 'CUSTOMER');
  usta = await kisi('5320000002', 'PROVIDER');
  yabanci = await kisi('5320000003', 'PROVIDER');
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hiz, location: 'Bayraklı', description: 'kapı kilidi değişecek acil' } });
  offerId = (await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 400, note: '' } })).json.id;
  await istek(`/api/v1/offers/${offerId}/communication`, { yontem: 'POST', token: alan.token });
});
after(async () => {
  hub?.hepsiniKapat();
  sunucu?.closeAllConnections?.();
  sunucu?.close();
  await db?.close();
});

test('geçersiz token: bağlantı reddedilir', async () => {
  const c = sio('gecersiz');
  assert.ok(await c.bekle((p) => p.startsWith('44/ws')));
  await c.kapandi;
});

test('taraf odaya katılır, mesaj anında gelir; yabancı katılamaz', async () => {
  const u = sio(usta.token);
  const y = sio(yabanci.token);
  assert.ok(await u.bekle((p) => p.startsWith('40/ws')));
  assert.ok(await y.bekle((p) => p.startsWith('40/ws')));
  u.emit('conversation.join', { offerId });
  y.emit('conversation.join', { offerId });
  await new Promise((ok) => setTimeout(ok, 100));
  await istek('/api/v1/messages', { yontem: 'POST', token: alan.token, govde: { offerId, text: 'Gerçek zamanlı merhaba', idempotencyKey: randomUUID() } });
  const p = await u.bekle((x) => x.startsWith('42/ws,["message.new"'));
  assert.ok(p, 'usta mesajı almalı');
  assert.equal(JSON.parse(p.slice(6))[1].text, 'Gerçek zamanlı merhaba');
  assert.equal(await y.bekle((x) => x.includes('message.new'), 300), null, 'yabancı almamalı');
  u.ws.close();
  y.ws.close();
});

test('oturumlar iptal edilince (askı/ban) açık soket kapanır', async () => {
  const u = sio(usta.token);
  assert.ok(await u.bekle((p) => p.startsWith('40/ws')));
  await oturumlariIptal(db, usta.id, 'SUSPENDED');
  await u.kapandi;
  assert.ok(true);
});

// ── KVKK takip denetimi E4 (22 Eki): soketler düzenli yeniden doğrulanır ──
const { bakimOnbellegiTemizle } = await import('../src/bakim_modu.js');
const giris = async (tel) => (await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: tel, password: 'sifre1234' } })).json.accessToken;
const acikMi = (b) => b.ws.readyState === WebSocket.OPEN;
const bakim = async (acik) => {
  if (acik) {
    await db.prepare(`INSERT INTO app_config (platform, maintenance_active, maintenance_message, updated_at) VALUES ('web', TRUE, 'Bakım', ?)`).run(new Date().toISOString());
  } else {
    await db.prepare(`DELETE FROM app_config WHERE platform = 'web'`).run();
  }
  bakimOnbellegiTemizle();
};

test('oturum süresi dolunca yeniden doğrulamada soket kapanır; geçerli oturum açık kalır; yeni oturumla yeniden bağlanılır', async () => {
  const k = await kisi('5320000011', 'CUSTOMER');
  const d = await kisi('5320000012', 'CUSTOMER');
  const a = sio(k.token);
  const b = sio(d.token);
  assert.ok(await a.bekle((p) => p.startsWith('40/ws')));
  assert.ok(await b.bekle((p) => p.startsWith('40/ws')));
  await db.prepare('UPDATE user_sessions SET expires_at = ? WHERE user_id = ?').run('2000-01-01T00:00:00.000Z', k.id);
  assert.equal(await hub.yenidenDogrula(), 1);
  await a.kapandi;
  assert.equal(acikMi(b), true, 'geçerli oturumun soketi etkilenmez');
  // Süresi dolmuş oturumun jetonuyla yeniden bağlanma reddedilir…
  const red = sio(k.token);
  assert.ok(await red.bekle((p) => p.startsWith('44/ws')));
  await red.kapandi;
  // …yeni girişin jetonuyla kabul edilir.
  const yeni = sio(await giris('5320000011'));
  assert.ok(await yeni.bekle((p) => p.startsWith('40/ws')));
  yeni.ws.close();
  b.ws.close();
});

test('dondurulan ya da silinen hesabın soketi yeniden doğrulamada kapanır', async () => {
  const k = await kisi('5320000021', 'CUSTOMER');
  const a = sio(k.token);
  assert.ok(await a.bekle((p) => p.startsWith('40/ws')));
  await db.prepare('UPDATE users SET frozen_at = ? WHERE id = ?').run(new Date().toISOString(), k.id);
  assert.equal(await hub.yenidenDogrula(), 1);
  await a.kapandi;
  const s = await kisi('5320000022', 'CUSTOMER');
  const c = sio(s.token);
  assert.ok(await c.bekle((p) => p.startsWith('40/ws')));
  await db.prepare('UPDATE users SET deleted_at = ? WHERE id = ?').run(new Date().toISOString(), s.id);
  assert.equal(await hub.yenidenDogrula(), 1);
  await c.kapandi;
});

test('bakım açılınca listede olmayan hesabın soketi kapanır, yenisi kabul edilmez; bakım test hesabı açık kalır', async () => {
  const n = await kisi('5320000031', 'CUSTOMER');
  const t = await kisi('5320000032', 'CUSTOMER');
  await db.prepare('UPDATE users SET maintenance_bypass = TRUE WHERE id = ?').run(t.id);
  const a = sio(n.token);
  const b = sio(t.token);
  assert.ok(await a.bekle((p) => p.startsWith('40/ws')));
  assert.ok(await b.bekle((p) => p.startsWith('40/ws')));
  await bakim(true);
  try {
    assert.equal(await hub.yenidenDogrula(), 1);
    await a.kapandi;
    assert.equal(acikMi(b), true);
    const red = sio(n.token);
    assert.ok(await red.bekle((p) => p.startsWith('44/ws')), 'bakımda yeni bağlantı reddedilir');
    await red.kapandi;
  } finally {
    await bakim(false);
    b.ws.close();
  }
});

test('veritabanı geçici okunamazsa soketler kapatılmaz', async () => {
  const k = await kisi('5320000041', 'CUSTOMER');
  const a = sio(k.token);
  assert.ok(await a.bekle((p) => p.startsWith('40/ws')));
  const asil = db.prepare.bind(db);
  db.prepare = (sql) => (/FROM user_sessions s JOIN users/.test(sql)
    ? { all: async () => { throw new Error('geçici'); } }
    : asil(sql));
  try {
    assert.equal(await hub.yenidenDogrula(), 0);
  } finally {
    db.prepare = asil;
  }
  assert.equal(acikMi(a), true);
  a.ws.close();
});
