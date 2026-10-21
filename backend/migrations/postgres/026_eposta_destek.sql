-- 026 — DESTEK E-POSTALARI GELEN TALEPLER'E (21 Eki). sqlite/026 ile BİREBİR.
-- destek@ adresine gelen e-posta (Resend Receiving → webhook) bir destek
-- talebi açar; aynı talebe yazılan yanıt e-postası talebe eklenir.
--   · user_id artık boş olabilir: göndereni kayıtlı kullanıcı olmayan e-posta.
--   · source: APP (uygulamadan, eski) | EMAIL (destek e-postasından).
--   · sender_email / sender_name: e-postanın göndereni (yanıt buraya gider).
--   · inbound_email_id: Resend kimliği — webhook tekrarı İKİNCİ kayıt açmaz.
--   · Yanıtlar: author ADMIN | USER; kullanıcının e-postayla yanıtı admin_id'siz.
-- İki tablo SQLite ile aynı biçimde yeniden kurulur (eski tablolar kenara
-- alınır, veri taşınır, eskiler silinir); bütün göç tek işlemdir.
ALTER TABLE support_ticket_replies RENAME TO support_ticket_replies__eski;
ALTER TABLE support_tickets RENAME TO support_tickets__eski;
ALTER INDEX support_tickets_pkey RENAME TO support_tickets__eski_pkey;
ALTER INDEX support_tickets_ticket_no_key RENAME TO support_tickets__eski_ticket_no_key;
ALTER INDEX support_ticket_replies_pkey RENAME TO support_ticket_replies__eski_pkey;
DROP INDEX support_tickets_kullanici;
DROP INDEX support_tickets_durum;
DROP INDEX support_tickets_idem;
DROP INDEX support_ticket_replies_talep;

CREATE TABLE support_tickets (
  id UUID PRIMARY KEY,
  ticket_no TEXT NOT NULL UNIQUE,
  user_id UUID REFERENCES users(id),
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('OPEN','ANSWERED','CLOSED')),
  platform TEXT CHECK (platform IN ('android','ios','web')),
  app_version TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  closed_at TIMESTAMPTZ,
  closed_by UUID,
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
  id UUID PRIMARY KEY,
  ticket_id UUID NOT NULL REFERENCES support_tickets(id),
  admin_id UUID REFERENCES admins(id),
  body TEXT NOT NULL,
  outbound_id UUID,
  created_at TIMESTAMPTZ NOT NULL,
  author TEXT NOT NULL DEFAULT 'ADMIN' CHECK (author IN ('ADMIN','USER')),
  inbound_email_id TEXT
);
INSERT INTO support_ticket_replies (id, ticket_id, admin_id, body, outbound_id, created_at)
  SELECT id, ticket_id, admin_id, body, outbound_id, created_at FROM support_ticket_replies__eski;

DROP TABLE support_ticket_replies__eski;
DROP TABLE support_tickets__eski;

CREATE INDEX support_tickets_kullanici ON support_tickets(user_id, created_at DESC);
CREATE INDEX support_tickets_durum ON support_tickets(status, created_at DESC);
CREATE UNIQUE INDEX support_tickets_idem ON support_tickets(user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX support_tickets_gelen ON support_tickets(inbound_email_id) WHERE inbound_email_id IS NOT NULL;
CREATE INDEX support_tickets_gonderen ON support_tickets(lower(sender_email), created_at DESC) WHERE sender_email IS NOT NULL;
CREATE INDEX support_ticket_replies_talep ON support_ticket_replies(ticket_id, created_at);
CREATE UNIQUE INDEX support_ticket_replies_gelen ON support_ticket_replies(inbound_email_id) WHERE inbound_email_id IS NOT NULL;
