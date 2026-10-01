-- 001 — çekirdek şema (PostgreSQL · CANLI)
-- ⚠ Mantıksal olarak sqlite/001_cekirdek.sql ile BİREBİR aynı olmalı
--   (tablo/sütun adları, kısıtlar, benzersizlik kuralları).
-- Tür eşlemesi: kimlik UUID · zaman TIMESTAMPTZ · tarih DATE ·
--   bayrak BOOLEAN · sayaç BIGINT IDENTITY · gövde TEXT.

CREATE TABLE admins (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('super_admin','moderator','content','operations','readonly')),
  password_hash TEXT NOT NULL,
  totp_secret_enc TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  failed_count INTEGER NOT NULL DEFAULT 0,
  locked_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE admin_sessions (
  token_hash TEXT PRIMARY KEY,
  admin_id UUID NOT NULL REFERENCES admins(id),
  stage TEXT NOT NULL CHECK (stage IN ('mfa','full')),
  created_at TIMESTAMPTZ NOT NULL,
  last_seen TIMESTAMPTZ NOT NULL,
  reauth_at TIMESTAMPTZ,
  ip TEXT,
  user_agent TEXT
);
CREATE INDEX admin_sessions_admin ON admin_sessions(admin_id);

CREATE TABLE audit_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  admin_id UUID,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  before_json JSONB,
  after_json JSONB,
  reason TEXT,
  ip TEXT,
  created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX audit_log_hedef ON audit_log(target_type, target_id);
CREATE INDEX audit_log_admin ON audit_log(admin_id, created_at DESC);

-- Denetim kaydı yalnız eklenir.
CREATE FUNCTION hc_degistirilemez() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% değiştirilemez/silinemez', TG_TABLE_NAME;
END $$;
CREATE TRIGGER audit_log_degismez BEFORE UPDATE OR DELETE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION hc_degistirilemez();

CREATE TABLE categories (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  sort INTEGER NOT NULL,
  icon TEXT,
  photo TEXT,
  kart_disi BOOLEAN NOT NULL DEFAULT FALSE,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
CREATE UNIQUE INDEX categories_ad ON categories(name) WHERE deleted_at IS NULL;

CREATE TABLE services (
  id UUID PRIMARY KEY,
  category_id UUID NOT NULL REFERENCES categories(id),
  name TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  sort INTEGER NOT NULL,
  lider BOOLEAN NOT NULL DEFAULT FALSE,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
CREATE UNIQUE INDEX services_ad ON services(category_id, name) WHERE deleted_at IS NULL;
CREATE INDEX services_kategori ON services(category_id) WHERE deleted_at IS NULL;

CREATE TABLE cities (
  id UUID PRIMARY KEY, name TEXT NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE,
  deleted_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL, updated_at TIMESTAMPTZ NOT NULL
);
CREATE UNIQUE INDEX cities_ad ON cities(name) WHERE deleted_at IS NULL;

CREATE TABLE districts (
  id UUID PRIMARY KEY, city_id UUID NOT NULL REFERENCES cities(id),
  name TEXT NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE,
  all_supported BOOLEAN NOT NULL DEFAULT FALSE,
  deleted_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL, updated_at TIMESTAMPTZ NOT NULL
);
CREATE UNIQUE INDEX districts_ad ON districts(city_id, name) WHERE deleted_at IS NULL;

CREATE TABLE neighborhoods (
  id UUID PRIMARY KEY, district_id UUID NOT NULL REFERENCES districts(id),
  name TEXT NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE, postal_code TEXT,
  deleted_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL, updated_at TIMESTAMPTZ NOT NULL
);
CREATE UNIQUE INDEX neighborhoods_ad ON neighborhoods(district_id, name) WHERE deleted_at IS NULL;

CREATE TABLE legal_documents (
  slug TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  requires_acceptance BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE legal_versions (
  id UUID PRIMARY KEY,
  slug TEXT NOT NULL REFERENCES legal_documents(slug),
  version INTEGER NOT NULL,
  body TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  effective_date DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED')),
  created_by UUID, created_at TIMESTAMPTZ NOT NULL,
  published_by UUID, published_at TIMESTAMPTZ,
  UNIQUE (slug, version)
);
-- Bir belgenin aynı anda EN FAZLA bir yayındaki sürümü olur.
CREATE UNIQUE INDEX legal_versions_tek_yayin ON legal_versions(slug) WHERE status = 'PUBLISHED';
CREATE TRIGGER legal_versions_silinmez BEFORE DELETE ON legal_versions
  FOR EACH ROW EXECUTE FUNCTION hc_degistirilemez();

CREATE TABLE support_info (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  description TEXT NOT NULL, email TEXT NOT NULL, updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE app_config (
  platform TEXT PRIMARY KEY CHECK (platform IN ('android','ios','web')),
  maintenance_active BOOLEAN NOT NULL DEFAULT FALSE,
  maintenance_message TEXT,
  maintenance_end_at TIMESTAMPTZ,
  min_version TEXT,
  latest_version TEXT,
  updated_at TIMESTAMPTZ NOT NULL
);
