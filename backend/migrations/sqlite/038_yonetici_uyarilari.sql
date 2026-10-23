-- 038 — YÖNETİCİ UYARILARI (23 Eki). postgres/038 ile AYNI mantık
-- (SQLite · yalnız geliştirme/test).
CREATE TABLE admin_alerts (
    key TEXT PRIMARY KEY,
    active INTEGER NOT NULL DEFAULT 0,
    since TEXT,
    last_sent_at TEXT,
    cursor_at TEXT,
    detail TEXT
);
