-- 001 — çekirdek şema (SQLite · yalnız geliştirme/test)
-- ⚠ Mantıksal olarak postgres/001_cekirdek.sql ile BİREBİR aynı olmalı.
CREATE TABLE admins (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    totp_secret_enc TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    failed_count INTEGER NOT NULL DEFAULT 0,
    locked_until TEXT,
    created_at TEXT NOT NULL
  );
  CREATE TABLE admin_sessions (
    token_hash TEXT PRIMARY KEY,
    admin_id TEXT NOT NULL REFERENCES admins(id),
    stage TEXT NOT NULL,                -- 'mfa' | 'full'
    created_at TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    reauth_at TEXT,
    ip TEXT,
    user_agent TEXT
  );
  CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    admin_id TEXT,
    action TEXT NOT NULL,
    target_type TEXT,
    target_id TEXT,
    before_json TEXT,
    after_json TEXT,
    reason TEXT,
    ip TEXT,
    created_at TEXT NOT NULL
  );
  CREATE TRIGGER audit_log_degismez_u BEFORE UPDATE ON audit_log
    BEGIN SELECT RAISE(ABORT, 'audit_log değiştirilemez'); END;
  CREATE TRIGGER audit_log_degismez_d BEFORE DELETE ON audit_log
    BEGIN SELECT RAISE(ABORT, 'audit_log silinemez'); END;

  CREATE TABLE categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    sort INTEGER NOT NULL,
    icon TEXT,
    photo TEXT,
    kart_disi INTEGER NOT NULL DEFAULT 0,
    deleted_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
  CREATE UNIQUE INDEX categories_ad ON categories(name) WHERE deleted_at IS NULL;
  CREATE TABLE services (
    id TEXT PRIMARY KEY,
    category_id TEXT NOT NULL REFERENCES categories(id),
    name TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    sort INTEGER NOT NULL,
    lider INTEGER NOT NULL DEFAULT 0,
    deleted_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
  CREATE UNIQUE INDEX services_ad ON services(category_id, name) WHERE deleted_at IS NULL;

  CREATE TABLE cities (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1,
    deleted_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
  );
  CREATE UNIQUE INDEX cities_ad ON cities(name) WHERE deleted_at IS NULL;
  CREATE TABLE districts (
    id TEXT PRIMARY KEY, city_id TEXT NOT NULL REFERENCES cities(id),
    name TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1,
    all_supported INTEGER NOT NULL DEFAULT 0,
    deleted_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
  );
  CREATE UNIQUE INDEX districts_ad ON districts(city_id, name) WHERE deleted_at IS NULL;
  CREATE TABLE neighborhoods (
    id TEXT PRIMARY KEY, district_id TEXT NOT NULL REFERENCES districts(id),
    name TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1, postal_code TEXT,
    deleted_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
  );
  CREATE UNIQUE INDEX neighborhoods_ad ON neighborhoods(district_id, name) WHERE deleted_at IS NULL;

  CREATE TABLE legal_documents (
    slug TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    requires_acceptance INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  );
  CREATE TABLE legal_versions (
    id TEXT PRIMARY KEY,
    slug TEXT NOT NULL REFERENCES legal_documents(slug),
    version INTEGER NOT NULL,
    body TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    effective_date TEXT NOT NULL,
    status TEXT NOT NULL,               -- DRAFT | PUBLISHED | ARCHIVED
    created_by TEXT, created_at TEXT NOT NULL,
    published_by TEXT, published_at TEXT,
    UNIQUE(slug, version)
  );
  CREATE TRIGGER legal_versions_silinmez BEFORE DELETE ON legal_versions
    BEGIN SELECT RAISE(ABORT, 'yasal sürüm silinemez; arşivlenir'); END;

  CREATE TABLE support_info (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    description TEXT NOT NULL, email TEXT NOT NULL, updated_at TEXT NOT NULL
  );
  CREATE TABLE app_config (
    platform TEXT PRIMARY KEY,          -- android | ios | web
    maintenance_active INTEGER NOT NULL DEFAULT 0,
    maintenance_message TEXT,
    maintenance_end_at TEXT,
    min_version TEXT,
    latest_version TEXT,
    updated_at TEXT NOT NULL
  );

-- Bir belgenin aynı anda EN FAZLA bir yayındaki sürümü olur.
CREATE UNIQUE INDEX legal_versions_tek_yayin ON legal_versions(slug) WHERE status = 'PUBLISHED';
