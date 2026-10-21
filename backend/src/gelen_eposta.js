// ═══════════════════════════════════════════════════════════════
// DESTEK E-POSTALARI → GELEN TALEPLER (21 Eki, kullanıcı kararı)
//
// Uygulamada kullanıcılar sorunlarını destek e-posta adresine yazar
// (Destek Merkezi → e-posta). O adrese gelen posta Resend "Receiving" ile
// alınır; Resend her e-posta için bu webhook'u çağırır:
//
//   POST /webhooks/resend/inbound   (Svix imzalı: svix-id/-timestamp/-signature)
//     → imza doğrulanır (imza anahtarı: Entegrasyonlar › E-posta (Resend) ›
//       "Gelen e-posta anahtarı", şifreli saklanır)
//     → e-postanın tamamı Resend API'sinden okunur (webhook gövde taşımaz)
//     → konuda "Talep No: N" varsa ve gönderen aynıysa o talebe eklenir,
//       yoksa yeni destek talebi açılır (Admin › Gelen Talepler)
//
// ⚠ Aynı e-posta iki kez gelse de (webhook tekrarı) İKİNCİ kayıt açılmaz.
// ⚠ Otomatik yanıtlar (Auto-Submitted, mailer-daemon) ve kendi gönderen
//   adresimizden gelenler kayda girmez (döngü olmaz).
// ⚠ Gönderen başına saatlik sınır: kötüye kullanımda kuyruk şişmez.
// ═══════════════════════════════════════════════════════════════
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { guvenliIstek } from './ag_guvenligi.js';
import { simdi } from './db.js';
import { etkinEntegrasyon } from './entegrasyon.js';
import { HizSiniri } from './http.js';

export const GELEN_YOL = '/webhooks/resend/inbound';
const RESEND_ALINAN = 'https://api.resend.com/emails/receiving/';
const TOLERANS_SN = 5 * 60;
const AZAMI_GOVDE = 256 * 1024;
const AZAMI_MESAJ = 10_000;
const gonderenSiniri = new HizSiniri('destek_eposta', 20, 60 * 60 * 1000);

let testGetirici = null;
/** Yalnız testler: Resend API'si yerine (id) → { status, json }. */
export function gelenEpostaTestGetirici(f) { testGetirici = f; }

/** Svix imzası (Resend webhook'ları). Doğruysa true. */
export function svixDogrula(sir, basliklar, ham, simdiSn = Math.floor(Date.now() / 1000)) {
  const id = basliklar['svix-id']; const ts = basliklar['svix-timestamp']; const imza = basliklar['svix-signature'];
  if (typeof sir !== 'string' || !sir.startsWith('whsec_') || !id || !ts || !imza) return false;
  const t = Number(ts);
  if (!Number.isInteger(t) || Math.abs(simdiSn - t) > TOLERANS_SN) return false;
  const beklenen = createHmac('sha256', Buffer.from(sir.slice('whsec_'.length), 'base64'))
    .update(`${id}.${ts}.${ham}`).digest();
  return String(imza).split(' ').some((p) => {
    const [surum, deger] = p.split(',');
    if (surum !== 'v1' || !deger) return false;
    const b = Buffer.from(deger, 'base64');
    return b.length === beklenen.length && timingSafeEqual(b, beklenen);
  });
}

const adresAyikla = (v) => {
  const m = /<([^<>\s]+@[^<>\s]+)>/.exec(String(v ?? '')) ?? /([^\s<>"']+@[^\s<>"']+)/.exec(String(v ?? ''));
  return m ? m[1].toLowerCase() : null;
};
const adAyikla = (v) => {
  const m = /^\s*"?([^"<]*?)"?\s*<[^>]+>\s*$/.exec(String(v ?? ''));
  return m && m[1].trim() ? m[1].trim().slice(0, 120) : null;
};
function baslik(h, ad) {
  if (!h) return null;
  if (Array.isArray(h)) {
    const x = h.find((y) => String(y?.name ?? y?.key ?? '').toLowerCase() === ad);
    return x ? String(x.value ?? '') : null;
  }
  const k = Object.keys(h).find((y) => y.toLowerCase() === ad);
  return k ? String(Array.isArray(h[k]) ? h[k][0] : h[k]) : null;
}
const htmldenMetin = (html) => String(html ?? '')
  .replace(/<(script|style)[\s\S]*?<\/\1>/gi, '')
  .replace(/<br\s*\/?>/gi, '\n').replace(/<\/(p|div|li|tr|h\d)>/gi, '\n')
  .replace(/<[^>]+>/g, '')
  .replace(/&nbsp;/g, ' ').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');

/** Yanıt e-postasında alıntılanan eski metni keser (yalnız yeni yazılan kalır). */
export function alintiyiKes(metin) {
  const satirlar = String(metin ?? '').replace(/\r\n/g, '\n').split('\n');
  const out = [];
  for (const s of satirlar) {
    if (/^\s*>/.test(s)) break;
    if (/^\s*(On .+ wrote:|.+ tarihinde .+ yazdı:|-----\s*Original Message|-----\s*Özgün İleti|From:\s.+@)/i.test(s)) break;
    out.push(s);
  }
  return out.join('\n').trim();
}

const TALEP_NO = /Talep No:?\s*#?(\d{5,})/i;

/** Webhook olayı → kayıt. Dönüş: { durum: 'ticket'|'reply'|'yok-sayildi', ... } */
export async function gelenEpostayiIsle(db, olay, entegrasyon) {
  if (olay?.type !== 'email.received') return { durum: 'yok-sayildi', neden: 'tür' };
  const emailId = String(olay.data?.email_id ?? '');
  if (!/^[A-Za-z0-9-]{8,80}$/.test(emailId)) return { durum: 'yok-sayildi', neden: 'kimlik' };
  // Webhook tekrarı: aynı e-posta ikinci kez kayda girmez.
  if (await db.prepare('SELECT 1 FROM support_tickets WHERE inbound_email_id = ?').get(emailId)
    || await db.prepare('SELECT 1 FROM support_ticket_replies WHERE inbound_email_id = ?').get(emailId)) {
    return { durum: 'yok-sayildi', neden: 'tekrar' };
  }
  const r = testGetirici
    ? await testGetirici(emailId)
    : await guvenliIstek(RESEND_ALINAN + encodeURIComponent(emailId), {
      headers: { Authorization: `Bearer ${entegrasyon.secret.token}` }, timeoutMs: 10_000,
    }).then((x) => ({ status: x.status, json: (() => { try { return JSON.parse(x.text); } catch { return null; } })() }));
  if (r.status < 200 || r.status > 299 || !r.json) throw new Error(`resend alınan e-posta ${r.status}`);
  const e = r.json;

  const kimden = adresAyikla(e.from ?? olay.data.from);
  if (!kimden) return { durum: 'yok-sayildi', neden: 'gönderen' };
  const kendi = adresAyikla(entegrasyon.config?.from);
  const otomatik = (baslik(e.headers, 'auto-submitted') ?? 'no').toLowerCase() !== 'no'
    || /^(mailer-daemon|postmaster|no-?reply)@/i.test(kimden) || kimden === kendi;
  if (otomatik) return { durum: 'yok-sayildi', neden: 'otomatik' };
  try { await gonderenSiniri.denetle(db, kimden); } catch { return { durum: 'yok-sayildi', neden: 'sınır' }; }

  const ad = adAyikla(baslik(e.headers, 'from')) ?? adAyikla(e.from);
  const konu = String(e.subject ?? olay.data.subject ?? '').trim().slice(0, 120) || '(Konusuz e-posta)';
  const tamMetin = String(e.text ?? '').trim() || htmldenMetin(e.html).trim();
  const z = simdi();

  // ── Var olan talebe yanıt mı? (konuda talep numarası + aynı gönderen) ──
  const no = TALEP_NO.exec(konu)?.[1];
  if (no) {
    const t = await db.prepare(
      `SELECT t.id, t.status, t.sender_email, u.email user_email FROM support_tickets t LEFT JOIN users u ON u.id = t.user_id WHERE t.ticket_no = ?`,
    ).get(no);
    if (t && [t.sender_email, t.user_email].some((x) => x && String(x).toLowerCase() === kimden)) {
      const govde = (alintiyiKes(tamMetin) || tamMetin || '(Boş ileti)').slice(0, AZAMI_MESAJ);
      await db.tx(async () => {
        await db.prepare(`INSERT INTO support_ticket_replies (id, ticket_id, admin_id, body, created_at, author, inbound_email_id) VALUES (?, ?, NULL, ?, ?, 'USER', ?)`)
          .run(randomUUID(), t.id, govde, z, emailId);
        // Kullanıcı yeniden yazdı: talep yeniden yanıt bekler.
        await db.prepare(`UPDATE support_tickets SET status = 'OPEN', updated_at = ?, closed_at = NULL, closed_by = NULL WHERE id = ?`).run(z, t.id);
      });
      return { durum: 'reply', ticketId: t.id };
    }
  }

  // ── Yeni talep ──
  const u = await db.prepare('SELECT id FROM users WHERE lower(email) = ? AND deleted_at IS NULL').get(kimden);
  const id = randomUUID();
  await db.tx(async () => {
    const n = await db.prepare(`UPDATE counters SET value = value + 1 WHERE name = 'destek_no' RETURNING value`).get();
    await db.prepare(
      `INSERT INTO support_tickets (id, ticket_no, user_id, subject, message, status, created_at, updated_at, source, sender_email, sender_name, inbound_email_id)
       VALUES (?, ?, ?, ?, ?, 'OPEN', ?, ?, 'EMAIL', ?, ?, ?)`,
    ).run(id, String(n.value), u?.id ?? null, konu, (tamMetin || '(Boş ileti)').slice(0, AZAMI_MESAJ), z, z, kimden, ad, emailId);
  });
  return { durum: 'ticket', ticketId: id };
}

/** Ham HTTP işleyicisi (server.js çağırır; JSON yönlendiricisinden önce). */
export async function gelenEpostaWebhook(db, req, res) {
  const yaz = (durum, govde) => { res.writeHead(durum, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(govde)); };
  if (req.method !== 'POST') return yaz(405, { error: 'METHOD_NOT_ALLOWED' });
  const parcalar = []; let boy = 0;
  for await (const p of req) {
    boy += p.length;
    if (boy > AZAMI_GOVDE) return yaz(413, { error: 'PAYLOAD_TOO_LARGE' });
    parcalar.push(p);
  }
  const ham = Buffer.concat(parcalar).toString('utf8');
  const e = await etkinEntegrasyon(db, 'EMAIL');
  // Yapılandırılmamış: Resend daha sonra yeniden dener (503).
  if (!e || e.provider !== 'resend' || !e.secret?.webhookSecret || !e.secret?.token) return yaz(503, { error: 'NOT_CONFIGURED' });
  if (!svixDogrula(e.secret.webhookSecret, req.headers, ham)) return yaz(401, { error: 'INVALID_SIGNATURE' });
  let olay;
  try { olay = JSON.parse(ham); } catch { return yaz(400, { error: 'INVALID_JSON' }); }
  try {
    const s = await gelenEpostayiIsle(db, olay, e);
    return yaz(200, { ok: true, result: s.durum });
  } catch (h) {
    // Geçici hata (Resend API'sine ulaşılamadı vb.): 500 → Resend yeniden dener.
    console.error('gelen e-posta işlenemedi:', h?.message);
    return yaz(500, { error: 'PROCESSING_FAILED' });
  }
}
