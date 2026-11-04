-- 049 — KAYIT İLE TELEFON DOĞRULAMASI AYRILDI (4 Kas, kullanıcı kararı).
-- sqlite/049 ile BİREBİR.
--
-- Kayıt formu artık SMS kodu istemez; telefon "doğrulanmamış" kaydedilir,
-- doğrulama profil tamamlama adımında yapılır. Kural aynen: bir numara
-- yalnız BİR hesaba tanımlıdır. Doğrulanmamış numara, numaranın gerçek
-- sahibi SMS koduyla doğrulayınca eski hesaptan düşer; o hesabın telefonu
-- boş dize ('') olur ve tamamlama formu yeniden istenir. Boş dize birden
-- çok hesapta bulunabildiği için benzersizlikten çıkarılır.
--
-- ⚠ Mevcut kayıtlar DEĞİŞMEZ (bütün mevcut numaralar dolu ve tekil).
-- GERİ DÖNÜŞ: scripts/geri_al_049.sql — yalnız telefonu boş hesap yoksa.
DROP INDEX users_telefon;
CREATE UNIQUE INDEX users_telefon ON users(phone) WHERE deleted_at IS NULL AND phone <> '';
