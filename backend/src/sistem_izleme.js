// ═══════════════════════════════════════════════════════════════
// SİSTEM DURUMU ÖLÇÜMLERİ (22 Eki, kullanıcı kuralı)
//
// ⚠ Her gösterge GERÇEK bir kaynaktan gelir. Ölçülemeyen değer null döner
// ve panelde "ölçülemiyor" yazar; doğrulanmamış yedek "doğrulanmadı" olur.
// Tahmini, varsayılan ya da sabit "sağlıklı" değer ÜRETİLMEZ.
//
//   · API hata oranı / yanıt süresi: /api/v1 isteklerinin dakikalık
//     toplamları (api_metrics). Her örnek bellekte biriktirir, kısa
//     aralıklarla veritabanına EKLER (bütün örnekler aynı satıra).
//   · 5xx kayıtları: api_errors (yol deseni + hata kodu + istek kimliği;
//     kişisel veri, gövde, IP yok).
//   · CPU / RAM: yanıt veren sunucu örneğinin kapsayıcı (cgroup) ölçümü;
//     okunamazsa null. Node sürecinin belleği her zaman ölçülür.
//   · Veritabanı boyutu: gerçek boyut (pg_database_size).
//   · ⚠ SUNUCU DİSKİ GÖSTERİLMEZ (23 Eki, kullanıcı kuralı "sahte ve
//     varsayım olmamalı"): Render'da uygulama paylaşılan bir makinede
//     kapsayıcı olarak çalışır; kapsayıcı içinden `statfs('/')` o makinenin
//     TAMAMINI (başka müşteriler dahil) ölçer, HizmetCep'in kullanımını
//     değil. Uygulama diske veri yazmaz (veritabanı ayrı servis, dosyalar
//     nesne deposunda). Yanıltıcı olduğu için kaldırıldı.
//   · Gönderim kanalları: panel entegrasyonu, yoksa ortam değişkeni, yoksa
//     "yapılandırılmamış" (entegrasyon.js › kanalKaynaklari).
//   · Dosya depolama: sunucu 15 dakikada bir depoya imzalı GET ile olmayan
//     bir nesneyi sorar (yazma YOK); sonuç storage_monitor'da (23 Eki).
//   · Yedekleme: Render API (PITR durumu + dışa aktarmalar). Anahtar
//     girilmemişse "doğrulanmadı". İndirme adresleri hiçbir yere yazılmaz.
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { guvenliIstek } from './ag_guvenligi.js';
import { sirCoz } from './auth.js';
import { depolamaAyari, etkinEntegrasyon, s3ImzaliAdres } from './entegrasyon.js';
import { simdi } from './db.js';

const DAKIKA = 60_000;
const GUN = 24 * 60 * DAKIKA;

// ── İSTEK ÖLÇÜMÜ ─────────────────────────────────────────────
let birikim = new Map(); // bucket → sayaçlar
let hatalar = [];
const AZAMI_BEKLEYEN_HATA = 200;

const kova = (ms) => (ms < 100 ? 'lat_100' : ms < 300 ? 'lat_300' : ms < 1000 ? 'lat_1000' : ms < 3000 ? 'lat_3000' : 'lat_over');

/** Yoldaki kimlikler desene çevrilir: kişisel/kayıt kimliği saklanmaz. */
export function yolDeseni(yol) {
  return String(yol).split('/').map((p) => (
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(p) || /^\d+$/.test(p) || p.length > 40 || /[^A-Za-z0-9_-]/.test(p) ? ':id' : p
  )).join('/').slice(0, 200);
}

/** server.js her /api/v1 yanıtı bittiğinde çağırır. */
export function istekOlc({ yontem, yol, durum, ms, kod, istekId }) {
  // Bakım modundaki bilinçli 503'ler hata sayılmaz (bakim_modu.js).
  if (kod === 'MAINTENANCE') return;
  const b = Math.floor(Date.now() / DAKIKA);
  let x = birikim.get(b);
  if (!x) birikim.set(b, (x = { requests: 0, errors_4xx: 0, errors_5xx: 0, total_ms: 0, max_ms: 0, lat_100: 0, lat_300: 0, lat_1000: 0, lat_3000: 0, lat_over: 0 }));
  const sure = Math.max(0, Math.round(ms));
  x.requests += 1;
  if (durum >= 400 && durum < 500) x.errors_4xx += 1;
  if (durum >= 500) x.errors_5xx += 1;
  x.total_ms += sure;
  x.max_ms = Math.max(x.max_ms, sure);
  x[kova(sure)] += 1;
  if (durum >= 500 && hatalar.length < AZAMI_BEKLEYEN_HATA) {
    hatalar.push({ id: randomUUID(), created_at: simdi(), method: String(yontem).slice(0, 10), path: yolDeseni(yol), status: durum, code: kod ? String(kod).slice(0, 60) : null, request_id: istekId ? String(istekId).slice(0, 60) : null });
  }
}

/** Biriken ölçümleri veritabanına EKLER (örnekler arası toplama). */
export async function olcumleriYaz(db) {
  if (!birikim.size && !hatalar.length) return;
  const b = birikim; const h = hatalar;
  birikim = new Map(); hatalar = [];
  const alanlar = ['requests', 'errors_4xx', 'errors_5xx', 'total_ms', 'lat_100', 'lat_300', 'lat_1000', 'lat_3000', 'lat_over'];
  try {
    for (const [bucket, x] of b) {
      await db.prepare(
        `INSERT INTO api_metrics (bucket, ${alanlar.join(', ')}, max_ms) VALUES (?, ${alanlar.map(() => '?').join(', ')}, ?)
         ON CONFLICT (bucket) DO UPDATE SET ${alanlar.map((a) => `${a} = api_metrics.${a} + excluded.${a}`).join(', ')},
           max_ms = CASE WHEN excluded.max_ms > api_metrics.max_ms THEN excluded.max_ms ELSE api_metrics.max_ms END`,
      ).run(bucket, ...alanlar.map((a) => x[a]), x.max_ms);
    }
    for (const e of h) {
      await db.prepare('INSERT INTO api_errors (id, created_at, method, path, status, code, request_id) VALUES (?, ?, ?, ?, ?, ?, ?)')
        .run(e.id, e.created_at, e.method, e.path, e.status, e.code, e.request_id);
    }
  } catch (e) {
    // Ölçüm yazılamadı: kaybolmasın diye geri konur (sonraki turda denenir).
    for (const [bucket, x] of b) {
      const y = birikim.get(bucket);
      if (!y) birikim.set(bucket, x);
      else for (const k of Object.keys(x)) y[k] = k === 'max_ms' ? Math.max(y[k], x[k]) : y[k] + x[k];
    }
    hatalar = [...h, ...hatalar].slice(0, AZAMI_BEKLEYEN_HATA);
    throw e;
  }
}

/** Ölçüm penceresinin özeti (dk). Hiç istek yoksa oranlar null. */
async function pencereOzeti(db, dakika) {
  const bas = Math.floor(Date.now() / DAKIKA) - dakika + 1;
  const r = await db.prepare(
    `SELECT COALESCE(SUM(requests),0) requests, COALESCE(SUM(errors_4xx),0) e4, COALESCE(SUM(errors_5xx),0) e5,
            COALESCE(SUM(total_ms),0) total_ms, COALESCE(MAX(max_ms),0) max_ms,
            COALESCE(SUM(lat_100),0) l100, COALESCE(SUM(lat_300),0) l300, COALESCE(SUM(lat_1000),0) l1000,
            COALESCE(SUM(lat_3000),0) l3000, COALESCE(SUM(lat_over),0) lover
       FROM api_metrics WHERE bucket >= ?`,
  ).get(bas);
  const n = Number(r.requests);
  const oran = (x) => (n ? Math.round((Number(x) / n) * 10000) / 100 : null);
  return {
    minutes: dakika, requests: n,
    errors4xx: Number(r.e4), errors5xx: Number(r.e5), rate4xx: oran(r.e4), rate5xx: oran(r.e5),
    avgMs: n ? Math.round(Number(r.total_ms) / n) : null, maxMs: n ? Number(r.max_ms) : null,
    latency: { under100: Number(r.l100), under300: Number(r.l300), under1000: Number(r.l1000), under3000: Number(r.l3000), over3000: Number(r.lover) },
  };
}

/**
 * Son 24 saatin SAAT SAAT gerçek ölçümü (grafik için, 23 Eki). Ölçülmeyen
 * saat (istek yok ya da ölçüm başlamadan önce) requests=0, avgMs=null;
 * değer uydurulmaz, boşluk doldurulmaz.
 */
async function saatlikSeri(db) {
  const simdiDk = Math.floor(Date.now() / DAKIKA);
  const bas = simdiDk - 24 * 60 + 1;
  const seri = Array.from({ length: 24 }, (_, i) => ({
    start: new Date((bas + i * 60) * DAKIKA).toISOString(), requests: 0, errors5xx: 0, errors4xx: 0, totalMs: 0, maxMs: 0,
  }));
  for (const r of await db.prepare('SELECT bucket, requests, errors_4xx, errors_5xx, total_ms, max_ms FROM api_metrics WHERE bucket >= ?').all(bas)) {
    const i = Math.floor((Number(r.bucket) - bas) / 60);
    if (i < 0 || i > 23) continue;
    const x = seri[i];
    x.requests += Number(r.requests); x.errors5xx += Number(r.errors_5xx); x.errors4xx += Number(r.errors_4xx);
    x.totalMs += Number(r.total_ms); x.maxMs = Math.max(x.maxMs, Number(r.max_ms));
  }
  return seri.map(({ totalMs, ...x }) => ({ ...x, avgMs: x.requests ? Math.round(totalMs / x.requests) : null, maxMs: x.requests ? x.maxMs : null }));
}

export async function apiOlcumleri(db) {
  const ilk = await db.prepare('SELECT MIN(bucket) b FROM api_metrics').get();
  return {
    since: ilk?.b === null || ilk?.b === undefined ? null : new Date(Number(ilk.b) * DAKIKA).toISOString(),
    last15m: await pencereOzeti(db, 15),
    last1h: await pencereOzeti(db, 60),
    last24h: await pencereOzeti(db, 24 * 60),
    hourly24h: await saatlikSeri(db),
  };
}

export async function sonSunucuHatalari(db, adet = 20) {
  return (await db.prepare('SELECT created_at, method, path, status, code, request_id FROM api_errors ORDER BY created_at DESC LIMIT ?').all(adet))
    .map((x) => ({ at: x.created_at, method: x.method, path: x.path, status: Number(x.status), code: x.code, requestId: x.request_id }));
}

// ── KAYNAK KULLANIMI (CPU / RAM / disk) ──────────────────────
const oku = async (yol) => { try { return (await readFile(yol, 'utf8')).trim(); } catch { return null; } };
const sayi = (v) => (v === null || v === undefined || v === '' || v === 'max' || !Number.isFinite(Number(v)) ? null : Number(v));

/** cgroup v2, yoksa v1. Okunamayan alan null (uydurulmaz). */
async function cgroupOku() {
  const v2 = await oku('/sys/fs/cgroup/cpu.stat');
  if (v2 !== null) {
    const kullanim = sayi(/usage_usec (\d+)/.exec(v2)?.[1]); // µs
    const [kota, periyot] = String(await oku('/sys/fs/cgroup/cpu.max') ?? '').split(/\s+/);
    return {
      kaynak: 'cgroup v2', cpuUs: kullanim,
      cpuLimitCores: sayi(kota) && sayi(periyot) ? sayi(kota) / sayi(periyot) : null,
      memUsed: sayi(await oku('/sys/fs/cgroup/memory.current')),
      memLimit: sayi(await oku('/sys/fs/cgroup/memory.max')),
    };
  }
  const v1 = await oku('/sys/fs/cgroup/cpuacct/cpuacct.usage');
  if (v1 !== null) {
    const kota = sayi(await oku('/sys/fs/cgroup/cpu/cpu.cfs_quota_us'));
    const periyot = sayi(await oku('/sys/fs/cgroup/cpu/cpu.cfs_period_us'));
    const sinir = sayi(await oku('/sys/fs/cgroup/memory/memory.limit_in_bytes'));
    return {
      kaynak: 'cgroup v1', cpuUs: sayi(v1) === null ? null : sayi(v1) / 1000,
      cpuLimitCores: kota && kota > 0 && periyot ? kota / periyot : null,
      memUsed: sayi(await oku('/sys/fs/cgroup/memory/memory.usage_in_bytes')),
      // v1'de sınırsız bellek çok büyük bir sayı olarak görünür: sınır yok sayılır.
      memLimit: sinir && sinir < 2 ** 60 ? sinir : null,
    };
  }
  return null;
}

const bekle = (ms) => new Promise((ok) => setTimeout(ok, ms));
let testCgroup = null;
/** Yalnız testler: cgroup okuyucusunu değiştirir. */
export function kaynakTestOkuyucu(f) { testCgroup = f; }

/** Anlık ölçüm: CPU, iki okuma arasındaki gerçek kullanımdan hesaplanır. */
export async function kaynakKullanimi(db, { aralikMs = 500 } = {}) {
  const okuyucu = testCgroup ?? cgroupOku;
  const a = await okuyucu();
  const t0 = process.hrtime.bigint();
  const s0 = process.cpuUsage();
  await bekle(aralikMs);
  const b = await okuyucu();
  const gecenUs = Number(process.hrtime.bigint() - t0) / 1000;
  const s1 = process.cpuUsage(s0);

  let cpu = null;
  if (a?.cpuUs !== null && a?.cpuUs !== undefined && b?.cpuUs !== null && b?.cpuUs !== undefined && gecenUs > 0) {
    const cekirdek = (b.cpuUs - a.cpuUs) / gecenUs;
    cpu = {
      source: b.kaynak, usedCores: Math.round(cekirdek * 1000) / 1000,
      limitCores: b.cpuLimitCores,
      percent: b.cpuLimitCores ? Math.round((cekirdek / b.cpuLimitCores) * 1000) / 10 : null,
    };
  }
  const bellek = b && b.memUsed !== null ? {
    source: b.kaynak, usedBytes: b.memUsed, limitBytes: b.memLimit,
    percent: b.memLimit ? Math.round((b.memUsed / b.memLimit) * 1000) / 10 : null,
  } : null;

  let veritabani = null;
  try {
    if (db.surucu === 'postgres') {
      veritabani = { sizeBytes: Number((await db.prepare('SELECT pg_database_size(current_database()) AS n').get()).n) };
    } else {
      const sayfa = await db.prepare('PRAGMA page_count').get();
      const boy = await db.prepare('PRAGMA page_size').get();
      veritabani = { sizeBytes: Number(Object.values(sayfa)[0]) * Number(Object.values(boy)[0]) };
    }
  } catch { veritabani = null; }

  return {
    measuredAt: simdi(),
    scope: 'Yanıt veren sunucu örneği',
    cpu,
    memory: bellek,
    process: {
      rssBytes: process.memoryUsage().rss,
      cpuPercentOfOneCore: gecenUs > 0 ? Math.round(((s1.user + s1.system) / gecenUs) * 1000) / 10 : null,
    },
    database: veritabani,
  };
}

// ── YEDEKLEME (Render API) ───────────────────────────────────
const RENDER_API = 'https://api.render.com/v1/postgres/';
const YEDEK_ONBELLEK = 10 * DAKIKA;
let testRender = null;
/** Yalnız testler: Render API yerine (yol) → { status, json }. */
export function yedekTestGetirici(f) { testRender = f; }

async function renderGetir(postgresId, anahtar, ek) {
  const yol = `${encodeURIComponent(postgresId)}/${ek}`;
  if (testRender) return testRender(yol);
  const r = await guvenliIstek(RENDER_API + yol, { headers: { Authorization: `Bearer ${anahtar}`, Accept: 'application/json' }, timeoutMs: 8000 });
  let json = null;
  try { json = JSON.parse(r.text); } catch { json = null; }
  return { status: r.status, json };
}

/** Render'dan okur ve sonucu kaydeder. İndirme adresi saklanmaz/döndürülmez. */
export async function yedegiKontrolEt(db) {
  const m = await db.prepare('SELECT * FROM backup_monitor WHERE id = 1').get();
  if (!m) return null;
  let ok = false; let mesaj = ''; let durum = null; let baslangic = null; let sonDisa = null; let disaSayisi = null;
  try {
    const anahtar = JSON.parse(sirCoz(m.secret_enc)).apiKey;
    const r1 = await renderGetir(m.postgres_id, anahtar, 'recovery');
    if (r1.status !== 200 || !r1.json) throw new Error(`Render geri yükleme bilgisi: HTTP ${r1.status}`);
    durum = typeof r1.json.recoveryStatus === 'string' ? r1.json.recoveryStatus.slice(0, 40) : null;
    baslangic = typeof r1.json.startsAt === 'string' ? r1.json.startsAt.slice(0, 40) : null;
    if (!durum) throw new Error('Render yanıtında geri yükleme durumu yok');
    const r2 = await renderGetir(m.postgres_id, anahtar, 'export');
    if (r2.status !== 200 || !Array.isArray(r2.json)) throw new Error(`Render dışa aktarma listesi: HTTP ${r2.status}`);
    const tarihler = r2.json.map((x) => (x?.export ?? x)?.createdAt).filter((t) => typeof t === 'string' && !Number.isNaN(Date.parse(t))).sort();
    disaSayisi = tarihler.length;
    sonDisa = tarihler.at(-1) ?? null;
    ok = true;
    mesaj = 'Render API okundu';
  } catch (e) {
    mesaj = String(e.message).slice(0, 200);
  }
  await db.prepare(`UPDATE backup_monitor SET checked_at = ?, check_ok = ?, check_message = ?, recovery_status = ?, recovery_starts_at = ?, last_export_at = ?, export_count = ? WHERE id = 1`)
    .run(simdi(), ok ? 1 : 0, mesaj, ok ? durum : null, ok ? baslangic : null, ok ? sonDisa : null, ok ? disaSayisi : null);
  return true;
}

/** Panel görünümü. Bağlantı yoksa configured:false ("doğrulanmadı"). */
export async function yedekDurumu(db, { yenile = false } = {}) {
  let m = await db.prepare('SELECT * FROM backup_monitor WHERE id = 1').get();
  if (!m) return { configured: false, status: 'UNVERIFIED' };
  if (yenile || !m.checked_at || Date.now() - Date.parse(m.checked_at) > YEDEK_ONBELLEK) {
    await yedegiKontrolEt(db);
    m = await db.prepare('SELECT * FROM backup_monitor WHERE id = 1').get();
  }
  const basarili = m.check_ok === 1 || m.check_ok === true;
  return {
    configured: true, provider: m.provider, postgresId: m.postgres_id, secretHint: m.secret_hint,
    checkedAt: m.checked_at, checkOk: basarili, checkMessage: m.check_message,
    // Okunamadıysa durum bilinmiyor: UNVERIFIED (asla "var" sayılmaz).
    status: basarili ? (m.recovery_status ?? 'UNVERIFIED') : 'UNVERIFIED',
    recoveryStartsAt: basarili ? m.recovery_starts_at : null,
    lastExportAt: basarili ? m.last_export_at : null,
    exportCount: basarili && m.export_count !== null ? Number(m.export_count) : null,
  };
}

// ── DOSYA DEPOLAMA OTOMATİK KONTROLÜ (23 Eki) ─────────────────
// Kullanıcı isteği: depolama durumu düğmeye basmadan, 15 dakikada bir
// otomatik doğrulansın. Kontrol depoya HİÇBİR ŞEY YAZMAZ: olmayan bir
// nesne imzalı GET ile istenir. "NoSuchKey" (404) yanıtı, anahtarın geçerli
// ve klasörün erişilebilir olduğunu kanıtlar; imza/yetki/klasör hatası
// başarısız sayılır. Adres, anahtar ve imza hiçbir yere yazılmaz.
export const DEPO_KONTROL_ARALIGI = 15 * DAKIKA;
const DEPO_KONTROL_ANAHTARI = '_saglik-kontrolu/olmayan-nesne';
let testDepo = null;
/** Yalnız testler: depo isteği yerine (adres) → { status, text }. */
export function depoTestGetirici(f) { testDepo = f; }

/** Hata metninden adresleri (imza ve anahtar kimliği içerir) çıkarır. */
const adressiz = (m) => String(m).replace(/https?:\/\/\S+/g, '[adres]').slice(0, 200);

/**
 * Depolamayı kontrol eder; son kontrol 15 dakikadan yeniyse (zorla değilse)
 * hiçbir şey yapmaz. Depolama yapılandırılmamışsa kontrol edilecek şey yok.
 * @returns {Promise<{ok:boolean, mesaj:string}|null>}
 */
export async function depolamaKontrolEt(db, { zorla = false } = {}) {
  const ayar = await depolamaAyari(db);
  if (!ayar) return null;
  if (!zorla) {
    const m = await db.prepare('SELECT checked_at FROM storage_monitor WHERE id = 1').get();
    if (m && Date.now() - Date.parse(m.checked_at) < DEPO_KONTROL_ARALIGI) return null;
  }
  let ok = false; let mesaj = '';
  try {
    const adres = s3ImzaliAdres(ayar, { yontem: 'GET', anahtar: DEPO_KONTROL_ANAHTARI, sureSn: 60 });
    const r = testDepo ? await testDepo(adres) : await guvenliIstek(adres, { method: 'GET', timeoutMs: 8000 });
    const kod = /<Code>([A-Za-z]{1,64})<\/Code>/.exec(r.text ?? '')?.[1] ?? null;
    if ((r.status === 404 && kod === 'NoSuchKey') || r.status === 200) {
      ok = true;
      mesaj = 'Depoya erişildi';
    } else {
      mesaj = `Depo yanıtı: HTTP ${r.status}${kod ? ` · ${kod}` : ''}`;
    }
  } catch (e) {
    mesaj = adressiz(e.message);
  }
  const an = simdi();
  await db.prepare(`INSERT INTO storage_monitor (id, checked_at, check_ok, check_message) VALUES (1, ?, ?, ?)
    ON CONFLICT (id) DO UPDATE SET checked_at = excluded.checked_at, check_ok = excluded.check_ok, check_message = excluded.check_message`)
    .run(an, ok ? 1 : 0, mesaj);
  return { ok, mesaj };
}

// ── E-POSTA OTOMATİK KONTROLÜ (23 Eki) ───────────────────────
// Kullanıcı isteği: "test et" demeden e-posta durumu otomatik bilinsin.
// Panelde etkin Resend entegrasyonu varsa 15 dakikada bir Resend'in alan adı
// listesi okunur (E-POSTA GÖNDERİLMEZ). Gönderen adresin alan adı Resend'de
// "verified" ise kanıt tamam. Anahtar yalnız gönderim yetkiliyse (Resend
// "restricted_api_key") alan adı okunamaz ama anahtar Resend'ce tanınmıştır:
// bu durum açıkça yazılır. Diğer sağlayıcılar (webhook) gönderim yapmadan
// doğrulanamaz; onlar için kontrol yapılmaz.
const RESEND_ALAN_ADLARI = 'https://api.resend.com/domains';
let testEposta = null;
/** Yalnız testler: Resend isteği yerine () → { status, text }. */
export function epostaTestGetirici(f) { testEposta = f; }

export async function epostaKontrolEt(db, { zorla = false } = {}) {
  const e = await etkinEntegrasyon(db, 'EMAIL');
  if (!e || e.provider !== 'resend') return null;
  if (!zorla) {
    const m = await db.prepare('SELECT checked_at FROM email_monitor WHERE id = 1').get();
    if (m && Date.now() - Date.parse(m.checked_at) < DEPO_KONTROL_ARALIGI) return null;
  }
  let ok = false; let mesaj = '';
  try {
    if (!e.secret?.token) throw new Error('Resend API anahtarı girilmemiş');
    const alan = /@([^>\s]+)/.exec(String(e.config?.from ?? ''))?.[1]?.toLowerCase() ?? null;
    const r = testEposta ? await testEposta() : await guvenliIstek(RESEND_ALAN_ADLARI, { headers: { Authorization: `Bearer ${e.secret.token}` }, timeoutMs: 8000 });
    let j = null;
    try { j = JSON.parse(r.text); } catch { j = null; }
    if (r.status === 200 && Array.isArray(j?.data)) {
      const d = alan ? j.data.find((x) => String(x?.name ?? '').toLowerCase() === alan) : null;
      if (!alan) mesaj = 'Gönderen adresi tanımlı değil';
      else if (!d) mesaj = `${alan} Resend'de kayıtlı değil`;
      else if (d.status !== 'verified') mesaj = `${alan} doğrulanmamış (Resend durumu: ${String(d.status).slice(0, 30)})`;
      else { ok = true; mesaj = `Resend bağlantısı ve ${alan} alan adı doğrulandı`; }
    } else if (r.status === 401 && j?.name === 'restricted_api_key') {
      ok = true;
      mesaj = 'Resend anahtarı geçerli (yalnız gönderim yetkili; alan adı durumu okunamadı)';
    } else {
      mesaj = `Resend yanıtı: HTTP ${r.status}${j?.name ? ` · ${String(j.name).slice(0, 40)}` : ''}`;
    }
  } catch (h) {
    mesaj = adressiz(h.message);
  }
  await db.prepare(`INSERT INTO email_monitor (id, checked_at, check_ok, check_message) VALUES (1, ?, ?, ?)
    ON CONFLICT (id) DO UPDATE SET checked_at = excluded.checked_at, check_ok = excluded.check_ok, check_message = excluded.check_message`)
    .run(simdi(), ok ? 1 : 0, mesaj);
  return { ok, mesaj };
}

// ── KRİTİK OLAYLAR ───────────────────────────────────────────
export async function yoneticiGuvenlikOlaylari(db) {
  const gun = new Date(Date.now() - GUN).toISOString();
  return (await db.prepare(
    `SELECT a.action, a.created_at, a.ip, ad.email FROM audit_log a LEFT JOIN admins ad ON ad.id = a.admin_id
      WHERE a.action IN ('auth.login_failed', 'auth.mfa_failed', 'auth.reauth_failed') AND a.created_at > ?
      ORDER BY a.created_at DESC LIMIT 20`,
  ).all(gun)).map((x) => ({ action: x.action, at: x.created_at, admin: x.email ?? null, ip: x.ip ?? null }));
}

/** Teknik kayıt bakımı: 30 günden eski ölçüm ve hata kayıtları silinir. */
export async function izlemeBakimi(db) {
  const otuz = Math.floor((Date.now() - 30 * GUN) / DAKIKA);
  const a = (await db.prepare('DELETE FROM api_metrics WHERE bucket < ?').run(otuz)).changes ?? 0;
  const b = (await db.prepare('DELETE FROM api_errors WHERE created_at < ?').run(new Date(Date.now() - 30 * GUN).toISOString())).changes ?? 0;
  return { olcum: a, hata: b };
}

// ── YAVAŞLAMA (23 Eki, kullanıcı isteği) ─────────────────────
// Kural: son 15 dakikada en az 20 istek varsa ve isteklerin %20'den fazlası
// 1 saniyeden uzun sürdüyse "yavaşlama". Az istekte oran anlamsız olduğu için
// karar verilmez. Panel (uyarı) ve e-posta uyarısı aynı kuralı kullanır.
export const YAVAS_ESIK = { enAzIstek: 20, ms: 1000, yuzde: 20 };
export function yavaslama(s15) {
  const n = Number(s15?.requests ?? 0);
  if (n < YAVAS_ESIK.enAzIstek || !s15?.latency) return { yavas: false, oran: null };
  const yavasSayi = Number(s15.latency.under3000 ?? 0) + Number(s15.latency.over3000 ?? 0);
  const oran = Math.round((yavasSayi / n) * 1000) / 10;
  return { yavas: oran > YAVAS_ESIK.yuzde, oran };
}

// ── GENEL DURUM ──────────────────────────────────────────────
// Kurallar panelde de yazılıdır. Ölçülemeyen gösterge "uyarı" sayılır,
// "sağlıklı" sayılmaz.
export function genelDurum({ veritabaniOk, api, kaynak, yedek, entegrasyonlar, silmeTukenen, kanallar, basarisiz24 }) {
  const sorunlar = []; const uyarilar = [];
  if (!veritabaniOk) sorunlar.push('Veritabanı yanıt vermiyor');
  const s = api?.last15m;
  if (s && s.requests >= 20 && s.rate5xx !== null && s.rate5xx >= 5) sorunlar.push(`Son 15 dakikada sunucu hatası oranı %${s.rate5xx}`);
  else if (s && s.errors5xx > 0) uyarilar.push(`Son 15 dakikada ${s.errors5xx} sunucu hatası`);
  const yv = yavaslama(s);
  if (yv.yavas) uyarilar.push(`Yavaşlama: son 15 dakikada isteklerin %${yv.oran}'i 1 saniyeden uzun sürdü`);
  if (kaynak?.memory?.percent !== null && kaynak?.memory?.percent !== undefined && kaynak.memory.percent >= 90) sorunlar.push(`Bellek kullanımı %${kaynak.memory.percent}`);
  if (!kaynak?.cpu) uyarilar.push('CPU kullanımı ölçülemiyor');
  if (!kaynak?.memory) uyarilar.push('Kapsayıcı belleği ölçülemiyor');
  if (yedek) {
    if (!yedek.configured) uyarilar.push('Yedekleme doğrulanmadı (Render bağlantısı yok)');
    else if (!yedek.checkOk) uyarilar.push('Yedekleme durumu okunamadı');
    else if (yedek.status === 'NOT_AVAILABLE') sorunlar.push('Anlık geri yükleme kullanılamıyor');
    else if (yedek.status !== 'AVAILABLE') uyarilar.push('Yedek henüz hazır değil');
  }
  for (const e of entegrasyonlar ?? []) if (e.active && e.lastTestOk === false) uyarilar.push(`${e.type} entegrasyonunun son testi başarısız`);
  // 23 Eki: gönderim yolu hiç yoksa ya da yalnız geliştirme kaydıysa
  // (gönderim YAPILMAZ) uyarı; son 24 saatte başarısız gönderim varsa uyarı.
  const KANAL_ADI = { SMS: 'SMS', EMAIL: 'E-posta', STORAGE: 'Dosya depolama' };
  for (const k of kanallar ?? []) {
    // 23 Eki: otomatik kontrol başarısızsa (depolama: fotoğraf yüklenemez;
    // e-posta: doğrulama/bildirim e-postaları gitmez) → sorun.
    if (k.type === 'STORAGE' && k.source !== 'yok' && k.autoCheckOk === false) sorunlar.push('Dosya depolamaya erişilemiyor (otomatik kontrol başarısız)');
    if (k.type === 'EMAIL' && k.source !== 'yok' && k.autoCheckOk === false) sorunlar.push('E-posta sağlayıcısına erişilemiyor (otomatik kontrol başarısız)');
    // SMS bilinçli olarak kapalı olabilir (kodları Firebase gönderir; 23 Eki karar A): uyarı değil.
    if (k.source === 'yok' && k.type !== 'SMS') uyarilar.push(`${KANAL_ADI[k.type] ?? k.type} yapılandırılmamış (panelde ve sunucu ayarında yok)`);
    else if (k.source === 'ortam' && k.provider === 'log') uyarilar.push(`${KANAL_ADI[k.type] ?? k.type} gerçekten gönderilmiyor (geliştirme kaydı)`);
  }
  for (const [kanal, n] of Object.entries(basarisiz24 ?? {})) {
    if (n > 0) uyarilar.push(`Son 24 saatte ${n} ${KANAL_ADI[kanal] ?? kanal} gönderilemedi`);
  }
  if (silmeTukenen > 0) uyarilar.push(`${silmeTukenen} silme işi deneme hakkını tüketti`);
  return { status: sorunlar.length ? 'PROBLEM' : uyarilar.length ? 'WARNING' : 'OK', problems: sorunlar, warnings: uyarilar };
}
