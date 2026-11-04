-- 051 · GOOGLE / APPLE İLE GİRİŞ (4 Kas, kullanıcı talebi)
--
-- password_set    — hesabın kullanıcının belirlediği bir şifresi var mı.
--                   Google/Apple ile açılan hesapta FALSE: kritik işlemlerde
--                   şifre yerine aynı sağlayıcıyla YENİ giriş (taze Firebase
--                   belgesi) istenir. Şifre sonradan belirlenirse TRUE olur.
-- social_provider — hesabın açıldığı sağlayıcı ('google.com' | 'apple.com');
--                   şifreyle açılan hesaplarda NULL.
--
-- Mevcut hesapların hepsi şifreyle açıldı: varsayılan TRUE / NULL, veri
-- değişmez. Geri dönüş: scripts/geri_al_051.sql
ALTER TABLE users ADD COLUMN password_set BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN social_provider TEXT;
