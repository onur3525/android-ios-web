-- 016 — Hesap silmede Firebase kimlik kaydının silinmesi (15 Eki güvenlik denetimi). sqlite/016 ile BİREBİR.
-- Yerel hesap anonimleştirilirken Firebase kullanıcısı (telefon/e-posta kopyası)
-- bu kuyruğa yazılır ve arka plan işi siler; hata olursa artan aralıkla yeniden
-- dener. Başarıda satır silinir (uid yalnız silme tamamlanana kadar tutulur).
CREATE TABLE firebase_silme_kuyrugu (
  uid TEXT PRIMARY KEY,
  deneme INTEGER NOT NULL DEFAULT 0,
  son_hata TEXT,
  sonraki_deneme TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);
