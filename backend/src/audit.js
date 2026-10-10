// ═══════════════════════════════════════════════════════════════
// DENETİM KAYDI — yalnız ekleme (tetikleyici güncellemeyi/silmeyi
// engeller). Her admin yazma işlemi buradan geçer.
// ═══════════════════════════════════════════════════════════════
import { simdi } from './db.js';

export async function denetimYaz(db, { adminId, islem, hedefTur, hedefId, once, sonra, gerekce, ip }) {
  await db.prepare(
    `INSERT INTO audit_log (admin_id, action, target_type, target_id, before_json, after_json, reason, ip, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    adminId ?? null,
    islem,
    hedefTur ?? null,
    hedefId ?? null,
    once === undefined ? null : JSON.stringify(once),
    sonra === undefined ? null : JSON.stringify(sonra),
    gerekce ?? null,
    ip ?? null,
    simdi(),
  );
}
