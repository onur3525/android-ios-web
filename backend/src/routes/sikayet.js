// ═══════════════════════════════════════════════════════════════
// ŞİKÂYET ET (UGC) — KULLANICI VE YÖNETİCİ UÇLARI (29 Eki, TASLAK)
//
// KULLANICI (oturum gerekir):
//   POST /api/v1/reports  { targetType: LISTING|USER|REVIEW, targetId,
//                           reason: FRAUD|INSULT|MISLEADING|OTHER, note? }
//     · kendi içeriği/profili şikâyet edilemez
//     · OTHER'da açıklama zorunlu (en az 10 karakter); açıklama ≤ 500
//     · aynı içerik için AÇIK şikâyet varsa aynısı döner (ikinci kayıt yok)
//     · 24 saatte en çok 10 şikâyet (kötüye kullanım sınırı)
//     · şikâyet edilen kişiye şikâyet edenin kimliği BİLDİRİLMEZ
//
// YÖNETİCİ:
//   GET  /admin/v1/reports?status=&targetType=   → en yeni 200 şikâyet
//   POST /admin/v1/reports/:id/resolve { action, reason }
//     action REMOVE  → ilan/yorum "Yönetim kaldırdı" (mevcut kaldırma
//                      yoluyla — ilan.js, TEK KAYNAK)
//     action SUSPEND → şikâyet edilen HESAP askıya alınır (mevcut askı
//                      yoluyla — admin_kullanici.js, TEK KAYNAK)
//     action DISMISS → işlem gerekmedi
//   Aynı içeriğe ait bütün AÇIK şikâyetler birlikte sonuçlanır. Gerekçe
//   zorunlu, yeniden doğrulama zorunlu, denetim kaydına yazılır.
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { yenidenDogrulamaIste, yetkiIste, yetkiliMi } from '../auth.js';
import { denetimYaz } from '../audit.js';
import { simdi } from '../db.js';
import { hata } from '../http.js';
import { kullaniciCoz } from './kullanici.js';
import { ilaniYonetimKaldir, yorumuYonetimKaldir } from './ilan.js';
import { hesapDurumunuDegistir } from './admin_kullanici.js';

export const SIKAYET_HEDEFLERI = ['LISTING', 'USER', 'REVIEW'];
export const SIKAYET_NEDENLERI = ['FRAUD', 'INSULT', 'MISLEADING', 'OTHER'];
const GUNLUK_SINIR = 10;
const DURUMLAR = ['OPEN', 'REMOVED', 'SUSPENDED', 'DISMISSED'];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Hedefin sahibi; yoksa/yayında değilse 404. */
async function hedefSahibi(db, tur, id) {
  if (tur === 'LISTING') {
    const l = await db.prepare(`SELECT owner_id FROM listings WHERE id = ? AND status IN ('ACTIVE','EXPIRED')`).get(id);
    if (!l) throw hata.bulunamadi('İlan bulunamadı');
    return l.owner_id;
  }
  if (tur === 'REVIEW') {
    const y = await db.prepare(`SELECT author_id FROM reviews WHERE id = ? AND status = 'PUBLISHED'`).get(id);
    if (!y) throw hata.bulunamadi('Yorum bulunamadı');
    return y.author_id;
  }
  const u = await db.prepare('SELECT id FROM users WHERE id = ? AND deleted_at IS NULL').get(id);
  if (!u) throw hata.bulunamadi('Kullanıcı bulunamadı');
  return u.id;
}

const sikayetGorunumu = (s) => ({
  id: s.id, targetType: s.target_type, targetId: s.target_id, targetOwnerId: s.target_owner_id,
  reporterId: s.reporter_id, reason: s.reason, note: s.note, status: s.status,
  resolvedAt: s.resolved_at, resolutionNote: s.resolution_note, createdAt: s.created_at,
});

export function sikayetRotalar(r, db) {
  const korumali = (f) => async (ctx) => {
    const { u, oturum } = await kullaniciCoz(db, ctx.req);
    ctx.kullanici = u;
    ctx.kOturum = oturum;
    return f(ctx);
  };

  // ════ KULLANICI ════
  r.post('/api/v1/reports', korumali(async (ctx) => {
    const u = ctx.kullanici;
    const tur = String(ctx.body.targetType ?? '');
    const hedefId = String(ctx.body.targetId ?? '');
    const neden = String(ctx.body.reason ?? '');
    const not = ctx.body.note == null ? '' : String(ctx.body.note).trim();
    if (!SIKAYET_HEDEFLERI.includes(tur)) throw hata.dogrulama('Geçersiz şikâyet konusu');
    if (!UUID.test(hedefId)) throw hata.dogrulama('Geçersiz kayıt');
    if (!SIKAYET_NEDENLERI.includes(neden)) throw hata.dogrulama('Şikâyet nedeni seçiniz');
    if (not.length > 500) throw hata.dogrulama('Açıklama en fazla 500 karakter olabilir');
    if (neden === 'OTHER' && not.length < 10) throw hata.dogrulama('"Diğer" seçildiğinde kısa bir açıklama yazınız (en az 10 karakter)');
    const sahip = await hedefSahibi(db, tur, hedefId);
    if (sahip === u.id) throw hata.dogrulama('Kendi içeriğinizi şikâyet edemezsiniz');
    const acik = await db.prepare(
      `SELECT * FROM reports WHERE reporter_id = ? AND target_type = ? AND target_id = ? AND status = 'OPEN'`,
    ).get(u.id, tur, hedefId);
    if (acik) return { id: acik.id, status: acik.status, duplicate: true };
    const gun = await db.prepare('SELECT COUNT(*) n FROM reports WHERE reporter_id = ? AND created_at > ?')
      .get(u.id, new Date(Date.now() - 86_400_000).toISOString());
    if (Number(gun.n) >= GUNLUK_SINIR) throw hata.hiz('Bugün çok fazla şikâyet gönderdiniz. Lütfen daha sonra tekrar deneyin.');
    const id = randomUUID();
    await db.prepare(
      `INSERT INTO reports (id, reporter_id, target_type, target_id, target_owner_id, reason, note, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'OPEN', ?)`,
    ).run(id, u.id, tur, hedefId, sahip, neden, not || null, simdi());
    return { id, status: 'OPEN', duplicate: false };
  }));

  // ════ YÖNETİCİ ════
  r.get('/admin/v1/reports', async (ctx) => {
    yetkiIste(ctx.admin, 'reports.read');
    const kosul = ['1 = 1'];
    const p = [];
    const durum = ctx.query.get('status');
    if (durum) {
      if (!DURUMLAR.includes(durum)) throw hata.dogrulama('Geçersiz durum');
      kosul.push('r.status = ?'); p.push(durum);
    }
    const tur = ctx.query.get('targetType');
    if (tur) {
      if (!SIKAYET_HEDEFLERI.includes(tur)) throw hata.dogrulama('Geçersiz şikâyet konusu');
      kosul.push('r.target_type = ?'); p.push(tur);
    }
    const satirlar = await db.prepare(
      `SELECT r.*, (SELECT COUNT(*) FROM reports r2 WHERE r2.target_type = r.target_type AND r2.target_id = r.target_id AND r2.status = 'OPEN') AS acik_sayisi
         FROM reports r WHERE ${kosul.join(' AND ')} ORDER BY r.created_at DESC LIMIT 200`,
    ).all(...p);
    const adGorebilir = yetkiliMi(ctx.admin.role, 'users.contact.read');
    const ozetler = new Map();
    for (const s of satirlar) {
      const k = `${s.target_type}:${s.target_id}`;
      if (ozetler.has(k)) continue;
      ozetler.set(k, await hedefOzeti(db, s.target_type, s.target_id, adGorebilir));
    }
    return satirlar.map((s) => ({
      ...sikayetGorunumu(s),
      openCountForTarget: Number(s.acik_sayisi),
      target: ozetler.get(`${s.target_type}:${s.target_id}`),
    }));
  });

  r.post('/admin/v1/reports/:id/resolve', async (ctx) => {
    yetkiIste(ctx.admin, 'reports.resolve');
    yenidenDogrulamaIste(ctx.oturum);
    const islem = String(ctx.body.action ?? '');
    const gerekce = String(ctx.body.reason ?? '').trim();
    if (gerekce.length < 5 || gerekce.length > 1000) throw hata.dogrulama('İşlem nedeni 5-1000 karakter olmalıdır');
    const s = await db.prepare('SELECT * FROM reports WHERE id = ?').get(ctx.params.id);
    if (!s) throw hata.bulunamadi('Şikâyet bulunamadı');
    if (s.status !== 'OPEN') throw hata.durum('Şikâyet zaten sonuçlandırılmış');
    const ek = { reportId: s.id };
    let yeniDurum;
    let sonuc = null;
    if (islem === 'REMOVE') {
      if (s.target_type === 'LISTING') {
        yetkiIste(ctx.admin, 'listings.remove');
        const l = await db.prepare('SELECT status FROM listings WHERE id = ?').get(s.target_id);
        if (l && l.status !== 'ADMIN_REMOVED') sonuc = await ilaniYonetimKaldir(db, { adminId: ctx.admin.id, ip: ctx.ip, ilanId: s.target_id, gerekceHam: gerekce, ek });
      } else if (s.target_type === 'REVIEW') {
        yetkiIste(ctx.admin, 'reviews.remove');
        const y = await db.prepare('SELECT status FROM reviews WHERE id = ?').get(s.target_id);
        if (y && y.status !== 'ADMIN_DELETED') sonuc = await yorumuYonetimKaldir(db, { adminId: ctx.admin.id, ip: ctx.ip, yorumId: s.target_id, gerekceHam: gerekce, ek });
      } else {
        throw hata.dogrulama('Kullanıcı şikâyetinde "Hesabı askıya al" kullanılır');
      }
      yeniDurum = 'REMOVED';
    } else if (islem === 'SUSPEND') {
      yetkiIste(ctx.admin, 'users.status.write');
      const kisi = s.target_type === 'USER' ? s.target_id : s.target_owner_id;
      const u = kisi ? await db.prepare('SELECT status FROM users WHERE id = ? AND deleted_at IS NULL').get(kisi) : null;
      if (!u) throw hata.bulunamadi('Kullanıcı bulunamadı');
      if (u.status === 'ACTIVE') sonuc = await hesapDurumunuDegistir(db, { adminId: ctx.admin.id, ip: ctx.ip, kullaniciId: kisi, eylem: 'suspend', gerekceHam: gerekce, ek });
      yeniDurum = 'SUSPENDED';
    } else if (islem === 'DISMISS') {
      yeniDurum = 'DISMISSED';
    } else {
      throw hata.dogrulama('Geçersiz işlem');
    }
    const z = simdi();
    let kapanan = 0;
    await db.tx(async () => {
      kapanan = (await db.prepare(
        `UPDATE reports SET status = ?, resolved_by = ?, resolved_at = ?, resolution_note = ?
          WHERE target_type = ? AND target_id = ? AND status = 'OPEN'`,
      ).run(yeniDurum, ctx.admin.id, z, gerekce, s.target_type, s.target_id)).changes ?? 0;
      await denetimYaz(db, {
        adminId: ctx.admin.id, ip: ctx.ip, islem: 'report.resolve', hedefTur: 'report', hedefId: s.id,
        once: { status: 'OPEN', targetType: s.target_type, targetId: s.target_id },
        sonra: { status: yeniDurum, closedReports: kapanan }, gerekce,
      });
    });
    return { id: s.id, status: yeniDurum, closedReports: kapanan, action: sonuc };
  });
}

/** Panel listesi için hedefin kısa özeti (yönetici görünümü). */
async function hedefOzeti(db, tur, id, adGorebilir) {
  if (tur === 'LISTING') {
    const l = await db.prepare('SELECT id, ilan_no, title, description, status, owner_id FROM listings WHERE id = ?').get(id);
    return l ? { kind: 'LISTING', title: l.title, ilanNo: l.ilan_no, text: String(l.description ?? '').slice(0, 300), status: l.status, ownerId: l.owner_id } : null;
  }
  if (tur === 'REVIEW') {
    const y = await db.prepare('SELECT id, text, stars, status, author_id FROM reviews WHERE id = ?').get(id);
    return y ? { kind: 'REVIEW', text: String(y.text ?? '').slice(0, 300), stars: y.stars, status: y.status, ownerId: y.author_id } : null;
  }
  const u = await db.prepare('SELECT id, name, status, deleted_at FROM users WHERE id = ?').get(id);
  return u ? { kind: 'USER', name: adGorebilir ? u.name : null, status: u.deleted_at ? 'DELETED' : u.status, ownerId: u.id } : null;
}
