-- 038 — YÖNETİCİ UYARILARI (23 Eki, kullanıcı isteği: gelen talep, sistem
-- sorunu, yavaşlama ve şüpheli yönetici girişinde e-posta uyarısı).
--
-- admin_alerts: her uyarı türünün durumu (tek satır / tür).
--   active       — durum şu an sürüyor mu (aynı durum için tekrar e-posta
--                  gitmez; 24 saatte bir hatırlatma gider)
--   since        — durumun başladığı an
--   last_sent_at — son e-postanın gönderildiği an
--   cursor_at    — talep/giriş taramasında en son işlenen kaydın zamanı
--   detail       — son gönderilen özet (değişirse güncelleme gider)
-- Kişisel veri, ileti içeriği ya da sır tutulmaz.
CREATE TABLE admin_alerts (
  key TEXT PRIMARY KEY,
  active BOOLEAN NOT NULL DEFAULT FALSE,
  since TIMESTAMPTZ,
  last_sent_at TIMESTAMPTZ,
  cursor_at TIMESTAMPTZ,
  detail TEXT
);
