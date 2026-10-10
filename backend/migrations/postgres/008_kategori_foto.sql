-- 008 — Admin'den yüklenen kategori fotoğrafı (nesne depolama anahtarı).
-- `photo` (uygulama paketindeki fotoğraf) DEĞİŞMEZ: sunucu fotoğrafı yoksa
-- Flutter paket fotoğrafına düşer. postgres/sqlite BİREBİR.
ALTER TABLE categories ADD COLUMN photo_ref TEXT;
