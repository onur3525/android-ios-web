-- 024 — Yönetici MFA yenileme yedekleri (16 Eki). sqlite/024 ile aynı kural.
-- Bakım aracı (scripts/admin_mfa_yenile.js) bir yöneticinin TOTP sırrını
-- yenilemeden ÖNCE eski şifreli değeri buraya yazar; yanlış işlemde geri
-- dönülebilir. Değer şifrelidir (ana anahtarla); düz sır hiçbir yerde
-- saklanmaz. Kayıt yalnız ekleme içindir.
CREATE TABLE admin_mfa_yedekleri (
  id UUID PRIMARY KEY,
  admin_id UUID NOT NULL REFERENCES admins(id),
  eski_sir_enc TEXT NOT NULL,
  neden TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);
