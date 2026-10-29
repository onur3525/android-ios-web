-- 045 — ŞİKÂYET ET (UGC) MEKANİZMASI (29 Eki, TASLAK — işletmeci talebi)
-- postgres/045 ile BİREBİR mantıksal şema; açıklamalar oradadır.
CREATE TABLE reports (
  id TEXT PRIMARY KEY,
  reporter_id TEXT NOT NULL REFERENCES users(id),
  target_type TEXT NOT NULL CHECK (target_type IN ('LISTING','USER','REVIEW')),
  target_id TEXT NOT NULL,
  target_owner_id TEXT REFERENCES users(id),
  reason TEXT NOT NULL CHECK (reason IN ('FRAUD','INSULT','MISLEADING','OTHER')),
  note TEXT,
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','REMOVED','SUSPENDED','DISMISSED')),
  resolved_by TEXT,
  resolved_at TEXT,
  resolution_note TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX reports_durum ON reports(status, created_at DESC);
CREATE INDEX reports_hedef ON reports(target_type, target_id);
CREATE INDEX reports_bildiren ON reports(reporter_id, created_at DESC);
CREATE UNIQUE INDEX reports_acik_tekil ON reports(reporter_id, target_type, target_id) WHERE status = 'OPEN';
