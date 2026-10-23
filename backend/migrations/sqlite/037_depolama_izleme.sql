-- 037 — DOSYA DEPOLAMA OTOMATİK KONTROLÜ (23 Eki). postgres/037 ile AYNI
-- mantık (SQLite · yalnız geliştirme/test).
CREATE TABLE storage_monitor (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    checked_at TEXT NOT NULL,
    check_ok INTEGER NOT NULL,
    check_message TEXT NOT NULL
);
