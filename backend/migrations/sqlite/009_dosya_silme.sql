-- 009 — Kullanıcı dosyalarının FİZİKSEL silinme yaşam döngüsü.
-- status (PENDING/ATTACHED/DISCARDED) DEĞİŞMEZ; DISCARDED = artık kullanılmıyor.
--   delete_requested_at : silme kuyruğuna girdiği an
--   deleted_at          : nesne depodan silindi (ya da zaten yoktu)
--   delete_attempts / delete_error : başarısız denemeler (yeniden denenir)
ALTER TABLE storage_objects ADD COLUMN delete_requested_at TEXT;
ALTER TABLE storage_objects ADD COLUMN deleted_at TEXT;
ALTER TABLE storage_objects ADD COLUMN delete_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE storage_objects ADD COLUMN delete_error TEXT;
