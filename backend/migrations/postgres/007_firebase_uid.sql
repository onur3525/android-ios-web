-- 007 — Firebase Authentication eşleşmesi. postgres/sqlite BİREBİR.
-- Firebase kimliği DOĞRULAR; HizmetCep hesabı (rol, durum, iş verisi)
-- burada kalır. Bir Firebase kullanıcısı EN FAZLA bir hesaba bağlanır.
ALTER TABLE users ADD COLUMN firebase_uid TEXT;
CREATE UNIQUE INDEX users_firebase_uid ON users(firebase_uid) WHERE firebase_uid IS NOT NULL;
