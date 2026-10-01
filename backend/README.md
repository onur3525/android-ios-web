# HizmetCep Backend

Kullanıcı API'si (`/api/v1`) + Admin API'si (`/admin/v1`) + Admin paneli (`/admin`).

## Veritabanı

- **Canlı:** yalnız **PostgreSQL** (16+). `NODE_ENV=production` iken SQLite ile sunucu AÇILMAZ.
- **Geliştirme/test:** SQLite (Node 22 yerleşik), kurulum gerekmez.
- Göçler `migrations/postgres/` ve `migrations/sqlite/` altında, AYNI numara ve
  AYNI mantıksal şema ile yazılır. `test/db.test.js` iki şemanın tablo/sütun
  eşdeğerliğini her testte denetler. Kural: yeni göç = iki dosya birden.

## Ortam değişkenleri

| Değişken | Zorunlu | Açıklama |
|---|---|---|
| `NODE_ENV` | canlıda `production` | |
| `HC_DB_DRIVER` | hayır | `postgres` (canlı varsayılan) / `sqlite` |
| `HC_DATABASE_URL` | canlıda | `postgres://kullanici:sifre@host:5432/hizmetcep` |
| `HC_DB_SSL` | hayır | varsayılan açık; canlıda kapatılamaz |
| `HC_DB_CA_PEM` | hayır | yönetilen PG'nin CA sertifikası (PEM) |
| `HC_DB_POOL` | hayır | havuz boyutu (varsayılan 10) |
| `HC_MASTER_KEY` | canlıda | 32 bayt base64; TOTP ve entegrasyon sırlarını şifreler. `openssl rand -base64 32` |
| `PORT` | hayır | varsayılan 8080 |
| `HC_FIREBASE_PROJECT_ID` | hayır | varsayılan `hizmetcep-fe036`; Firebase ID token'ının `aud`/`iss` denetimi |
| `HC_FIREBASE_WEB_API_KEY` | önerilir | AÇIK web API anahtarı; Firebase'e bağlı hesapta telefon+şifre girişini Firebase'e doğrulatır |
| `HC_JWT_SECRET` | canlıda | ≥32 karakter; kullanıcı erişim token'larını imzalar |
| `HC_SMS_PROVIDER` / `HC_EMAIL_PROVIDER` | canlıda | `webhook` (canlı) · `log` yalnız geliştirme, canlıda reddedilir |
| `HC_SMS_WEBHOOK_URL` / `HC_EMAIL_WEBHOOK_URL` | webhook ise | https; gerçek SMS/e-posta sağlayıcısına köprü |
| `HC_SMS_WEBHOOK_TOKEN` / `HC_EMAIL_WEBHOOK_TOKEN` | webhook ise | Bearer anahtarı (yalnız sunucuda) |

## Komutlar

    npm test                         # SQLite ile tüm testler
    HC_TEST_DB=postgres HC_DATABASE_URL=... npm test   # aynı testler PostgreSQL'de
    npm run seed                     # Flutter'ın GERÇEK katalog/bölge/yasal verisini aktarır (yalnız boş tablolara)
    HC_ADMIN_PASSWORD=... npm run admin:create -- e-posta "Ad Soyad"   # ilk süper yönetici + TOTP
    npm start

## Kullanıcı hesabı

- OTP: 6 hane, rastgele, 3 dk geçerli, 5 hatalı denemede geçersiz, numara başına
  60 sn aralık ve saatte en fazla 5 kod; kod veritabanına ve bildirim kaydına
  ASLA düz yazılmaz.
- Oturum: 15 dk erişim token'ı (JWT HS256) + 30 gün yenileme token'ı (rotasyonlu;
  eski token tekrar kullanılırsa kullanıcının bütün oturumları kapanır).
- Hesap durumu (ACTIVE / SUSPENDED / BANNED) HER istekte veritabanından okunur;
  askı ve ban anında bütün oturumlar iptal edilir.

## Firebase Authentication

Firebase kimliği DOĞRULAR (SMS OTP, e-posta/şifre, e-posta bağlantıları);
backend ID token'ı Google'ın AÇIK sertifikalarıyla doğrular
(`src/firebase_token.js`, servis hesabı/Admin SDK gerekmez), Firebase UID'yi
`users.firebase_uid` ile hesaba bağlar ve KENDİ oturumunu verir. Hesap, rol,
askı/ban ve bütün iş verisi backend'de kalır. Uçlar: `POST /auth/firebase/session`;
kayıt/şifre sıfırlama/rol ekleme/telefon değişiminde `otpCode` yerine
`firebaseIdToken` kabul edilir (telefon numarası token'daki doğrulanmış
numarayla eşleşmek zorunda).

## Güvenlik

- Admin: scrypt şifre + TOTP (zorunlu), HttpOnly/SameSite=Strict/Secure çerez,
  30 dk hareketsizlik / 8 sa mutlak oturum, 5 hatalı denemede kilit, kritik
  işlemde yeniden doğrulama, sunucu tarafı rol yetkisi, değiştirilemez denetim kaydı.
- Admin paneli CSP + `frame-ancestors 'none'` + HSTS başlıklarıyla sunulur.
