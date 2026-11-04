-- 052 GERİ DÖNÜŞ (PostgreSQL ve SQLite ≥ 3.35 aynı). Önce yedek alın (yedek_al.sh).
-- ⚠ İzin geçmişi (marketing_consents) silinir; ticari ileti gönderiyorsanız
-- izinlerin ispatı için önce dışa aktarın.
DROP TABLE marketing_consents;
ALTER TABLE users DROP COLUMN marketing_consent_at;
DELETE FROM schema_migrations WHERE id = '052_ticari_ileti_izni';
