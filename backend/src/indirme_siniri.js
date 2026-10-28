// ═══════════════════════════════════════════════════════════════
// İNDİRME SINIRI — fotoğraf / PDF / katalog varlığı (28 Eki)
// ═══════════════════════════════════════════════════════════════
//
// Sorun (ölçüm, yerel): bu uçlar kimliksizdir ve her istek depodan 5–10 MB
// çeker. Tek IP'den 50 eşzamanlı istek 30 sn'de depodan ~10 GB indirdi;
// aynı anda normal kullanıcıların p95 süresi 1,2 sn'ye çıktı.
//
// Kural (bellekte, sunucu başına; veritabanına dokunmaz):
//   · IP başına aynı anda en çok `ipEsz` (6) indirme,
//   · sunucu genelinde aynı anda en çok `toplamEsz` (40) indirme,
//   · fazlası HEMEN REDDEDİLMEZ, sıraya girer (en çok `beklemeMs`, 10 sn) —
//     aynı IP'yi paylaşan (operatör NAT'ı) gerçek kullanıcılar yavaşlar ama
//     fotoğrafsız kalmaz,
//   · sıra doluysa (IP başına `ipKuyruk`, genel `toplamKuyruk`) ya da
//     bekleme süresi dolarsa 429,
//   · IP başına dakikada en çok `ipDakika` (300) indirme; aşan 429.
// İstemci beklerken bağlantıyı kaparsa sıradan çıkar.
// Tek kaynak: sınırlar HC_INDIRME_* ortam değişkenleriyle değiştirilebilir.

const sayi = (ad, v) => {
  const n = Number(process.env[ad]);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : v;
};

export function indirmeSiniriKur({
  ipEsz = sayi('HC_INDIRME_IP_ESZ', 6),
  toplamEsz = sayi('HC_INDIRME_TOPLAM_ESZ', 40),
  ipDakika = sayi('HC_INDIRME_IP_DAKIKA', 300),
  beklemeMs = sayi('HC_INDIRME_BEKLEME_MS', 10_000),
  ipKuyruk = sayi('HC_INDIRME_IP_KUYRUK', 20),
  toplamKuyruk = sayi('HC_INDIRME_TOPLAM_KUYRUK', 200),
  simdi = () => Date.now(),
} = {}) {
  const aktif = new Map(); // ip → eşzamanlı indirme sayısı
  let toplamAktif = 0;
  const sira = []; // { ip, coz, zaman }
  const bekleyenIp = new Map(); // ip → sıradaki sayısı
  const dakika = new Map(); // ip → { pencere, n }
  const AZAMI_IP = 50_000; // bellek tavanı (sayaç tablosu)

  const artir = (m, k, d) => {
    const v = (m.get(k) ?? 0) + d;
    if (v > 0) m.set(k, v); else m.delete(k);
  };
  const yerVar = (ip) => toplamAktif < toplamEsz && (aktif.get(ip) ?? 0) < ipEsz;

  // Dakika sayacı yalnız BAŞLAYAN indirmeleri sayar (429 alan denemeler
  // sayılmaz; aynı IP'yi paylaşan gerçek kullanıcıların payını yemesin).
  function dakikaKaydi(ip) {
    const p = Math.floor(simdi() / 60_000);
    let s = dakika.get(ip);
    if (!s || s.pencere !== p) {
      if (!s && dakika.size >= AZAMI_IP) {
        for (const [k, v] of dakika) if (v.pencere !== p) dakika.delete(k);
        if (dakika.size >= AZAMI_IP) dakika.clear();
      }
      s = { pencere: p, n: 0 };
      dakika.set(ip, s);
    }
    return s;
  }
  const dakikaSonu = () => Math.max(1, 60 - Math.floor((simdi() % 60_000) / 1000));

  function baslat(ip) {
    dakikaKaydi(ip).n += 1;
    artir(aktif, ip, 1);
    toplamAktif += 1;
    let birakildi = false;
    return () => {
      if (birakildi) return;
      birakildi = true;
      artir(aktif, ip, -1);
      toplamAktif -= 1;
      siradakiler();
    };
  }

  function siradakiler() {
    for (let i = 0; i < sira.length && toplamAktif < toplamEsz;) {
      const b = sira[i];
      if (yerVar(b.ip)) {
        sira.splice(i, 1);
        artir(bekleyenIp, b.ip, -1);
        b.coz({ ok: true, birak: baslat(b.ip) });
      } else {
        i += 1;
      }
    }
  }

  /**
   * İndirme izni ister. `{ ok: true, birak }` (indirme bitince birak() ÇAĞRILMALI)
   * ya da `{ ok: false, sonraSn }` (429 dönülmeli).
   * @param kapanis istemci bağlantısı kapanınca tetiklenen olay kaynağı (req)
   */
  function al(ip, kapanis) {
    const anahtar = String(ip || '?');
    // Sırada bekleyenler de payı kullanmış sayılır (sınır aşılmasın).
    if (dakikaKaydi(anahtar).n + (bekleyenIp.get(anahtar) ?? 0) >= ipDakika) {
      return Promise.resolve({ ok: false, sonraSn: dakikaSonu() });
    }
    if (yerVar(anahtar) && !sira.length) return Promise.resolve({ ok: true, birak: baslat(anahtar) });
    if (sira.length >= toplamKuyruk || (bekleyenIp.get(anahtar) ?? 0) >= ipKuyruk) {
      return Promise.resolve({ ok: false, sonraSn: Math.ceil(beklemeMs / 1000) });
    }
    return new Promise((coz) => {
      const kayit = { ip: anahtar, coz: null };
      const cik = (sonuc) => {
        const i = sira.indexOf(kayit);
        if (i < 0) return;
        sira.splice(i, 1);
        artir(bekleyenIp, anahtar, -1);
        clearTimeout(zaman);
        kapanis?.off?.('close', kapandi);
        coz(sonuc);
      };
      const kapandi = () => cik({ ok: false, sonraSn: 1, kapandi: true });
      const zaman = setTimeout(() => cik({ ok: false, sonraSn: Math.ceil(beklemeMs / 1000) }), beklemeMs);
      kayit.coz = (sonuc) => {
        clearTimeout(zaman);
        kapanis?.off?.('close', kapandi);
        coz(sonuc);
      };
      sira.push(kayit);
      artir(bekleyenIp, anahtar, 1);
      kapanis?.once?.('close', kapandi);
      siradakiler();
    });
  }

  return {
    al,
    durum: () => ({ toplamAktif, sira: sira.length, ipSayisi: dakika.size }),
  };
}

/** 429 yanıtı (ham; fotoğraf/PDF uçları JSON beklemez). */
export function cokFazlaIndirme(res, sonraSn) {
  if (res.headersSent || res.destroyed) return;
  // Sistem Durumu'nda ayrı sayılır (sistem_izleme.js, 043).
  res.hcHataKodu = 'DOWNLOAD_LIMIT';
  res.writeHead(429, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store',
    'Retry-After': String(sonraSn),
  });
  res.end('Çok fazla istek');
}
