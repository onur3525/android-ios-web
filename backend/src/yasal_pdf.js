// ═══════════════════════════════════════════════════════════════
// YASAL BELGE PDF'İ (22 Eki, kullanıcı kararı)
//
// Admin yasal belgeyi PDF olarak yükler ve kısa bir özet yazar. Kullanıcı
// uygulamaya girdiğinde özeti görür; isterse PDF'in tamamını açar, "Tamam"
// ile kabul eder. PDF mevcut nesne depolamada (özel) durur ve backend
// üzerinden akıtılır; anahtarı sunucu üretir (`yasal/<uuid>.pdf`).
// Kabulün ispatı (sha256) PDF'in baytlarından hesaplanır: kullanıcı tam
// olarak hangi dosyayı kabul ettiği kayda geçer.
// ═══════════════════════════════════════════════════════════════
import { createHash, randomUUID } from 'node:crypto';
import { depolamaAyari, s3ImzaliAdres } from './entegrasyon.js';
import { ApiHatasi } from './http.js';

export const PDF_AZAMI = 10 * 1024 * 1024; // 10 MB
export const PDF_ANAHTAR = /^yasal\/[0-9a-f-]{36}\.pdf$/;

/** Doğrular, depoya yazar. { anahtar, sha256, boyut } döner. */
export async function pdfYukle(db, base64) {
  const veri = Buffer.from(String(base64 || ''), 'base64');
  if (!veri.length) throw new ApiHatasi(400, 'VALIDATION_ERROR', 'PDF dosyası boş');
  if (veri.length > PDF_AZAMI) throw new ApiHatasi(400, 'VALIDATION_ERROR', 'PDF en fazla 10 MB olabilir');
  if (veri.toString('latin1', 0, 5) !== '%PDF-') throw new ApiHatasi(400, 'VALIDATION_ERROR', 'Dosya bir PDF değil');
  const ayar = await depolamaAyari(db);
  if (!ayar) throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Dosya depolama yapılandırılmamış (Entegrasyonlar → Depolama)');
  const anahtar = `yasal/${randomUUID()}.pdf`;
  const r = await fetch(s3ImzaliAdres(ayar, { yontem: 'PUT', anahtar, sureSn: 300, icerikTuru: 'application/pdf' }), {
    method: 'PUT', headers: { 'Content-Type': 'application/pdf' }, body: veri, signal: AbortSignal.timeout(30000),
  }).catch(() => null);
  if (!r || !r.ok) throw new ApiHatasi(502, 'EXTERNAL_SERVICE_ERROR', 'PDF depoya yazılamadı');
  return { anahtar, sha256: createHash('sha256').update(veri).digest('hex'), boyut: veri.length };
}

/** PDF'i istemciye akıtır (depo özel; imzalı GET sunucuda). */
export async function pdfGonder(db, anahtar, res, dosyaAdi = 'belge.pdf') {
  const bulunamadi = () => { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' }); res.end('Bulunamadı'); };
  if (!PDF_ANAHTAR.test(String(anahtar || ''))) return bulunamadi();
  const ayar = await depolamaAyari(db);
  const r = ayar ? await fetch(s3ImzaliAdres(ayar, { yontem: 'GET', anahtar, sureSn: 120 }), { signal: AbortSignal.timeout(20000) }).catch(() => null) : null;
  if (!r || !r.ok) return bulunamadi();
  res.writeHead(200, {
    'Content-Type': 'application/pdf',
    'Content-Disposition': `inline; filename="${dosyaAdi.replace(/[^A-Za-z0-9._-]/g, '_')}"`,
    'Cache-Control': 'public, max-age=31536000, immutable', // anahtar benzersiz
    'X-Content-Type-Options': 'nosniff',
    'Content-Security-Policy': "default-src 'none'; sandbox",
  });
  res.end(Buffer.from(await r.arrayBuffer()));
}
