-- 002 — (SQLite · yalnız geliştirme/test) kullanıcı, oturum, OTP, adres, hizmet veren profili, hesap durumu,
--        giden bildirimler (SMS/e-posta). postgres/002 ile BİREBİR.

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  phone TEXT NOT NULL,
  email TEXT,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  phone_verified INTEGER NOT NULL DEFAULT 0,
  email_verified INTEGER NOT NULL DEFAULT 0,
  roles TEXT NOT NULL,                       -- 'CUSTOMER' | 'PROVIDER' | 'CUSTOMER,PROVIDER'
  active_role TEXT NOT NULL CHECK (active_role IN ('CUSTOMER','PROVIDER')),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','BANNED')),
  status_reason TEXT,
  status_changed_at TEXT,
  status_changed_by TEXT,
  terms_accepted INTEGER NOT NULL DEFAULT 0,
  failed_logins INTEGER NOT NULL DEFAULT 0,
  locked_until TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE UNIQUE INDEX users_telefon ON users(phone) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX users_eposta ON users(lower(email)) WHERE deleted_at IS NULL AND email IS NOT NULL;
CREATE INDEX users_durum ON users(status);

CREATE TABLE user_sessions (
  id TEXT PRIMARY KEY,                       -- erişim token'ındaki jti
  user_id TEXT NOT NULL REFERENCES users(id),
  refresh_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_used TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  revoked_at TEXT,
  revoke_reason TEXT,
  ip TEXT,
  user_agent TEXT
);
CREATE UNIQUE INDEX user_sessions_refresh ON user_sessions(refresh_hash);
CREATE INDEX user_sessions_kullanici ON user_sessions(user_id);

CREATE TABLE otp_codes (
  id TEXT PRIMARY KEY,
  phone TEXT NOT NULL,
  purpose TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  consumed_at TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX otp_codes_telefon ON otp_codes(phone, purpose, created_at DESC);

CREATE TABLE addresses (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  city TEXT NOT NULL,
  district TEXT NOT NULL,
  neighborhood TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE provider_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  categories_json TEXT NOT NULL,
  districts_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE user_status_history (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  old_status TEXT NOT NULL,
  new_status TEXT NOT NULL,
  reason TEXT NOT NULL,
  admin_id TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX user_status_history_kullanici ON user_status_history(user_id, created_at DESC);
CREATE TRIGGER user_status_history_degismez_u BEFORE UPDATE ON user_status_history
  BEGIN SELECT RAISE(ABORT, 'user_status_history değiştirilemez'); END;
CREATE TRIGGER user_status_history_degismez_d BEFORE DELETE ON user_status_history
  BEGIN SELECT RAISE(ABORT, 'user_status_history silinemez'); END;

CREATE TABLE outbound_messages (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  channel TEXT NOT NULL CHECK (channel IN ('SMS','EMAIL')),
  target TEXT NOT NULL,
  template TEXT NOT NULL,
  subject TEXT,
  body TEXT NOT NULL,                        -- OTP kodu ASLA düz yazılmaz
  status TEXT NOT NULL CHECK (status IN ('PENDING','SENT','FAILED')),
  provider TEXT,
  provider_response TEXT,
  attempts INTEGER NOT NULL DEFAULT 0,
  audit_ref TEXT,
  created_at TEXT NOT NULL,
  sent_at TEXT
);
CREATE INDEX outbound_messages_kullanici ON outbound_messages(user_id, created_at DESC);
CREATE INDEX outbound_messages_durum ON outbound_messages(status);
