// ═══════════════════════════════════════════════════════════════
// ADMİN — HESAP SİLME KUYRUKLARININ İZLENMESİ (15 Eki güvenlik denetimi)
//
// Hesap silme veritabanında tek işlemde uygulanır; Firebase kaydı ve
// depodaki dosyalar ise kuyruğa yazılıp arka plan işleriyle silinir. Bu
// kuyruklar takılırsa (servis hesabı/depo ayarı yok, sağlayıcı hatası,
// deneme hakkı tükendi) kişisel veri üçüncü tarafta kalır; önceden bunu
// gören yoktu. Bu uçlar:
//   · bekleyen / başarısız / denemesi tükenen işleri SAYILARLA ve satır
//     satır gösterir — Firebase uid'si ve dosya anahtarı (sahip kimliği
//     içerir) gösterilmez, yerine kısa özet kimlik verilir;
//   · süresi geçtiği hâlde uygulanmamış silme taleplerini gösterir
//     (zamanlayıcı yalnız sunucu ayaktayken çalışır; Render ücretsiz
//     planında sunucu uyurken iş de bekler, ilk uyanışta yetişir);
//   · başarısız işi gerekçeyle yeniden denemeye alır (denetim kaydına yazılır).
//   · Firebase işlem kuyruğunu (yarım kalan oturum iptali / telefon
//     eşitlemesi) da aynı kurallarla gösterir.
// ═══════════════════════════════════════════════════════════════
import { createHash } from 'node:crypto';
import { yetkiIste } from '../auth.js';
import { denetimYaz } from '../audit.js';
import { simdi } from '../db.js';
import { AZAMI_DENEME as DOSYA_AZAMI_DENEME } from '../dosya_temizligi.js';
import { depolamaAyari } from '../entegrasyon.js';
import { firebaseYonetimiHazir } from '../firebase_token.js';
import { hata } from '../http.js';

/** Firebase kuyruğunda bu denemeden sonrası "uzun süreli hata" sayılır (iş yine dener). */
export const FIREBASE_UZUN_SURELI_DENEME = 10;

const ozetKimlik = (v) => createHash('sha256').update(String(v)).digest('hex').slice(0, 16);
const hataKisa = (v) => (v == null ? null : String(v).slice(0, 200));

function gerekce(v) {
  if (typeof v !== 'string' || v.trim().length < 5 || v.length > 1000) throw hata.dogrulama('İşlem nedeni 5-1000 karakter olmalıdır');
  return v.trim();
}

async function firebaseSatirlari(db) {
  return (await db.prepare('SELECT * FROM firebase_silme_kuyrugu ORDER BY created_at').all()).map((s) => ({
    id: ozetKimlik(s.uid),
    durum: s.deneme === 0 ? 'BEKLIYOR' : (s.deneme >= FIREBASE_UZUN_SURELI_DENEME ? 'UZUN_SURELI_HATA' : 'BASARISIZ'),
    deneme: s.deneme, sonHata: hataKisa(s.son_hata), sonrakiDeneme: s.sonraki_deneme, olusturma: s.created_at,
  }));
}

async function dosyaSatirlari(db) {
  return (await db.prepare(
    `SELECT ref, kind, delete_attempts, delete_error, delete_next_at, delete_requested_at FROM storage_objects
      WHERE status = 'DISCARDED' AND deleted_at IS NULL ORDER BY delete_requested_at LIMIT 500`,
  ).all()).map((o) => ({
    id: ozetKimlik(o.ref),
    tur: o.kind,
    durum: o.delete_attempts === 0 ? 'BEKLIYOR' : (o.delete_attempts >= DOSYA_AZAMI_DENEME ? 'DENEME_TUKENDI' : 'BASARISIZ'),
    deneme: o.delete_attempts, sonHata: hataKisa(o.delete_error), sonrakiDeneme: o.delete_next_at, istenme: o.delete_requested_at,
  }));
}

// Firebase işlem kuyruğu (oturum iptali / telefon eşitleme — firebase_islemleri.js).
async function firebaseIslemSatirlari(db) {
  return (await db.prepare('SELECT * FROM firebase_islem_kuyrugu ORDER BY created_at').all()).map((s) => ({
    id: ozetKimlik(`${s.user_id}|${s.islem}`),
    islem: s.islem,
    durum: s.deneme === 0 ? 'BEKLIYOR' : (s.deneme >= FIREBASE_UZUN_SURELI_DENEME ? 'UZUN_SURELI_HATA' : 'BASARISIZ'),
    deneme: s.deneme, sonHata: hataKisa(s.son_hata), sonrakiDeneme: s.sonraki_deneme, olusturma: s.created_at,
  }));
}

/**
 * Sistem Durumu (22 Eki): takılı silme işlerinin SAYILARI (kimlik yok).
 * Kaynak bu ekrandaki kuyruklarla aynıdır.
 */
export async function silmeKuyruguSorunlari(db) {
  const n = async (sql, ...p) => Number((await db.prepare(sql).get(...p)).n);
  return {
    filesExhausted: await n(`SELECT COUNT(*) AS n FROM storage_objects WHERE status = 'DISCARDED' AND deleted_at IS NULL AND delete_attempts >= ?`, DOSYA_AZAMI_DENEME),
    firebaseLongFailure: await n('SELECT COUNT(*) AS n FROM firebase_silme_kuyrugu WHERE deneme >= ?', FIREBASE_UZUN_SURELI_DENEME),
    firebaseOpsLongFailure: await n('SELECT COUNT(*) AS n FROM firebase_islem_kuyrugu WHERE deneme >= ?', FIREBASE_UZUN_SURELI_DENEME),
    overdueAccountDeletions: await n(`SELECT COUNT(*) AS n FROM account_requests WHERE type = 'DELETION' AND status = 'PENDING' AND scheduled_for < ?`, simdi()),
  };
}

const say = (satirlar) => satirlar.reduce((a, s) => ({ ...a, [s.durum]: (a[s.durum] ?? 0) + 1 }), {});

export function silmeKuyruklariRotalar(r, db) {
  r.get('/admin/v1/deletion-queues', async (ctx) => {
    yetkiIste(ctx.admin, 'deletion.queues.read');
    const z = simdi();
    const gecikmis = await db.prepare(
      `SELECT COUNT(*) AS n, MIN(scheduled_for) AS en_eski FROM account_requests WHERE type = 'DELETION' AND status = 'PENDING' AND scheduled_for < ?`,
    ).get(z);
    const bekleyen = await db.prepare(`SELECT COUNT(*) AS n FROM account_requests WHERE type = 'DELETION' AND status = 'PENDING'`).get();
    const firebase = await firebaseSatirlari(db);
    const dosyalar = await dosyaSatirlari(db);
    const islemler = await firebaseIslemSatirlari(db);
    return {
      accountDeletions: { pending: Number(bekleyen.n), overdue: Number(gecikmis.n), oldestOverdueAt: gecikmis.en_eski ?? null },
      firebase: { configured: firebaseYonetimiHazir(), counts: say(firebase), items: firebase, longFailureAfter: FIREBASE_UZUN_SURELI_DENEME },
      files: { configured: !!(await depolamaAyari(db)), counts: say(dosyalar), items: dosyalar, maxAttempts: DOSYA_AZAMI_DENEME },
      firebaseOps: { configured: firebaseYonetimiHazir(), counts: say(islemler), items: islemler, longFailureAfter: FIREBASE_UZUN_SURELI_DENEME },
    };
  });

  // Başarısız (ya da denemesi tükenmiş) işi hemen yeniden denemeye alır.
  // `id` verilmezse o kuyruğun BÜTÜN başarısız işleri. İş bir sonraki
  // zamanlayıcı turunda (≤ 1 dk) çalışır; sonucu bu ekranda görünür.
  r.post('/admin/v1/deletion-queues/retry', async (ctx) => {
    yetkiIste(ctx.admin, 'deletion.queues.retry');
    const neden = gerekce(ctx.body.reason);
    const kuyruk = String(ctx.body.queue ?? '');
    const id = ctx.body.id == null ? null : String(ctx.body.id);
    const z = simdi();
    let n = 0;
    if (kuyruk === 'firebase') {
      for (const s of await db.prepare('SELECT uid FROM firebase_silme_kuyrugu WHERE deneme > 0').all()) {
        if (id && ozetKimlik(s.uid) !== id) continue;
        n += (await db.prepare('UPDATE firebase_silme_kuyrugu SET sonraki_deneme = ? WHERE uid = ?').run(z, s.uid)).changes;
      }
    } else if (kuyruk === 'files') {
      for (const o of await db.prepare(`SELECT ref FROM storage_objects WHERE status = 'DISCARDED' AND deleted_at IS NULL AND delete_attempts > 0`).all()) {
        if (id && ozetKimlik(o.ref) !== id) continue;
        // Hata metni korunur (başarıyla silinince temizlenir).
        n += (await db.prepare('UPDATE storage_objects SET delete_attempts = 0, delete_next_at = NULL WHERE ref = ?').run(o.ref)).changes;
      }
    } else if (kuyruk === 'firebase_ops') {
      for (const s of await db.prepare('SELECT user_id, islem FROM firebase_islem_kuyrugu WHERE deneme > 0').all()) {
        if (id && ozetKimlik(`${s.user_id}|${s.islem}`) !== id) continue;
        n += (await db.prepare('UPDATE firebase_islem_kuyrugu SET sonraki_deneme = ? WHERE user_id = ? AND islem = ?').run(z, s.user_id, s.islem)).changes;
      }
    } else {
      throw hata.dogrulama('Geçersiz kuyruk');
    }
    if (id && n === 0) throw hata.bulunamadi('Yeniden denenecek başarısız iş bulunamadı');
    await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'deletion.queue.retry', hedefTur: `deletion_queue.${kuyruk}`, hedefId: id ?? 'all', sonra: { count: n }, gerekce: neden });
    return { queue: kuyruk, retried: n };
  });
}
