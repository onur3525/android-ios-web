// ═══════════════════════════════════════════════════════════════
// HESAP SİLME — FIREBASE KİMLİK KAYDI (15 Eki güvenlik denetimi)
//
// Hesap silme yerelde kişisel veriyi anonimleştiriyor ve `firebase_uid`yi
// siliyordu; Firebase Authentication'daki kullanıcı (telefon numarası,
// e-posta) ise HİÇ silinmiyordu — üçüncü tarafta kalan kişisel veri kopyası.
//
// Silme işlemi (veritabanı işlemi) Firebase'e bağımlı olmasın diye uid
// kuyruğa yazılır; bu iş kuyruğu boşaltır. Hata olursa artan aralıkla
// (1 dk → en fazla 24 sa) yeniden dener; hata metni kişisel veri içermez.
// ═══════════════════════════════════════════════════════════════
import { simdi } from './db.js';
import { firebaseKullaniciSil } from './firebase_token.js';

const AZAMI_ARALIK_DK = 24 * 60;

/** Silinen hesabın Firebase uid'sini kuyruğa yazar (silme işleminin İÇİNDE çağrılır). */
export async function firebaseSilmeKuyrugunaEkle(db, uid) {
  if (!uid) return;
  const z = simdi();
  await db.prepare(
    'INSERT INTO firebase_silme_kuyrugu (uid, deneme, sonraki_deneme, created_at) VALUES (?, 0, ?, ?) ON CONFLICT (uid) DO NOTHING',
  ).run(uid, z, z);
}

/** Zamanı gelen kayıtları işler; işlenen kayıt sayısını döner. */
export async function firebaseSilmeKuyrugunuIsle(db, { limit = 50 } = {}) {
  const satirlar = await db.prepare(
    'SELECT * FROM firebase_silme_kuyrugu WHERE sonraki_deneme <= ? ORDER BY sonraki_deneme LIMIT ?',
  ).all(simdi(), limit);
  for (const s of satirlar) {
    try {
      await firebaseKullaniciSil(s.uid);
      await db.prepare('DELETE FROM firebase_silme_kuyrugu WHERE uid = ?').run(s.uid);
    } catch (e) {
      const deneme = s.deneme + 1;
      const aralikDk = Math.min(2 ** Math.min(deneme, 11), AZAMI_ARALIK_DK);
      await db.prepare('UPDATE firebase_silme_kuyrugu SET deneme = ?, son_hata = ?, sonraki_deneme = ? WHERE uid = ?')
        .run(deneme, String(e?.message ?? 'bilinmeyen hata').slice(0, 200), new Date(Date.now() + aralikDk * 60_000).toISOString(), s.uid);
      if (deneme === 5 || deneme % 20 === 0) console.error(`firebase_silme: ${deneme}. deneme başarısız: ${String(e?.message ?? '').slice(0, 120)}`);
    }
  }
  return satirlar.length;
}
