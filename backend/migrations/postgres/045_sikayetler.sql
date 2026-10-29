-- 045 — ŞİKÂYET ET (UGC) MEKANİZMASI (29 Eki, TASLAK — işletmeci talebi)
-- sqlite/045 ile BİREBİR mantıksal şema.
--
-- Kullanıcı bir İLANI, bir KULLANICI PROFİLİNİ ya da bir YORUMU şikâyet eder;
-- kayıt yönetici panelindeki "Şikâyetler" sayfasına düşer.
--   target_type : LISTING | USER | REVIEW
--   reason      : FRAUD (Dolandırıcılık) | INSULT (Hakaret) |
--                 MISLEADING (Yanıltıcı bilgi) | OTHER (Diğer)
--   note        : isteğe bağlı açıklama (en çok 500 karakter; OTHER'da zorunlu)
--   status      : OPEN (incelenmedi) | REMOVED (içerik "Yönetim kaldırdı") |
--                 SUSPENDED (hesap askıya alındı) | DISMISSED (işlem gerekmedi)
--   target_owner_id : şikâyet edilen içeriğin sahibi (kendi içeriğini
--                 şikâyet etme engeli ve panelde kişi bağlantısı için)
-- Aynı kişi aynı içeriği, açık şikâyeti dururken ikinci kez şikâyet edemez.
-- Şikâyet eden hesabını silerse açıklama metni (kişisel içerik) silinir;
-- kayıt (kim/ne/ne zaman) yönetim işleminin dayanağı olarak kalır.
CREATE TABLE reports (
  id UUID PRIMARY KEY,
  reporter_id UUID NOT NULL REFERENCES users(id),
  target_type TEXT NOT NULL CHECK (target_type IN ('LISTING','USER','REVIEW')),
  target_id UUID NOT NULL,
  target_owner_id UUID REFERENCES users(id),
  reason TEXT NOT NULL CHECK (reason IN ('FRAUD','INSULT','MISLEADING','OTHER')),
  note TEXT,
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','REMOVED','SUSPENDED','DISMISSED')),
  resolved_by UUID,
  resolved_at TIMESTAMPTZ,
  resolution_note TEXT,
  created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX reports_durum ON reports(status, created_at DESC);
CREATE INDEX reports_hedef ON reports(target_type, target_id);
CREATE INDEX reports_bildiren ON reports(reporter_id, created_at DESC);
CREATE UNIQUE INDEX reports_acik_tekil ON reports(reporter_id, target_type, target_id) WHERE status = 'OPEN';
