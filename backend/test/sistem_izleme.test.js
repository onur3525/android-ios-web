// SİSTEM DURUMU ÖLÇÜMLERİ (22 Eki, kullanıcı kuralı)
//   Her gösterge gerçek bir kaynaktan gelir; ölçülemeyen değer null
//   ("ölçülemiyor"), doğrulanamayan yedek "UNVERIFIED" döner. Hiçbir
//   gösterge varsayılan olarak sağlıklı sayılmaz.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { simdi } = await import('../src/db.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { istekOlc, olcumleriYaz, yolDeseni, kaynakTestOkuyucu, yedekTestGetirici, izlemeBakimi, genelDurum, depolamaKontrolEt, depoTestGetirici, epostaKontrolEt, epostaTestGetirici } = await import('../src/sistem_izleme.js');
const { onbellegiTemizle } = await import('../src/entegrasyon.js');
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');

const SIFRE = 'GucluSifre12345';
let db, sunucu, taban;
const cerezler = {};

async function istek(yol, { yontem = 'GET', govde, rol = 'super_admin' } = {}) {
  if (yol.startsWith('/admin/')) await degisiklikOnayi(taban, yol, yontem, cerezler[rol]);
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(yol.startsWith('/admin/') ? { Cookie: cerezler[rol] ?? '', 'X-HC-Admin': '1' } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, ham: m };
}
async function adminGiris(rol) {
  const sir = base32Uret();
  await db.prepare('INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(randomUUID(), `${rol}@izleme.test`, rol, rol, sifreOzetle(SIFRE), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: `${rol}@izleme.test`, password: SIFRE }) });
  const c = g.headers.get('set-cookie').split(';')[0];
  const m = await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  assert.equal(m.status, 200);
  cerezler[rol] = c;
  onayKimligi(c, SIFRE, sir);
}
const durum = async (rol, ek = '') => {
  const r = await istek(`/admin/v1/system/status${ek}`, { rol });
  assert.equal(r.durum, 200, r.ham);
  return r.json;
};

before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  await adminGiris('super_admin');
  await adminGiris('readonly');
});
after(async () => { kaynakTestOkuyucu(null); yedekTestGetirici(null); depoTestGetirici(null); epostaTestGetirici(null); sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('yol deseni: kimlik ve sayılar saklanmaz', () => {
  assert.equal(yolDeseni(`/api/v1/listings/${randomUUID()}/offers/12345`), '/api/v1/listings/:id/offers/:id');
  assert.equal(yolDeseni('/api/v1/users/me'), '/api/v1/users/me');
  assert.equal(yolDeseni('/api/v1/x/ayşe@ornek.com'), '/api/v1/x/:id');
});

test('API ölçümü: gerçek istekler sayılır; 4xx ve 5xx ayrılır; 5xx kaydı kişisel veri taşımaz', async () => {
  const bas = await durum('super_admin');
  assert.equal(bas.apiMetrics.last15m.requests, 0, 'ölçüm yokken sıfır, oran null');
  assert.equal(bas.apiMetrics.last15m.rate5xx, null);
  assert.equal((await istek('/api/v1/config/app?platform=web')).durum, 200);
  assert.equal((await istek('/api/v1/boyle-bir-uc-yok')).durum, 404);
  // Admin istekleri uygulama API'si ölçümüne GİRMEZ.
  await istek('/admin/v1/system/status');
  // Gerçek bir 5xx üretmek için ölçüm girişi doğrudan çağrılır (server.js'in çağırdığı aynı işlev).
  const kimlik = randomUUID();
  istekOlc({ yontem: 'GET', yol: `/api/v1/listings/${kimlik}`, durum: 500, ms: 1234, kod: 'INTERNAL_ERROR', istekId: 'istek-1' });
  const s = await durum('super_admin');
  const p = s.apiMetrics.last15m;
  assert.equal(p.requests, 3);
  assert.equal(p.errors4xx, 1);
  assert.equal(p.errors5xx, 1);
  assert.equal(p.rate5xx, 33.33);
  assert.ok(p.maxMs >= 1234);
  assert.equal(p.latency.under3000, 1, '1234 ms, 1-3 sn kovasında');
  assert.ok(s.apiMetrics.since);
  assert.equal(s.serverErrors.length, 1);
  assert.deepEqual({ ...s.serverErrors[0], at: undefined }, { at: undefined, method: 'GET', path: '/api/v1/listings/:id', status: 500, code: 'INTERNAL_ERROR', requestId: 'istek-1' });
  assert.ok(!JSON.stringify(s.serverErrors).includes(kimlik), 'kayıt kimliği saklanmaz');
});

test('ölçümler örnekler arasında toplanır (aynı dakika satırına eklenir)', async () => {
  const once = Number((await db.prepare('SELECT COALESCE(SUM(requests),0) n FROM api_metrics').get()).n);
  istekOlc({ yontem: 'GET', yol: '/api/v1/a', durum: 200, ms: 10 });
  await olcumleriYaz(db);
  istekOlc({ yontem: 'GET', yol: '/api/v1/b', durum: 200, ms: 20 });
  await olcumleriYaz(db);
  const sonra = Number((await db.prepare('SELECT COALESCE(SUM(requests),0) n FROM api_metrics').get()).n);
  assert.equal(sonra - once, 2);
});

test('CPU/RAM: kapsayıcı ölçümünden hesaplanır; okunamazsa null ve uyarı (uydurulmaz)', async () => {
  let cagri = 0;
  kaynakTestOkuyucu(async () => {
    cagri += 1;
    // 2 çekirdek sınır; iki okuma arasında 0,5 sn'de 0,25 sn CPU → ~0,5 çekirdek → ~%25.
    return { kaynak: 'cgroup v2', cpuUs: cagri === 1 ? 1_000_000 : 1_250_000, cpuLimitCores: 2, memUsed: 256 * 1024 * 1024, memLimit: 512 * 1024 * 1024 };
  });
  const s = await durum('super_admin');
  assert.equal(s.resources.memory.percent, 50);
  assert.equal(s.resources.memory.limitBytes, 512 * 1024 * 1024);
  assert.ok(s.resources.cpu.percent > 15 && s.resources.cpu.percent < 30, `cpu ${s.resources.cpu.percent}`);
  assert.equal(s.resources.cpu.limitCores, 2);
  assert.ok(s.resources.process.rssBytes > 0);
  assert.ok(s.resources.database.sizeBytes > 0, 'veritabanı boyutu gerçek');
  assert.ok(!s.overall.warnings.includes('CPU kullanımı ölçülemiyor'));

  kaynakTestOkuyucu(async () => null);
  const y = await durum('super_admin');
  assert.equal(y.resources.cpu, null);
  assert.equal(y.resources.memory, null);
  assert.ok(y.overall.warnings.includes('CPU kullanımı ölçülemiyor'));
  assert.ok(y.overall.warnings.includes('Kapsayıcı belleği ölçülemiyor'));
  assert.notEqual(y.overall.status, 'OK', 'ölçülemeyen gösterge sağlıklı sayılmaz');

  // Bellek %90 ve üstü: sorun.
  kaynakTestOkuyucu(async () => ({ kaynak: 'cgroup v2', cpuUs: 5, cpuLimitCores: 1, memUsed: 95, memLimit: 100 }));
  assert.equal((await durum('super_admin')).overall.status, 'PROBLEM');
  kaynakTestOkuyucu(null);
});

test('yedekleme: bağlantı yoksa DOĞRULANMADI; okunamazsa da doğrulanmadı sayılır', async () => {
  const s = await durum('super_admin');
  assert.deepEqual(s.backup, { configured: false, status: 'UNVERIFIED' });
  assert.ok(s.overall.warnings.includes('Yedekleme doğrulanmadı (Render bağlantısı yok)'));
  assert.equal((await durum('readonly')).backup, null, 'yetkisiz rol göremez');

  const yanlis = await istek('/admin/v1/system/backup-monitor', { yontem: 'PUT', govde: { postgresId: 'xyz', apiKey: 'rnd_abcdefghijklmnopqrst' } });
  assert.equal(yanlis.durum, 400);
  assert.equal((await istek('/admin/v1/system/backup-monitor', { yontem: 'PUT', govde: { postgresId: 'dpg-abc123def456', apiKey: 'yanlis' } })).durum, 400);
  assert.equal((await istek('/admin/v1/system/backup-monitor', { yontem: 'PUT', rol: 'readonly', govde: { postgresId: 'dpg-abc123def456', apiKey: 'rnd_abcdefghijklmnopqrstuv' } })).durum, 403);

  yedekTestGetirici(async () => ({ status: 401, json: { message: 'unauthorized' } }));
  const okunamadi = await istek('/admin/v1/system/backup-monitor', { yontem: 'PUT', govde: { postgresId: 'dpg-abc123def456', apiKey: 'rnd_GizliAnahtar1234567890' } });
  assert.equal(okunamadi.durum, 200, okunamadi.ham);
  assert.equal(okunamadi.json.checkOk, false);
  assert.equal(okunamadi.json.status, 'UNVERIFIED', 'okunamayan yedek var sayılmaz');
  assert.match(okunamadi.json.checkMessage, /HTTP 401/);
});

test('yedekleme: Render yanıtı gerçek alanlardan okunur; indirme adresi ve anahtar hiçbir yere çıkmaz', async () => {
  const istenen = [];
  yedekTestGetirici(async (yol) => {
    istenen.push(yol);
    if (yol.endsWith('/recovery')) return { status: 200, json: { recoveryStatus: 'AVAILABLE', startsAt: '2026-10-19T00:00:00Z' } };
    return { status: 200, json: [
      { id: 'exp-1', createdAt: '2026-10-20T10:00:00Z', url: 'https://gizli-indirme.ornek/yedek1.tar.gz' },
      { export: { id: 'exp-2', createdAt: '2026-10-21T23:34:00Z', url: 'https://gizli-indirme.ornek/yedek2.tar.gz' } },
    ] };
  });
  const s = await durum('super_admin', '?refreshBackup=1');
  assert.deepEqual(istenen.slice(-2), ['dpg-abc123def456/recovery', 'dpg-abc123def456/export']);
  assert.equal(s.backup.status, 'AVAILABLE');
  assert.equal(s.backup.checkOk, true);
  assert.equal(s.backup.recoveryStartsAt, '2026-10-19T00:00:00Z');
  assert.equal(s.backup.lastExportAt, '2026-10-21T23:34:00Z');
  assert.equal(s.backup.exportCount, 2);
  assert.equal(s.backup.secretHint, '••••7890');
  const tum = JSON.stringify(s) + JSON.stringify(await db.prepare('SELECT * FROM backup_monitor').all()) + JSON.stringify(await db.prepare('SELECT * FROM audit_log').all());
  assert.ok(!tum.includes('gizli-indirme'), 'indirme adresi saklanmaz/dönmez');
  assert.ok(!tum.includes('rnd_GizliAnahtar'), 'API anahtarı düz görünmez');
  assert.ok(!s.overall.warnings.some((w) => /Yedek/.test(w)));

  // Önbellek: 10 dk içinde Render yeniden çağrılmaz.
  const n = istenen.length;
  await durum('super_admin');
  assert.equal(istenen.length, n);

  // Geri yükleme kullanılamıyorsa: SORUN.
  yedekTestGetirici(async (yol) => (yol.endsWith('/recovery') ? { status: 200, json: { recoveryStatus: 'NOT_AVAILABLE' } } : { status: 200, json: [] }));
  const k = await durum('super_admin', '?refreshBackup=1');
  assert.equal(k.backup.status, 'NOT_AVAILABLE');
  assert.equal(k.backup.lastExportAt, null);
  assert.equal(k.overall.status, 'PROBLEM');
  assert.ok(k.overall.problems.includes('Anlık geri yükleme kullanılamıyor'));

  assert.equal((await istek('/admin/v1/system/backup-monitor', { yontem: 'DELETE', govde: { reason: 'test temizliği' } })).durum, 204);
  assert.equal((await durum('super_admin')).backup.configured, false);
});

test('kritik olaylar: yönetici güvenlik olayları ve silme kuyrukları yetkiye bağlı', async () => {
  await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 'super_admin@izleme.test', password: 'yanlis-sifre-1' }) });
  const s = await durum('super_admin');
  assert.ok(s.adminSecurityEvents.some((x) => x.action === 'auth.login_failed' && x.admin === 'super_admin@izleme.test'));
  assert.deepEqual(Object.keys(s.deletionIssues).sort(), ['filesExhausted', 'firebaseLongFailure', 'firebaseOpsLongFailure', 'overdueAccountDeletions']);
  const r = await durum('readonly');
  assert.equal(r.adminSecurityEvents, null);
  assert.equal(r.deletionIssues, null);
  assert.equal(r.serverErrors, null);
  assert.ok(r.resources && r.apiMetrics && r.overall, 'genel göstergeler görünür');
});

test('genel durum kuralları: az istekte oran alarmı yok; %5 ve üstü sorun', () => {
  const temel = { veritabaniOk: true, kaynak: { cpu: {}, memory: { percent: 10 }, disk: { percent: 10 } }, yedek: { configured: true, checkOk: true, status: 'AVAILABLE' }, entegrasyonlar: [], silmeTukenen: 0 };
  assert.equal(genelDurum({ ...temel, api: { last15m: { requests: 0, errors5xx: 0, rate5xx: null } } }).status, 'OK');
  assert.equal(genelDurum({ ...temel, api: { last15m: { requests: 10, errors5xx: 5, rate5xx: 50 } } }).status, 'WARNING');
  assert.equal(genelDurum({ ...temel, api: { last15m: { requests: 40, errors5xx: 2, rate5xx: 5 } } }).status, 'PROBLEM');
  assert.equal(genelDurum({ ...temel, veritabaniOk: false, api: { last15m: { requests: 0 } } }).status, 'PROBLEM');
  assert.equal(genelDurum({ ...temel, silmeTukenen: 2, api: { last15m: { requests: 0 } } }).status, 'WARNING');
});

test('bakım: 30 günden eski ölçüm ve hata kayıtları silinir, yenileri kalır', async () => {
  const eskiKova = Math.floor((Date.now() - 31 * 86_400_000) / 60_000);
  await db.prepare('INSERT INTO api_metrics (bucket, requests) VALUES (?, 5)').run(eskiKova);
  await db.prepare('INSERT INTO api_errors (id, created_at, method, path, status) VALUES (?, ?, ?, ?, ?)').run(randomUUID(), new Date(Date.now() - 31 * 86_400_000).toISOString(), 'GET', '/api/v1/x', 500);
  const once = Number((await db.prepare('SELECT COUNT(*) n FROM api_errors').get()).n);
  const r = await izlemeBakimi(db);
  assert.equal(r.olcum, 1);
  assert.equal(r.hata, 1);
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM api_errors').get()).n), once - 1);
  assert.ok(Number((await db.prepare('SELECT COUNT(*) n FROM api_metrics').get()).n) > 0);
});

// ── 23 Eki (kullanıcı kuralı: "sahte ve varsayım olmamalı") ──
test('sunucu diski gösterilmez (paylaşılan makine); saatlik seri 24 saat ve gerçek', async () => {
  await db.prepare('DELETE FROM api_metrics').run();
  const simdiDk = Math.floor(Date.now() / 60_000);
  await db.prepare('INSERT INTO api_metrics (bucket, requests, errors_5xx, errors_4xx, total_ms, max_ms) VALUES (?, 10, 1, 2, 1000, 400)').run(simdiDk - 5);
  const s = await durum('super_admin');
  assert.equal('disk' in s.resources, false);
  assert.ok(!s.overall.problems.concat(s.overall.warnings).some((x) => /disk/i.test(x)));
  const seri = s.apiMetrics.hourly24h;
  assert.equal(seri.length, 24);
  const dolu = seri.filter((x) => x.requests > 0);
  assert.equal(dolu.length, 1, 'yalnız ölçülen saat dolu; boşluk doldurulmaz');
  assert.deepEqual({ r: dolu[0].requests, e5: dolu[0].errors5xx, e4: dolu[0].errors4xx, ort: dolu[0].avgMs, max: dolu[0].maxMs }, { r: 10, e5: 1, e4: 2, ort: 100, max: 400 });
  assert.ok(seri.filter((x) => !x.requests).every((x) => x.avgMs === null && x.maxMs === null));
});

test('kanallar: gerçek kaynak (panel → sunucu ayarı → yok); geliştirme kaydı ve başarısız gönderim uyarıdır', async () => {
  const s = await durum('super_admin');
  const sms = s.channels.find((x) => x.type === 'SMS');
  // Test ortamında sağlayıcı ortam değişkeninden 'log': gerçek gönderim yok.
  assert.equal(sms.source, 'ortam');
  assert.equal(sms.provider, 'log');
  assert.ok(s.overall.warnings.includes('SMS gerçekten gönderilmiyor (geliştirme kaydı)'));
  const depo = s.channels.find((x) => x.type === 'STORAGE');
  assert.equal(depo.source, 'yok');
  assert.ok(s.overall.warnings.includes('Dosya depolama yapılandırılmamış (panelde ve sunucu ayarında yok)'));
  // Son 24 saatte başarısız SMS → uyarı ve sayı.
  await db.prepare(`INSERT INTO outbound_messages (id, user_id, channel, target, template, subject, body, status, attempts, created_at) VALUES (?, NULL, 'SMS', '-', 'OTP', NULL, '-', 'FAILED', 1, ?)`)
    .run(randomUUID(), new Date().toISOString());
  const y = await durum('super_admin');
  assert.equal(y.failures24h.SMS, 1);
  assert.ok(y.overall.warnings.includes('Son 24 saatte 1 SMS gönderilemedi'));
  // Panel entegrasyonu etkinse kaynak panel olur; sır dönmez.
  const e = await istek('/admin/v1/integrations/effective');
  assert.equal(e.durum, 200);
  assert.deepEqual(e.json.map((x) => x.type), ['SMS', 'EMAIL', 'STORAGE']);
  assert.equal(JSON.stringify(e.json).includes('secret'), false);
  assert.equal((await istek('/admin/v1/integrations/effective', { rol: 'readonly' })).durum, 403);
});

test('genel durum: yapılandırılmamış kanal ve 24 saatlik başarısızlık uyarı; disk kuralı yok', () => {
  const temel = { veritabaniOk: true, api: { last15m: { requests: 0 } }, kaynak: { cpu: {}, memory: { percent: 10 } }, yedek: { configured: true, checkOk: true, status: 'AVAILABLE' }, entegrasyonlar: [], silmeTukenen: 0 };
  assert.equal(genelDurum({ ...temel, kanallar: [{ type: 'SMS', source: 'panel', provider: 'x' }] }).status, 'OK');
  const y = genelDurum({ ...temel, kanallar: [{ type: 'EMAIL', source: 'yok' }], basarisiz24: { SMS: 3 } });
  assert.equal(y.status, 'WARNING');
  assert.deepEqual(y.warnings, ['E-posta yapılandırılmamış (panelde ve sunucu ayarında yok)', 'Son 24 saatte 3 SMS gönderilemedi']);
  assert.equal(genelDurum({ ...temel, kaynak: { ...temel.kaynak, disk: { percent: 99 } } }).status, 'OK', 'disk artık kural değil');
});

test('depolama: 15 dakikada bir otomatik kontrol; depoya yazmaz, adres/anahtar saklanmaz; başarısızlık sorun', async () => {
  const DEPO = { HC_S3_ENDPOINT: 'https://depo.example', HC_S3_BUCKET: 'kova', HC_S3_ACCESS_KEY_ID: 'AKIDKONTROL', HC_S3_SECRET_ACCESS_KEY: 'gizli-depo-anahtari' };
  const eski = Object.fromEntries(Object.keys(DEPO).map((k) => [k, process.env[k]]));
  Object.assign(process.env, DEPO);
  try {
    await db.prepare('DELETE FROM storage_monitor').run();
    const istenen = [];
    depoTestGetirici(async (adres) => { istenen.push(adres); return { status: 404, text: '<?xml version="1.0"?><Error><Code>NoSuchKey</Code></Error>' }; });
    assert.deepEqual(await depolamaKontrolEt(db), { ok: true, mesaj: 'Depoya erişildi' });
    assert.equal(istenen.length, 1);
    assert.ok(istenen[0].startsWith('https://kova.depo.example/_saglik-kontrolu/olmayan-nesne?'), 'olmayan bir nesne istenir');
    assert.ok(istenen[0].includes('X-Amz-Signature='), 'imzalı istek');
    // 15 dakika dolmadan yeniden kontrol edilmez.
    assert.equal(await depolamaKontrolEt(db), null);
    assert.equal(istenen.length, 1);

    const s = await durum('super_admin');
    const depo = s.channels.find((x) => x.type === 'STORAGE');
    assert.equal(depo.source, 'ortam');
    assert.equal(depo.autoCheckOk, true);
    assert.ok(depo.autoCheckAt);
    assert.ok(!s.overall.problems.some((p) => p.startsWith('Dosya depolama')));
    // Yetkisi kısıtlı rol de durumu görür (sonuç metni yalnız yetkiliye).
    const k = (await durum('readonly')).channels.find((x) => x.type === 'STORAGE');
    assert.equal(k.autoCheckOk, true);
    assert.equal('autoCheckMessage' in k, false);

    // Yetki/imza hatası → başarısız → genel durumda sorun.
    depoTestGetirici(async () => ({ status: 403, text: '<Error><Code>SignatureDoesNotMatch</Code></Error>' }));
    assert.deepEqual(await depolamaKontrolEt(db, { zorla: true }), { ok: false, mesaj: 'Depo yanıtı: HTTP 403 · SignatureDoesNotMatch' });
    const y = await durum('super_admin');
    assert.equal(y.channels.find((x) => x.type === 'STORAGE').autoCheckOk, false);
    assert.equal(y.overall.status, 'PROBLEM');
    assert.ok(y.overall.problems.includes('Dosya depolamaya erişilemiyor (otomatik kontrol başarısız)'));

    // Bağlantı hatasında mesajdan imzalı adres çıkarılır.
    depoTestGetirici(async (adres) => { throw new Error(`bağlanamadı ${adres}`); });
    const h = await depolamaKontrolEt(db, { zorla: true });
    assert.equal(h.ok, false);
    assert.ok(h.mesaj.includes('[adres]'));
    const kayit = JSON.stringify(await db.prepare('SELECT * FROM storage_monitor').all());
    for (const yasak of ['AKIDKONTROL', 'gizli-depo-anahtari', 'X-Amz', 'depo.example']) assert.equal(kayit.includes(yasak), false, yasak);
  } finally {
    for (const [k, v] of Object.entries(eski)) { if (v === undefined) delete process.env[k]; else process.env[k] = v; }
    depoTestGetirici(null);
    await db.prepare('DELETE FROM storage_monitor').run();
  }
});

test('depolama yapılandırılmamışsa otomatik kontrol yapılmaz', async () => {
  let cagri = 0;
  depoTestGetirici(async () => { cagri += 1; return { status: 404, text: '<Code>NoSuchKey</Code>' }; });
  assert.equal(await depolamaKontrolEt(db, { zorla: true }), null);
  assert.equal(cagri, 0);
  depoTestGetirici(null);
});

test('e-posta: Resend 15 dakikada bir otomatik kontrol edilir (gönderim yok); alan adı doğrulanmamışsa sorun', async () => {
  // Resend entegrasyonu yokken kontrol yapılmaz.
  let cagri = 0;
  epostaTestGetirici(async () => { cagri += 1; return { status: 200, text: '{"data":[]}' }; });
  assert.equal(await epostaKontrolEt(db, { zorla: true }), null);
  assert.equal(cagri, 0);

  const id = randomUUID();
  await db.prepare(`INSERT INTO integrations (id, type, provider, active, config_json, secret_enc, secret_hint, created_at, updated_at) VALUES (?, 'EMAIL', 'resend', TRUE, ?, ?, '••••test', ?, ?)`)
    .run(id, JSON.stringify({ from: 'HizmetCep <bildirim@hizmetcep.com>' }), sirSifrele(JSON.stringify({ token: 're_gizli_anahtar' })), simdi(), simdi());
  onbellegiTemizle();
  try {
    epostaTestGetirici(async () => ({ status: 200, text: JSON.stringify({ data: [{ name: 'hizmetcep.com', status: 'verified' }] }) }));
    assert.deepEqual(await epostaKontrolEt(db, { zorla: true }), { ok: true, mesaj: 'Resend bağlantısı ve hizmetcep.com alan adı doğrulandı' });
    assert.equal(await epostaKontrolEt(db), null, '15 dakika dolmadan tekrar kontrol yok');
    let k = (await durum('super_admin')).channels.find((x) => x.type === 'EMAIL');
    assert.equal(k.source, 'panel');
    assert.equal(k.autoCheckOk, true);
    // Kısıtlı rol de sonucu görür (ana ekranlar aynı sonucu göstersin).
    assert.equal((await durum('readonly')).channels.find((x) => x.type === 'EMAIL').autoCheckOk, true);

    epostaTestGetirici(async () => ({ status: 401, text: '{"name":"restricted_api_key","message":"x"}' }));
    assert.equal((await epostaKontrolEt(db, { zorla: true })).ok, true, 'yalnız gönderim yetkili anahtar Resend\'ce tanınmıştır');

    epostaTestGetirici(async () => ({ status: 200, text: JSON.stringify({ data: [{ name: 'hizmetcep.com', status: 'pending' }] }) }));
    assert.deepEqual(await epostaKontrolEt(db, { zorla: true }), { ok: false, mesaj: 'hizmetcep.com doğrulanmamış (Resend durumu: pending)' });
    const y = await durum('super_admin');
    assert.equal(y.overall.status, 'PROBLEM');
    assert.ok(y.overall.problems.includes('E-posta sağlayıcısına erişilemiyor (otomatik kontrol başarısız)'));

    epostaTestGetirici(async () => ({ status: 401, text: '{"name":"validation_error"}' }));
    assert.deepEqual(await epostaKontrolEt(db, { zorla: true }), { ok: false, mesaj: 'Resend yanıtı: HTTP 401 · validation_error' });
    const kayit = JSON.stringify(await db.prepare('SELECT * FROM email_monitor').all());
    assert.equal(kayit.includes('re_gizli_anahtar'), false, 'anahtar kayda yazılmaz');
  } finally {
    epostaTestGetirici(null);
    await db.prepare('DELETE FROM integrations WHERE id = ?').run(id);
    await db.prepare('DELETE FROM email_monitor').run();
    onbellegiTemizle();
  }
});

test('ana ekran son 24 saati gösterir: eski hatalar sayıya ve listeye girmez, Kayıtlar sayfasında durur', async () => {
  await db.prepare('DELETE FROM outbound_messages').run();
  const eski = new Date(Date.now() - 2 * 86_400_000).toISOString();
  await db.prepare(`INSERT INTO outbound_messages (id, user_id, channel, target, template, subject, body, status, attempts, created_at) VALUES (?, NULL, 'EMAIL', '-', 'HESAP_ASKIYA_ALINDI', NULL, '-', 'FAILED', 1, ?)`)
    .run(randomUUID(), eski);
  let s = await durum('super_admin');
  assert.deepEqual(s.recentFailures, [], '24 saatten eski hata ana ekranda yok');
  assert.equal(s.delivery.email.FAILED, 0);
  assert.equal(s.channels.find((x) => x.type === 'EMAIL').failed24h, 0);
  assert.equal((await istek('/admin/v1/stats')).json.failedNotifications, 0);
  // Kayıt silinmez: detay (Kayıtlar) sayfasında görünür.
  assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM outbound_messages WHERE status = 'FAILED'`).get()).n), 1);

  await db.prepare(`INSERT INTO outbound_messages (id, user_id, channel, target, template, subject, body, status, attempts, created_at) VALUES (?, NULL, 'EMAIL', '-', 'HESAP_ASKIYA_ALINDI', NULL, '-', 'FAILED', 1, ?)`)
    .run(randomUUID(), new Date().toISOString());
  await db.prepare(`INSERT INTO outbound_messages (id, user_id, channel, target, template, subject, body, status, attempts, created_at) VALUES (?, NULL, 'EMAIL', '-', 'HESAP_ASKIYA_ALINDI', NULL, '-', 'SENT', 1, ?)`)
    .run(randomUUID(), new Date().toISOString());
  s = await durum('super_admin');
  assert.equal(s.recentFailures.length, 1);
  assert.equal(s.delivery.email.FAILED, 1);
  const k = s.channels.find((x) => x.type === 'EMAIL');
  assert.deepEqual({ g: k.sent24h, b: k.failed24h }, { g: 1, b: 1 });
  assert.equal((await istek('/admin/v1/stats')).json.failedNotifications, 1);
});
