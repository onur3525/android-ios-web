-- 013 — Son kapatma turu. sqlite/013 ile BİREBİR.
-- Varsayılansız ADD COLUMN: PostgreSQL'de tabloyu yeniden yazmaz.

-- Hesap dondurma GERÇEK bir durumdur: frozen_at doluyken hesap oturum
-- kullanamaz, aramada görünmez, push almaz. Yeniden giriş hesabı açar
-- (uygulamadaki metin: "tekrar giriş yaparak etkinleştirebilirsiniz").
ALTER TABLE users ADD COLUMN frozen_at TIMESTAMPTZ;

-- Profil fotoğrafı ROL BAZLI (Flutter Account.fotografi(Role)).
ALTER TABLE users ADD COLUMN photo_customer_ref TEXT;
ALTER TABLE users ADD COLUMN photo_provider_ref TEXT;

-- Yüklenen nesne sunucuda doğrulandı mı (boyut, tür, sihirli bayt).
ALTER TABLE storage_objects ADD COLUMN verified_at TIMESTAMPTZ;

-- Idempotency: aynı anahtar aynı sonucu döndürür; farklı gövdeyle gelirse ret.
ALTER TABLE listings ADD COLUMN idempotency_key TEXT;
ALTER TABLE listings ADD COLUMN idem_hash TEXT;
CREATE UNIQUE INDEX listings_idem ON listings(owner_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE teklif_talepleri ADD COLUMN idempotency_key TEXT;
ALTER TABLE teklif_talepleri ADD COLUMN idem_hash TEXT;
CREATE UNIQUE INDEX teklif_talepleri_idem ON teklif_talepleri(hizmet_alan_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE teklif_mesajlari ADD COLUMN idempotency_key TEXT;
ALTER TABLE teklif_mesajlari ADD COLUMN idem_hash TEXT;
CREATE UNIQUE INDEX teklif_mesajlari_idem ON teklif_mesajlari(gonderen_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE messages ADD COLUMN idem_hash TEXT;
ALTER TABLE offers ADD COLUMN idem_hash TEXT;
CREATE UNIQUE INDEX offers_idem ON offers(provider_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
ALTER TABLE support_tickets ADD COLUMN idem_hash TEXT;

-- Bir kullanıcının EN ÇOK BİR bekleyen silme talebi (eşzamanlı çift istek).
CREATE UNIQUE INDEX account_requests_tek_silme ON account_requests(user_id) WHERE type = 'DELETION' AND status = 'PENDING';

-- Bul araması: etkin hizmet veren profilleri.
CREATE INDEX provider_profiles_guncel ON provider_profiles(updated_at);
