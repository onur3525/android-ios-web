// ═══════════════════════════════════════════════════════════════
// SİSTEM DURUMU — Özet'teki kartın ayrıntısı (21 Eki)
//
// Kaynak: /system/status (yalnız backend'in gerçekten bildiği değerler).
// Alıcı ve ileti içeriği gösterilmez. Entegrasyon ve son hata ayrıntısı
// yetkiye bağlıdır; yetki yoksa bölüm "yetkiniz yok" der, sayı uydurulmaz.
// ⚠ 22 Eki kuralı: ölçülemeyen değer "ölçülemiyor", doğrulanmamış yedek
// "doğrulanmadı" yazılır; hiçbir gösterge varsayılan olarak "iyi" olmaz.
// ═══════════════════════════════════════════════════════════════
import { api, h } from './cekirdek.js';

const sayi = (v) => (Number.isFinite(v) ? v.toLocaleString('tr-TR') : '—');
const zaman = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
const ENTEGRASYON = { SMS: 'SMS', EMAIL: 'E-posta', STORAGE: 'Depolama' };
const SURUCU = { postgres: 'PostgreSQL', sqlite: 'SQLite (geliştirme)' };

function sure(sn) {
  const g = Math.floor(sn / 86400); const s = Math.floor((sn % 86400) / 3600); const d = Math.floor((sn % 3600) / 60);
  return [g ? `${g} gün` : '', s ? `${s} saat` : '', !g ? `${d} dk` : ''].filter(Boolean).join(' ') || '1 dakikadan az';
}

const durum = (metin, sinif) => h('span', { class: `oz-durum ${sinif}` }, metin);
const olculemiyor = () => durum('Ölçülemiyor', 'notr');
function bayt(n) {
  if (!Number.isFinite(n)) return '—';
  const b = ['B', 'KB', 'MB', 'GB', 'TB']; let i = 0; let v = n;
  while (v >= 1024 && i < b.length - 1) { v /= 1024; i += 1; }
  return `${v.toLocaleString('tr-TR', { maximumFractionDigits: v < 10 ? 1 : 0 })} ${b[i]}`;
}
const yuzde = (v) => (Number.isFinite(v) ? `%${v.toLocaleString('tr-TR')}` : null);
const esikDurumu = (p) => (!Number.isFinite(p) ? null : p >= 90 ? 'kotu' : p >= 75 ? 'uyari' : 'iyi');
const GENEL = { OK: ['Sağlıklı', 'iyi'], WARNING: ['Uyarı var', 'uyari'], PROBLEM: ['Sorun var', 'kotu'] };
const YEDEK = {
  AVAILABLE: ['Anlık geri yükleme hazır', 'iyi'],
  BACKUP_NOT_READY: ['Yedek henüz hazır değil', 'uyari'],
  NOT_AVAILABLE: ['Anlık geri yükleme kullanılamıyor', 'kotu'],
  UNVERIFIED: ['Doğrulanmadı', 'notr'],
};
const OLAY = { 'auth.login_failed': 'Hatalı şifreyle giriş denemesi', 'auth.mfa_failed': 'Hatalı doğrulama kodu (giriş)', 'auth.reauth_failed': 'Hatalı şifre/kod (değişiklik onayı)' };

function kart(baslik, ...icerik) {
  return h('section', { class: 'oz-kart' }, h('div', { class: 'oz-kart-ust' }, h('h3', {}, baslik)), ...icerik);
}

function satirlar(ciftler) {
  return h('dl', { class: 'sd-liste' }, ciftler.map(([ad, deger]) => [h('dt', {}, ad), h('dd', {}, deger)]));
}

function tablo(kolonlar, satir) {
  if (!satir.length) return h('p', { class: 'oz-bos' }, 'Kayıt yok.');
  return h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo' },
    h('thead', {}, h('tr', {}, kolonlar.map((k) => h('th', {}, k[0])))),
    h('tbody', {}, satir.map((s) => h('tr', {}, kolonlar.map((k) => h('td', {}, k[1](s))))))));
}

export async function sistemSayfasi({ yedekYenile = false } = {}) {
  // API yanıt süresi hafif bir istekle ölçülür (durum ucu CPU ölçümü için
  // ~0,5 sn örnek aldığından onun süresi API hızını göstermez).
  const t0 = performance.now();
  await api('/auth/me');
  const apiMs = Math.round(performance.now() - t0);
  const s = await api(`/system/status${yedekYenile ? '?refreshBackup=1' : ''}`);
  const d = s.delivery;

  const entegrasyonlar = s.integrations === null
    ? h('p', { class: 'oz-bos' }, 'Entegrasyon ayrıntısı için yetkiniz yok.')
    : tablo([
      ['Tür', (x) => ENTEGRASYON[x.type] ?? x.type],
      ['Sağlayıcı', (x) => x.provider ?? '—'],
      ['Durum', (x) => (x.missing ? durum('Panelde tanımlı değil', 'notr') : x.active ? durum('Etkin', 'iyi') : durum('Pasif', 'notr'))],
      ['Son test', (x) => zaman(x.lastTestAt)],
      ['Sonuç', (x) => (x.lastTestOk === true ? durum('Başarılı', 'iyi') : x.lastTestOk === false ? durum('Başarısız', 'kotu') : '—')],
      ['Mesaj', (x) => x.lastTestMessage ?? '—'],
    ], ['SMS', 'EMAIL', 'STORAGE'].flatMap((t) => {
      const v = s.integrations.filter((x) => x.type === t);
      return v.length ? v : [{ type: t, missing: true }];
    }));

  const gonderim = tablo([
    ['Kanal', (x) => x.ad],
    ['Gönderildi', (x) => sayi(x.v.SENT)],
    ['Başarısız', (x) => (x.v.FAILED ? durum(sayi(x.v.FAILED), 'kotu') : '0')],
    ['Bekleyen', (x) => sayi(x.v.PENDING)],
    ['Not', (x) => x.not ?? '—'],
  ], [
    { ad: 'SMS', v: d.sms },
    { ad: 'E-posta', v: d.email },
    { ad: 'Push bildirim', v: d.push,
      not: d.push.configured
        ? `Cihaz kaydı yok: ${sayi(d.push.NO_TOKEN)} · Kullanıcı tercihi/hesap durumu nedeniyle atlanan: ${sayi(d.push.SKIPPED)}`
        : 'Push gönderimi sunucuda yapılandırılmamış' },
  ]);

  const hatalar = s.recentFailures === null
    ? h('p', { class: 'oz-bos' }, 'Gönderim hatalarını görmek için yetkiniz yok.')
    : tablo([
      ['Tarih', (m) => zaman(m.createdAt)],
      ['Kanal', (m) => (m.channel === 'EMAIL' ? 'E-posta' : m.channel)],
      ['Şablon', (m) => m.template],
      ['Sağlayıcı', (m) => m.provider ?? '—'],
      ['Deneme', (m) => sayi(m.attempts)],
      ['Sağlayıcı yanıtı', (m) => m.providerResponse ?? '—'],
    ], s.recentFailures);

  // ── 1. Genel durum ──
  const g = s.overall;
  const genel = h('section', { class: `oz-kart sd-genel ${GENEL[g.status][1]}` },
    h('div', { class: 'oz-kart-ust' }, h('h3', {}, 'Genel sistem durumu'), durum(GENEL[g.status][0], GENEL[g.status][1])),
    h('p', { class: 'not' }, `Son kontrol: ${zaman(s.checkedAt)}`),
    g.problems.length ? h('ul', { class: 'sd-madde kotu' }, g.problems.map((m) => h('li', {}, m))) : null,
    g.warnings.length ? h('ul', { class: 'sd-madde uyari' }, g.warnings.map((m) => h('li', {}, m))) : null,
    !g.problems.length && !g.warnings.length ? h('p', {}, 'Ölçülen bütün göstergeler eşiklerin içinde.') : null,
    h('p', { class: 'not' }, 'Kurallar: veritabanı yanıt vermezse, son 15 dakikada en az 20 istekte sunucu hatası oranı %5 ve üstündeyse, bellek ya da disk %90 ve üstündeyse veya anlık geri yükleme kullanılamıyorsa "Sorun var". Ölçülemeyen ya da doğrulanamayan gösterge "Uyarı" sayılır.'));

  // ── 3. CPU, RAM, disk ──
  const k = s.resources;
  const kaynak = kart('CPU, RAM ve disk', satirlar([
    ['CPU', k.cpu
      ? (k.cpu.percent !== null
        ? durum(`${yuzde(k.cpu.percent)} (${k.cpu.usedCores.toLocaleString('tr-TR')} / ${k.cpu.limitCores.toLocaleString('tr-TR')} çekirdek)`, esikDurumu(k.cpu.percent))
        : `${k.cpu.usedCores.toLocaleString('tr-TR')} çekirdek kullanılıyor (sınır okunamadı)`)
      : olculemiyor()],
    ['Bellek (RAM)', k.memory
      ? (k.memory.percent !== null ? durum(`${yuzde(k.memory.percent)} · ${bayt(k.memory.usedBytes)} / ${bayt(k.memory.limitBytes)}`, esikDurumu(k.memory.percent)) : `${bayt(k.memory.usedBytes)} (sınır okunamadı)`)
      : olculemiyor()],
    ['Uygulama süreci belleği', bayt(k.process.rssBytes)],
    ['Sunucu diski', k.disk ? durum(`${yuzde(k.disk.percent)} · ${bayt(k.disk.usedBytes)} / ${bayt(k.disk.totalBytes)}`, esikDurumu(k.disk.percent)) : olculemiyor()],
    ['Veritabanı boyutu', k.database ? bayt(k.database.sizeBytes) : olculemiyor()],
  ]), h('p', { class: 'not' }, `${k.scope} · ölçüm ${zaman(k.measuredAt)}${k.cpu?.source ? ` · kaynak: ${k.cpu.source}` : ''}. Veritabanı plan sınırı buradan okunamadığından yalnız gerçek boyut gösterilir.`));

  // ── 4. Hata oranları ve yanıt süreleri ──
  const m = s.apiMetrics;
  const pencere = [['Son 15 dk', m.last15m], ['Son 1 saat', m.last1h], ['Son 24 saat', m.last24h]];
  const olcum = kart('Hata oranları ve yanıt süreleri (uygulama API\'si)',
    tablo([
      ['Dönem', (x) => x[0]],
      ['İstek', (x) => sayi(x[1].requests)],
      ['Sunucu hatası (5xx)', (x) => (x[1].requests ? durum(`${sayi(x[1].errors5xx)} · ${yuzde(x[1].rate5xx)}`, x[1].errors5xx ? (x[1].rate5xx >= 5 ? 'kotu' : 'uyari') : 'iyi') : '—')],
      ['İstemci hatası (4xx)', (x) => (x[1].requests ? `${sayi(x[1].errors4xx)} · ${yuzde(x[1].rate4xx)}` : '—')],
      ['Ortalama yanıt', (x) => (x[1].avgMs === null ? '—' : `${sayi(x[1].avgMs)} ms`)],
      ['En yavaş', (x) => (x[1].maxMs === null ? '—' : `${sayi(x[1].maxMs)} ms`)],
      ['1 sn üstü', (x) => (x[1].requests ? sayi(x[1].latency.under3000 + x[1].latency.over3000) : '—')],
    ], pencere),
    h('p', { class: 'not' }, m.since ? `Ölçüm başlangıcı: ${zaman(m.since)}. Bütün sunucu örneklerinin toplamıdır.` : 'Henüz ölçülmüş istek yok (ölçüm bu sürümle başladı).'));

  // ── 5. Yedekleme ──
  const y = s.backup;
  const yedek = kart('Yedekleme durumu', y === null
    ? h('p', { class: 'oz-bos' }, 'Yedekleme durumunu görmek için yetkiniz yok.')
    : !y.configured
      ? [satirlar([['Durum', durum(YEDEK.UNVERIFIED[0], 'notr')]]),
        h('p', { class: 'not' }, 'Render bağlantısı kurulmadığı için yedekleme doğrulanamıyor. Bağlantı Entegrasyonlar sayfasından (Yedekleme izleme) kurulur.'),
        h('a', { class: 'oz-tumu', href: '#/entegrasyonlar' }, 'Entegrasyonlar ›')]
      : [satirlar([
        ['Durum', durum(...(YEDEK[y.status] ?? [y.status, 'notr']))],
        ['Geri yüklenebilir başlangıç', zaman(y.recoveryStartsAt)],
        ['Son dışa aktarma (yedek dosyası)', y.lastExportAt ? zaman(y.lastExportAt) : (y.checkOk ? 'Yok' : '—')],
        ['Dışa aktarma sayısı', y.exportCount === null ? '—' : sayi(y.exportCount)],
        ['Son kontrol', `${zaman(y.checkedAt)} · ${y.checkOk ? 'Render API okundu' : `Okunamadı: ${y.checkMessage ?? '—'}`}`],
      ]), h('a', { class: 'oz-tumu', href: '#/sistem/yedek' }, 'Şimdi kontrol et ›')]);

  // ── 7. Son sistem hataları ve kritik olaylar ──
  const sunucuHatalari = s.serverErrors === null
    ? h('p', { class: 'oz-bos' }, 'Sunucu hatalarını görmek için yetkiniz yok.')
    : tablo([
      ['Tarih', (x) => zaman(x.at)],
      ['İstek', (x) => `${x.method} ${x.path}`],
      ['Durum', (x) => durum(String(x.status), 'kotu')],
      ['Hata kodu', (x) => x.code ?? '—'],
      ['İstek kimliği', (x) => x.requestId ?? '—'],
    ], s.serverErrors);
  const di = s.deletionIssues;
  const silme = di === null ? null : satirlar([
    ['Denemesi tükenen dosya silme', di.filesExhausted ? durum(sayi(di.filesExhausted), 'kotu') : '0'],
    ['Uzun süreli hata · Firebase kaydı silme', di.firebaseLongFailure ? durum(sayi(di.firebaseLongFailure), 'kotu') : '0'],
    ['Uzun süreli hata · Firebase işlemleri', di.firebaseOpsLongFailure ? durum(sayi(di.firebaseOpsLongFailure), 'kotu') : '0'],
    ['Süresi geçmiş hesap silme talebi', di.overdueAccountDeletions ? durum(sayi(di.overdueAccountDeletions), 'uyari') : '0'],
  ]);
  const guvenlik = s.adminSecurityEvents === null ? null : tablo([
    ['Tarih', (x) => zaman(x.at)],
    ['Olay', (x) => OLAY[x.action] ?? x.action],
    ['Yönetici', (x) => x.admin ?? '—'],
    ['IP', (x) => x.ip ?? '—'],
  ], s.adminSecurityEvents);

  return h('div', { class: 'oz' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Sistem Durumu'),
        h('p', {}, `Sunucu saati: ${zaman(s.api.serverTime)}`))),
    genel,
    h('div', { class: 'oz-uclu sd-iki' },
      kart('Backend API', satirlar([
        ['Durum', durum('Çalışıyor', 'iyi')],
        ['Yanıt süresi', `${sayi(apiMs)} ms`],
        ['Kesintisiz çalışma', sure(s.api.uptimeSeconds)],
      ])),
      kart('Veritabanı', satirlar([
        ['Durum', durum('Çalışıyor', 'iyi')],
        ['Tür', SURUCU[s.database.driver] ?? s.database.driver],
        ['Sorgu süresi', `${s.database.responseMs.toLocaleString('tr-TR')} ms`],
        ['Son veritabanı güncellemesi', `${s.database.lastMigration ?? '—'} · ${zaman(s.database.lastMigrationAt)}`],
        ['Uygulanan güncelleme', sayi(s.database.migrations)],
      ]))),
    h('div', { class: 'oz-uclu sd-iki' }, kaynak, yedek),
    olcum,
    kart('Entegrasyonlar', entegrasyonlar),
    kart('Bildirim gönderimi (son 7 gün)', gonderim),
    kart('Son sunucu hataları (5xx)', sunucuHatalari),
    silme ? kart('Hesap silme kuyrukları', silme, h('a', { class: 'oz-tumu', href: '#/silmekuyruklari' }, 'Silme Kuyrukları ›')) : null,
    guvenlik ? kart('Yönetici güvenlik olayları (son 24 saat)', guvenlik) : null,
    h('section', { class: 'oz-kart' },
      h('div', { class: 'oz-kart-ust' }, h('h3', {}, 'Son başarısız gönderimler'),
        s.recentFailures === null ? null : h('a', { class: 'oz-tumu', href: '#/gonderimler' }, 'Tümünü gör ›')),
      hatalar));
}
