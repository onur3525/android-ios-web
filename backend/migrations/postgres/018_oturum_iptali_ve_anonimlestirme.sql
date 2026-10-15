-- 018 — Firebase oturum iptali, dosya silme aralığı, denetim kaydı anonimleştirme
-- (15 Eki güvenlik denetimi). sqlite/018 ile BİREBİR.
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
ALTER TABLE users ADD COLUMN firebase_valid_since BIGINT;
ALTER TABLE storage_objects ADD COLUMN delete_next_at TIMESTAMPTZ;
ALTER TABLE audit_log ADD COLUMN anonymized_at TIMESTAMPTZ;
ALTER TABLE user_status_history ADD COLUMN anonymized_at TIMESTAMPTZ;

CREATE FUNCTION hc_denetim_anonimlestir() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.anonymized_at IS NULL AND NEW.anonymized_at IS NOT NULL
     AND NEW.id = OLD.id AND NEW.admin_id IS NOT DISTINCT FROM OLD.admin_id AND NEW.action = OLD.action
     AND NEW.target_type IS NOT DISTINCT FROM OLD.target_type AND NEW.target_id IS NOT DISTINCT FROM OLD.target_id
     AND NEW.ip IS NOT DISTINCT FROM OLD.ip AND NEW.created_at = OLD.created_at THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION '% değiştirilemez/silinemez', TG_TABLE_NAME;
END $$;
DROP TRIGGER audit_log_degismez ON audit_log;
CREATE TRIGGER audit_log_degismez BEFORE DELETE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION hc_degistirilemez();
CREATE TRIGGER audit_log_anonimlestirme BEFORE UPDATE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION hc_denetim_anonimlestir();

CREATE FUNCTION hc_durum_gecmisi_anonimlestir() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.anonymized_at IS NULL AND NEW.anonymized_at IS NOT NULL
     AND NEW.id = OLD.id AND NEW.user_id = OLD.user_id AND NEW.old_status = OLD.old_status
     AND NEW.new_status = OLD.new_status AND NEW.admin_id IS NOT DISTINCT FROM OLD.admin_id
     AND NEW.created_at = OLD.created_at THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION '% değiştirilemez/silinemez', TG_TABLE_NAME;
END $$;
DROP TRIGGER user_status_history_degismez ON user_status_history;
CREATE TRIGGER user_status_history_degismez BEFORE DELETE ON user_status_history
  FOR EACH ROW EXECUTE FUNCTION hc_degistirilemez();
CREATE TRIGGER user_status_history_anonimlestirme BEFORE UPDATE ON user_status_history
  FOR EACH ROW EXECUTE FUNCTION hc_durum_gecmisi_anonimlestir();
