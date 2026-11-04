-- 049 GERİ DÖNÜŞ (PostgreSQL ve SQLite aynı). Önce yedek alın (yedek_al.sh).
-- ⚠ Telefonu boş ('') hesap varsa eski dizin kurulamaz; önce sayın:
--   SELECT COUNT(*) FROM users WHERE phone = '' AND deleted_at IS NULL;
-- Sonuç 0 değilse bu betiği ÇALIŞTIRMAYIN.
DROP INDEX users_telefon;
CREATE UNIQUE INDEX users_telefon ON users(phone) WHERE deleted_at IS NULL;
DELETE FROM schema_migrations WHERE id = '049_telefon_sahipligi';
