-- 012 — Bildirim tercihleri sunucuda + push kuyruğu dizini. postgres/012 ile BİREBİR.
-- Tercihler önce yalnız cihazda tutuluyordu: kapatılan bildirim türü için
-- push gönderilmeye devam ediyordu ve tercih yeniden girişte sıfırlanıyordu.
-- Varsayılan AÇIK (mevcut davranış); yalnız PUSH'u etkiler, uygulama içi
-- bildirim kaydı aynen yazılır.
ALTER TABLE users ADD COLUMN notif_offer INTEGER NOT NULL DEFAULT 1;
ALTER TABLE users ADD COLUMN notif_message INTEGER NOT NULL DEFAULT 1;
ALTER TABLE users ADD COLUMN notif_announcement INTEGER NOT NULL DEFAULT 1;
ALTER TABLE users ADD COLUMN notif_email INTEGER NOT NULL DEFAULT 1;
-- Push kuyruğu: bekleyen (NULL) ve sahiplenilmiş (SENDING) satırlar için
-- kısmi dizin. Bildirim tablosu büyüdükçe kuyruk taraması tam tablo
-- taramasına dönüşüyordu.
CREATE INDEX notifications_push_kuyrugu ON notifications(created_at) WHERE push_status IS NULL OR push_status = 'SENDING';
