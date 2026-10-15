-- 017 — Kayıtta 18 yaş beyanı (15 Eki, işletmeci kararı: asgari yaş 18). postgres/017 ile BİREBİR.
-- Doğum tarihi TOPLANMAZ (veri en aza indirme); kullanıcının "18 yaşından
-- büyüğüm" beyanının zamanı tutulur. Mevcut hesaplar NULL kalır (beyan
-- bu sürümden önce istenmiyordu); yeni kayıtta zorunludur.
ALTER TABLE users ADD COLUMN age_confirmed_at TEXT;
