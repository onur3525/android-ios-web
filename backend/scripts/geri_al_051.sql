-- 051 GERİ DÖNÜŞ (PostgreSQL ve SQLite ≥ 3.35 aynı). Önce yedek alın (yedek_al.sh).
-- ⚠ Google/Apple ile açılmış hesap varsa bu hesapların şifresi YOKTUR; geri
-- dönüşten sonra yalnız "Şifremi Unuttum" ile girebilirler. Önce sayın:
--   SELECT COUNT(*) FROM users WHERE password_set = FALSE AND deleted_at IS NULL;
ALTER TABLE users DROP COLUMN social_provider;
ALTER TABLE users DROP COLUMN password_set;
DELETE FROM schema_migrations WHERE id = '051_sosyal_giris';
