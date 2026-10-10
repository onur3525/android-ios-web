-- 012 — Bildirim tercihleri sunucuda + push kuyruğu dizini. sqlite/012 ile BİREBİR.
-- Tercihler önce yalnız cihazda tutuluyordu: kapatılan bildirim türü için
-- push gönderilmeye devam ediyordu ve tercih yeniden girişte sıfırlanıyordu.
-- Varsayılan AÇIK (mevcut davranış); yalnız PUSH'u etkiler, uygulama içi
-- bildirim kaydı aynen yazılır.
-- PostgreSQL 11+: sabit varsayılanlı ADD COLUMN tabloyu YENİDEN YAZMAZ (kısa kilit).
ALTER TABLE users ADD COLUMN notif_offer BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN notif_message BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN notif_announcement BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN notif_email BOOLEAN NOT NULL DEFAULT TRUE;
-- Push kuyruğu: bekleyen (NULL) ve sahiplenilmiş (SENDING) satırlar için
-- kısmi dizin. Bildirim tablosu büyüdükçe kuyruk taraması tam tablo
-- taramasına dönüşüyordu.
-- ⚠ Canlıda tablo büyükse bu göç yerine CREATE INDEX CONCURRENTLY elle
-- uygulanabilir (göç işlem içinde koştuğu için CONCURRENTLY kullanılamaz).
CREATE INDEX notifications_push_kuyrugu ON notifications(created_at) WHERE push_status IS NULL OR push_status = 'SENDING';
