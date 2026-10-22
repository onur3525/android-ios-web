-- 032 — BAKIMDA TEST HESABI (22 Eki, kullanıcı kararı). Admin'in seçtiği
-- kullanıcı hesapları bakım modunda şifreyle giriş yapıp uygulamayı
-- kullanabilir; diğer herkes bakım ekranını görür. Varsayılan: kapalı.
ALTER TABLE users ADD COLUMN maintenance_bypass BOOLEAN NOT NULL DEFAULT FALSE;
