// ═══════════════════════════════════════════════════════════════
// KATEGORİ FOTOĞRAFI — MEVCUT nesne depolama (S3 uyumlu, imzalı adres)
//
//   · Yükleme SUNUCU ÜZERİNDEN: admin dosyayı backend'e gönderir; backend
//     tür (sihirli bayt), boyut ve uzantıyı DOĞRULAR, anahtarı KENDİ üretir
//     (`katalog/kategori/<uuid>.<uzantı>`; kullanıcı dosya adı kullanılmaz)
//     ve kısa ömürlü imzalı PUT ile depoya yazar.
//   · Okuma: depo ÖZEL kalır; görsel backend üzerinden akıtılır
//     (`GET /api/v1/categories/photo/<anahtar>`), anahtar benzersiz
//     olduğundan değişmez önbellek başlığıyla. Admin ve Flutter aynı yolu
//     kullanır; CSP/CORS gevşetilmez.
//   · Değiştirme/kaldırma: eski nesne imzalı DELETE ile silinir.
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { dirname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import { depolamaAyari, s3ImzaliAdres } from './entegrasyon.js';
import { ApiHatasi } from './http.js';

export const FOTO_AZAMI = 5 * 1024 * 1024; // 5 MB
const TURLER = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };
export const FOTO_ANAHTAR = /^katalog\/kategori\/[0-9a-f-]{36}\.(jpg|png|webp)$/;

/** İçerik gerçekten iddia edilen görsel türü mü? (sihirli baytlar) */
function turDogru(b, tur) {
  if (tur === 'image/jpeg') return b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;
  if (tur === 'image/png') return b.length > 8 && b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  if (tur === 'image/webp') return b.length > 12 && b.toString('latin1', 0, 4) === 'RIFF' && b.toString('latin1', 8, 12) === 'WEBP';
  return false;
}

async function ayarIste(db) {
  const a = await depolamaAyari(db);
  if (!a) throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Dosya depolama yapılandırılmamış (Entegrasyonlar → Depolama)');
  return a;
}

/** Doğrular ve depoya yazar; nesne anahtarını döndürür. */
export async function fotoYukle(db, contentType, base64) {
  const tur = String(contentType || '');
  if (!TURLER[tur]) throw new ApiHatasi(400, 'VALIDATION_ERROR', 'Yalnız JPEG, PNG ya da WEBP yüklenebilir');
  const veri = Buffer.from(String(base64 || ''), 'base64');
  if (!veri.length) throw new ApiHatasi(400, 'VALIDATION_ERROR', 'Dosya boş');
  if (veri.length > FOTO_AZAMI) throw new ApiHatasi(400, 'VALIDATION_ERROR', 'Fotoğraf en fazla 5 MB olabilir');
  if (!turDogru(veri, tur)) throw new ApiHatasi(400, 'VALIDATION_ERROR', 'Dosya içeriği seçilen görsel türüyle uyuşmuyor');
  const ayar = await ayarIste(db);
  const anahtar = `katalog/kategori/${randomUUID()}.${TURLER[tur]}`;
  const r = await fetch(s3ImzaliAdres(ayar, { yontem: 'PUT', anahtar, sureSn: 300, icerikTuru: tur }), {
    method: 'PUT', headers: { 'Content-Type': tur }, body: veri, signal: AbortSignal.timeout(20000),
  }).catch(() => null);
  if (!r || !r.ok) throw new ApiHatasi(502, 'EXTERNAL_SERVICE_ERROR', 'Fotoğraf depoya yazılamadı');
  return anahtar;
}

/** Nesneyi depodan siler. Başarısızsa false (çağıran denetim kaydına yazar). */
export async function fotoSil(db, anahtar) {
  if (!FOTO_ANAHTAR.test(String(anahtar || ''))) return false;
  const ayar = await depolamaAyari(db);
  if (!ayar) return false;
  const r = await fetch(s3ImzaliAdres(ayar, { yontem: 'DELETE', anahtar, sureSn: 300 }), { method: 'DELETE', signal: AbortSignal.timeout(10000) }).catch(() => null);
  return !!r && (r.ok || r.status === 404);
}

/** Depodaki fotoğrafı istemciye akıtır (özel depo; imzalı GET sunucuda). */
export async function fotoGonder(db, anahtar, res) {
  if (!FOTO_ANAHTAR.test(anahtar)) return bulunamadi(res);
  const bagli = await db.prepare('SELECT 1 FROM categories WHERE photo_ref = ? AND deleted_at IS NULL').get(anahtar);
  if (!bagli) return bulunamadi(res); // yalnız bir kategoriye BAĞLI fotoğraflar sunulur
  const ayar = await depolamaAyari(db);
  const r = ayar ? await fetch(s3ImzaliAdres(ayar, { yontem: 'GET', anahtar, sureSn: 120 }), { signal: AbortSignal.timeout(10000) }).catch(() => null) : null;
  if (!r || !r.ok) return bulunamadi(res);
  const tur = r.headers.get('content-type') || 'application/octet-stream';
  res.writeHead(200, {
    'Content-Type': TURLER[tur] ? tur : 'application/octet-stream',
    'Cache-Control': 'public, max-age=31536000, immutable', // anahtar benzersiz
    'X-Content-Type-Options': 'nosniff',
    'Content-Security-Policy': "default-src 'none'",
  });
  res.end(Buffer.from(await r.arrayBuffer()));
}

// ── Uygulama paketindeki katalog görselleri (admin önizlemesi) ──
// Zaten herkese açık uygulama paketinin parçası; yalnız beyaz listedeki
// iki klasör, yalnız okuma.
const VARLIK_KOKU = normalize(join(dirname(fileURLToPath(import.meta.url)), '..', '..'));
const VARLIK = /^assets\/(categories\/[a-z0-9_]+\.(jpg|png|webp)|svg\/categories\/[a-z0-9_]+\.svg)$/;
const VARLIK_TUR = { jpg: 'image/jpeg', png: 'image/png', webp: 'image/webp', svg: 'image/svg+xml' };

export async function varlikGonder(yol, res) {
  if (!VARLIK.test(yol)) return bulunamadi(res);
  const tam = normalize(join(VARLIK_KOKU, yol));
  if (!tam.startsWith(join(VARLIK_KOKU, 'assets'))) return bulunamadi(res);
  try {
    const icerik = await readFile(tam);
    res.writeHead(200, {
      'Content-Type': VARLIK_TUR[yol.split('.').pop()],
      'Cache-Control': 'public, max-age=3600',
      'X-Content-Type-Options': 'nosniff',
      // SVG içinde betik çalışmasın.
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'",
    });
    res.end(icerik);
  } catch {
    bulunamadi(res);
  }
}

function bulunamadi(res) {
  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end('Bulunamadı');
}
