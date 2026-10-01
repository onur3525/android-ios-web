-- 004 — ilan sohbeti, teklif talebi + mesajları, hesap talepleri
--        (dondurma/silme), yasal belge kabulleri. postgres/004 ile BİREBİR (SQLite · yalnız geliştirme/test).

CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  offer_id TEXT NOT NULL REFERENCES offers(id),
  sender_id TEXT NOT NULL REFERENCES users(id),
  text TEXT,
  storage_ref TEXT,
  idempotency_key TEXT,
  created_at TEXT NOT NULL,
  read_at TEXT
);
CREATE INDEX messages_teklif ON messages(offer_id, created_at);
CREATE UNIQUE INDEX messages_idem ON messages(sender_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

CREATE TABLE teklif_talepleri (
  id TEXT PRIMARY KEY,
  talep_no TEXT NOT NULL UNIQUE,
  hizmet_alan_id TEXT NOT NULL REFERENCES users(id),
  saglayici_id TEXT NOT NULL REFERENCES users(id),
  kategori TEXT NOT NULL,
  hizmet TEXT NOT NULL,
  aciklama TEXT NOT NULL,
  fotograflar_json TEXT NOT NULL,
  iletisim_tercihi TEXT NOT NULL,
  is_zamani TEXT CHECK (is_zamani IN ('NOW','THIS_WEEK','FLEXIBLE')),
  durum TEXT NOT NULL CHECK (durum IN ('BEKLEMEDE','TEKLIF_GELDI','SECILDI','REDDEDILDI','SURESI_DOLDU','TAMAMLANDI')),
  teklif_fiyati INTEGER,
  teklif_aciklamasi TEXT,
  teklif_tarihi TEXT,
  red_gerekcesi TEXT,
  reddeden_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX teklif_talepleri_alan ON teklif_talepleri(hizmet_alan_id, created_at DESC);
CREATE INDEX teklif_talepleri_saglayici ON teklif_talepleri(saglayici_id, created_at DESC);
INSERT INTO counters (name, value) VALUES ('talep_no', 20458230);

CREATE TABLE teklif_mesajlari (
  id TEXT PRIMARY KEY,
  talep_id TEXT NOT NULL REFERENCES teklif_talepleri(id),
  gonderen_id TEXT NOT NULL REFERENCES users(id),
  metin TEXT,
  fotograf_ref TEXT,
  created_at TEXT NOT NULL,
  read_at TEXT
);
CREATE INDEX teklif_mesajlari_talep ON teklif_mesajlari(talep_id, created_at);

CREATE TABLE account_requests (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  type TEXT NOT NULL CHECK (type IN ('FREEZE','DELETION')),
  status TEXT NOT NULL CHECK (status IN ('PENDING','COMPLETED','CANCELLED')),
  reason TEXT,
  created_at TEXT NOT NULL,
  scheduled_for TEXT,
  completed_at TEXT
);
CREATE INDEX account_requests_kullanici ON account_requests(user_id, created_at DESC);

CREATE TABLE legal_acceptances (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  slug TEXT NOT NULL REFERENCES legal_documents(slug),
  version_id TEXT NOT NULL REFERENCES legal_versions(id),
  version INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  platform TEXT,
  accepted_at TEXT NOT NULL,
  UNIQUE (user_id, version_id)
);
CREATE TRIGGER legal_acceptances_degismez_u BEFORE UPDATE ON legal_acceptances
  BEGIN SELECT RAISE(ABORT, 'legal_acceptances değiştirilemez'); END;
CREATE TRIGGER legal_acceptances_degismez_d BEFORE DELETE ON legal_acceptances
  BEGIN SELECT RAISE(ABORT, 'legal_acceptances silinemez'); END;
