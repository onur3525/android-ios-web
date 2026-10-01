-- 006 — cihaz push jetonları (FCM). postgres/006 ile BİREBİR (SQLite · yalnız geliştirme/test).
-- ⚠ Jeton YALNIZ sunucuda tutulur (istemci kalıcı depoya yazmaz).
-- Gönderim (FCM HTTP v1, servis hesabı) HENÜZ YOK; bu tablo onun girdisidir.
CREATE TABLE push_tokens (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  platform TEXT NOT NULL CHECK (platform IN ('android','ios','web')),
  created_at TEXT NOT NULL,
  last_seen TEXT NOT NULL
);
CREATE INDEX push_tokens_kullanici ON push_tokens(user_id);
