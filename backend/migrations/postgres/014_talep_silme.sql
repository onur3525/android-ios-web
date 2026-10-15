-- 014 — Hizmet alan teklif talebini SİLER (15 Eki). sqlite/014 ile BİREBİR.
-- Kayıt kalıcı silinmez (hizmet verenin geçmişi ve mesajlar için gerekir);
-- hizmet alanın listesinden kalkar, hizmet veren "iptal edildi" görür.
-- Varsayılansız ADD COLUMN: PostgreSQL'de tabloyu yeniden yazmaz, mevcut kayıtlar değişmez.
ALTER TABLE teklif_talepleri ADD COLUMN silindi_at TIMESTAMPTZ;
