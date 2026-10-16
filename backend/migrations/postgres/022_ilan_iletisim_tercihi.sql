-- 022 — İlanın iletişim tercihi (16 Eki, kullanıcı isteği). sqlite/022 ile aynı kural.
-- "Hizmet alan ilan oluştururken numarasını gizlemediyse telefonu görünür,
-- mesajlaşma açık olmalı." İlan oluşturma ekranındaki seçim (Telefon +
-- Uygulama İçi Mesaj / Sadece Uygulama İçi Mesaj) sunucuya iletilmiyordu.
-- Mevcut ilanlar 'telefonGoster' olur (önceki davranış: telefon görünürdü).
ALTER TABLE listings ADD COLUMN iletisim_tercihi TEXT NOT NULL DEFAULT 'telefonGoster';
