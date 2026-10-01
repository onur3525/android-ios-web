-- 003 — ilan, teklif, iletişim, değerlendirme, uygulama içi bildirim,
--        duyuru, uygulama geri bildirimi, sayaçlar. sqlite/003 ile BİREBİR.

CREATE TABLE counters (
  name TEXT PRIMARY KEY,
  value BIGINT NOT NULL
);
-- İlan numarası 10458231'den ARTAR (Flutter ile aynı başlangıç);
-- silinen numara yeniden verilmez.
INSERT INTO counters (name, value) VALUES ('ilan_no', 10458230);

CREATE TABLE listings (
  id UUID PRIMARY KEY,
  ilan_no TEXT NOT NULL UNIQUE,
  owner_id UUID NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,                       -- seçilen hizmet adı (Flutter ile aynı)
  location TEXT NOT NULL,
  description TEXT NOT NULL,
  photo_refs_json TEXT NOT NULL,
  work_timing TEXT CHECK (work_timing IN ('NOW','THIS_WEEK','FLEXIBLE')),
  status TEXT NOT NULL CHECK (status IN ('ACTIVE','EXPIRED','USER_DELETED','ADMIN_REMOVED')),
  selected_offer_id UUID,
  delete_reason TEXT,
  removed_reason TEXT,
  removed_by UUID,
  removed_at TIMESTAMPTZ,
  expiry_notified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX listings_sahip ON listings(owner_id, created_at DESC);
CREATE INDEX listings_acik ON listings(status, expires_at);

CREATE TABLE offers (
  id UUID PRIMARY KEY,
  listing_id UUID NOT NULL REFERENCES listings(id),
  provider_id UUID NOT NULL REFERENCES users(id),
  amount_tl INTEGER NOT NULL CHECK (amount_tl > 0),
  note TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE','SELECTED','EXPIRED','CLOSED')),
  idempotency_key TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  UNIQUE (listing_id, provider_id)
);
CREATE INDEX offers_saglayici ON offers(provider_id, created_at DESC);

CREATE TABLE contacts (
  offer_id UUID PRIMARY KEY REFERENCES offers(id),
  opened_by UUID NOT NULL REFERENCES users(id),
  opened_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE reviews (
  id UUID PRIMARY KEY,
  listing_id UUID REFERENCES listings(id),
  offer_id UUID UNIQUE REFERENCES offers(id),
  talep_id UUID UNIQUE,
  provider_id UUID NOT NULL REFERENCES users(id),
  author_id UUID NOT NULL REFERENCES users(id),
  stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  text TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('PUBLISHED','ADMIN_DELETED')),
  removed_reason TEXT,
  removed_by UUID,
  removed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  published_at TIMESTAMPTZ
);
CREATE INDEX reviews_saglayici ON reviews(provider_id, created_at DESC);

CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  ref_id TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  read_at TIMESTAMPTZ
);
CREATE INDEX notifications_kullanici ON notifications(user_id, created_at DESC);

CREATE TABLE announcements (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  target TEXT NOT NULL CHECK (target IN ('ALL','CUSTOMER','PROVIDER')),
  recipient_count INTEGER NOT NULL,
  admin_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE app_feedback (
  user_id UUID PRIMARY KEY REFERENCES users(id),
  stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment TEXT,
  platform TEXT NOT NULL,
  app_version TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
