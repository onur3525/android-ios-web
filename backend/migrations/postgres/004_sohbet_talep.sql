-- 004 — ilan sohbeti, teklif talebi + mesajları, hesap talepleri
--        (dondurma/silme), yasal belge kabulleri. sqlite/004 ile BİREBİR.

CREATE TABLE messages (
  id UUID PRIMARY KEY,
  offer_id UUID NOT NULL REFERENCES offers(id),
  sender_id UUID NOT NULL REFERENCES users(id),
  text TEXT,
  storage_ref TEXT,
  idempotency_key TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  read_at TIMESTAMPTZ
);
CREATE INDEX messages_teklif ON messages(offer_id, created_at);
CREATE UNIQUE INDEX messages_idem ON messages(sender_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

CREATE TABLE teklif_talepleri (
  id UUID PRIMARY KEY,
  talep_no TEXT NOT NULL UNIQUE,
  hizmet_alan_id UUID NOT NULL REFERENCES users(id),
  saglayici_id UUID NOT NULL REFERENCES users(id),
  kategori TEXT NOT NULL,
  hizmet TEXT NOT NULL,
  aciklama TEXT NOT NULL,
  fotograflar_json TEXT NOT NULL,
  iletisim_tercihi TEXT NOT NULL,
  is_zamani TEXT CHECK (is_zamani IN ('NOW','THIS_WEEK','FLEXIBLE')),
  durum TEXT NOT NULL CHECK (durum IN ('BEKLEMEDE','TEKLIF_GELDI','SECILDI','REDDEDILDI','SURESI_DOLDU','TAMAMLANDI')),
  teklif_fiyati INTEGER,
  teklif_aciklamasi TEXT,
  teklif_tarihi TIMESTAMPTZ,
  red_gerekcesi TEXT,
  reddeden_id UUID,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX teklif_talepleri_alan ON teklif_talepleri(hizmet_alan_id, created_at DESC);
CREATE INDEX teklif_talepleri_saglayici ON teklif_talepleri(saglayici_id, created_at DESC);
INSERT INTO counters (name, value) VALUES ('talep_no', 20458230);

CREATE TABLE teklif_mesajlari (
  id UUID PRIMARY KEY,
  talep_id UUID NOT NULL REFERENCES teklif_talepleri(id),
  gonderen_id UUID NOT NULL REFERENCES users(id),
  metin TEXT,
  fotograf_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  read_at TIMESTAMPTZ
);
CREATE INDEX teklif_mesajlari_talep ON teklif_mesajlari(talep_id, created_at);

CREATE TABLE account_requests (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  type TEXT NOT NULL CHECK (type IN ('FREEZE','DELETION')),
  status TEXT NOT NULL CHECK (status IN ('PENDING','COMPLETED','CANCELLED')),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  scheduled_for TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);
CREATE INDEX account_requests_kullanici ON account_requests(user_id, created_at DESC);

CREATE TABLE legal_acceptances (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  slug TEXT NOT NULL REFERENCES legal_documents(slug),
  version_id UUID NOT NULL REFERENCES legal_versions(id),
  version INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  platform TEXT,
  accepted_at TIMESTAMPTZ NOT NULL,
  UNIQUE (user_id, version_id)
);
CREATE TRIGGER legal_acceptances_degismez BEFORE UPDATE OR DELETE ON legal_acceptances
  FOR EACH ROW EXECUTE FUNCTION hc_degistirilemez();
