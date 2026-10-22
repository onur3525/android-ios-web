-- 029 — ANA SAYFA ÇATILARI SUNUCUYA (22 Eki, kullanıcı kararı).
-- Uygulamanın ana sayfasındaki 24 çatı (Ev & Yaşam, Araç Hizmetleri…)
-- önceden yalnız uygulamaya gömülüydü. Artık adı ve fotoğrafı admin
-- panelinden değiştirilebilir; uygulama çatıları GET /api/v1/categories
-- yanıtındaki `roofs` alanından okur (yoksa gömülü listeye düşer).
--   key          — kalıcı kimlik (uygulama paketindeki görsel adı: ev, arac…)
--   card_label   — kart üstündeki kısa etiket (uygulamadaki kısaltma); ad
--                  değişince boşaltılır, kart adı gösterir
--   bundled_photo— uygulama paketindeki fotoğraf; photo_ref yüklenen
-- Kategori → çatı bağı categories.roof_key (başlangıç verisi uygulamadaki
-- eşlemeden gelir).
CREATE TABLE catalog_roofs (
  key TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  card_label TEXT,
  sort INTEGER NOT NULL,
  bundled_photo TEXT,
  photo_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
ALTER TABLE categories ADD COLUMN roof_key TEXT;
