-- 030 — YÖNETİCİ SİLME (22 Eki). postgres/030 ile AYNI mantık (SQLite · yalnız geliştirme/test).
ALTER TABLE admins ADD COLUMN deleted_at TEXT;
