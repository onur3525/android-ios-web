-- 037 — DOSYA DEPOLAMA OTOMATİK KONTROLÜ (23 Eki, kullanıcı isteği:
-- "otomatik yapsın", 15 dakikada bir).
--
-- storage_monitor: sunucunun depolamaya (S3/R2) 15 dakikada bir yaptığı
--   erişim kontrolünün SON sonucu (tek satır). Kontrol depoya YAZMAZ:
--   olmayan bir nesne imzalı GET ile istenir; "NoSuchKey" yanıtı anahtarın
--   ve klasörün geçerli olduğunu kanıtlar. Adres, anahtar ve imza
--   SAKLANMAZ; yalnız zaman, sonuç ve kısa sonuç metni tutulur.
CREATE TABLE storage_monitor (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  checked_at TIMESTAMPTZ NOT NULL,
  check_ok BOOLEAN NOT NULL,
  check_message TEXT NOT NULL
);
