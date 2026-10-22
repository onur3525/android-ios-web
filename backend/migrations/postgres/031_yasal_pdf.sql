-- 031 — YASAL BELGE PDF'İ (22 Eki, kullanıcı kararı). Sürüm PDF olarak
-- yüklenebilir: kısa özet (summary) + depodaki PDF (pdf_ref). PDF'li sürümde
-- sha256 PDF baytlarının özetidir (kabulün ispatı); body özeti taşır.
ALTER TABLE legal_versions ADD COLUMN summary TEXT;
ALTER TABLE legal_versions ADD COLUMN pdf_ref TEXT;
ALTER TABLE legal_versions ADD COLUMN pdf_size INTEGER;
