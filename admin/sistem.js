// ═══════════════════════════════════════════════════════════════
// SİSTEM DURUMU (21 Eki; 23 Eki görsel yenileme)
//
// Kaynak: /system/status — yalnız backend'in GERÇEKTEN ölçtüğü/bildiği
// değerler. Her sistem ayrı bir kartta, kendi gerçek verisinden türeyen
// durumuyla çizilir:
//   · ölçülemeyen değer "Ölçülemiyor", doğrulanmamış şey "Doğrulanmadı"
//     (nötr) yazılır; hiçbir gösterge kanıt olmadan "iyi" olmaz;
//   · grafikler son 24 saatin saat saat gerçek ölçümüdür; ölçülmeyen saat
//     boş kalır, değer uydurulmaz;
//   · sunucu diski GÖSTERİLMEZ: Render'da kapsayıcı içinden görünen disk
//     paylaşılan makinenin tamamıdır, HizmetCep'in değil (sistem_izleme.js).
// Alıcı ve ileti içeriği gösterilmez. Yetkiye bağlı bölüm "yetkiniz yok"
// der, sayı uydurulmaz. CSP: satır içi stil yok (SVG öznitelik + CSS sınıfı).
// ═══════════════════════════════════════════════════════════════
import { api, h } from './cekirdek.js';
import { ikon, svg } from './svg.js';
import { kanalDurumu, kanalKaynagi } from './kanal_durumu.js';

const sayi = (v) => (Number.isFinite(v) ? v.toLocaleString('tr-TR') : '—');
const zaman = (v) => (v ? new Date(v).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
const saat = (v) => new Date(v).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
const SURUCU = { postgres: 'PostgreSQL', sqlite: 'SQLite (geliştirme)' };
const SINIF_ADI = { iyi: 'Sağlıklı', uyari: 'Uyarı', kotu: 'Sorun', notr: 'Doğrulanmadı' };

function sure(sn) {
  if (!Number.isFinite(sn) || sn < 60) return '1 dakikadan az';
  const g = Math.floor(sn / 86400); const s = Math.floor((sn % 86400) / 3600); const d = Math.floor((sn % 3600) / 60);
  return [g ? `${g} gün` : '', s ? `${s} saat` : '', !g && d ? `${d} dk` : ''].filter(Boolean).join(' ');
}
function bayt(n) {
  if (!Number.isFinite(n)) return '—';
  const b = ['B', 'KB', 'MB', 'GB', 'TB']; let i = 0; let v = n;
  while (v >= 1024 && i < b.length - 1) { v /= 1024; i += 1; }
  return `${v.toLocaleString('tr-TR', { maximumFractionDigits: v < 10 ? 1 : 0 })} ${b[i]}`;
}
const yuzde = (v) => (Number.isFinite(v) ? `%${v.toLocaleString('tr-TR')}` : '—');
const esik = (p) => (!Number.isFinite(p) ? 'notr' : p >= 90 ? 'kotu' : p >= 75 ? 'uyari' : 'iyi');
const enKotu = (...s) => (['kotu', 'uyari', 'notr', 'iyi'].find((x) => s.includes(x)) ?? 'notr');

const GENEL = { OK: ['Bütün sistemler sağlıklı', 'iyi'], WARNING: ['Dikkat gerektiren durum var', 'uyari'], PROBLEM: ['Sorun var', 'kotu'] };
const YEDEK = {
  AVAILABLE: ['Anlık geri yükleme hazır', 'iyi'],
  BACKUP_NOT_READY: ['Yedek henüz hazır değil', 'uyari'],
  NOT_AVAILABLE: ['Anlık geri yükleme kullanılamıyor', 'kotu'],
  UNVERIFIED: ['Doğrulanmadı', 'notr'],
};
const OLAY = { 'auth.login_failed': 'Hatalı şifreyle giriş denemesi', 'auth.mfa_failed': 'Hatalı doğrulama kodu (giriş)', 'auth.reauth_failed': 'Hatalı şifre/kod (değişiklik onayı)' };

const rozet = (metin, sinif) => h('span', { class: `oz-durum ${sinif}` }, metin);

// ── GÖRSEL PARÇALAR ──────────────────────────────────────────

/** Halka gösterge: yüzde null ise boş halka + "Ölçülemiyor". */
function halka(baslik, yuzdeDeger, altMetin) {
  const r = 34; const cevre = 2 * Math.PI * r;
  const p = Number.isFinite(yuzdeDeger) ? Math.max(0, Math.min(100, yuzdeDeger)) : null;
  const sinif = esik(p);
  return h('div', { class: 'sd-halka' },
    svg('svg', { viewBox: '0 0 84 84', width: 92, height: 92, role: 'img', 'aria-label': `${baslik}: ${p === null ? 'ölçülemiyor' : yuzde(p)}` },
      svg('circle', { cx: 42, cy: 42, r, class: 'sd-halka-zemin' }),
      p === null ? null : svg('circle', {
        cx: 42, cy: 42, r, class: `sd-halka-deger ${sinif}`,
        'stroke-dasharray': `${(cevre * p) / 100} ${cevre}`, transform: 'rotate(-90 42 42)',
      }),
      (() => { const t = svg('text', { x: 42, y: 47, 'text-anchor': 'middle', class: 'sd-halka-yazi' }); t.textContent = p === null ? '—' : `%${Math.round(p)}`; return t; })()),
    h('div', { class: 'sd-halka-ad' }, baslik),
    h('div', { class: 'sd-halka-alt' }, p === null ? 'Ölçülemiyor' : altMetin));
}

/** Oran çubuğu: [{deger, sinif, ad}] — toplam 0 ise boş çubuk. */
function oranCubugu(parcalar) {
  const toplam = parcalar.reduce((a, x) => a + (x.deger || 0), 0);
  let x0 = 0;
  return h('div', { class: 'sd-oran' },
    svg('svg', { viewBox: '0 0 100 8', preserveAspectRatio: 'none', width: '100%', height: 8, 'aria-hidden': 'true' },
      svg('rect', { x: 0, y: 0, width: 100, height: 8, rx: 4, class: 'sd-oran-zemin' }),
      ...(toplam ? parcalar.filter((p) => p.deger > 0).map((p) => {
        const w = (p.deger / toplam) * 100; const r = svg('rect', { x: x0, y: 0, width: w, height: 8, class: `sd-oran-${p.sinif}` }); x0 += w; return r;
      }) : [])),
    h('div', { class: 'sd-oran-lejant' }, parcalar.map((p) => h('span', { class: `sd-lejant ${p.sinif}` }, `${p.ad}: ${sayi(p.deger)}`))));
}

/** Son 24 saat: istek çubukları (5xx kırmızı, 4xx turuncu) ya da ortalama yanıt çizgisi. */
function saatlikGrafik(seri, tur) {
  const G = 640; const Y = 150; const sol = 40; const alt = 22; const ust = 10;
  const en = (G - sol) / seri.length;
  const degerler = tur === 'istek' ? seri.map((x) => x.requests) : seri.map((x) => x.avgMs);
  const enBuyuk = Math.max(1, ...degerler.filter(Number.isFinite));
  const yuks = (v) => ((Y - alt - ust) * v) / enBuyuk;
  const ciz = [];
  // Yatay ızgara + eksen etiketleri (0, yarı, en büyük).
  for (const k of [0, 0.5, 1]) {
    const y = Y - alt - (Y - alt - ust) * k;
    ciz.push(svg('line', { x1: sol, x2: G, y1: y, y2: y, class: 'sd-izgara-cizgi' }));
    const t = svg('text', { x: sol - 6, y: y + 4, 'text-anchor': 'end', class: 'sd-eksen' });
    const v = Math.round(enBuyuk * k * 10) / 10;
    t.textContent = tur === 'istek' ? sayi(Math.round(enBuyuk * k)) : `${sayi(v)} ms`;
    ciz.push(t);
  }
  seri.forEach((x, i) => {
    const xs = sol + i * en;
    if (i % 6 === 0) {
      const t = svg('text', { x: xs + en / 2, y: Y - 6, 'text-anchor': 'middle', class: 'sd-eksen' });
      t.textContent = saat(x.start);
      ciz.push(t);
    }
    if (tur === 'istek' && x.requests > 0) {
      const tam = yuks(x.requests); const h5 = yuks(x.errors5xx); const h4 = yuks(x.errors4xx);
      const baslik = svg('title'); baslik.textContent = `${saat(x.start)} · ${sayi(x.requests)} istek · ${sayi(x.errors5xx)} sunucu hatası · ${sayi(x.errors4xx)} istemci hatası`;
      ciz.push(svg('g', {}, baslik,
        svg('rect', { x: xs + 2, y: Y - alt - tam, width: Math.max(1, en - 4), height: tam, rx: 2, class: 'sd-cubuk' }),
        h4 > 0 ? svg('rect', { x: xs + 2, y: Y - alt - h5 - h4, width: Math.max(1, en - 4), height: h4, class: 'sd-cubuk-4xx' }) : null,
        h5 > 0 ? svg('rect', { x: xs + 2, y: Y - alt - h5, width: Math.max(1, en - 4), height: h5, class: 'sd-cubuk-5xx' }) : null));
    }
  });
  if (tur === 'sure') {
    // Ölçülmeyen saatte çizgi KOPAR (boşluk doldurulmaz).
    let parca = [];
    const bitir = () => { if (parca.length > 1) ciz.push(svg('polyline', { points: parca.join(' '), class: 'sd-cizgi' })); parca = []; };
    seri.forEach((x, i) => {
      if (x.avgMs === null) { bitir(); return; }
      const px = sol + i * en + en / 2; const py = Y - alt - yuks(x.avgMs);
      parca.push(`${px},${py}`);
      const nokta = svg('circle', { cx: px, cy: py, r: 3, class: 'sd-nokta' });
      const t = svg('title'); t.textContent = `${saat(x.start)} · ortalama ${sayi(x.avgMs)} ms · en yavaş ${sayi(x.maxMs)} ms`;
      nokta.append(t);
      ciz.push(nokta);
    });
    bitir();
  }
  const bos = tur === 'istek' ? seri.every((x) => !x.requests) : seri.every((x) => x.avgMs === null);
  return h('div', { class: 'sd-grafik' },
    svg('svg', { viewBox: `0 0 ${G} ${Y}`, width: '100%', role: 'img', 'aria-label': tur === 'istek' ? 'Son 24 saatte saatlik istek sayısı' : 'Son 24 saatte saatlik ortalama yanıt süresi' }, ...ciz),
    bos ? h('p', { class: 'sd-grafik-bos' }, 'Bu dönemde ölçülmüş istek yok.') : null);
}

/** Bir sistemin kartı. */
function sistemKarti({ ad, ikonAd, sinif, durumMetni, ana, anaAlt, satirlar = [], ek, not, baglanti }) {
  return h('section', { class: `sd-kutu ${sinif}` },
    h('div', { class: 'sd-kutu-ust' },
      h('span', { class: `sd-kutu-ikon ${sinif}` }, ikon(ikonAd, 22)),
      h('div', { class: 'sd-kutu-baslik' }, h('h3', {}, ad), rozet(durumMetni, sinif))),
    ana !== undefined ? h('div', { class: 'sd-ana' }, h('span', { class: 'sd-ana-deger' }, ana), anaAlt ? h('span', { class: 'sd-ana-alt' }, anaAlt) : null) : null,
    ek ?? null,
    satirlar.length ? h('dl', { class: 'sd-liste sd-kutu-liste' }, satirlar.map(([a, d]) => [h('dt', {}, a), h('dd', {}, d)])) : null,
    not ? h('p', { class: 'not' }, not) : null,
    baglanti ?? null);
}

function tablo(kolonlar, satir) {
  if (!satir.length) return h('p', { class: 'oz-bos' }, 'Kayıt yok.');
  return h('div', { class: 'oz-tablo-sar' }, h('table', { class: 'oz-tablo' },
    h('thead', {}, h('tr', {}, kolonlar.map((k) => h('th', {}, k[0])))),
    h('tbody', {}, satir.map((s) => h('tr', {}, kolonlar.map((k) => h('td', {}, k[1](s))))))));
}

const katlanir = (baslik, ...icerik) => h('details', { class: 'oz-kart sd-ayrinti' }, h('summary', {}, baslik), ...icerik);

// ── SAYFA ────────────────────────────────────────────────────

export async function sistemSayfasi({ yedekYenile = false } = {}) {
  // Yanıt süresi, tarayıcıdan hafif bir istekle ölçülür (durum ucu CPU
  // örneği aldığı için ~0,5 sn sürer; onun süresi API hızını göstermez).
  const t0 = performance.now();
  await api('/auth/me');
  const apiMs = Math.round(performance.now() - t0);
  const s = await api(`/system/status${yedekYenile ? '?refreshBackup=1' : ''}`);
  const d = s.delivery;
  const m = s.apiMetrics;
  const k = s.resources;
  const kanal = (t) => (s.channels ?? []).find((x) => x.type === t);

  const kartlar = [];

  // 1) Backend API — kural: son 15 dk ≥20 istekte 5xx ≥%5 sorun; 5xx varsa uyarı.
  const s15 = m.last15m; const s24 = m.last24h;
  const apiSinif = s15.requests >= 20 && s15.rate5xx >= 5 ? 'kotu' : s15.errors5xx > 0 ? 'uyari' : 'iyi';
  kartlar.push(sistemKarti({
    ad: 'Backend API', ikonAd: 'sunucu', sinif: apiSinif,
    durumMetni: apiSinif === 'iyi' ? 'Yanıt veriyor' : apiSinif === 'uyari' ? `Son 15 dk: ${sayi(s15.errors5xx)} sunucu hatası` : `Son 15 dk hata oranı ${yuzde(s15.rate5xx)}`,
    ana: `${sayi(apiMs)} ms`, anaAlt: 'şu anki yanıt süresi (tarayıcınızdan)',
    satirlar: [
      ['Son 24 saat', `${sayi(s24.requests)} istek`],
      ['Sunucu hatası (24 sa)', s24.requests ? `${sayi(s24.errors5xx)} · ${yuzde(s24.rate5xx)}` : '—'],
      ['Ortalama yanıt (24 sa)', s24.avgMs === null ? '—' : `${sayi(s24.avgMs)} ms`],
      // 28 Eki: fotoğraf/PDF indirme sınırına takılan istek — yalnız varsa
      // görünür (son 24 saat kuralı); çoğu toplu indirme girişimidir.
      s24.downloadLimited > 0 ? ['İndirme sınırına takılan (24 sa)', sayi(s24.downloadLimited)] : null,
      ['Bu sunucu örneği açık', sure(s.api.uptimeSeconds)],
    ].filter(Boolean),
    not: 'Sunucu her güncellemede yeniden başlar; "açık" süresi son başlatmadan beri geçen süredir.',
  }));

  // 2) Veritabanı — bu yanıt veritabanından okundu; sorgu süresi gerçek ölçüm.
  kartlar.push(sistemKarti({
    ad: 'Veritabanı', ikonAd: 'db', sinif: 'iyi', durumMetni: 'Yanıt veriyor',
    ana: `${s.database.responseMs.toLocaleString('tr-TR')} ms`, anaAlt: 'sorgu süresi',
    satirlar: [
      ['Tür', SURUCU[s.database.driver] ?? s.database.driver],
      ['Boyut', k.database ? bayt(k.database.sizeBytes) : 'Ölçülemiyor'],
      ['Son güncelleme', `${s.database.lastMigration ?? '—'} · ${zaman(s.database.lastMigrationAt)}`],
      ['Uygulanan güncelleme', sayi(s.database.migrations)],
    ],
    not: 'Veritabanı plan sınırı buradan okunamadığından yalnız gerçek boyut gösterilir.',
  }));

  // 3) Sunucu kaynakları — kapsayıcı (cgroup) ölçümü; okunamazsa "Ölçülemiyor".
  const kaynakSinif = !k.cpu && !k.memory ? 'notr' : enKotu(k.cpu ? esik(k.cpu.percent) : 'notr', k.memory ? esik(k.memory.percent) : 'notr');
  kartlar.push(sistemKarti({
    ad: 'Sunucu kaynakları', ikonAd: 'islemci', sinif: kaynakSinif,
    durumMetni: kaynakSinif === 'notr' ? 'Ölçülemiyor' : SINIF_ADI[kaynakSinif],
    ek: h('div', { class: 'sd-halkalar' },
      halka('CPU', k.cpu?.percent ?? null, k.cpu ? `${k.cpu.usedCores.toLocaleString('tr-TR')} / ${k.cpu.limitCores?.toLocaleString('tr-TR') ?? '?'} çekirdek` : ''),
      halka('Bellek', k.memory?.percent ?? null, k.memory ? `${bayt(k.memory.usedBytes)} / ${bayt(k.memory.limitBytes)}` : '')),
    satirlar: [['Uygulama süreci belleği', bayt(k.process.rssBytes)]],
    not: `${k.scope} · ${zaman(k.measuredAt)}${k.cpu?.source ? ` · ${k.cpu.source}` : ''}. Bellek, sınırın uygulandığı kapsayıcı ölçümüdür; süreç belleği paylaşılan dosya sayfalarını da saydığından daha büyük görünebilir.`,
  }));

  // 4) Yedekleme — Render API'den okunamadıkça "Doğrulanmadı".
  const y = s.backup;
  if (y === null) {
    kartlar.push(sistemKarti({ ad: 'Yedekleme', ikonAd: 'yedek', sinif: 'notr', durumMetni: 'Yetkiniz yok', not: 'Yedekleme durumunu görmek için yetkiniz yok.' }));
  } else {
    const [yMetin, ySinif] = y.configured ? (YEDEK[y.status] ?? [y.status, 'notr']) : YEDEK.UNVERIFIED;
    kartlar.push(sistemKarti({
      ad: 'Yedekleme', ikonAd: 'yedek', sinif: ySinif, durumMetni: yMetin,
      satirlar: y.configured ? [
        ['Geri yüklenebilir başlangıç', zaman(y.recoveryStartsAt)],
        ['Son dışa aktarma', y.lastExportAt ? zaman(y.lastExportAt) : (y.checkOk ? 'Yok' : '—')],
        ['Dışa aktarma sayısı', y.exportCount === null ? '—' : sayi(y.exportCount)],
        ['Son kontrol', `${zaman(y.checkedAt)} · ${y.checkOk ? 'Render API okundu' : `okunamadı: ${y.checkMessage ?? '—'}`}`],
      ] : [],
      not: y.configured ? null : 'Render bağlantısı kurulmadığı için yedeklemenin varlığı doğrulanamıyor.',
      baglanti: h('a', { class: 'oz-tumu', href: y.configured ? '#/sistem/yedek' : '#/entegrasyonlar' }, y.configured ? 'Şimdi kontrol et ›' : 'Bağlantıyı kur ›'),
    }));
  }

  // 5–7) SMS, e-posta, dosya depolama — gerçek kaynak + son 24 saat gönderim (23 Eki).
  const gonderimKarti = (tur, ad, ikonAd, v) => {
    const kk = kanal(tur);
    const dd = kanalDurumu(kk);
    return sistemKarti({
      ad, ikonAd, sinif: dd.sinif, durumMetni: dd.metin,
      ana: v ? sayi(v.SENT) : undefined, anaAlt: v ? 'başarılı gönderim · son 24 saat' : undefined,
      // Hata yoksa çubuk gösterilmez (23 Eki: ana ekranda yalnız son 24 saatin hataları).
      ek: v && (v.SENT + v.FAILED + v.PENDING) > 0 ? oranCubugu([{ ad: 'Gönderildi', deger: v.SENT, sinif: 'iyi' }, { ad: 'Başarısız', deger: v.FAILED, sinif: 'kotu' }, { ad: 'Bekleyen', deger: v.PENDING, sinif: 'notr' }]) : null,
      satirlar: [
        ['Kaynak', kanalKaynagi(kk)],
        ...(kk?.lastTestAt ? [['Son test', `${zaman(kk.lastTestAt)} · ${kk.lastTestOk ? 'başarılı' : 'başarısız'}`]] : []),
        ...((tur === 'STORAGE' || (tur === 'EMAIL' && kk?.provider === 'resend' && kk?.source === 'panel')) && kk?.source !== 'yok' ? [['Otomatik kontrol', kk?.autoCheckAt ? `${zaman(kk.autoCheckAt)} · ${kk.autoCheckOk ? 'başarılı' : 'başarısız'} · 15 dakikada bir` : 'Henüz yapılmadı · 15 dakikada bir']] : []),
      ],
    });
  };
  kartlar.push(gonderimKarti('SMS', 'SMS', 'sms', d.sms));
  kartlar.push(gonderimKarti('EMAIL', 'E-posta', 'posta', d.email));
  kartlar.push(gonderimKarti('STORAGE', 'Dosya depolama', 'depo', null));

  // 8) Push bildirim — sunucu yapılandırması + son 24 saat (23 Eki).
  const p = d.push;
  const pushSinif = !p.configured ? 'uyari' : p.FAILED > 0 ? 'uyari' : p.SENT > 0 ? 'iyi' : 'notr';
  kartlar.push(sistemKarti({
    ad: 'Push bildirim', ikonAd: 'bulut', sinif: pushSinif,
    durumMetni: !p.configured ? 'Sunucuda yapılandırılmamış' : p.FAILED > 0 ? `${sayi(p.FAILED)} başarısız (24 saat)` : p.SENT > 0 ? 'Çalışıyor · gönderim var' : 'Yapılandırılmış · henüz gönderim yok',
    ana: sayi(p.SENT), anaAlt: 'gönderilen bildirim · son 24 saat',
    ek: (p.SENT + p.FAILED + p.NO_TOKEN + p.SKIPPED) === 0 ? null : oranCubugu([
      { ad: 'Gönderildi', deger: p.SENT, sinif: 'iyi' }, { ad: 'Başarısız', deger: p.FAILED, sinif: 'kotu' },
      { ad: 'Cihaz kaydı yok', deger: p.NO_TOKEN, sinif: 'notr' }, { ad: 'Tercih/hesap nedeniyle atlanan', deger: p.SKIPPED, sinif: 'notr' },
    ]),
  }));

  // 9) Hesap silme kuyrukları (yetkiye bağlı).
  const di = s.deletionIssues;
  if (di !== null) {
    const tukenen = di.filesExhausted + di.firebaseLongFailure + di.firebaseOpsLongFailure;
    const siSinif = tukenen > 0 ? 'kotu' : di.overdueAccountDeletions > 0 ? 'uyari' : 'iyi';
    kartlar.push(sistemKarti({
      ad: 'Hesap silme kuyrukları', ikonAd: 'silme', sinif: siSinif,
      durumMetni: siSinif === 'iyi' ? 'Bekleyen sorun yok' : siSinif === 'kotu' ? `${sayi(tukenen)} iş deneme hakkını tüketti` : 'Gecikmiş silme talebi var',
      satirlar: [
        ['Denemesi tükenen dosya silme', sayi(di.filesExhausted)],
        ['Uzun süreli hata · Firebase kaydı', sayi(di.firebaseLongFailure)],
        ['Uzun süreli hata · Firebase işlemleri', sayi(di.firebaseOpsLongFailure)],
        ['Süresi geçmiş hesap silme talebi', sayi(di.overdueAccountDeletions)],
      ],
      baglanti: h('a', { class: 'oz-tumu', href: '#/silmekuyruklari' }, 'Silme Kuyrukları ›'),
    }));
  }

  // 10) Yönetici güvenliği (yetkiye bağlı) — son 24 saat başarısız denemeler.
  const gv = s.adminSecurityEvents;
  if (gv !== null) {
    const gSinif = gv.length >= 5 ? 'uyari' : 'iyi';
    kartlar.push(sistemKarti({
      ad: 'Yönetici güvenliği', ikonAd: 'kalkan', sinif: gSinif,
      durumMetni: gv.length ? `${sayi(gv.length)} başarısız deneme (24 sa)` : 'Başarısız deneme yok (24 sa)',
      ana: sayi(gv.length), anaAlt: 'hatalı şifre/kod denemesi · son 24 saat',
    }));
  }

  // ── Genel durum (sunucunun kuralları) + kart sayımı ──
  const g = s.overall;
  const say = (x) => kartlar.filter((c) => c.classList.contains(x)).length;
  const genel = h('section', { class: `sd-hero ${GENEL[g.status][1]}` },
    h('div', { class: 'sd-hero-sol' },
      h('span', { class: `sd-hero-ikon ${GENEL[g.status][1]}` }, ikon(g.status === 'OK' ? 'tik' : 'nabiz', 30)),
      h('div', {},
        h('h3', {}, GENEL[g.status][0]),
        h('p', { class: 'not' }, `Son kontrol: ${zaman(s.checkedAt)} · sunucu saati ${zaman(s.api.serverTime)}`))),
    h('div', { class: 'sd-hero-sayac' },
      [['iyi', 'Sağlıklı'], ['uyari', 'Uyarı'], ['kotu', 'Sorun'], ['notr', 'Doğrulanmadı']].map(([c, ad]) =>
        h('div', { class: `sd-sayac ${c}` }, h('strong', {}, String(say(c))), h('span', {}, ad)))),
    g.problems.length || g.warnings.length
      ? h('ul', { class: 'sd-hero-madde' },
        g.problems.map((x) => h('li', { class: 'kotu' }, x)),
        g.warnings.map((x) => h('li', { class: 'uyari' }, x)))
      : h('p', { class: 'sd-hero-tamam' }, 'Ölçülen bütün göstergeler eşiklerin içinde.'),
    h('p', { class: 'not' }, 'Kurallar: veritabanı yanıt vermezse, son 15 dakikada en az 20 istekte sunucu hatası oranı %5 ve üstündeyse, bellek %90 ve üstündeyse veya anlık geri yükleme kullanılamıyorsa "Sorun var". Ölçülemeyen, doğrulanamayan, yapılandırılmamış gösterge ve son 24 saatteki başarısız gönderim "Uyarı" sayılır.'));

  // ── Son 24 saat grafikleri ──
  const grafikler = h('div', { class: 'oz-uclu sd-iki' },
    h('section', { class: 'oz-kart' },
      h('div', { class: 'oz-kart-ust' }, h('h3', {}, 'İstekler · son 24 saat'),
        h('div', { class: 'sd-oran-lejant' }, h('span', { class: 'sd-lejant mavi' }, 'İstek'), h('span', { class: 'sd-lejant uyari' }, '4xx'), h('span', { class: 'sd-lejant kotu' }, '5xx'))),
      saatlikGrafik(m.hourly24h, 'istek')),
    h('section', { class: 'oz-kart' },
      h('div', { class: 'oz-kart-ust' }, h('h3', {}, 'Ortalama yanıt süresi · son 24 saat')),
      saatlikGrafik(m.hourly24h, 'sure')));

  // ── Ayrıntı tabloları (katlanır) ──
  const pencere = [['Son 15 dk', m.last15m], ['Son 1 saat', m.last1h], ['Son 24 saat', m.last24h]];
  const olcumTablosu = tablo([
    ['Dönem', (x) => x[0]],
    ['İstek', (x) => sayi(x[1].requests)],
    ['Sunucu hatası (5xx)', (x) => (x[1].requests ? rozet(`${sayi(x[1].errors5xx)} · ${yuzde(x[1].rate5xx)}`, x[1].errors5xx ? (x[1].rate5xx >= 5 ? 'kotu' : 'uyari') : 'iyi') : '—')],
    ['İstemci hatası (4xx)', (x) => (x[1].requests ? `${sayi(x[1].errors4xx)} · ${yuzde(x[1].rate4xx)}` : '—')],
    ['İndirme sınırına takılan', (x) => (x[1].requests ? sayi(x[1].downloadLimited ?? 0) : '—')],
    ['Ortalama yanıt', (x) => (x[1].avgMs === null ? '—' : `${sayi(x[1].avgMs)} ms`)],
    ['En yavaş', (x) => (x[1].maxMs === null ? '—' : `${sayi(x[1].maxMs)} ms`)],
    ['1 sn üstü', (x) => (x[1].requests ? sayi(x[1].latency.under3000 + x[1].latency.over3000) : '—')],
  ], pencere);
  const entegrasyonlar = s.integrations === null
    ? h('p', { class: 'oz-bos' }, 'Entegrasyon ayrıntısı için yetkiniz yok.')
    : tablo([
      ['Tür', (x) => ({ SMS: 'SMS', EMAIL: 'E-posta', STORAGE: 'Depolama' }[x.type] ?? x.type)],
      ['Sağlayıcı', (x) => x.provider ?? '—'],
      ['Durum', (x) => (x.active ? rozet('Etkin', 'iyi') : rozet('Pasif', 'notr'))],
      ['Son test', (x) => zaman(x.lastTestAt)],
      ['Sonuç', (x) => (x.lastTestOk === true ? rozet('Başarılı', 'iyi') : x.lastTestOk === false ? rozet('Başarısız', 'kotu') : '—')],
      ['Mesaj', (x) => x.lastTestMessage ?? '—'],
    ], s.integrations);
  const sunucuHatalari = s.serverErrors === null
    ? h('p', { class: 'oz-bos' }, 'Sunucu hatalarını görmek için yetkiniz yok.')
    : tablo([
      ['Tarih', (x) => zaman(x.at)],
      ['İstek', (x) => `${x.method} ${x.path}`],
      ['Durum', (x) => rozet(String(x.status), 'kotu')],
      ['Hata kodu', (x) => x.code ?? '—'],
      ['İstek kimliği', (x) => x.requestId ?? '—'],
    ], s.serverErrors);
  const basarisiz = s.recentFailures === null
    ? h('p', { class: 'oz-bos' }, 'Gönderim hatalarını görmek için yetkiniz yok.')
    : tablo([
      ['Tarih', (x) => zaman(x.createdAt)],
      ['Kanal', (x) => (x.channel === 'EMAIL' ? 'E-posta' : x.channel)],
      ['Şablon', (x) => x.template],
      ['Sağlayıcı', (x) => x.provider ?? '—'],
      ['Deneme', (x) => sayi(x.attempts)],
      ['Sağlayıcı yanıtı', (x) => x.providerResponse ?? '—'],
    ], s.recentFailures);
  const guvenlik = gv === null ? null : tablo([
    ['Tarih', (x) => zaman(x.at)],
    ['Olay', (x) => OLAY[x.action] ?? x.action],
    ['Yönetici', (x) => x.admin ?? '—'],
    ['IP', (x) => x.ip ?? '—'],
  ], gv);

  return h('div', { class: 'oz' },
    h('div', { class: 'oz-baslik' },
      h('div', {}, h('h2', {}, 'Sistem Durumu'),
        h('p', {}, 'Her sistem kendi gerçek ölçümüyle; ölçülemeyen gösterge "Ölçülemiyor", kanıtı olmayan "Doğrulanmadı" yazar.'))),
    genel,
    h('div', { class: 'sd-izgara' }, kartlar),
    grafikler,
    katlanir('Hata oranları ve yanıt süreleri (dönemlere göre)', olcumTablosu,
      h('p', { class: 'not' }, m.since ? `Ölçüm başlangıcı: ${zaman(m.since)}. Bütün sunucu örneklerinin toplamıdır.` : 'Henüz ölçülmüş istek yok.')),
    katlanir('Panel entegrasyonları', entegrasyonlar),
    katlanir('Son sunucu hataları (5xx)', sunucuHatalari),
    // 23 Eki: yalnız son 24 saatin hataları; yoksa bölüm görünmez (eskiler Kayıtlar sayfasında).
    s.recentFailures?.length === 0 ? null : katlanir('Son başarısız gönderimler (24 saat)', basarisiz, s.recentFailures === null ? null : h('a', { class: 'oz-tumu', href: '#/gonderimler' }, 'Tümünü gör ›')),
    guvenlik ? katlanir('Yönetici güvenlik olayları (son 24 saat)', guvenlik) : null);
}
