// ═══════════════════════════════════════════════════════════════
// FIREBASE İŞLEM KUYRUĞU — yarım kalan işlemlerin kurtarılması (15 Eki)
//
// Şifre ve telefon işlemlerinde yerel kayıt ile Firebase iki ayrı sistemdir;
// Firebase çağrısı ağ/sağlayıcı hatasıyla başarısız olabilir. Ana işlem bu
// yüzden geri alınamıyorsa (yerel değişiklik yapılmış, Firebase yazılamamış)
// eksik adım bu kuyruğa yazılır ve arka plan işi tamamlar:
//   REVOKE     — yenileme belirteçlerini iptal et. Gönderilen validSince,
//                hesabın GÜNCEL yerel sınırından küçük olamaz (eski bir
//                yeniden deneme sonraki iptali geri almasın).
//   SYNC_PHONE — Firebase telefonu = hesabın GÜNCEL numarası. Önce Firebase
//                kaydı okunur; zaten eşitse yazılmaz (idempotent). Yarım
//                kalan telefon değişikliğinde iki sistem yerel kayıtta birleşir.
// Kullanıcı + işlem başına TEK satır (yeniden ekleme mevcut satırı öne alır).
// Hata artan aralıkla (1 dk → en çok 6 sa) SÜRESİZ yeniden denenir; hata
// metni kişisel veri içermez; yönetici panelinde görünür.
// Yerel güvenlik sınırı (users.firebase_valid_since) kuyruktan BAĞIMSIZ hemen
// yazılır: Firebase'e yazılamasa da eski belgeyle sunucu oturumu açılmaz.
// ═══════════════════════════════════════════════════════════════
import { simdi } from './db.js';
import {
  firebaseKullaniciBilgisi, firebaseOturumlariniIptalEt, firebaseTelefonAyarla, firebaseYonetimiHazir,
} from './firebase_token.js';

const AZAMI_ARALIK_DK = 6 * 60;

/** Kuyruğa yazar (varsa öne alır). `deger` REVOKE için validSince (saniye). */
export async function firebaseIslemiKuyrugaEkle(db, kullaniciId, islem, deger = null) {
  const z = simdi();
  await db.prepare(
    `INSERT INTO firebase_islem_kuyrugu (user_id, islem, deger, deneme, sonraki_deneme, created_at) VALUES (?, ?, ?, 0, ?, ?)
     ON CONFLICT (user_id, islem) DO UPDATE SET
       deger = CASE WHEN excluded.deger IS NULL THEN firebase_islem_kuyrugu.deger
                    WHEN firebase_islem_kuyrugu.deger IS NULL OR excluded.deger > firebase_islem_kuyrugu.deger THEN excluded.deger
                    ELSE firebase_islem_kuyrugu.deger END,
       sonraki_deneme = excluded.sonraki_deneme`,
  ).run(kullaniciId, islem, deger, z, z);
}

async function uygula(db, s) {
  const u = await db.prepare('SELECT id, phone, firebase_uid, firebase_valid_since, deleted_at FROM users WHERE id = ?').get(s.user_id);
  // Hesap silindiyse ya da Firebase'e bağlı değilse yapılacak iş kalmaz
  // (silinen hesabın Firebase kaydı ayrı kuyrukla silinir).
  if (!u || u.deleted_at || !u.firebase_uid) return;
  if (s.islem === 'REVOKE') {
    const sinir = Math.max(Number(s.deger ?? 0), Number(u.firebase_valid_since ?? 0));
    await firebaseOturumlariniIptalEt(u.firebase_uid, sinir || Math.floor(Date.now() / 1000));
    return;
  }
  if (s.islem === 'SYNC_PHONE') {
    const hedef = `+90${u.phone}`;
    const k = await firebaseKullaniciBilgisi(u.firebase_uid);
    if (!k) throw new Error('Firebase kullanıcısı bulunamadı');
    if (k.phoneNumber !== hedef) await firebaseTelefonAyarla(u.firebase_uid, hedef);
  }
}

/** Zamanı gelen işleri uygular; işlenen satır sayısını döner. */
export async function firebaseIslemKuyrugunuIsle(db, { limit = 50 } = {}) {
  if (!firebaseYonetimiHazir()) return 0; // servis hesabı yok: kuyruk bekler (panelde görünür)
  const satirlar = await db.prepare(
    'SELECT * FROM firebase_islem_kuyrugu WHERE sonraki_deneme <= ? ORDER BY sonraki_deneme LIMIT ?',
  ).all(simdi(), limit);
  for (const s of satirlar) {
    try {
      await uygula(db, s);
      // Yalnız işlenen sürüm silinir: bu arada yeniden eklenen (öne alınan) iş kalır.
      await db.prepare('DELETE FROM firebase_islem_kuyrugu WHERE user_id = ? AND islem = ? AND sonraki_deneme = ?')
        .run(s.user_id, s.islem, s.sonraki_deneme);
    } catch (e) {
      const deneme = s.deneme + 1;
      const aralikDk = Math.min(2 ** Math.min(deneme, 9), AZAMI_ARALIK_DK);
      await db.prepare('UPDATE firebase_islem_kuyrugu SET deneme = ?, son_hata = ?, sonraki_deneme = ? WHERE user_id = ? AND islem = ?')
        .run(deneme, String(e?.message ?? 'bilinmeyen hata').slice(0, 200), new Date(Date.now() + aralikDk * 60_000).toISOString(), s.user_id, s.islem);
      if (deneme === 5 || deneme % 20 === 0) console.error(`firebase_islemleri: ${s.islem} ${deneme}. deneme başarısız: ${String(e?.message ?? '').slice(0, 120)}`);
    }
  }
  return satirlar.length;
}
