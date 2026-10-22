-- 030 — YÖNETİCİ SİLME (22 Eki, kullanıcı kararı). Süper yönetici diğer
-- yönetici hesaplarını siler. Kayıt fiziksel silinmez (destek yanıtları,
-- denetim kaydı ona bağlı): deleted_at işaretlenir, hesap pasif olur,
-- e-posta yeniden kullanılabilsin diye serbest bırakılır.
ALTER TABLE admins ADD COLUMN deleted_at TIMESTAMPTZ;
