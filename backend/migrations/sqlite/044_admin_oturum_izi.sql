-- 044 — ADMİN OTURUM İZİ (28 Eki, kullanıcı isteği: süper admin her
-- yöneticinin oturumunu ne zaman açıp kapattığını görebilmeli)
--
-- admin_sessions.id: oturumun kalıcı kimliği. Giriş (auth.login) ve kapanış
-- (auth.session_end) denetim kayıtları bu kimlikle (target_id) eşleşir;
-- belirteç özeti (token_hash) denetime YAZILMAZ. Eski satırlarda NULL.
ALTER TABLE admin_sessions ADD COLUMN id TEXT;
CREATE INDEX audit_log_admin_zaman ON audit_log(admin_id, id);
