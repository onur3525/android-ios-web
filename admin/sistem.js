// ═══════════════════════════════════════════════════════════════
// SİSTEM DURUMU — Özet'teki kartın ayrıntısı (21 Eki)
//
// Kaynak: /system/status (yalnız backend'in gerçekten bildiği değerler).
// Alıcı ve ileti içeriği gösterilmez. Entegrasyon ve son hata ayrıntısı
// yetkiye bağlıdır; yetki yoksa bölüm "yetkiniz yok" der, sayı uydurulmaz.
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

export async function sistemSayfasi() {
  const t0 = performance.now();
  const s = await api('/system/status');
  const apiMs = Math.round(performance.now() - t0);
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

  return h('div', { class: 'oz' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('a', { class: 'oz-tumu', href: '#/ozet' }, '‹ Özet'), h('h2', {}, 'Sistem Durumu'),
        h('p', {}, `Sunucu saati: ${zaman(s.api.serverTime)}`))),
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
    kart('Entegrasyonlar', entegrasyonlar),
    kart('Bildirim gönderimi (son 7 gün)', gonderim),
    h('section', { class: 'oz-kart' },
      h('div', { class: 'oz-kart-ust' }, h('h3', {}, 'Son başarısız gönderimler'),
        s.recentFailures === null ? null : h('a', { class: 'oz-tumu', href: '#/gonderimler' }, 'Tümünü gör ›')),
      hatalar));
}
