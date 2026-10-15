-- 014 — Hizmet alan teklif talebini SİLER (15 Eki). postgres/014 ile BİREBİR.
-- Kayıt kalıcı silinmez (hizmet verenin geçmişi ve mesajlar için gerekir);
-- hizmet alanın listesinden kalkar, hizmet veren "iptal edildi" görür.
-- Varsayılansız ADD COLUMN: mevcut kayıtlar değişmez.
ALTER TABLE teklif_talepleri ADD COLUMN silindi_at TEXT;
