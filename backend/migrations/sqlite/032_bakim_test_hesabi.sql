-- 032 — BAKIMDA TEST HESABI (22 Eki). postgres/032 ile AYNI mantık (SQLite · yalnız geliştirme/test).
ALTER TABLE users ADD COLUMN maintenance_bypass INTEGER NOT NULL DEFAULT 0;

CREATE TABLE maintenance_devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  device_hash TEXT NOT NULL,
  platform TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);
CREATE UNIQUE INDEX maintenance_devices_kullanici_cihaz ON maintenance_devices(user_id, device_hash);
CREATE INDEX maintenance_devices_cihaz ON maintenance_devices(device_hash);
