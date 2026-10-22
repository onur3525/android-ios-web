-- 029 — ANA SAYFA ÇATILARI SUNUCUYA (22 Eki). postgres/029 ile AYNI mantık
-- (SQLite · yalnız geliştirme/test).
CREATE TABLE catalog_roofs (
    key TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    card_label TEXT,
    sort INTEGER NOT NULL,
    bundled_photo TEXT,
    photo_ref TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
ALTER TABLE categories ADD COLUMN roof_key TEXT;
