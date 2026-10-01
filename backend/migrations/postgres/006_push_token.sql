-- 006 — cihaz push jetonları (FCM). sqlite/006 ile BİREBİR.
-- ⚠ Jeton YALNIZ sunucuda tutulur (istemci kalıcı depoya yazmaz).
-- Gönderim (FCM HTTP v1, servis hesabı) HENÜZ YOK; bu tablo onun girdisidir.
CREATE TABLE push_tokens (
  token TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  platform TEXT NOT NULL CHECK (platform IN ('android','ios','web')),
  created_at TIMESTAMPTZ NOT NULL,
  last_seen TIMESTAMPTZ NOT NULL
);
CREATE INDEX push_tokens_kullanici ON push_tokens(user_id);
