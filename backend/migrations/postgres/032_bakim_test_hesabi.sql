-- 032 — BAKIMDA TEST HESABI (22 Eki, kullanıcı kararı). Admin'in seçtiği
-- kullanıcı hesapları bakım modunda, YALNIZ önceden tanınmış cihazlarından
-- şifreyle giriş yapıp uygulamayı kullanabilir; diğer herkes bakım
-- ekranını görür. Varsayılan: kapalı.
ALTER TABLE users ADD COLUMN maintenance_bypass BOOLEAN NOT NULL DEFAULT FALSE;

-- Tanınmış cihazlar: listedeki hesap bakım KAPALIYKEN bir cihazda giriş
-- yapınca (ya da oturumu yenilenince) otomatik kaydedilir. Uygulamanın
-- ürettiği rastgele cihaz kimliği saklanmaz, yalnız SHA-256 özeti tutulur
-- (IMEI vb. donanım/kişisel bilgi YOK).
CREATE TABLE maintenance_devices (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  device_hash TEXT NOT NULL,
  platform TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL
);
CREATE UNIQUE INDEX maintenance_devices_kullanici_cihaz ON maintenance_devices(user_id, device_hash);
CREATE INDEX maintenance_devices_cihaz ON maintenance_devices(device_hash);
