-- 041 — OTURUM YENİLEME YARIŞI: HALEF YANITININ TEKRARI (28 Eki)
--
-- Aynı yenileme belirteci aynı anda (iki sekme) ya da yanıt kaybolup
-- tekrar gönderilince yalnız BİR istek oturumu döndürür. Kaybeden istek
-- 401 alıyor, web'de ortak çerez silinip İKİ SEKME de çıkış yapıyordu.
-- Artık döndürülen satıra halefin kimliği ve (ana anahtarla şifreli)
-- yeni yenileme belirteci yazılır; kaybeden/geç gelen istek AYNI yanıtı
-- alır — yeni oturum açılmaz, soy çatallanmaz.
--   halef_id         → bu satırın yerine geçen oturum
--   halef_token_enc  → halefin yenileme belirteci (sirSifrele, AES-GCM);
--                      halef de döndürülünce silinir (yalnız son halka tutulur)
ALTER TABLE user_sessions ADD COLUMN halef_id TEXT;
ALTER TABLE user_sessions ADD COLUMN halef_token_enc TEXT;
CREATE INDEX user_sessions_halef ON user_sessions(halef_id);
