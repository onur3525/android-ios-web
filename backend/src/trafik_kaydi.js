// ═══════════════════════════════════════════════════════════════
// 5651 TRAFİK KAYDI VE YASAL KİMLİK ARŞİVİ (29 Eki, TASLAK)
//
// · trafikYaz: kullanıcının işleminde IP, KAYNAK PORT, işlem türü ve
//   zaman `trafik_kayitlari` tablosuna yazılır (yalnız ekleme). Oturum
//   tablosundan bağımsızdır; hesap silinse de 365 gün kalır.
// · Tek kaynak: kullanıcı API'sinde oturumlu ve BAŞARILI her değişiklik
//   isteği sunucu çekirdeğinde (server.js) BURADAN kaydedilir — rotalara
//   tek tek kayıt satırı eklenmez. Oturum açma/yenileme (henüz oturum
//   yokken) kullanici.js'te aynı fonksiyonla kaydedilir.
// · Kayıt yazılamazsa kullanıcının işlemi DURMAZ; hata (kişisel değer
//   içermeden) günlüğe yazılır.
// · kimlikArsivle: hesap silinirken kullanıcı satırı anonimleşmeden ÖNCE
//   ad/telefon/e-posta 365 gün saklanır (yalnız yetkili merci talebi).
// · yasalKayitBakimi: 365 günü dolan trafik kayıtları ve kimlik arşivi,
//   sonuçlanmasının üzerinden 2 yıl geçen şikâyetler silinir.
// ═══════════════════════════════════════════════════════════════
import { isIP } from 'node:net';
import { simdi } from './db.js';
import { istemciIp, kaynakPort } from './http.js';
import { hataOzeti } from './guvenli_gunluk.js';
// İstemci türü tek kaynaktan (oturum kayıtlarıyla aynı sınıflandırma).
// Döngüsel içe aktarma güvenlidir: yalnız çağrı anında kullanılır.
import { istemciTuru } from './routes/kullanici.js';

const GUN = 24 * 60 * 60 * 1000;
export const TRAFIK_SAKLAMA_GUN = 365;
export const SIKAYET_SAKLAMA_GUN = 2 * 365;

/** Trafik kaydı yazar. ASLA fırlatmaz (kullanıcı işlemi durmaz). */
export async function trafikYaz(db, req, { kullaniciId = null, olay, hedefTur = null, hedefId = null }) {
  try {
    const ip = istemciIp(req);
    await db.prepare(
      `INSERT INTO trafik_kayitlari (user_id, olay, hedef_tur, hedef_id, ip, kaynak_port, user_agent, istemci, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      kullaniciId,
      String(olay).slice(0, 120),
      hedefTur ? String(hedefTur).slice(0, 40) : null,
      hedefId != null ? String(hedefId).slice(0, 80) : null,
      isIP(ip) ? ip : String(ip ?? 'bilinmiyor').slice(0, 64),
      kaynakPort(req),
      String(req.headers?.['user-agent'] ?? '').slice(0, 200) || null,
      istemciTuru(req),
      simdi(),
    );
  } catch (e) {
    console.error('UYARI: trafik kaydı yazılamadı', JSON.stringify(hataOzeti(e)));
  }
}

// Kullanıcı API'sinde kayda DEĞMEYEN değişiklik istekleri (yalnız okundu
// işareti, cihaz jetonu yenileme, sunucuya iş yükü bırakmayan yardımcılar).
const KAYITSIZ = new Set([
  'POST /api/v1/notifications/:id/read',
  'POST /api/v1/notifications/read-for-page',
  'POST /api/v1/notifications/read-all',
  'POST /api/v1/messages/:offerId/read',
  'POST /api/v1/teklif-talepleri/:id/okundu',
  'POST /api/v1/auth/verify-password',
  'POST /api/v1/devices/push-token',
  'DELETE /api/v1/devices/push-token',
  'DELETE /api/v1/storage/uploads/pending',
]);

/**
 * Sunucu çekirdeğinden çağrılır: oturumlu kullanıcının BAŞARILI değişiklik
 * isteği. Olay adı "YÖNTEM /yol/deseni" biçimindedir (ör.
 * "POST /api/v1/listings"); hedef, yoldaki kimlik ya da yanıtın `id`'si.
 */
export async function islemKaydi(db, ctx, desen, sonuc) {
  const yontem = ctx.req.method;
  if (yontem === 'GET' || !ctx.kullanici?.id || !desen?.startsWith('/api/v1/')) return;
  const olay = `${yontem} ${desen}`;
  if (KAYITSIZ.has(olay)) return;
  const p = ctx.params ?? {};
  const hedefId = p.id ?? p.offerId ?? p.jti ?? (sonuc && typeof sonuc === 'object' && !Array.isArray(sonuc) ? sonuc.id : null) ?? null;
  await trafikYaz(db, ctx.req, { kullaniciId: ctx.kullanici.id, olay, hedefId });
}

/** Hesap silinirken (anonimleştirmeden ÖNCE, aynı işlem içinde) çağrılır. */
export async function kimlikArsivle(db, { id, ad, telefon, eposta, kayitTarihi }, z) {
  const bitis = new Date(Date.parse(z) + TRAFIK_SAKLAMA_GUN * GUN).toISOString();
  await db.prepare('DELETE FROM yasal_kimlik_arsivi WHERE user_id = ?').run(id);
  await db.prepare(
    `INSERT INTO yasal_kimlik_arsivi (user_id, ad, telefon, eposta, kayit_tarihi, silinme_tarihi, saklama_bitis)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(id, ad ?? null, telefon ?? null, eposta ?? null, kayitTarihi ?? null, z, bitis);
}

/** Günlük bakım: süresi dolan yasal kayıtlar silinir. */
export async function yasalKayitBakimi(db) {
  const once = (gun) => new Date(Date.now() - gun * GUN).toISOString();
  const trafik = (await db.prepare('DELETE FROM trafik_kayitlari WHERE created_at < ?').run(once(TRAFIK_SAKLAMA_GUN))).changes ?? 0;
  const kimlik = (await db.prepare('DELETE FROM yasal_kimlik_arsivi WHERE saklama_bitis < ?').run(simdi())).changes ?? 0;
  const sikayet = (await db.prepare(`DELETE FROM reports WHERE status <> 'OPEN' AND resolved_at < ?`).run(once(SIKAYET_SAKLAMA_GUN))).changes ?? 0;
  return { trafik, kimlik, sikayet };
}
