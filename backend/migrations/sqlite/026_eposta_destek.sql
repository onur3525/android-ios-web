-- 026 — DESTEK E-POSTALARI GELEN TALEPLER'E (21 Eki). postgres/026 ile AYNI mantık
-- (SQLite · yalnız geliştirme/test). SQLite NOT NULL kaldıramadığı için iki
-- tablo yeniden kurulur. Eski tablolar önce kenara alınır (legacy_alter_table:
-- bağlı tablolardaki başvurular yeniden yazılmaz), yeni tablolar asıl adlarla
-- kurulup veri taşınır, eskiler silinir.
PRAGMA legacy_alter_table = ON;
ALTER TABLE support_ticket_replies RENAME TO support_ticket_replies__eski;
ALTER TABLE support_tickets RENAME TO support_tickets__eski;

CREATE TABLE support_tickets (
  id TEXT PRIMARY KEY,
  ticket_no TEXT NOT NULL UNIQUE,
  user_id TEXT REFERENCES users(id),
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('OPEN','ANSWERED','CLOSED')),
  platform TEXT CHECK (platform IN ('android','ios','web')),
  app_version TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  closed_at TEXT,
  closed_by TEXT,
  idempotency_key TEXT,
  idem_hash TEXT,
  source TEXT NOT NULL DEFAULT 'APP' CHECK (source IN ('APP','EMAIL')),
  sender_email TEXT,
  sender_name TEXT,
  inbound_email_id TEXT
);
INSERT INTO support_tickets (id, ticket_no, user_id, subject, message, status, platform, app_version, created_at, updated_at, closed_at, closed_by, idempotency_key, idem_hash)
  SELECT id, ticket_no, user_id, subject, message, status, platform, app_version, created_at, updated_at, closed_at, closed_by, idempotency_key, idem_hash FROM support_tickets__eski;

CREATE TABLE support_ticket_replies (
  id TEXT PRIMARY KEY,
  ticket_id TEXT NOT NULL REFERENCES support_tickets(id),
  admin_id TEXT REFERENCES admins(id),
  body TEXT NOT NULL,
  outbound_id TEXT,
  created_at TEXT NOT NULL,
  author TEXT NOT NULL DEFAULT 'ADMIN' CHECK (author IN ('ADMIN','USER')),
  inbound_email_id TEXT
);
INSERT INTO support_ticket_replies (id, ticket_id, admin_id, body, outbound_id, created_at)
  SELECT id, ticket_id, admin_id, body, outbound_id, created_at FROM support_ticket_replies__eski;

DROP TABLE support_ticket_replies__eski;
DROP TABLE support_tickets__eski;
PRAGMA legacy_alter_table = OFF;

CREATE INDEX support_tickets_kullanici ON support_tickets(user_id, created_at DESC);
CREATE INDEX support_tickets_durum ON support_tickets(status, created_at DESC);
CREATE UNIQUE INDEX support_tickets_idem ON support_tickets(user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX support_tickets_gelen ON support_tickets(inbound_email_id) WHERE inbound_email_id IS NOT NULL;
CREATE INDEX support_tickets_gonderen ON support_tickets(lower(sender_email), created_at DESC) WHERE sender_email IS NOT NULL;
CREATE INDEX support_ticket_replies_talep ON support_ticket_replies(ticket_id, created_at);
CREATE UNIQUE INDEX support_ticket_replies_gelen ON support_ticket_replies(inbound_email_id) WHERE inbound_email_id IS NOT NULL;
