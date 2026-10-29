-- 048 — MESAJ "İLETİLDİ" ZAMANI (29 Eki, kullanıcı bulgusu: "mesaj karşı
-- tarafa ulaşmadan iki tik olmamalı"). sqlite/048 ile BİREBİR.
--
-- Önceden sunucu mesajı kaydettiği anda "İletildi" (iki tik) diyordu.
-- Artık durum üç aşamalı: SENT (sunucuda) → DELIVERED (alıcının açık
-- uygulamasına ulaştı: anlık bağlantı, sohbet listesi/sohbet ya da talep
-- listesi alıcı tarafından çekildi) → READ (alıcı sohbeti açtı/görüyor).
-- Mevcut mesajlar geriye dönük "iletildi" sayılır (geçmiş tek tike düşmesin).
ALTER TABLE messages ADD COLUMN delivered_at TIMESTAMPTZ;
ALTER TABLE teklif_mesajlari ADD COLUMN delivered_at TIMESTAMPTZ;
UPDATE messages SET delivered_at = COALESCE(read_at, created_at);
UPDATE teklif_mesajlari SET delivered_at = COALESCE(read_at, created_at);
