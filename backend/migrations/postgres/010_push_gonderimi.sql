-- 010 — Uygulama içi bildirimlerin FCM ile telefona/tarayıcıya gönderimi.
--   push_status : NULL = gönderilecek · SENDING · SENT · NO_TOKEN · SKIPPED · FAILED
--   push_target : Flutter yönlendirme hedefi (ilan/is/teklif/talep/mesaj); NULL = Bildirimler
-- Göçten ÖNCEKİ bildirimler SKIPPED işaretlenir (eski kayıtlar push olarak gönderilmez).
ALTER TABLE notifications ADD COLUMN push_status TEXT;
ALTER TABLE notifications ADD COLUMN push_target TEXT;
ALTER TABLE notifications ADD COLUMN push_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE notifications ADD COLUMN push_claimed_at TIMESTAMPTZ;
UPDATE notifications SET push_status = 'SKIPPED';
