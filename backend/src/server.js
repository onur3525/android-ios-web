// ═══════════════════════════════════════════════════════════════
// SUNUCU — /api/v1 (kullanıcı), /admin/v1 (admin API), /admin (panel)
//
// Admin API kuralları (her istekte, işleyiciden ÖNCE):
//   · /auth/login ve /auth/mfa dışında TAM oturum zorunlu
//   · GET dışındaki her istekte `X-HC-Admin: 1` başlığı zorunlu (CSRF:
//     özel başlık çapraz kaynaklı isteklerde ön kontrol gerektirir;
//     çerez ayrıca SameSite=Strict)
// ═══════════════════════════════════════════════════════════════
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { OTURUM_CEREZI, oturumCoz } from './auth.js';
import { config } from './config.js';
import { veritabaniAc } from './db.js';
import {
  ApiHatasi, Yonlendirici, cerezleriOku, govdeOku, hata, istekKimligi,
  istemciIp, jsonGonder,
} from './http.js';
import { adminRotalar } from './routes/admin.js';
import { depolamaEntegrasyonRotalar } from './routes/depolama_entegrasyon.js';
import { gercekZamanliKur } from './gercek_zamanli.js';
import { olaylar } from './olaylar.js';
import { fotoGonder, varlikGonder } from './katalog_foto.js';
import { adminKullaniciRotalar } from './routes/admin_kullanici.js';
import { kullaniciRotalar } from './routes/kullanici.js';
import { ilanRotalar, suresiDolanlariIsle } from './routes/ilan.js';
import { silmeTalepleriniIsle, sohbetTalepRotalar, talepSureleriniIsle } from './routes/sohbet_talep.js';
import { publicRotalar } from './routes/public.js';

const PANEL_KOKU = normalize(join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'admin'));
const ACIK_ADMIN_YOLLARI = new Set(['/admin/v1/auth/login', '/admin/v1/auth/mfa']);
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
  depolamaEntegrasyonRotalar(r, db);
  publicRotalar(r, db);
  adminRotalar(r, db);
  adminKullaniciRotalar(r, db);

  return async (req, res) => {
    const istekId = istekKimligi();
    const url = new URL(req.url, 'http://yerel');
    const yol = url.pathname;
    const cerezler = [];
    try {
      // Katalog görselleri (ham yanıt): yüklenen fotoğraf (depodan, özel) ve
      // uygulama paketindeki katalog görselleri (beyaz listeli, salt okunur).
      if (req.method === 'GET' && yol.startsWith('/api/v1/categories/photo/')) {
        return fotoGonder(db, decodeURIComponent(yol.slice('/api/v1/categories/photo/'.length)), res);
      }
      if (req.method === 'GET' && yol.startsWith('/katalog-varlik/')) {
        return varlikGonder(decodeURIComponent(yol.slice('/katalog-varlik/'.length)), res);
      }
      if (req.method === 'GET' && (yol === '/admin' || (yol.startsWith('/admin/') && !yol.startsWith('/admin/v1/')))) {
        return await panelDosyasi(res, yol);
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
          const c = await oturumCoz(db, token, 'full');
          if (!c) throw hata.kimlik();
          ctx.admin = c.admin;
          ctx.oturum = c.oturum;
        }
      }
      if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
        // Kategori fotoğrafı (base64, en fazla 5 MB) için daha geniş sınır; yalnız bu yol ve oturum doğrulandıktan sonra.
        const fotoYolu = req.method === 'POST' && /^\/admin\/v1\/catalog\/categories\/[^/]+\/photo$/.test(yol);
        ctx.body = await govdeOku(req, fotoYolu ? 8 * 1024 * 1024 : undefined);
      }

      const sonuc = await bulunan.isleyici(ctx);
      const baslik = cerezler.length ? { 'Set-Cookie': cerezler } : {};
      if (sonuc === undefined) return jsonGonder(res, 204, undefined, baslik);
      return jsonGonder(res, 200, sonuc, baslik);
    } catch (e) {
      const bilinen = e instanceof ApiHatasi;
      if (!bilinen) console.error(`[${istekId}]`, e);
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
  await olaylar.kur(db);
  const isler = [
    ['ilan_suresi', suresiDolanlariIsle],
    ['talep_suresi', talepSureleriniIsle],
    ['hesap_silme', silmeTalepleriniIsle],
  ];
  // Arka plan işleri her örnekte zamanlanır ama danışma kilidiyle YALNIZ
  // BİRİ çalıştırır; örnek düşerse sonraki turda başka biri devralır.
  const zamanlayici = setInterval(() => {
    for (const [ad, f] of isler) db.isKilidi(`is:${ad}`, () => f(db)).catch((e) => console.error(ad, e));
  }, 60_000);
  zamanlayici.unref();

  const uygulama = uygulamaKur(db);
  const sunucu = createServer((req, res) => {
    // Yük dengeleyici sağlık uçları (kimlik gerektirmez, veri sızdırmaz).
    if (req.url === '/healthz') return jsonGonder(res, 200, { ok: true });
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
  });

  // Düzgün kapanış (ölçek küçültme / yeni sürüm): önce hazır değil de,
  // yeni bağlantı alma, açık istekleri bitir, soketleri kapat, çık.
  const durum = { kapaniyor: false };
  const kapat = async () => {
    if (durum.kapaniyor) return;
    durum.kapaniyor = true;
    clearInterval(zamanlayici);
    setTimeout(() => process.exit(1), 25_000).unref();
    await new Promise((ok) => setTimeout(ok, 5_000)); // dengeleyici /readyz'yi görsün
    sunucu.close();
    hub.hepsiniKapat();
    sunucu.closeIdleConnections?.();
    await olaylar.kapat();
    await db.close();
    process.exit(0);
  };
  process.on('SIGTERM', kapat);
  process.on('SIGINT', kapat);
}
