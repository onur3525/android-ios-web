-- 046 — 5651 TRAFİK KAYITLARI VE YASAL KİMLİK ARŞİVİ (29 Eki, TASLAK)
-- sqlite/046 ile BİREBİR mantıksal şema.
--
-- trafik_kayitlari: kullanıcının yaptığı işlemin IP adresi, KAYNAK PORTU ve
--   zamanı. Oturum tablosundan (user_sessions) BAĞIMSIZDIR: oturum satırları
--   eskisi gibi kısa sürede silinir; bu tablo 365 gün tutulur ve HESAP
--   SİLİNSE DE silinmez (bakım işi 365 günü dolanı siler).
--   olay: REGISTER | LOGIN | SESSION_REFRESH | LISTING_CREATE | OFFER_CREATE |
--         MESSAGE_SEND | TALEP_CREATE | TALEP_MESSAGE | REVIEW_CREATE |
--         REPORT_CREATE | PROFILE_UPDATE | PASSWORD_CHANGE | PHONE_CHANGE |
--         ACCOUNT_DELETE_REQUEST
--   kaynak_port: Cloudflare'in istemci kaynak portu başlığından (Transform
--   Rule — bkz. DEPLOY notu); başlık yoksa NULL. Değer UYDURULMAZ.
--   Satırlar DEĞİŞTİRİLEMEZ (yalnız ekleme; süre dolunca bakım siler).
--
-- yasal_kimlik_arsivi: hesap SİLİNDİĞİNDE kullanıcı satırı anonimleşmeden
--   hemen önce ad, telefon ve e-postanın bir kopyası. Amaç yalnız yetkili
--   mercilerin (savcılık/mahkeme) talebinde trafik kaydını kişiyle
--   eşleştirebilmektir. Silinmeden itibaren 365 gün tutulur, sonra silinir.
CREATE TABLE trafik_kayitlari (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID,
  olay TEXT NOT NULL,
  hedef_tur TEXT,
  hedef_id TEXT,
  ip TEXT NOT NULL,
  kaynak_port INTEGER CHECK (kaynak_port IS NULL OR kaynak_port BETWEEN 0 AND 65535),
  user_agent TEXT,
  istemci TEXT,
  created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX trafik_zaman ON trafik_kayitlari(created_at);
CREATE INDEX trafik_kullanici ON trafik_kayitlari(user_id, created_at DESC);
CREATE INDEX trafik_ip ON trafik_kayitlari(ip, created_at DESC);

CREATE FUNCTION hc_trafik_degismez() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'trafik_kayitlari değiştirilemez';
END $$;
CREATE TRIGGER trafik_kayitlari_degismez BEFORE UPDATE ON trafik_kayitlari
  FOR EACH ROW EXECUTE FUNCTION hc_trafik_degismez();

CREATE TABLE yasal_kimlik_arsivi (
  user_id UUID PRIMARY KEY,
  ad TEXT,
  telefon TEXT,
  eposta TEXT,
  kayit_tarihi TIMESTAMPTZ,
  silinme_tarihi TIMESTAMPTZ NOT NULL,
  saklama_bitis TIMESTAMPTZ NOT NULL
);
CREATE INDEX yasal_kimlik_bitis ON yasal_kimlik_arsivi(saklama_bitis);
