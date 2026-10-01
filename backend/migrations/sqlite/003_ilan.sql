-- 003 — ilan, teklif, iletişim, değerlendirme, uygulama içi bildirim,
--        duyuru, uygulama geri bildirimi, sayaçlar. postgres/003 ile BİREBİR (SQLite · yalnız geliştirme/test).

CREATE TABLE counters (
  name TEXT PRIMARY KEY,
  value INTEGER NOT NULL
);
-- İlan numarası 10458231'den ARTAR (Flutter ile aynı başlangıç);
-- silinen numara yeniden verilmez.
INSERT INTO counters (name, value) VALUES ('ilan_no', 10458230);

CREATE TABLE listings (
  id TEXT PRIMARY KEY,
  ilan_no TEXT NOT NULL UNIQUE,
  owner_id TEXT NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,                       -- seçilen hizmet adı (Flutter ile aynı)
  location TEXT NOT NULL,
  description TEXT NOT NULL,
  photo_refs_json TEXT NOT NULL,
  work_timing TEXT CHECK (work_timing IN ('NOW','THIS_WEEK','FLEXIBLE')),
  status TEXT NOT NULL CHECK (status IN ('ACTIVE','EXPIRED','USER_DELETED','ADMIN_REMOVED')),
  selected_offer_id TEXT,
  delete_reason TEXT,
  removed_reason TEXT,
  removed_by TEXT,
  removed_at TEXT,
  expiry_notified INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX listings_sahip ON listings(owner_id, created_at DESC);
CREATE INDEX listings_acik ON listings(status, expires_at);

CREATE TABLE offers (
  id TEXT PRIMARY KEY,
  listing_id TEXT NOT NULL REFERENCES listings(id),
  provider_id TEXT NOT NULL REFERENCES users(id),
  amount_tl INTEGER NOT NULL CHECK (amount_tl > 0),
  note TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE','SELECTED','EXPIRED','CLOSED')),
  idempotency_key TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (listing_id, provider_id)
);
CREATE INDEX offers_saglayici ON offers(provider_id, created_at DESC);

CREATE TABLE contacts (
  offer_id TEXT PRIMARY KEY REFERENCES offers(id),
  opened_by TEXT NOT NULL REFERENCES users(id),
  opened_at TEXT NOT NULL
);

CREATE TABLE reviews (
  id TEXT PRIMARY KEY,
  listing_id TEXT REFERENCES listings(id),
  offer_id TEXT UNIQUE REFERENCES offers(id),
  talep_id TEXT UNIQUE,
  provider_id TEXT NOT NULL REFERENCES users(id),
  author_id TEXT NOT NULL REFERENCES users(id),
  stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  text TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('PUBLISHED','ADMIN_DELETED')),
  removed_reason TEXT,
  removed_by TEXT,
  removed_at TEXT,
  created_at TEXT NOT NULL,
  published_at TEXT
);
CREATE INDEX reviews_saglayici ON reviews(provider_id, created_at DESC);

CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  ref_id TEXT,
  created_at TEXT NOT NULL,
  read_at TEXT
);
CREATE INDEX notifications_kullanici ON notifications(user_id, created_at DESC);

CREATE TABLE announcements (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  target TEXT NOT NULL CHECK (target IN ('ALL','CUSTOMER','PROVIDER')),
  recipient_count INTEGER NOT NULL,
  admin_id TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE app_feedback (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment TEXT,
  platform TEXT NOT NULL,
  app_version TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
