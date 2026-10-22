-- 031 — YASAL BELGE PDF (22 Eki). postgres/031 ile AYNI (SQLite · yalnız geliştirme/test).
-- yüklenebilir: kısa özet (summary) + depodaki PDF (pdf_ref). PDF'li sürümde
-- sha256 PDF baytlarının özetidir (kabulün ispatı); body özeti taşır.
ALTER TABLE legal_versions ADD COLUMN summary TEXT;
ALTER TABLE legal_versions ADD COLUMN pdf_ref TEXT;
ALTER TABLE legal_versions ADD COLUMN pdf_size INTEGER;
