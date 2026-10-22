-- 028 — SİSTEM DURUMU ÖLÇÜMLERİ (22 Eki, kullanıcı kuralı: her gösterge
-- gerçek bir kaynaktan beslenir; ölçülmeyen değer gösterilmez).
--
-- api_metrics: kullanıcı API'sine (/api/v1) gelen isteklerin DAKİKALIK
--   toplamları. Bütün sunucu örnekleri aynı satıra ekler (UPSERT). Yanıt
--   süresi dağılımı kovalarla tutulur (ms: <100, <300, <1000, <3000, ≥3000).
-- api_errors: 5xx yanıtlarının teknik kaydı (yol deseni, hata kodu, istek
--   kimliği). Kişisel veri, gövde, IP TUTULMAZ. 30 günden eskisi silinir.
-- backup_monitor: yedekleme durumunu Render API'sinden okumak için tek
--   satırlık ayar (Postgres kimliği + şifreli API anahtarı) ve son kontrol
--   sonucu. İndirme adresleri SAKLANMAZ.
CREATE TABLE api_metrics (
  bucket BIGINT PRIMARY KEY,
  requests INTEGER NOT NULL DEFAULT 0,
  errors_4xx INTEGER NOT NULL DEFAULT 0,
  errors_5xx INTEGER NOT NULL DEFAULT 0,
  total_ms BIGINT NOT NULL DEFAULT 0,
  max_ms INTEGER NOT NULL DEFAULT 0,
  lat_100 INTEGER NOT NULL DEFAULT 0,
  lat_300 INTEGER NOT NULL DEFAULT 0,
  lat_1000 INTEGER NOT NULL DEFAULT 0,
  lat_3000 INTEGER NOT NULL DEFAULT 0,
  lat_over INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE api_errors (
  id TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL,
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
  updated_at TIMESTAMPTZ NOT NULL,
  checked_at TIMESTAMPTZ,
  check_ok BOOLEAN,
  check_message TEXT,
  recovery_status TEXT,
  recovery_starts_at TEXT,
  last_export_at TEXT,
  export_count INTEGER
);
