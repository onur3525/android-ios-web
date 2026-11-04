-- 052 · TİCARİ ELEKTRONİK İLETİ İZNİ (4 Kas, kullanıcı kararı)
--
-- Kayıttaki isteğe bağlı kutu "Duyurular ve kampanyalar" tercihini
-- (notif_announcement) belirler; YENİ hesaplarda işaretlenmezse kapalıdır.
-- İznin ne zaman ve nereden verildiği / geri alındığı ispat için tutulur.
--   users.marketing_consent_at — iznin son değiştiği an
--   marketing_consents         — her değişiklik (kayıt, ayarlar)
-- Mevcut hesapların tercihleri DEĞİŞMEZ. Geri dönüş: scripts/geri_al_052.sql
ALTER TABLE users ADD COLUMN marketing_consent_at TIMESTAMPTZ;
CREATE TABLE marketing_consents (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  granted BOOLEAN NOT NULL,
  source TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX marketing_consents_kullanici ON marketing_consents(user_id, created_at DESC);
