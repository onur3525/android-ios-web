// ═══════════════════════════════════════════════════════════════
// SUNUCU — /api/v1 (kullanıcı), /admin/v1 (admin API), /admin (panel)
//
// Admin API kuralları (her istekte, işleyiciden ÖNCE):
//   · /auth/login ve /auth/mfa dışında TAM oturum zorunlu
//   · GET dışındaki her istekte `X-HC-Admin: 1` başlığı zorunlu (CSRF:
//     özel başlık çapraz kaynaklı isteklerde ön kontrol gerektirir;
//     çerez ayrıca SameSite=Strict)
// ═══════════════════════════════════════════════════════════════
import { gorselAdresleriEkle } from './gorsel_adresleri.js';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { OTURUM_CEREZI, anahtarParmakIzi, oturumCoz, yetkiliMi, yenidenDogrulamaHatasi, yenidenDogrulamayiTuket } from './auth.js';
import { config } from './config.js';
import { veritabaniAc } from './db.js';
import {
  ApiHatasi, Yonlendirici, cerezleriOku, govdeOku, hata, istekKimligi,
  ipTeshisi, istemciIp, jsonGonder,
} from './http.js';
import { GELEN_YOL, gelenEpostaWebhook } from './gelen_eposta.js';
import { pdfGonder } from './yasal_pdf.js';
import { depolamaKontrolEt, epostaKontrolEt, istekOlc, izlemeBakimi, olcumleriYaz } from './sistem_izleme.js';
import { yoneticiUyarilariniIsle } from './yonetici_uyarilari.js';
import { BAKIMDA_GIRIS_YOLLARI, bakimDurumu, bakimdaAcikMi, bakimIstisnasiMi } from './bakim_modu.js';
import { adminRotalar } from './routes/admin.js';
import { depolamaEntegrasyonRotalar } from './routes/depolama_entegrasyon.js';
import { gercekZamanliKur } from './gercek_zamanli.js';
import { olaylar } from './olaylar.js';
import { fotoGonder, varlikGonder } from './katalog_foto.js';
import { epostaVarligiGonder } from './eposta_tasarimi.js';
import { adminKullaniciRotalar } from './routes/admin_kullanici.js';
import { silmeKuyruklariRotalar } from './routes/silme_kuyruklari.js';
import { kullaniciRotalar } from './routes/kullanici.js';
import { ilanRotalar, suresiDolanlariIsle } from './routes/ilan.js';
import { silmeTalepleriniIsle, sohbetTalepRotalar, talepSureleriniIsle } from './routes/sohbet_talep.js';
import { kisiOzetiRotalar } from './routes/kisi_ozeti.js';
import { hataOzeti } from './guvenli_gunluk.js';
import { dosyaTemizliginiIsle } from './dosya_temizligi.js';
import { pushKuyrugunuIsle } from './fcm.js';
import { publicRotalar } from './routes/public.js';
import { destekRotalar } from './routes/destek.js';
import { kayitBakimi, saklamaSuresiBakimi } from './bakim.js';
import { firebaseSilmeKuyrugunuIsle } from './firebase_silme.js';
import { firebaseIslemKuyrugunuIsle } from './firebase_islemleri.js';
import { baslangicVerisiniHazirla } from './baslangic_verisi.js';

const PANEL_KOKU = normalize(join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'admin'));
const ACIK_ADMIN_YOLLARI = new Set(['/admin/v1/auth/login', '/admin/v1/auth/mfa']);
// 23 Eki: oturum ister ama hareketsizlik süresini UZATMAZ (panelin dakikalık arka plan sorgusu).
const PASIF_ADMIN_YOLLARI = new Set(['/admin/v1/support/pending-count']);
// Değişiklik sayılmayan oturum işlemleri: yeniden doğrulamanın kendisi ve çıkış.
const YENIDEN_DOGRULAMASIZ = new Set(['/admin/v1/auth/reauth', '/admin/v1/auth/logout']);
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml' };
const PANEL_CSP = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; object-src 'none'";

async function panelDosyasi(res, yol) {
  let goreli = yol.replace(/^\/admin\/?/, '') || 'index.html';
  if (!extname(goreli)) goreli = 'index.html'; // tek sayfa uygulama
  const tam = normalize(join(PANEL_KOKU, goreli));
  if (!tam.startsWith(PANEL_KOKU)) return jsonGonder(res, 404, { error: { code: 'NOT_FOUND', message: 'Bulunamadı' } });
  try {
    const icerik = await readFile(tam);
    res.writeHead(200, {
      'Content-Type': MIME[extname(tam)] || 'application/octet-stream',
      'Content-Security-Policy': PANEL_CSP,
      'X-Frame-Options': 'DENY',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
      ...(config.cerezSecure ? { 'Strict-Transport-Security': 'max-age=31536000; includeSubDomains' } : {}),
      'Cache-Control': 'no-store',
    });
    res.end(icerik);
  } catch {
    jsonGonder(res, 404, { error: { code: 'NOT_FOUND', message: 'Bulunamadı' } });
  }
}

export function uygulamaKur(db) {
  const r = new Yonlendirici();
  // ⚠ SIRA: özel yollar ('/legal/pending-acceptances') genel desenden
  // ('/legal/:slug') ÖNCE kaydedilir; yönlendirici ilk eşleşeni alır.
  kullaniciRotalar(r, db);
  ilanRotalar(r, db);
  sohbetTalepRotalar(r, db);
  kisiOzetiRotalar(r, db);
  depolamaEntegrasyonRotalar(r, db);
  destekRotalar(r, db);
  publicRotalar(r, db);
  adminRotalar(r, db);
  adminKullaniciRotalar(r, db);
  silmeKuyruklariRotalar(r, db);

  return async (req, res) => {
    const istekId = istekKimligi();
    const url = new URL(req.url, 'http://yerel');
    const yol = url.pathname;
    const cerezler = [];
    // ── SİSTEM DURUMU ÖLÇÜMÜ (22 Eki): kullanıcı API'sinin her yanıtı
    // (durum kodu + süre) sayılır; 5xx'te hata kodu ve istek kimliği de.
    if (yol.startsWith('/api/v1/')) {
      const t0 = performance.now();
      res.once('finish', () => istekOlc({ yontem: req.method, yol, durum: res.statusCode, ms: performance.now() - t0, kod: res.hcHataKodu, istekId }));
    }
    // ── CORS (yalnız kullanıcı API'si ve gerçek zamanlı yol) ──
    // İzin listesindeki tam köken yansıtılır ('*' yok). Kimlik Bearer ile
    // taşınır; YALNIZ web istemcisinin oturum yenileme çerezi (hc_rt,
    // HttpOnly) için Allow-Credentials verilir — bu da yalnız izin
    // listesindeki kökenlere. Admin yolları kapsam dışı.
    const corsYolu = yol.startsWith('/api/v1/') || yol.startsWith('/socket.io/');
    const koken = req.headers.origin;
    const corsIzinli = corsYolu && typeof koken === 'string' && config.corsKokenleri.includes(koken);
    if (corsIzinli) {
      res.setHeader('Access-Control-Allow-Origin', koken);
      res.setHeader('Access-Control-Allow-Credentials', 'true');
      res.setHeader('Vary', 'Origin');
    }
    if (req.method === 'OPTIONS' && corsYolu) {
      if (corsIzinli) {
        res.writeHead(204, {
          'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE',
          'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept, Idempotency-Key, X-HC-Web, X-HC-Cihaz, X-HC-Platform',
          'Access-Control-Max-Age': '600',
        });
      } else {
        res.writeHead(204, { Vary: 'Origin' }); // izin verilmeyen köken: CORS başlığı yok, tarayıcı engeller
      }
      return res.end();
    }
    try {
      // Geçici IP teşhisi: yalnız HC_IP_TESHIS=true iken (bkz. http.js ipTeshisi).
      if (req.method === 'GET' && yol === '/teshis/ip' && process.env.HC_IP_TESHIS === 'true') {
        return jsonGonder(res, 200, ipTeshisi(req));
      }
      // Katalog görselleri (ham yanıt): yüklenen fotoğraf (depodan, özel) ve
      // uygulama paketindeki katalog görselleri (beyaz listeli, salt okunur).
      if (req.method === 'GET' && yol.startsWith('/api/v1/categories/photo/')) {
        return fotoGonder(db, decodeURIComponent(yol.slice('/api/v1/categories/photo/'.length)), res);
      }
      // ── YASAL BELGE PDF'İ (031): yayında ya da arşivdeki sürüm herkese açık
      // (kullanıcı kabul ettiği sürümü görebilmeli); taslak YALNIZ admin.
      {
        const m = req.method === 'GET' && /^\/api\/v1\/legal\/([a-z][a-z0-9-]{1,40})\/pdf\/(\d{1,6})$/.exec(yol);
        if (m) {
          const v = await db.prepare(`SELECT pdf_ref FROM legal_versions WHERE slug = ? AND version = ? AND status <> 'DRAFT'`).get(m[1], Number(m[2]));
          return pdfGonder(db, v?.pdf_ref, res, `${m[1]}-v${m[2]}.pdf`);
        }
        const a = req.method === 'GET' && /^\/admin\/v1\/legal\/([a-z][a-z0-9-]{1,40})\/versions\/(\d{1,6})\/pdf$/.exec(yol);
        if (a) {
          const c = await oturumCoz(db, cerezleriOku(req)[OTURUM_CEREZI], 'full');
          if (!c) throw hata.kimlik();
          if (!yetkiliMi(c.admin.role, 'legal.read')) throw hata.yetki();
          const v = await db.prepare('SELECT pdf_ref FROM legal_versions WHERE slug = ? AND version = ?').get(a[1], Number(a[2]));
          return pdfGonder(db, v?.pdf_ref, res, `${a[1]}-v${a[2]}.pdf`);
        }
      }
      // Destek e-postaları (Resend Receiving webhook'u): ham gövde + imza (gelen_eposta.js).
      if (yol === GELEN_YOL) return await gelenEpostaWebhook(db, req, res);
      if (req.method === 'GET' && yol.startsWith('/eposta-varlik/')) {
        return epostaVarligiGonder(yol.slice('/eposta-varlik/'.length), res);
      }
      if (req.method === 'GET' && yol.startsWith('/katalog-varlik/')) {
        return varlikGonder(decodeURIComponent(yol.slice('/katalog-varlik/'.length)), res);
      }
      if (req.method === 'GET' && (yol === '/admin' || (yol.startsWith('/admin/') && !yol.startsWith('/admin/v1/')))) {
        return await panelDosyasi(res, yol);
      }
      // ── BAKIM MODU (22 Eki): kullanıcı API'si 503 döner (admin etkilenmez).
      // Bakımda erişebilen test hesabı (032) geçer; giriş uçlarında karar
      // şifre doğrulandıktan sonra hesaba göre verilir (bakimGirisKapisi).
      if (yol.startsWith('/api/v1/') && !bakimdaAcikMi(yol) && !BAKIMDA_GIRIS_YOLLARI.has(yol)) {
        const b = await bakimDurumu(db);
        if (b.aktif && !(await bakimIstisnasiMi(db, req))) {
          res.setHeader('Retry-After', '60');
          throw new ApiHatasi(503, 'MAINTENANCE', b.mesaj || 'Bakım çalışması sürüyor');
        }
      }
      const bulunan = r.bul(req.method, yol);
      if (bulunan === 'YONTEM') throw new ApiHatasi(405, 'METHOD_NOT_ALLOWED', 'Yöntem desteklenmiyor');
      if (!bulunan) throw hata.bulunamadi('Uç nokta bulunamadı');

      const token = cerezleriOku(req)[OTURUM_CEREZI];
      const ctx = {
        req, params: bulunan.params, query: url.searchParams, ip: istemciIp(req), token,
        body: {}, admin: null, oturum: null,
        cerezEkle: (c) => cerezler.push(c),
        oturumAsamasi: (a) => oturumCoz(db, token, a),
      };

      if (yol.startsWith('/admin/v1/')) {
        if (req.method !== 'GET' && req.headers['x-hc-admin'] !== '1') throw hata.yetki('Eksik istek başlığı');
        if (!ACIK_ADMIN_YOLLARI.has(yol)) {
          // 23 Eki: arka plan sorguları (bekleyen talep sayısı) hareketsizlik süresini uzatmaz.
          const c = await oturumCoz(db, token, 'full', { etkinlik: !(req.method === 'GET' && PASIF_ADMIN_YOLLARI.has(yol)) });
          if (!c) throw hata.kimlik();
          ctx.admin = c.admin;
          ctx.oturum = c.oturum;
          // ⚠ HER DEĞİŞİKLİK şifre + doğrulama kodu ister (tek kullanımlık).
          // Görüntüleme (GET) serbest. Gövde okunmadan ÖNCE reddedilir.
          if (req.method !== 'GET' && !YENIDEN_DOGRULAMASIZ.has(yol) && !(await yenidenDogrulamayiTuket(db, token))) {
            throw yenidenDogrulamaHatasi();
          }
        }
      }
      if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
        // Kategori fotoğrafı (base64, en fazla 5 MB) için daha geniş sınır; yalnız bu yol ve oturum doğrulandıktan sonra.
        const fotoYolu = req.method === 'POST' && /^\/admin\/v1\/catalog\/roofs\/[^/]+\/photo$/.test(yol);
        // Yasal belge PDF'i (en fazla 10 MB; base64 ile ~13,4 MB) — yalnız bu yol, oturum doğrulandıktan sonra.
        const pdfYolu = req.method === 'POST' && /^\/admin\/v1\/legal\/[^/]+\/versions$/.test(yol);
        ctx.body = await govdeOku(req, pdfYolu ? 15 * 1024 * 1024 : fotoYolu ? 8 * 1024 * 1024 : undefined);
      }

      let sonuc = await bulunan.isleyici(ctx);
      // Kullanıcı API'si: dosya referanslarının yanına imzalı görüntüleme
      // adresi eklenir (ilan/talep/sohbet fotoğrafları; bkz. gorsel_adresleri.js).
      if (sonuc !== undefined && yol.startsWith('/api/v1/')) sonuc = await gorselAdresleriEkle(db, sonuc);
      const baslik = cerezler.length ? { 'Set-Cookie': cerezler } : {};
      if (sonuc === undefined) return jsonGonder(res, 204, undefined, baslik);
      return jsonGonder(res, 200, sonuc, baslik);
    } catch (e) {
      const bilinen = e instanceof ApiHatasi;
      if (!bilinen) console.error(`[${istekId}]`, JSON.stringify(hataOzeti(e))); // B11: tam nesne yazılmaz
      res.hcHataKodu = bilinen ? e.kod : 'INTERNAL_ERROR';
      const baslik = cerezler.length ? { 'Set-Cookie': cerezler } : {};
      return jsonGonder(res, bilinen ? e.durum : 500, {
        error: { code: bilinen ? e.kod : 'INTERNAL_ERROR', message: bilinen ? e.message : 'Beklenmeyen bir hata oluştu' },
        requestId: istekId,
      }, baslik);
    }
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  // ═══ ÇOK ÖRNEKLİ ÇALIŞMA ═══
  // Bu süreç DURUMSUZDUR: oturumlar, hız sınırları, olaylar, dosyalar ve
  // ayarlar ortak kaynaklarda (PostgreSQL, nesne depolama). Yük
  // dengeleyici arkasında N örnek aynı kodla çalışır; otomatik ölçekleme
  // altyapıya aittir (bkz. backend/DEPLOY.md).
  const db = await veritabaniAc(config.veritabani);
  // Katalog/bölge/yasal tablolar BOŞSA uygulama verisinden doldurulur
  // (bkz. baslangic_verisi.js). Hata açılışı durdurmaz ama açıkça yazılır.
  try {
    const s = await baslangicVerisiniHazirla(db);
    if (s && Object.values(s).some((n) => n > 0)) console.log('Başlangıç verisi aktarıldı:', JSON.stringify(s));
  } catch (e) {
    console.error('UYARI: başlangıç verisi aktarılamadı (ilan açma katalog ister):', e.message);
  }
  await olaylar.kur(db);
  const isler = [
    ['ilan_suresi', suresiDolanlariIsle],
    ['talep_suresi', talepSureleriniIsle],
    ['hesap_silme', silmeTalepleriniIsle],
    ['dosya_temizligi', dosyaTemizliginiIsle],
    ['kayit_bakimi', kayitBakimi],
    // 23 Eki: Gizlilik Politikası'ndaki 2 yıllık saklama süreleri.
    ['saklama_suresi', saklamaSuresiBakimi],
    ['firebase_silme', firebaseSilmeKuyrugunuIsle],
    ['firebase_islemleri', firebaseIslemKuyrugunuIsle],
    ['izleme_bakimi', izlemeBakimi],
    // 23 Eki: dakikada bir bakılır; son kontrol 15 dakikadan eskiyse depo kontrol edilir.
    ['depolama_kontrolu', depolamaKontrolEt],
    ['eposta_kontrolu', epostaKontrolEt],
    // 23 Eki: yönetici e-posta uyarıları (yeni talep, giriş, sistem sorunu, yavaşlama).
    ['yonetici_uyarilari', yoneticiUyarilariniIsle],
  ];
  // Arka plan işleri her örnekte zamanlanır ama danışma kilidiyle YALNIZ
  // BİRİ çalıştırır; örnek düşerse sonraki turda başka biri devralır.
  const zamanlayici = setInterval(() => {
    for (const [ad, f] of isler) db.isKilidi(`is:${ad}`, () => f(db)).catch((e) => console.error(ad, JSON.stringify(hataOzeti(e))));
    // Push kendi kilit yuvalarını yönetir (HC_PUSH_PARALEL ile çok işçi).
    pushKuyrugunuIsle(db).catch((e) => console.error('push_gonderimi', JSON.stringify(hataOzeti(e))));
  }, 60_000);
  zamanlayici.unref();
  // API ölçümleri her örnekte 15 sn'de bir veritabanına eklenir.
  const olcumZamanlayici = setInterval(() => olcumleriYaz(db).catch((e) => console.error('olcum_yazma', e?.message)), 15_000);
  olcumZamanlayici.unref();

  const uygulama = uygulamaKur(db);
  const sunucu = createServer((req, res) => {
    // Yük dengeleyici sağlık uçları (kimlik gerektirmez, veri sızdırmaz).
    // `anahtar`: ana anahtarın tek yönlü parmak izi (bkz. auth.js
    // anahtarParmakIzi) — bakım aracı canlıyla aynı anahtarı kullandığını
    // doğrular. Anahtarın kendisi ya da çözülebilir bir bilgisi DEĞİLDİR.
    if (req.url === '/healthz') return jsonGonder(res, 200, { ok: true, anahtar: anahtarParmakIzi() });
    if (req.url === '/readyz') {
      if (durum.kapaniyor) return jsonGonder(res, 503, { ok: false });
      return db.prepare('SELECT 1 AS ok').get()
        .then(() => jsonGonder(res, 200, { ok: true }))
        .catch(() => jsonGonder(res, 503, { ok: false }));
    }
    return uygulama(req, res);
  });
  sunucu.keepAliveTimeout = 65_000; // yük dengeleyicinin boşta süresinden uzun
  const hub = gercekZamanliKur(sunucu, db);
  sunucu.listen(config.port, () => {
    console.log(`HizmetCep backend dinliyor: :${config.port} (veritabanı: ${config.veritabani.surucu}, örnek: ${olaylar.ornekId})`);
    // Ortamda SMS/e-posta sağlayıcısı yoksa açıkça uyarılır (admin
    // entegrasyonu da etkin değilse gönderimler FAILED düşer). Sır yazılmaz.
    if (process.env.HC_IP_TESHIS === 'true') console.warn('UYARI: HC_IP_TESHIS açık — /teshis/ip geçici ölçüm ucu yanıt veriyor; ölçüm bitince kaldırın.');
    for (const [ad, s] of [['SMS', config.sms], ['EMAIL', config.eposta]]) {
      if (s.ad === 'yok') console.warn(`UYARI: HC_${ad}_PROVIDER tanımsız — ${ad} gönderimi yalnız admin panelindeki etkin entegrasyonla yapılır; o da yoksa gönderimler FAILED kaydedilir.`);
    }
  });

  // Düzgün kapanış (ölçek küçültme / yeni sürüm): önce hazır değil de,
  // yeni bağlantı alma, açık istekleri bitir, soketleri kapat, çık.
  const durum = { kapaniyor: false };
  const kapat = async () => {
    if (durum.kapaniyor) return;
    durum.kapaniyor = true;
    clearInterval(zamanlayici);
    clearInterval(olcumZamanlayici);
    setTimeout(() => process.exit(1), 25_000).unref();
    await new Promise((ok) => setTimeout(ok, 5_000)); // dengeleyici /readyz'yi görsün
    sunucu.close();
    hub.hepsiniKapat();
    sunucu.closeIdleConnections?.();
    await olaylar.kapat();
    await olcumleriYaz(db).catch(() => {}); // kapanmadan son ölçümler
    await db.close();
    process.exit(0);
  };
  process.on('SIGTERM', kapat);
  process.on('SIGINT', kapat);
}
