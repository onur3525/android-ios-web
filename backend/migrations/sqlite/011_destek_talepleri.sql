-- 011 — GELEN TALEPLER (destek talepleri). postgres/011 ile BİREBİR (SQLite · yalnız geliştirme/test).
-- Kullanıcının uygulamadan destek ekibine gönderdiği gerçek talepler ve
-- admin yanıtları. Hesap dondurma/silme talepleri (account_requests) AYRIDIR,
-- bu tabloya girmez. Yanıt e-postası mevcut bildirim altyapısıyla gider
-- (outbound_messages; outbound_id ile bağlanır).
CREATE TABLE support_tickets (
  id TEXT PRIMARY KEY,
  ticket_no TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL REFERENCES users(id),
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('OPEN','ANSWERED','CLOSED')),
  platform TEXT CHECK (platform IN ('android','ios','web')),
  app_version TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  closed_at TEXT,
  closed_by TEXT,
  idempotency_key TEXT
);
CREATE INDEX support_tickets_kullanici ON support_tickets(user_id, created_at DESC);
CREATE INDEX support_tickets_durum ON support_tickets(status, created_at DESC);
-- Ağ kesintisinde istemcinin yeniden denemesi İKİNCİ talep oluşturmaz.
CREATE UNIQUE INDEX support_tickets_idem ON support_tickets(user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

CREATE TABLE support_ticket_replies (
  id TEXT PRIMARY KEY,
  ticket_id TEXT NOT NULL REFERENCES support_tickets(id),
  admin_id TEXT NOT NULL REFERENCES admins(id),
  body TEXT NOT NULL,
  outbound_id TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX support_ticket_replies_talep ON support_ticket_replies(ticket_id, created_at);

-- Kullanıcıya gösterilen talep numarası (ilan/teklif talebi sayaçlarından ayrı aralık).
INSERT INTO counters (name, value) VALUES ('destek_no', 30458230);
