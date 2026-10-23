-- 039 — E-POSTA OTOMATİK KONTROLÜ (23 Eki, kullanıcı isteği: "otomatik
-- olarak tüm sistem verileri almalı, test et dememize gerek kalmamalı").
--
-- email_monitor: sunucunun e-posta sağlayıcısına (Resend) 15 dakikada bir
--   yaptığı kontrolün SON sonucu (tek satır). Kontrol e-posta GÖNDERMEZ:
--   API anahtarıyla alan adı listesi okunur; gönderen alan adının
--   "verified" olması kanıttır. Anahtar SAKLANMAZ (zaten şifreli
--   entegrasyonda); yalnız zaman, sonuç ve kısa sonuç metni tutulur.
CREATE TABLE email_monitor (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  checked_at TIMESTAMPTZ NOT NULL,
  check_ok BOOLEAN NOT NULL,
  check_message TEXT NOT NULL
);
