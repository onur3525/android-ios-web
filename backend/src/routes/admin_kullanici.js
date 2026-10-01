// ═══════════════════════════════════════════════════════════════
// ADMİN — KULLANICI YÖNETİMİ VE BİLDİRİM KAYITLARI
//
// Durum geçişleri (gerekçe ZORUNLU, kritik işlem → yeniden doğrulama):
//   ACTIVE    → SUSPENDED (askıya al)   · SUSPENDED → ACTIVE (askıyı kaldır)
//   ACTIVE/SUSPENDED → BANNED (banla)    · BANNED → ACTIVE (banı kaldır)
// Her geçişte TEK işlem içinde: kullanıcı durumu, durum geçmişi,
// denetim kaydı (önceki/yeni/gerekçe/admin), askı ve ban'da bütün
// oturumların iptali. Ardından kullanıcıya doğrulanmış kanallardan
// SMS/e-posta (sonuç `outbound_messages`'ta ve yanıtta).
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { yenidenDogrulamaIste, yetkiIste } from '../auth.js';
import { denetimYaz } from '../audit.js';
import { kullaniciyaBildir } from '../bildirim.js';
import { simdi } from '../db.js';
import { hata } from '../http.js';
import { kullaniciGorunumu, oturumlariIptal } from './kullanici.js';

const GECISLER = {
  suspend: { from: ['ACTIVE'], to: 'SUSPENDED', sablon: 'HESAP_ASKIYA_ALINDI', islem: 'user.suspend' },
  unsuspend: { from: ['SUSPENDED'], to: 'ACTIVE', sablon: 'HESAP_ASKI_KALDIRILDI', islem: 'user.unsuspend' },
  ban: { from: ['ACTIVE', 'SUSPENDED'], to: 'BANNED', sablon: 'HESAP_BANLANDI', islem: 'user.ban' },
  unban: { from: ['BANNED'], to: 'ACTIVE', sablon: 'HESAP_BAN_KALDIRILDI', islem: 'user.unban' },
};

function gerekce(v) {
  if (typeof v !== 'string' || v.trim().length < 5 || v.length > 1000) throw hata.dogrulama('İşlem nedeni 5-1000 karakter olmalıdır');
  return v.trim();
}

export function adminKullaniciRotalar(r, db) {
  r.get('/admin/v1/users', async (ctx) => {
    yetkiIste(ctx.admin, 'users.read');
    const ara = String(ctx.query.get('q') ?? '').trim().toLowerCase();
    const durum = ctx.query.get('status');
    const limit = Math.min(Number(ctx.query.get('limit') ?? 50), 200);
    const ofset = Math.max(Number(ctx.query.get('offset') ?? 0), 0);
    const kosul = ['deleted_at IS NULL'];
    const p = [];
    if (ara) {
      kosul.push('(lower(name) LIKE ? OR phone LIKE ? OR lower(email) LIKE ?)');
      p.push(`%${ara}%`, `%${ara.replace(/\D/g, '') || ara}%`, `%${ara}%`);
    }
    if (durum) {
      if (!['ACTIVE', 'SUSPENDED', 'BANNED'].includes(durum)) throw hata.dogrulama('Geçersiz durum');
      kosul.push('status = ?');
      p.push(durum);
    }
    const iletisimGor = ['super_admin', 'moderator'].includes(ctx.admin.role);
    const satirlar = await db.prepare(
      `SELECT * FROM users WHERE ${kosul.join(' AND ')} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
    ).all(...p, limit, ofset);
    const toplam = (await db.prepare(`SELECT COUNT(*) n FROM users WHERE ${kosul.join(' AND ')}`).get(...p)).n;
    return {
      total: toplam,
      items: satirlar.map((u) => ({
        id: u.id, name: u.name, roles: u.roles.split(','), activeRole: u.active_role,
        status: u.status, createdAt: u.created_at,
        // KVKK: iletişim bilgisi yalnız yetkili rollere; diğerlerine maskeli.
        phone: iletisimGor ? u.phone : `${u.phone.slice(0, 3)}*****${u.phone.slice(-2)}`,
        email: iletisimGor ? (u.email ?? '') : (u.email ? u.email.replace(/^(.).*(@.*)$/, '$1***$2') : ''),
        phoneVerified: u.phone_verified === 1, emailVerified: u.email_verified === 1,
      })),
    };
  });

  r.get('/admin/v1/users/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'users.contact.read');
    const u = await db.prepare('SELECT * FROM users WHERE id = ?').get(ctx.params.id);
    if (!u) throw hata.bulunamadi('Kullanıcı bulunamadı');
    const adres = await db.prepare('SELECT city, district, neighborhood FROM addresses WHERE user_id = ?').get(u.id);
    const sp = await db.prepare('SELECT * FROM provider_profiles WHERE user_id = ?').get(u.id);
    const gecmis = await db.prepare(
      `SELECT h.*, a.email admin_email FROM user_status_history h LEFT JOIN admins a ON a.id = h.admin_id
        WHERE h.user_id = ? ORDER BY h.created_at DESC`,
    ).all(u.id);
    const oturum = await db.prepare(
      `SELECT id, created_at, last_used, user_agent, revoked_at, revoke_reason FROM user_sessions
        WHERE user_id = ? ORDER BY last_used DESC LIMIT 20`,
    ).all(u.id);
    const mesaj = await db.prepare(
      `SELECT id, channel, template, status, provider_response, created_at, sent_at FROM outbound_messages
        WHERE user_id = ? AND template <> 'OTP' ORDER BY created_at DESC LIMIT 50`,
    ).all(u.id);
    await denetimYaz(db, { adminId: ctx.admin.id, islem: 'user.view', hedefTur: 'user', hedefId: u.id, ip: ctx.ip });
    return {
      ...kullaniciGorunumu(u, sp ? { categories: JSON.parse(sp.categories_json), districts: JSON.parse(sp.districts_json) } : null),
      status: u.status, statusReason: u.status_reason, statusChangedAt: u.status_changed_at,
      termsAccepted: u.terms_accepted === 1, deletedAt: u.deleted_at,
      address: adres ?? null,
      statusHistory: gecmis.map((h) => ({ from: h.old_status, to: h.new_status, reason: h.reason, admin: h.admin_email, at: h.created_at })),
      sessions: oturum.map((o) => ({ id: o.id, createdAt: o.created_at, lastUsedAt: o.last_used, userAgent: o.user_agent, revokedAt: o.revoked_at, revokeReason: o.revoke_reason })),
      notifications: mesaj.map((m) => ({ id: m.id, channel: m.channel, template: m.template, status: m.status, providerResponse: m.provider_response, createdAt: m.created_at, sentAt: m.sent_at })),
    };
  });

  for (const [eylem, g] of Object.entries(GECISLER)) {
    r.post(`/admin/v1/users/:id/${eylem}`, async (ctx) => {
      yetkiIste(ctx.admin, 'users.status.write');
      yenidenDogrulamaIste(ctx.oturum);
      const neden = gerekce(ctx.body.reason);
      const u = await db.prepare('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL').get(ctx.params.id);
      if (!u) throw hata.bulunamadi('Kullanıcı bulunamadı');
      if (!g.from.includes(u.status)) throw hata.durum(`Bu işlem ${u.status} durumundaki hesaba uygulanamaz`);
      const z = simdi();
      const denetimRef = randomUUID();
      await db.tx(async () => {
        await db.prepare('UPDATE users SET status = ?, status_reason = ?, status_changed_at = ?, status_changed_by = ?, updated_at = ? WHERE id = ?')
          .run(g.to, neden, z, ctx.admin.id, z, u.id);
        await db.prepare('INSERT INTO user_status_history (id, user_id, old_status, new_status, reason, admin_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
          .run(randomUUID(), u.id, u.status, g.to, neden, ctx.admin.id, z);
        if (g.to !== 'ACTIVE') await oturumlariIptal(db, u.id, g.to);
        await denetimYaz(db, {
          adminId: ctx.admin.id, ip: ctx.ip, islem: g.islem, hedefTur: 'user', hedefId: u.id,
          once: { status: u.status }, sonra: { status: g.to, ref: denetimRef }, gerekce: neden,
        });
      });
      // Bildirim işlemden SONRA: sağlayıcı hatası durumu geri almaz,
      // sonuç kaydedilir ve admin'e döner.
      const bildirim = ctx.body.notify === false ? [] : await kullaniciyaBildir(db, u, g.sablon, { NEDEN: neden }, denetimRef);
      return { id: u.id, status: g.to, notifications: bildirim };
    });
  }

  r.get('/admin/v1/notifications/outbound', async (ctx) => {
    yetkiIste(ctx.admin, 'notifications.read');
    const durum = ctx.query.get('status');
    const limit = Math.min(Number(ctx.query.get('limit') ?? 100), 500);
    const satirlar = durum
      ? await db.prepare(`SELECT * FROM outbound_messages WHERE status = ? AND template <> 'OTP' ORDER BY created_at DESC LIMIT ?`).all(durum, limit)
      : await db.prepare(`SELECT * FROM outbound_messages WHERE template <> 'OTP' ORDER BY created_at DESC LIMIT ?`).all(limit);
    return satirlar.map((m) => ({
      id: m.id, userId: m.user_id, channel: m.channel, target: m.target, template: m.template,
      body: m.body, status: m.status, provider: m.provider, providerResponse: m.provider_response,
      auditRef: m.audit_ref, createdAt: m.created_at, sentAt: m.sent_at,
    }));
  });
}
