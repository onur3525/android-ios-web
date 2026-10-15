-- 018 — Firebase oturum iptali, dosya silme aralığı, denetim kaydı anonimleştirme
-- (15 Eki güvenlik denetimi). postgres/018 ile BİREBİR.
--
-- users.firebase_valid_since : bu andan (Unix saniye) ÖNCE kimlik doğrulaması
--   yapılmış Firebase belgeleriyle yeni sunucu oturumu açılmaz (Firebase
--   Admin SDK'nın tokensValidAfterTime / validSince kuralının yerel kopyası).
-- storage_objects.delete_next_at : başarısız dosya silmesinin bir sonraki
--   deneme zamanı (artan aralık; NULL = hemen).
-- audit_log / user_status_history .anonymized_at : hesap silinince kişisel
--   değerlerin maskelendiği zaman. Kayıtlar yine SİLİNEMEZ; güncelleme YALNIZ
--   tek seferlik anonimleştirmeye izin verir — kim, ne zaman, hangi işlem,
--   hangi hedef alanları değişemez.
ALTER TABLE users ADD COLUMN firebase_valid_since INTEGER;
ALTER TABLE storage_objects ADD COLUMN delete_next_at TEXT;
ALTER TABLE audit_log ADD COLUMN anonymized_at TEXT;
ALTER TABLE user_status_history ADD COLUMN anonymized_at TEXT;

DROP TRIGGER audit_log_degismez_u;
CREATE TRIGGER audit_log_degismez_u BEFORE UPDATE ON audit_log
  WHEN NOT (OLD.anonymized_at IS NULL AND NEW.anonymized_at IS NOT NULL
            AND NEW.id = OLD.id AND NEW.admin_id IS OLD.admin_id AND NEW.action = OLD.action
            AND NEW.target_type IS OLD.target_type AND NEW.target_id IS OLD.target_id
            AND NEW.ip IS OLD.ip AND NEW.created_at = OLD.created_at)
  BEGIN SELECT RAISE(ABORT, 'audit_log değiştirilemez'); END;

DROP TRIGGER user_status_history_degismez_u;
CREATE TRIGGER user_status_history_degismez_u BEFORE UPDATE ON user_status_history
  WHEN NOT (OLD.anonymized_at IS NULL AND NEW.anonymized_at IS NOT NULL
            AND NEW.id = OLD.id AND NEW.user_id = OLD.user_id AND NEW.old_status = OLD.old_status
            AND NEW.new_status = OLD.new_status AND NEW.admin_id IS OLD.admin_id
            AND NEW.created_at = OLD.created_at)
  BEGIN SELECT RAISE(ABORT, 'user_status_history değiştirilemez'); END;
