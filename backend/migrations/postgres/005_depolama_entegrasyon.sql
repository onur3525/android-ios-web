-- 005 — dosya nesneleri, entegrasyonlar (şifreli sırlar), ORTAK hız sınırı
--        (çok sunuculu ortamda sayaçlar örnekler arasında paylaşılır).
--        sqlite/005 ile BİREBİR.

CREATE TABLE storage_objects (
  ref TEXT PRIMARY KEY,
  owner_id UUID NOT NULL REFERENCES users(id),
  kind TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('PENDING','ATTACHED','DISCARDED')),
  created_at TIMESTAMPTZ NOT NULL,
  attached_at TIMESTAMPTZ
);
CREATE INDEX storage_objects_sahip ON storage_objects(owner_id, created_at DESC);

CREATE TABLE integrations (
  id UUID PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('SMS','EMAIL','STORAGE','PUSH')),
  provider TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT FALSE,
  config_json TEXT NOT NULL,                 -- gizli OLMAYAN ayarlar
  secret_enc TEXT,                           -- AES-256-GCM (HC_MASTER_KEY); düz değer ASLA
  secret_hint TEXT,                          -- yalnız son 4 karakter
  last_test_at TIMESTAMPTZ,
  last_test_ok BOOLEAN,
  last_test_message TEXT,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
-- Her türde aynı anda EN FAZLA bir etkin sağlayıcı.
CREATE UNIQUE INDEX integrations_tek_aktif ON integrations(type) WHERE active = TRUE AND deleted_at IS NULL;

CREATE TABLE rate_limits (
  key TEXT PRIMARY KEY,
  window_start BIGINT NOT NULL,
  count INTEGER NOT NULL
);
