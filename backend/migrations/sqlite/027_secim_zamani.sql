-- 027 — SEÇİM ZAMANI (21 Eki). postgres/027 ile BİREBİR.
-- Admin Özet'teki "seçilen tekliflerin toplam tutarı" seçilen tarih
-- aralığına göre hesaplanır: bir teklifin SEÇİLDİĞİ an kaydedilir.
--   · offers.selected_at            — ilan teklifi hizmet alan tarafından seçildi
--   · teklif_talepleri.secildi_at   — doğrudan teklif talebinde teklif kabul edildi
-- Seçim bir kez sayılır: teklif sonradan kapansa/tamamlansa da tarih kalır.
-- Eski kayıtlar: seçim anı tutulmadığı için en yakın değer olan updated_at
-- yazılır (yalnız seçilmiş olanlara).
ALTER TABLE offers ADD COLUMN selected_at TEXT;
ALTER TABLE teklif_talepleri ADD COLUMN secildi_at TEXT;
UPDATE offers SET selected_at = updated_at WHERE status = 'SELECTED';
UPDATE teklif_talepleri SET secildi_at = updated_at WHERE durum IN ('SECILDI', 'TAMAMLANDI') AND teklif_fiyati IS NOT NULL;
CREATE INDEX offers_secim ON offers(selected_at) WHERE selected_at IS NOT NULL;
CREATE INDEX teklif_talepleri_secim ON teklif_talepleri(secildi_at) WHERE secildi_at IS NOT NULL;
