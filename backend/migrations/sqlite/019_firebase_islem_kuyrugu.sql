-- 019 — Firebase işlem kuyruğu ve dış değişiklik uzlaştırması (15 Eki güvenlik
-- denetimi). postgres/019 ile BİREBİR.
--
-- firebase_islem_kuyrugu : Firebase'e yazılamayan işlemlerin kalıcı yeniden
--   deneme kuyruğu (kullanıcı + işlem başına tek satır):
--     REVOKE     — yenileme belirteçlerini iptal et (deger = validSince, saniye;
--                  gönderilen değer hesabın güncel sınırından küçük olamaz)
--     SYNC_PHONE — Firebase'deki telefonu hesabın GÜNCEL numarasına eşitle
--   Başarıda satır silinir; hata artan aralıkla süresiz yeniden denenir ve
--   yönetici panelinde (Silme Kuyrukları) görünür.
-- users.firebase_checked_at : Firebase kaydının (dışarıda yapılan şifre
--   sıfırlama / oturum iptali) en son uzlaştırıldığı an (yenilemede en çok
--   5 dakikada bir okunur).
ALTER TABLE users ADD COLUMN firebase_checked_at TEXT;
CREATE TABLE firebase_islem_kuyrugu (
  user_id TEXT NOT NULL,
  islem TEXT NOT NULL CHECK (islem IN ('REVOKE','SYNC_PHONE')),
  deger INTEGER,
  deneme INTEGER NOT NULL DEFAULT 0,
  son_hata TEXT,
  sonraki_deneme TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, islem)
);
