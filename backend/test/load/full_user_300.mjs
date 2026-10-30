// HizmetCep 300 kullanicili izole uctan uca yuk testi.
// Yalniz GitHub Actions icindeki gecici SQLite veritabanina ve yerel sunucuya baglanir.
// Canli Render, gercek SMS/e-posta/FCM veya gercek kullanici verisi kullanilmaz.
process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';

import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { performance } from 'node:perf_hooks';
import { testDb } from '../destek.js';
import { uygulamaKur } from '../../src/server.js';
import { tohumla } from '../../scripts/seed_from_flutter.js';

const db = await testDb();
let server;
let base;
const results = [];
const WEB = { 'Content-Type': 'application/json' };

async function request(path, { method = 'GET', body, token } = {}) {
  const start = performance.now();
  let response;
  try {
    response = await fetch(base + path, {
      method,
      headers: {
        ...(body ? WEB : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(20000),
    });
    const raw = await response.text();
    let json = null;
    try { json = raw ? JSON.parse(raw) : null; } catch {}
    const row = { method, path, status: response.status, ms: performance.now() - start };
    results.push(row);
    if (!response.ok) throw new Error(`${method} ${path}: HTTP ${response.status} ${raw.slice(0, 300)}`);
    return json;
  } catch (error) {
    if (!response) results.push({ method, path, status: 0, ms: performance.now() - start, error: String(error) });
    throw error;
  }
}

async function createUser(index, role) {
  const phone = String(5300000000 + index);
  // Test veritabaninda IP hiz siniri sayaclarini her sahte hesap icin sifirla.
  await db.prepare("DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%' OR key LIKE 'giris_ip:%'").run();
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', phone);
  await request('/api/v1/auth/otp/request', { method: 'POST', body: { phone, purpose: 'REGISTER' } });
  const otpCode = globalThis.__sonOtp;
  assert.match(String(otpCode), /^\\d{6}$/, 'Test OTP kancasi kod uretmedi');
  const registered = await request('/api/v1/auth/register', {
    method: 'POST',
    body: {
      termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true,
      phone, password: 'TestSifre123!', name: `Yuk Test ${index}`,
      email: `hc-load-${index}@example.invalid`, role, otpCode,
    },
  });
  assert.ok(registered?.accessToken, 'Kayit tokeni donmedi');
  const me = await request('/api/v1/users/me', { token: registered.accessToken });
  assert.ok(me?.id, 'Profil ucu kullanici kimligi donmedi');
  return { id: me.id, token: registered.accessToken, role };
}

async function runPair(customer, provider, service, pairNo) {
  const listing = await request('/api/v1/listings', {
    method: 'POST', token: customer.token,
    body: {
      title: service,
      location: 'Karsiyaka, Bostanli',
      description: `300 kullanici yuk testinde ${pairNo} numarali sahte ilan. Hizmet talebi aciklamasi.`,
      workTiming: 'NOW',
    },
  });
  assert.ok(listing?.id, 'Ilan olusturulamadi');

  const offer = await request('/api/v1/offers', {
    method: 'POST', token: provider.token,
    body: { listingId: listing.id, amountTl: 1200 + pairNo, note: 'Yuk testi sahte teklifi' },
  });
  assert.ok(offer?.id, 'Teklif olusturulamadi');

  const selected = await request(`/api/v1/listings/${listing.id}/selected-offer`, {
    method: 'PUT', token: customer.token, body: { offerId: offer.id },
  });
  assert.equal(selected?.selectedOfferId, offer.id, 'Teklif secilemedi');

  const contact = await request(`/api/v1/offers/${offer.id}/communication`, {
    method: 'POST', token: customer.token,
  });
  assert.equal(contact?.open, true, 'Iletisim acilamadi');

  const message = await request('/api/v1/messages', {
    method: 'POST', token: customer.token,
    body: { offerId: offer.id, text: 'Merhaba, yuk testi mesajidir.', idempotencyKey: `hc-load-${pairNo}` },
  });
  assert.ok(message?.id, 'Mesaj gonderilemedi');

  const history = await request(`/api/v1/messages/${offer.id}`, { token: provider.token });
  assert.ok(Array.isArray(history) && history.length >= 1, 'Hizmet veren mesaj gecmisini goremedi');

  const review = await request(`/api/v1/listings/${listing.id}/review`, {
    method: 'POST', token: customer.token,
    body: { stars: 5, text: 'Otomatik yuk testi degerlendirmesi' },
  });
  assert.ok(review, 'Degerlendirme tamamlanamadi');
  return { listingId: listing.id, offerId: offer.id };
}

try {
  await tohumla(db);
  server = createServer(uygulamaKur(db));
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  base = `http://127.0.0.1:${server.address().port}`;

  const catalog = await db.prepare('SELECT name FROM services WHERE deleted_at IS NULL ORDER BY name LIMIT 1').get();
  assert.ok(catalog?.name, 'Test katalogunda hizmet bulunamadi');

  console.log('300 sahte hesap hazirlaniyor (150 hizmet alan + 150 hizmet veren)...');
  const users = [];
  for (let i = 1; i <= 300; i++) {
    users.push(await createUser(i, i <= 150 ? 'CUSTOMER' : 'PROVIDER'));
    if (i % 25 === 0) console.log(`Hesaplar: ${i}/300`);
  }

  console.log('150 eszamanli ilan-teklif-mesaj-degerlendirme akisi baslatiliyor...');
  const started = performance.now();
  const pairs = await Promise.all(Array.from({ length: 150 }, (_, i) =>
    runPair(users[i], users[i + 150], catalog.name, i + 1)
  ));
  const elapsedMs = performance.now() - started;

  const failures = results.filter(x => x.status < 200 || x.status >= 300 || x.error);
  const times = results.map(x => x.ms).sort((a, b) => a - b);
  const percentile = p => Math.round(times[Math.min(times.length - 1, Math.ceil(p * times.length) - 1)]);
  const summary = {
    isolatedTestDatabase: 'SQLite in-memory',
    target: 'local ephemeral backend only',
    virtualUsers: 300,
    customerUsers: 150,
    providerUsers: 150,
    completedBusinessFlows: pairs.length,
    successfulHttpRequests: results.length - failures.length,
    failedHttpRequests: failures.length,
    errorRatePct: +(failures.length / results.length * 100).toFixed(2),
    flowDurationSeconds: +(elapsedMs / 1000).toFixed(2),
    requestRpsDuringFlows: +((results.length) / (elapsedMs / 1000)).toFixed(2),
    p50Ms: percentile(0.50),
    p95Ms: percentile(0.95),
    p99Ms: percentile(0.99),
    maxMs: Math.round(Math.max(...times)),
    failureSamples: failures.slice(0, 10),
  };
  console.log(JSON.stringify(summary, null, 2));
  await import('node:fs/promises').then(async ({ writeFile, mkdir }) => {
    const report = [
      '# HizmetCep 300 kullanicili tam akis testi',
      '',
      '- Ortam: GitHub Actions icinde gecici SQLite + yerel backend.',
      '- Canli sistem, gercek hesap, SMS, e-posta, FCM veya canli depolama kullanilmadi.',
      '- 150 hizmet alan + 150 hizmet veren sahte hesap.',
      '- Her cift: kayit/giris, profil okuma, ilan, teklif, teklif secimi, iletisim, mesaj, mesaj gecmisi ve degerlendirme.',
      '',
      '| Olcum | Sonuc |',
      '|---|---:|',
      ...Object.entries(summary).filter(([k]) => !['failureSamples'].includes(k)).map(([k, v]) => `| ${k} | ${v} |`),
      '',
      failures.length ? '## Hatalar\n\n```json\n' + JSON.stringify(failures.slice(0, 20), null, 2) + '\n```' : '## Sonuc\n\nButun 150 is akisi basariyla tamamlandi.',
      '',
      '> Bu test tam API/is akisi testidir; gercek mobil cihaz arayuzu, harici S3 depolama ve Socket.IO ag katmani performansini kapsamaz.',
    ].join('\n') + '\n')
  );
  if (failures.length) process.exitCode = 1;
} catch (error) {
  console.error(error);
  process.exitCode = 1;
} finally {
  server?.closeAllConnections?.();
  if (server) await new Promise(resolve => server.close(resolve));
  await db.close();
}
