-- 043 — İNDİRME SINIRI ÖLÇÜMÜ (28 Eki, kullanıcı isteği)
--
-- Fotoğraf/PDF indirme sınırına takılan (429, kod DOWNLOAD_LIMIT) istekler
-- dakikalık ölçümde AYRI sayılır; Sistem Durumu'nda gösterilir. Bu istekler
-- 4xx toplamında da sayılmaya devam eder.
ALTER TABLE api_metrics ADD COLUMN download_limited INTEGER NOT NULL DEFAULT 0;
