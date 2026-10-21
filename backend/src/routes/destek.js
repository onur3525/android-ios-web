// ═══════════════════════════════════════════════════════════════
// GELEN TALEPLER — kullanıcının uygulamadan destek ekibine gönderdiği
// gerçek talepler (ürün kararı, Eki 2026)
//
//   Kullanıcı destek adresine e-posta yazar (21 Eki — asıl yol)
//     → Resend Receiving webhook → gelen_eposta.js (talep açılır / yanıt eklenir)
//   Kullanıcı (uygulamadan, eski form)
//     → POST /api/v1/support/tickets          (gerçek kayıt, PostgreSQL)
//     → Admin > Gelen Talepler                 (GET /admin/v1/support/tickets)
//     → Admin yanıtı                           (POST …/:id/reply)
//     → kullanıcıya e-posta                    (MEVCUT bildirim altyapısı:
//                                               outbound_messages + sağlayıcı
//                                               soyutlaması; sağlayıcı yoksa
//                                               kayıt FAILED düşer, uydurulmaz)
//     → kullanıcı yanıtı uygulamada da görür  (GET /api/v1/support/tickets)
//
// ⚠ Hesap dondurma/silme talepleri (account_requests) BURAYA KARIŞMAZ.
// ⚠ Sahte/örnek kayıt üretilmez; yalnız kullanıcıların gönderdiği kayıtlar.
// ⚠ Kullanıcı yalnız KENDİ taleplerini görür (başkasınınki 404).
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { yetkiIste, yetkiliMi } from '../auth.js';
import { denetimYaz } from '../audit.js';
import { gonder } from '../bildirim.js';
import { simdi } from '../db.js';
import { HizSiniri, hata } from '../http.js';
import { kullaniciCoz } from './kullanici.js';

const DURUMLAR = ['OPEN', 'ANSWERED', 'CLOSED'];
const talepSiniri = new HizSiniri('destek_talebi', 5, 60 * 60 * 1000); // kullanıcı başına saatte 5
const ACIK_TALEP_SINIRI = 20;

function metin(v, alan, min, max) {
  const t = String(v ?? '').trim();
  if (t.length < min || t.length > max) throw hata.dogrulama(`${alan} ${min}-${max} karakter olmalıdır`);
  return t;
}

const yanitGorunumu = (y) => ({ id: y.id, body: y.body, createdAt: y.created_at, author: y.author ?? 'ADMIN' });

function kullaniciTalepGorunumu(t, yanitlar) {
  return {
    id: t.id, ticketNo: t.ticket_no, subject: t.subject, message: t.message, status: t.status,
    createdAt: t.created_at, updatedAt: t.updated_at, closedAt: t.closed_at,
    replies: yanitlar.map(yanitGorunumu),
  };
}

const epostaMaskele = (e) => (e ? String(e).replace(/^(.).*(@.*)$/, '$1***$2') : '');

export function destekRotalar(r, db) {
  const korumali = (f) => async (ctx) => {
    const { u, oturum } = await kullaniciCoz(db, ctx.req);
    ctx.kullanici = u;
    ctx.kOturum = oturum;
    return f(ctx);
  };
  const yanitlar = (id) => db.prepare('SELECT * FROM support_ticket_replies WHERE ticket_id = ? ORDER BY created_at').all(id);

  // ════ KULLANICI ════
  r.post('/api/v1/support/tickets', korumali(async (ctx) => {
    const u = ctx.kullanici;
    // Idempotency-Key: aynı anahtarla gelen tekrar (ağ kesintisinde istemcinin
    // yeniden denemesi) YENİ kayıt açmaz, ilk talebi döndürür.
    const anahtar = String(ctx.req.headers['idempotency-key'] ?? '').trim().slice(0, 100) || null;
    if (anahtar) {
      const once = await db.prepare('SELECT * FROM support_tickets WHERE user_id = ? AND idempotency_key = ?').get(u.id, anahtar);
      if (once) return kullaniciTalepGorunumu(once, await yanitlar(once.id));
    }
    const konu = metin(ctx.body.subject, 'Konu', 3, 120);
    const mesaj = metin(ctx.body.message, 'Mesaj', 10, 4000);
    const pl = ctx.body.platform == null ? null : String(ctx.body.platform);
    if (pl !== null && !['android', 'ios', 'web'].includes(pl)) throw hata.dogrulama('Geçersiz platform');
    const surum = ctx.body.appVersion == null ? null : String(ctx.body.appVersion).slice(0, 30);
    await talepSiniri.denetle(db, u.id);
    const acik = (await db.prepare(`SELECT COUNT(*) n FROM support_tickets WHERE user_id = ? AND status <> 'CLOSED'`).get(u.id)).n;
    if (acik >= ACIK_TALEP_SINIRI) throw hata.hiz('Yanıt bekleyen çok fazla talebiniz var. Lütfen yanıtlanmasını bekleyin.');
    const id = randomUUID();
    const z = simdi();
    await db.tx(async () => {
      const no = await db.prepare(`UPDATE counters SET value = value + 1 WHERE name = 'destek_no' RETURNING value`).get();
      await db.prepare(
        `INSERT INTO support_tickets (id, ticket_no, user_id, subject, message, status, platform, app_version, created_at, updated_at, idempotency_key)
         VALUES (?, ?, ?, ?, ?, 'OPEN', ?, ?, ?, ?, ?)`,
      ).run(id, String(no.value), u.id, konu, mesaj, pl, surum, z, z, anahtar);
    });
    return kullaniciTalepGorunumu(await db.prepare('SELECT * FROM support_tickets WHERE id = ?').get(id), []);
  }));

  r.get('/api/v1/support/tickets', korumali(async (ctx) => {
    const liste = await db.prepare('SELECT * FROM support_tickets WHERE user_id = ? ORDER BY created_at DESC LIMIT 100').all(ctx.kullanici.id);
    const out = [];
    for (const t of liste) out.push(kullaniciTalepGorunumu(t, await yanitlar(t.id)));
    return out;
  }));

  r.get('/api/v1/support/tickets/:id', korumali(async (ctx) => {
    const t = await db.prepare('SELECT * FROM support_tickets WHERE id = ? AND user_id = ?').get(ctx.params.id, ctx.kullanici.id);
    if (!t) throw hata.bulunamadi('Talep bulunamadı'); // başkasının talebinin varlığı da sızmaz
    return kullaniciTalepGorunumu(t, await yanitlar(t.id));
  }));

  // ════ ADMİN ════
  // E-postayla gelen talepte gönderen kayıtlı kullanıcı olmayabilir (userId
  // boş); ad ve adres e-postanın gönderenidir. Yanıt o adrese gider.
  const adminGorunumu = (t, iletisimGor) => ({
    id: t.id, ticketNo: t.ticket_no, userId: t.user_id ?? null, userName: t.user_name ?? '',
    userEmail: iletisimGor ? (t.user_email ?? '') : epostaMaskele(t.user_email),
    userEmailVerified: t.user_email_verified === 1 || t.user_email_verified === true,
    source: t.source ?? 'APP',
    senderName: t.sender_name ?? null,
    senderEmail: t.sender_email ? (iletisimGor ? t.sender_email : epostaMaskele(t.sender_email)) : null,
    subject: t.subject, status: t.status, platform: t.platform, appVersion: t.app_version,
    createdAt: t.created_at, updatedAt: t.updated_at, closedAt: t.closed_at,
  });
  const adminGetir = (id) => db.prepare(
    `SELECT t.*, u.name user_name, u.email user_email, u.email_verified user_email_verified
       FROM support_tickets t LEFT JOIN users u ON u.id = t.user_id WHERE t.id = ?`,
  ).get(id);

  r.get('/admin/v1/support/tickets', async (ctx) => {
    yetkiIste(ctx.admin, 'support.tickets.read');
    const durum = ctx.query.get('status');
    if (durum && !DURUMLAR.includes(durum)) throw hata.dogrulama('Geçersiz durum');
    const limit = Math.min(Math.max(Number(ctx.query.get('limit') ?? 100) || 100, 1), 500);
    const ofset = Math.min(Math.max(Number(ctx.query.get('offset') ?? 0) || 0, 0), 100_000);
    // ── ARAMA (21 Eki): talep no, gönderen/kullanıcı e-postası ya da adı,
    // konu ve mesaj. Veritabanında aranır (yalnız ekrandaki kayıtlarda değil).
    const kosul = []; const p = [];
    if (durum) { kosul.push('t.status = ?'); p.push(durum); }
    const ara = String(ctx.query.get('q') ?? '').trim().slice(0, 100).toLocaleLowerCase('tr-TR');
    if (ara) {
      const k = `%${ara.replace(/[!%_]/g, (c) => `!${c}`)}%`; // LIKE özel karakterleri düz aranır
      const alanlar = ['t.subject', 't.message', "COALESCE(t.sender_email, '')", "COALESCE(t.sender_name, '')", "COALESCE(u.name, '')", "COALESCE(u.email, '')"];
      kosul.push(`(t.ticket_no = ? OR ${alanlar.map((a) => `lower(${a}) LIKE ? ESCAPE '!'`).join(' OR ')})`);
      p.push(ara, ...alanlar.map(() => k));
    }
    const satir = await db.prepare(
      `SELECT t.*, u.name user_name, u.email user_email, u.email_verified user_email_verified
         FROM support_tickets t LEFT JOIN users u ON u.id = t.user_id
        ${kosul.length ? `WHERE ${kosul.join(' AND ')}` : ''} ORDER BY t.created_at DESC, t.id DESC LIMIT ? OFFSET ?`,
    ).all(...p, limit, ofset);
    const iletisimGor = yetkiliMi(ctx.admin.role, 'users.contact.read');
    return satir.map((t) => adminGorunumu(t, iletisimGor));
  });

  r.get('/admin/v1/support/tickets/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'support.tickets.read');
    const t = await adminGetir(ctx.params.id);
    if (!t) throw hata.bulunamadi('Talep bulunamadı');
    const ys = await db.prepare(
      `SELECT y.*, a.email admin_email, o.status email_status
         FROM support_ticket_replies y LEFT JOIN admins a ON a.id = y.admin_id
         LEFT JOIN outbound_messages o ON o.id = y.outbound_id
        WHERE y.ticket_id = ? ORDER BY y.created_at`,
    ).all(t.id);
    await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'support.ticket.view', hedefTur: 'support_ticket', hedefId: t.id });
    return {
      ...adminGorunumu(t, yetkiliMi(ctx.admin.role, 'users.contact.read')),
      message: t.message,
      replies: ys.map((y) => ({ ...yanitGorunumu(y), admin: y.admin_email ?? null, emailStatus: y.email_status ?? null })),
    };
  });

  r.post('/admin/v1/support/tickets/:id/reply', async (ctx) => {
    yetkiIste(ctx.admin, 'support.tickets.write');
    const t = await adminGetir(ctx.params.id);
    if (!t) throw hata.bulunamadi('Talep bulunamadı');
    if (t.status === 'CLOSED') throw hata.durum('Kapatılmış talebe yanıt verilemez');
    const govde = metin(ctx.body.body, 'Yanıt', 2, 4000);
    const kapat = ctx.body.close === true;
    const id = randomUUID();
    const z = simdi();
    const yeniDurum = kapat ? 'CLOSED' : 'ANSWERED';
    await db.tx(async () => {
      await db.prepare('INSERT INTO support_ticket_replies (id, ticket_id, admin_id, body, created_at) VALUES (?, ?, ?, ?, ?)')
        .run(id, t.id, ctx.admin.id, govde, z);
      await db.prepare(`UPDATE support_tickets SET status = ?, updated_at = ?, closed_at = ?, closed_by = ? WHERE id = ?`)
        .run(yeniDurum, z, kapat ? z : null, kapat ? ctx.admin.id : null, t.id);
      await denetimYaz(db, {
        adminId: ctx.admin.id, ip: ctx.ip, islem: 'support.ticket.reply', hedefTur: 'support_ticket', hedefId: t.id,
        once: { status: t.status }, sonra: { status: yeniDurum, replyId: id },
      });
    });
    // E-posta işlemden SONRA (sağlayıcı hatası yanıtı geri almaz; sonuç kayıtlı).
    // E-postayla gelen talep: yanıt, kullanıcının yazdığı adrese gider.
    // Uygulamadan gelen talep: yalnız DOĞRULANMIŞ e-postaya; yoksa FAILED.
    // Kullanıcının bu e-postaya yanıtı destek adresine döner (Reply-To) ve
    // konudaki talep numarasıyla aynı talebe eklenir.
    let destek = null;
    try { destek = await db.prepare('SELECT email FROM support_info WHERE id = 1').get(); } catch { /* Reply-To'suz gider */ }
    const dogrulanmis = (t.user_email_verified === 1 || t.user_email_verified === true) && t.user_email ? t.user_email : null;
    const e = await gonder(db, {
      kullaniciId: t.user_id, kanal: 'EMAIL', sablon: 'DESTEK_YANITI', denetimRef: id,
      hedef: t.source === 'EMAIL' && t.sender_email ? t.sender_email : dogrulanmis,
      degerler: { NO: t.ticket_no, KONU: t.subject, YANIT: govde },
      yanitAdresi: destek?.email || undefined,
    });
    await db.prepare('UPDATE support_ticket_replies SET outbound_id = ? WHERE id = ?').run(e.id, id);
    return { id, ticketId: t.id, status: yeniDurum, email: e };
  });

  r.post('/admin/v1/support/tickets/:id/close', async (ctx) => {
    yetkiIste(ctx.admin, 'support.tickets.write');
    const t = await adminGetir(ctx.params.id);
    if (!t) throw hata.bulunamadi('Talep bulunamadı');
    if (t.status === 'CLOSED') throw hata.durum('Talep zaten kapalı');
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`UPDATE support_tickets SET status = 'CLOSED', closed_at = ?, closed_by = ?, updated_at = ? WHERE id = ?`)
        .run(z, ctx.admin.id, z, t.id);
      await denetimYaz(db, {
        adminId: ctx.admin.id, ip: ctx.ip, islem: 'support.ticket.close', hedefTur: 'support_ticket', hedefId: t.id,
        once: { status: t.status }, sonra: { status: 'CLOSED' }, gerekce: ctx.body.reason ? String(ctx.body.reason).slice(0, 1000) : undefined,
      });
    });
    return { id: t.id, status: 'CLOSED' };
  });
}
