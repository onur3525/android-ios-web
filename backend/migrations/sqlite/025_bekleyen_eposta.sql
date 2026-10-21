-- 025 — (postgres/025 ile aynı kural) Bekleyen e-posta değişikliği (21 Eki güvenlik düzeltmesi Y2).
-- E-posta değişikliği yalnız sunucunun ŞİFRE doğrulamasıyla başlattığı
-- isteğe karşılık işlenir: Firebase'de doğrulanmış yeni adres, burada
-- bekleyen adresle aynıysa ve istek süresi dolmamışsa hesaba yazılır.
-- Kişisel veridir; hesap silmede temizlenir.
ALTER TABLE users ADD COLUMN pending_email TEXT;
ALTER TABLE users ADD COLUMN pending_email_at TEXT;
