-- 042 — TEK CİHAZ KURALI (28 Eki, kullanıcı kararı)
--
-- "Yeni bir cihazdan uygulamada oturum açılırsa eski oturum açık olsa bile
-- kapatılır." Telefon/tablet ayrımı yok: cihaz. Bilgisayardaki web oturumu
-- kalır; telefon/tablet tarayıcısındaki web oturumu kapanır. Eski cihazın
-- bildirim kayıtları silinir. Eski cihazda açıklama GÖSTERİLMEZ.
--   user_sessions.istemci  'mobil' (uygulama) | 'web_mobil' (telefon/tablet
--                          tarayıcısı) | 'web' (bilgisayar); eski satırlarda
--                          NULL → user_agent'tan tahmin edilir
--   user_sessions.soy_id   oturum soyunun kimliği (ilk oturum); döndürmede
--                          aynen taşınır
--   push_tokens.soy_id     bildirim kaydının ait olduğu oturum soyu
ALTER TABLE user_sessions ADD COLUMN istemci TEXT;
ALTER TABLE user_sessions ADD COLUMN soy_id UUID;
CREATE INDEX user_sessions_soy ON user_sessions(soy_id);
ALTER TABLE push_tokens ADD COLUMN soy_id UUID;
