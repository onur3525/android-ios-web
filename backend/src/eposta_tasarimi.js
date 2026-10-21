// ═══════════════════════════════════════════════════════════════
// KURUMSAL E-POSTA TASARIMI — bütün HizmetCep e-postalarının tek kalıbı
//
// 21 Eki (kullanıcı isteği): "HizmetCep'in gönderdiği mailler daha
// kurumsal ve görselleri daha güzel görünmeli." Doğrulama e-postası
// Firebase'in düz şablonuyla gidiyordu; diğer e-postalar (askı, destek
// yanıtı, ilan kaldırma) yalnız düz metindi.
//
// ⚠ E-POSTA İSTEMCİLERİ İÇİN YAZILDI: Gmail/Outlook <style> bloğunu ve
// dış CSS'i büyük ölçüde atar; düzen TABLO ve SATIR İÇİ stil ile kurulur.
// Düğme "bulletproof" biçimdedir (görseller kapalıyken de görünür).
//
// ⚠ KAÇIŞ ZORUNLU: admin ve kullanıcı girdisi (gerekçe, destek yanıtı,
// ad) HTML'e her zaman kaçışlanarak yazılır. Bağlantılar yalnız https.
// ═══════════════════════════════════════════════════════════════
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from './config.js';

export const MARKA = {
  mavi: '#1D6BE3',
  koyuMavi: '#0D4FAF',
  turuncu: '#F57C00',
  metin: '#16233D',
  ikincil: '#475467',
  soluk: '#667085',
  zemin: '#F3F5F8',
  cizgi: '#E4E7EC',
};

const YAZI = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";

export function kacis(v) {
  return String(v ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function guvenliAdres(v) {
  const s = String(v ?? '').trim();
  try {
    const u = new URL(s);
    return u.protocol === 'https:' ? u.toString() : null;
  } catch {
    return null;
  }
}

/** Logo görsellerinin herkese açık kökü (sunucu `/eposta-varlik/` altında sunar). */
export function varlikKoku() {
  return config.epostaVarlikKoku.replace(/\/+$/, '');
}

/** Paragraf: kaçışlanır, satır sonları korunur. */
const paragraf = (metin, renk = MARKA.ikincil, boyut = 15) =>
  `<p style="margin:0 0 16px;font-family:${YAZI};font-size:${boyut}px;line-height:1.6;color:${renk};">${kacis(metin).replace(/\n/g, '<br>')}</p>`;

/**
 * Kurumsal e-posta üretir.
 * @param {object} p
 * @param {string} p.konu          Konu satırı (önizleme metni için de kullanılır)
 * @param {string} p.baslik        Kart başlığı
 * @param {string[]} p.paragraflar Gövde paragrafları (düz metin)
 * @param {{metin:string, adres:string}=} p.buton  Ana eylem düğmesi (https)
 * @param {string=} p.not          Düğmenin altındaki küçük not
 * @param {string=} p.destek       Destek e-posta adresi (alt bilgide)
 * @returns {{html:string, text:string}}
 */
export function kurumsalEposta({ konu, baslik, paragraflar = [], buton, not, destek }) {
  const adres = buton ? guvenliAdres(buton.adres) : null;
  const kok = varlikKoku();
  const yil = new Date().getFullYear();

  const dugme = adres ? `
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0 24px;">
                <tr>
                  <td align="center" bgcolor="${MARKA.mavi}" style="border-radius:10px;background:${MARKA.mavi};">
                    <a href="${kacis(adres)}" target="_blank" style="display:inline-block;padding:14px 28px;font-family:${YAZI};font-size:16px;font-weight:700;color:#FFFFFF;text-decoration:none;border-radius:10px;">${kacis(buton.metin)}</a>
                  </td>
                </tr>
              </table>
              <!-- ⚠ 21 Eki (kullanıcı bulgusu): uzun bağlantı METİN olarak
                   yazılmaz. Gmail uygulaması satır kırmayı (word-break)
                   desteklemiyor; tek satırlık uzun adres e-postayı ekrandan
                   genişletiyor, Gmail de bütün e-postayı küçültüyordu (yazı,
                   düğme ve logo önizlemedekinden küçük görünüyordu). -->
              <p style="margin:0 0 24px;font-family:${YAZI};font-size:13px;line-height:1.5;color:${MARKA.soluk};">Düğme çalışmazsa <a href="${kacis(adres)}" target="_blank" style="color:${MARKA.mavi};text-decoration:underline;">bu bağlantıya dokunun</a>.</p>` : '';

  const notKutusu = not ? `
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 8px;">
                <tr>
                  <td style="background:${MARKA.zemin};border-radius:10px;padding:14px 16px;font-family:${YAZI};font-size:13px;line-height:1.55;color:${MARKA.ikincil};">${kacis(not)}</td>
                </tr>
              </table>` : '';

  const destekSatiri = destek
    ? `Sorularınız için: <a href="mailto:${kacis(destek)}" style="color:${MARKA.mavi};text-decoration:none;">${kacis(destek)}</a><br>`
    : '';

  const html = `<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<!-- 21 Eki (kullanıcı isteği): her zaman BEYAZ görünüm. "light only"
     Apple Mail ve Outlook'ta koyu moda çevrilmeyi engeller. Gmail
     uygulaması bu işareti yok sayar ve rengi kendisi çevirir. -->
<meta name="color-scheme" content="light only">
<meta name="supported-color-schemes" content="light only">
<style>:root { color-scheme: light only; supported-color-schemes: light only; }</style>
<title>${kacis(konu)}</title>
</head>
<body style="margin:0;padding:0;background:${MARKA.zemin};">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">${kacis(paragraflar.slice(1, 2).join(' ') || konu)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${MARKA.zemin};">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;">
          <tr>
            <td align="center" style="padding:0 0 20px;">
              <!-- 21 Eki (kullanıcı isteği): logo büyük ve net. Beyaz zemin
                   GÖRSELİN İÇİNDE: koyu modda e-posta uygulaması zemini
                   koyulaştırsa da logo okunur kalır. -->
              <img src="${kok}/eposta-varlik/eposta_logo.png" width="280" height="76" alt="HizmetCep" style="display:block;border:0;width:280px;max-width:100%;height:auto;font-family:${YAZI};font-size:28px;font-weight:800;color:${MARKA.mavi};">
            </td>
          </tr>
          <tr>
            <td style="background:#FFFFFF;border-radius:16px;border:1px solid ${MARKA.cizgi};overflow:hidden;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr><td style="height:4px;line-height:4px;font-size:0;background:${MARKA.mavi};border-radius:16px 16px 0 0;">&nbsp;</td></tr>
                <tr>
                  <td style="padding:32px 32px 24px;">
              <h1 style="margin:0 0 16px;font-family:${YAZI};font-size:22px;line-height:1.3;font-weight:800;color:${MARKA.metin};">${kacis(baslik)}</h1>
              ${paragraflar.map((p, i) => paragraf(p, i === 0 ? MARKA.metin : MARKA.ikincil)).join('\n              ')}
              ${dugme}
              ${notKutusu}
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:24px 16px 0;font-family:${YAZI};font-size:12px;line-height:1.6;color:${MARKA.soluk};">
              ${destekSatiri}Bu e-posta HizmetCep hesabınızla ilgili bir işlem nedeniyle gönderildi.<br>
              © ${yil} HizmetCep
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  const text = [
    baslik,
    '',
    ...paragraflar.flatMap((p) => [p, '']),
    ...(adres ? [`${buton.metin}: ${adres}`, ''] : []),
    ...(not ? [not, ''] : []),
    ...(destek ? [`Sorularınız için: ${destek}`] : []),
    'HizmetCep',
  ].join('\n');

  return { html, text };
}

// ── E-posta logo görselleri: GET /eposta-varlik/<ad>.png ──
// Uygulama paketindeki iki logo dosyası; beyaz liste, yalnız okuma.
// (Dockerfile bunları /app/assets/logo altına kopyalar.)

const LOGO_KOKU = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'assets', 'logo');
const VARLIK_KOKU = join(dirname(fileURLToPath(import.meta.url)), '..', 'varliklar');
// Eski iki dosya önceden gönderilmiş e-postalar için sunulmaya devam eder.
const EPOSTA_VARLIKLARI = new Map([
  ['eposta_logo.png', VARLIK_KOKU],
  ['logo_mark.png', LOGO_KOKU],
  ['wordmark.png', LOGO_KOKU],
]);

export async function epostaVarligiGonder(ad, res) {
  if (!EPOSTA_VARLIKLARI.has(ad)) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
    return res.end('Bulunamadı');
  }
  try {
    const icerik = await readFile(join(EPOSTA_VARLIKLARI.get(ad), ad));
    res.writeHead(200, {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=86400',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'",
    });
    res.end(icerik);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end('Bulunamadı');
  }
}
