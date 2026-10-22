-- 028 — SİSTEM DURUMU ÖLÇÜMLERİ (22 Eki). postgres/028 ile AYNI mantık
-- (SQLite · yalnız geliştirme/test).
CREATE TABLE api_metrics (
    bucket INTEGER PRIMARY KEY,
    requests INTEGER NOT NULL DEFAULT 0,
    errors_4xx INTEGER NOT NULL DEFAULT 0,
    errors_5xx INTEGER NOT NULL DEFAULT 0,
    total_ms INTEGER NOT NULL DEFAULT 0,
    max_ms INTEGER NOT NULL DEFAULT 0,
    lat_100 INTEGER NOT NULL DEFAULT 0,
    lat_300 INTEGER NOT NULL DEFAULT 0,
    lat_1000 INTEGER NOT NULL DEFAULT 0,
    lat_3000 INTEGER NOT NULL DEFAULT 0,
    lat_over INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE api_errors (
    id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    method TEXT NOT NULL,
    path TEXT NOT NULL,
    status INTEGER NOT NULL,
    code TEXT,
    request_id TEXT
);
CREATE INDEX api_errors_zaman ON api_errors (created_at);

CREATE TABLE backup_monitor (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    provider TEXT NOT NULL CHECK (provider IN ('render')),
    postgres_id TEXT NOT NULL,
    secret_enc TEXT NOT NULL,
    secret_hint TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    checked_at TEXT,
    check_ok INTEGER,
    check_message TEXT,
    recovery_status TEXT,
    recovery_starts_at TEXT,
    last_export_at TEXT,
    export_count INTEGER
);
