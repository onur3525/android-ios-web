-- 046 — 5651 TRAFİK KAYITLARI VE YASAL KİMLİK ARŞİVİ (29 Eki, TASLAK)
-- postgres/046 ile BİREBİR mantıksal şema; açıklamalar oradadır.
CREATE TABLE trafik_kayitlari (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  olay TEXT NOT NULL,
  hedef_tur TEXT,
  hedef_id TEXT,
  ip TEXT NOT NULL,
  kaynak_port INTEGER CHECK (kaynak_port IS NULL OR kaynak_port BETWEEN 0 AND 65535),
  user_agent TEXT,
  istemci TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX trafik_zaman ON trafik_kayitlari(created_at);
CREATE INDEX trafik_kullanici ON trafik_kayitlari(user_id, created_at DESC);
CREATE INDEX trafik_ip ON trafik_kayitlari(ip, created_at DESC);
CREATE TRIGGER trafik_kayitlari_degismez BEFORE UPDATE ON trafik_kayitlari
  BEGIN SELECT RAISE(ABORT, 'trafik_kayitlari değiştirilemez'); END;

CREATE TABLE yasal_kimlik_arsivi (
  user_id TEXT PRIMARY KEY,
  ad TEXT,
  telefon TEXT,
  eposta TEXT,
  kayit_tarihi TEXT,
  silinme_tarihi TEXT NOT NULL,
  saklama_bitis TEXT NOT NULL
);
CREATE INDEX yasal_kimlik_bitis ON yasal_kimlik_arsivi(saklama_bitis);
