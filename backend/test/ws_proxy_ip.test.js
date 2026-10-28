// WEBSOCKET IP SINIRI — PROXY AYARI TANIMLIYKEN (29 Eki, güvenlik planı 2.1)
// Render gibi bir proxy arkasında sunucu bağlantıyı proxy'nin adresinden
// görür. HC_TRUST_PROXY_HOPS=1 iken gerçek istemci adresi, proxy'nin
// X-Forwarded-For başlığının SAĞINA eklediği değerdir; istemcinin kendi
// yazdığı (soldaki) değerler sahtedir ve sayılmaz.
// (Tanımsız durum: ws_sinirlari.test.js — başlık tamamen yok sayılır.)
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import net from 'node:net';
import { randomBytes } from 'node:crypto';

process.env.HC_SESSIZ = '1';
process.env.HC_TRUST_PROXY_HOPS = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur, WS_SINIRLARI, ipAnahtari } = await import('../src/gercek_zamanli.js');
const { istemciIp } = await import('../src/http.js');

let db, sunucu, hub, port;
const sus = (ms) => new Promise((ok) => setTimeout(ok, ms));

/** Proxy'nin eklediği başlığı taklit eden ham WebSocket bağlantısı. */
async function baglan(xff) {
  const c = net.connect(port, '127.0.0.1');
  const durum = { kapandi: false, acildi: false };
  c.on('close', () => { durum.kapandi = true; });
  c.on('error', () => {});
  c.on('data', (d) => { if (String(d).includes('0{"sid"')) durum.acildi = true; });
  c.write(`GET /socket.io/?EIO=4&transport=websocket HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ${randomBytes(16).toString('base64')}\r\nSec-WebSocket-Version: 13\r\nX-Forwarded-For: ${xff}\r\n\r\n`);
  for (let i = 0; i < 100 && !durum.acildi && !durum.kapandi; i++) await sus(10);
  return { c, durum };
}

before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  hub = gercekZamanliKur(sunucu, db);
  await new Promise((ok) => sunucu.listen(0, ok));
  port = sunucu.address().port;
});
after(async () => { hub?.hepsiniKapat(); sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('istemci adresi: proxy\'nin eklediği en sağdaki değer; istemcinin yazdığı sahte değer yok sayılır', () => {
  const req = (xff) => ({ socket: { remoteAddress: '10.0.0.1' }, headers: { 'x-forwarded-for': xff } });
  assert.equal(istemciIp(req('203.0.113.7')), '203.0.113.7');
  assert.equal(istemciIp(req('1.2.3.4, 203.0.113.7')), '203.0.113.7', 'soldaki sahte değer sayılmamalı');
  assert.equal(istemciIp(req('gecersiz')), '10.0.0.1', 'geçersiz değerde soket adresi');
  assert.equal(istemciIp({ socket: { remoteAddress: '10.0.0.1' }, headers: {} }), '10.0.0.1', 'başlık yoksa soket adresi');
});

test('farklı gerçek istemciler ayrı sayılır: biri sınırı doldursa da diğerleri bağlanır', async () => {
  const saldirgan = [];
  for (let i = 0; i < WS_SINIRLARI.IP_BASINA_KIMLIKSIZ; i++) saldirgan.push(await baglan('198.51.100.66'));
  const fazla = await baglan('198.51.100.66');
  for (let i = 0; i < 100 && !fazla.durum.kapandi; i++) await sus(20);
  assert.equal(fazla.durum.kapandi, true, 'aynı istemcinin 21. kimliksiz bağlantısı kapanmalı');
  // Başka bir gerçek kullanıcı (farklı adres) etkilenmez.
  const normal = await baglan('203.0.113.10');
  await sus(200);
  assert.equal(normal.durum.kapandi, false, 'başka istemci engellenmemeli');
  assert.equal(normal.durum.acildi, true);
  for (const w of [...saldirgan, normal]) w.c.destroy();
  await sus(200);
  assert.equal(hub.kimliksizler.size, 0);
});

test('saldırgan solda sahte adresler yazarak sınırı atlatamaz (proxy en sağa gerçek adresi ekler)', async () => {
  const acik = [];
  for (let i = 0; i < WS_SINIRLARI.IP_BASINA_KIMLIKSIZ; i++) acik.push(await baglan(`10.1.1.${i + 1}, 198.51.100.77`));
  const fazla = await baglan('10.1.1.250, 198.51.100.77');
  for (let i = 0; i < 100 && !fazla.durum.kapandi; i++) await sus(20);
  assert.equal(fazla.durum.kapandi, true);
  assert.deepEqual([...hub.kimliksizler.keys()], ['198.51.100.77']);
  for (const w of acik) w.c.destroy();
  await sus(200);
});

test('IPv6: sınır /64 ağı başına — saldırgan adres değiştirerek atlatamaz, başka ağ etkilenmez', async () => {
  assert.equal(ipAnahtari('2001:db8:1:2:3:4:5:6'), '2001:db8:1:2::/64');
  assert.equal(ipAnahtari('2001:DB8:0001:0002::ffff'), '2001:db8:1:2::/64', 'yazım farkı aynı ağ');
  assert.equal(ipAnahtari('203.0.113.7'), '203.0.113.7', 'IPv4 değişmez');
  const acik = [];
  for (let i = 0; i < WS_SINIRLARI.IP_BASINA_KIMLIKSIZ; i++) acik.push(await baglan(`2001:db8:aa:bb::${(i + 1).toString(16)}`));
  const fazla = await baglan('2001:db8:aa:bb::ffff');
  for (let i = 0; i < 100 && !fazla.durum.kapandi; i++) await sus(20);
  assert.equal(fazla.durum.kapandi, true, 'aynı /64 içinde yeni adres sınırı aşmamalı');
  const baska = await baglan('2001:db8:aa:cc::1');
  await sus(200);
  assert.equal(baska.durum.kapandi, false, 'başka /64 ağı engellenmemeli');
  for (const w of [...acik, baska]) w.c.destroy();
  await sus(200);
  assert.equal(hub.kimliksizler.size, 0);
});
