# HizmetCep — Canlı Dağıtım ve Yatay Ölçekleme

Uygulama kodu **tek sunucu varsaymaz**. Aynı imajdan bir ya da daha çok
örnek, yük dengeleyici (load balancer) arkasında çalışır. Örnek sayısını
artırmak/azaltmak KOD DEĞİŞİKLİĞİ gerektirmez; otomatik ölçeklemeyi
altyapı (Kubernetes HPA, ECS, Cloud Run, Fly, Render vb.) yapar.

## Neden durumsuz

| Durum | Nerede tutulur | Örnekler arası |
|---|---|---|
| Kullanıcı/admin oturumları | PostgreSQL (`user_sessions`, `admin_sessions`) | ortak |
| Hız sınırları (giriş, OTP, MFA) | PostgreSQL (`rate_limits`, atomik UPSERT) | ortak — örnek sayısıyla çoğalmaz |
| Gerçek zamanlı olaylar | PostgreSQL LISTEN/NOTIFY (`src/olaylar.js`) | her örnek kendi soketlerine iletir |
| Dosyalar | Nesne depolama (S3/R2/MinIO), imzalı adres | sunucu diskine yazılmaz |
| Entegrasyon ayarları | PostgreSQL; değişiklik olayla bütün örneklerde önbellekten düşer | ortak |
| Arka plan işleri (ilan/talep süresi, hesap silme) | her örnekte zamanlanır, **danışma kilidiyle yalnız biri** çalıştırır | çift iş yok |
| Şema göçleri | açılışta tek işlem + danışma kilidi | aynı anda açılan örnekler güvenli |

## Yük dengeleyici gereksinimleri

- **WebSocket upgrade** desteği (`/socket.io/`). İstemci yalnız WebSocket
  taşıyıcısı kullanır → **yapışkan oturum (sticky session) GEREKMEZ**.
- Boşta zaman aşımı ≥ 60 sn (sunucu keep-alive 65 sn; Socket.IO ping 25 sn).
- Sağlık uçları: `/healthz` (canlılık), `/readyz` (veritabanı erişimi;
  kapanış sırasında 503).
- İstemci IP'si: `HC_TRUST_PROXY_HOPS` (aşağıdaki bölüm). Tanımsızsa
  `X-Forwarded-For` yok sayılır ve soket adresi kullanılır.

## İstemci IP'si ve `HC_TRUST_PROXY_HOPS`

Hız sınırları (giriş, Firebase oturumu, OTP, admin giriş/MFA/yeniden
doğrulama), kullanıcı ve admin oturum kayıtları ve admin denetim kayıtları
IP'yi TEK yerden alır (`src/http.js` → `istemciIp`).

- `X-Forwarded-For`'un **en soldaki** değeri istemcinin kendi yazdığı değerdir
  ve doğrulanmaz; proxy'ler gerçek adresi **sona** ekler. Bu yüzden değer
  **sağdan** sayılarak alınır.
- `HC_TRUST_PROXY_HOPS`: güvenilen proxy altyapısının `X-Forwarded-For`
  başlığının **sağına eklediği değer sayısı** (0–5). Bu, **fiziksel proxy
  sayısı değildir**: bir proxy birden fazla değer ekleyebilir. Değer N ise
  sağdan N'inci değer istemci adresi kabul edilir. Tanımsız ya da 0 →
  başlığa güvenilmez. Başlıkta yeterli değer yoksa ya da seçilen değer geçerli bir IP
  değilse soket adresi kullanılır.
- Eski `HC_TRUST_PROXY` değişkeni (en sol değeri alıyordu) artık
  **reddedilir**; tanımlıysa sunucu açılmaz.

⚠ **Üretim değeri ÖLÇÜLMEDEN verilmez.** Aşağıdaki değerler yalnız ADAYDIR:

| Topoloji | Altyapının sağa eklediği değerler | Aday değer | Not |
|---|---|---|---|
| Doğrudan Cloud Run adresi / alan eşlemesi | Google ön ucu: muhtemelen yalnız `<istemci>` | muhtemelen 1 | Ön ucun kaç değer eklediği ölçülmeli |
| Harici Google yük dengeleyici → Cloud Run | dengeleyici: `<istemci>,<dengeleyici IP>` (tek proxy, **iki değer** — Google belgesi) | muhtemelen 2 | Cloud Run ön ucu bunlara ayrıca değer ekliyorsa 3 olur; ölçülmeli |
| Önde ek proxy (ör. CDN) | o proxy'nin eklediği değer(ler) | eklenen her değer için +1 | Ölçülmeli |
| Proxy yok / yerel | — | tanımsız | Soket adresi |

**Ölçüm — geçici teşhis ucu (15 Eki, önerilen):** Render'da
`HC_IP_TESHIS=true` ekleyip yeniden dağıtın; telefondan (Wi-Fi kapalı) ve
bilgisayardan `https://<api adresi>/teshis/ip` açın. Kendi genel IP'nizi
(herhangi bir "IP adresim" sitesinden) yanıttaki `sagdan` listesinde bulun:
o satırın `sira` değeri `HC_TRUST_PROXY_HOPS` değeridir. Değeri girin,
`HC_IP_TESHIS`'i SİLİN ve yeniden dağıtın (açıkken açılışta uyarı yazılır;
kapalıyken uç 404 döner). Yanıt yalnız isteği yapanın kendi bağlantı
bilgisidir.

**Ölçüm — kodsuz yöntem:** staging'de aday değerle başlat;
bilinen bir istemci IP'sinden `X-Forwarded-For: 203.0.113.9` başlığıyla
admin girişine bilerek yanlış şifre gönder; admin panelindeki denetim
kaydında `auth.login_failed` satırının IP'sine bak. Gerçek istemci IP'si ise
değer doğrudur; `203.0.113.9` ya da dengeleyici IP'si görünüyorsa yanlıştır.
Değer **eksik** verilirse altyapının kendi adresi (ör. dengeleyici IP'si)
seçilir: herkes tek IP'de toplanır ve gerçek kullanıcılar birbirinin hız
sınırına takılır. Değer **fazla** verilirse istemcinin yazdığı sahte değer
seçilir: sahtecilik geri gelir.

## Düzgün kapanış

`SIGTERM` → `/readyz` 503 döner (5 sn) → yeni bağlantı alınmaz → açık
istekler biter → WebSocket'ler kapanır (istemci başka örneğe yeniden
bağlanır) → veritabanı kapanır. En fazla 25 sn.

## PostgreSQL bağlantı bütçesi

Her örnek `HC_DB_POOL` (varsayılan 10) + 1 LISTEN bağlantısı açar.
`örnek_sayısı_azami × (HC_DB_POOL + 1) < max_connections` olmalı.

**Şifre özeti iş parçacığı havuzu:** şifre doğrulama (scrypt, ~100 ms CPU,
~32 MB bellek) olay döngüsünü kilitlememek için libuv iş parçacığı havuzunda
çalışır. Varsayılan havuz 4 iş parçacığıdır; bir örnek saniyede kabaca
`UV_THREADPOOL_SIZE × 10` şifre işlemi yapabilir. Giriş yükü yüksekse örnek
başına çekirdek sayısı kadar ayarlayın (ör. `UV_THREADPOOL_SIZE=8`) ve bellek
payını (`× 32 MB`) hesaba katın. Asıl ölçekleme örnek sayısıyladır.

**Kayıt bakımı:** `kayit_bakimi` işi dakikada bir (danışma kilidiyle tek
örnekte) süresi geçmiş hız sınırı satırlarını, 24 saatten eski OTP
kayıtlarını, süresi 30 günden önce dolmuş kullanıcı oturumlarını ve 2 günden
eski admin oturumlarını siler. İş verisine (ilan, teklif, mesaj, bildirim,
denetim kaydı) dokunmaz.
PgBouncer kullanılacaksa **transaction** modunda havuz bağlantıları için
uygundur; LISTEN bağlantısı ise **session** modu ister (ayrı havuz ya da
doğrudan bağlantı).

## Otomatik ölçekleme önerisi

- Başlangıç: 2 örnek (biri düşerse hizmet sürer), en fazla N.
- Ölçek ölçütü: CPU %60 ya da örnek başına açık WebSocket sayısı.
- Her örnek: 0,5 vCPU / 512 MB yeterli başlangıçtır.

## Zorunlu ortam değişkenleri (BÜTÜN örneklerde AYNI)

Tam liste ve biçimler: `backend/.env.example` (gerçek değer içermez).

Üretimde eksikse sunucu **açılmaz**: `NODE_ENV=production`,
`HC_DATABASE_URL`, `HC_MASTER_KEY`, `HC_JWT_SECRET` ve FCM servis hesabı
(`HC_FCM_SERVICE_ACCOUNT` **ya da** `HC_FCM_SERVICE_ACCOUNT_FILE`, yalnız biri).

Sunucuyu durdurmayan ama işlev için gerekenler: SMS/e-posta gönderim yolu
(`HC_SMS_PROVIDER`/`HC_EMAIL_PROVIDER=webhook` + adres/anahtar **ya da**
admin panelinden etkin entegrasyon), depolama için `HC_S3_*` ya da admin
entegrasyonu. ⚠ `HC_MASTER_KEY` ve `HC_JWT_SECRET` örnekler arasında farklı
olursa oturumlar ve şifreli sırlar ÇALIŞMAZ.

## Kova (bucket) ayarı

- Genel erişim KAPALI; okuma/yazma yalnız imzalı adresle.
- Yaşam döngüsü kuralı: `u/` önekinde 1 günden eski, ilana bağlanmamış
  nesneler (uygulama `storage_objects.status = DISCARDED/PENDING` tutar)
  için temizlik işi ya da kural.
- CORS: web istemcisinin kaynağından `PUT` + `Content-Type` (yükleme) ve `GET`
  (14 Eki: ilan/talep/sohbet fotoğrafları web'de imzalı adresten doğrudan
  çizilir; GET izni yoksa tarayıcı görseli açmaz, yer tutucu görünür).

---

## Ek (7 Eki): yeni ortam değişkenleri, yedekleme, push, izleme

### Yeni/ek ortam değişkenleri

| Değişken | Zorunlu mu | Varsayılan | Açıklama |
|---|---|---|---|
| `HC_CORS_ORIGINS` | Hayır | Üretimde `https://hizmetcep.com`, geliştirmede boş | Kullanıcı API'sine tarayıcıdan erişebilecek kökenler (virgülle). `*` ve yol içeren değer reddedilir; üretimde yalnız https. |
| `HC_FCM_SERVICE_ACCOUNT` / `HC_FCM_SERVICE_ACCOUNT_FILE` | **Üretimde evet (yalnız biri)** | Yok | Firebase servis hesabı. `HC_FCM_SERVICE_ACCOUNT`: JSON'un kendisi (düz ya da base64). `HC_FCM_SERVICE_ACCOUNT_FILE`: JSON dosyasının yolu (Render Secret File → `/etc/secrets/<dosya adı>`). İkisi birden verilirse, dosya okunamazsa, JSON bozuksa ya da `project_id` değeri `HC_FIREBASE_PROJECT_ID` (varsayılan `hizmetcep-fe036`) ile aynı değilse sunucu **açılmaz** (yanlış projeyle gönderim cihaz kayıtlarını sildirirdi). Hata mesajları içerik/anahtar yazmaz. Geliştirmede tanımsızsa bildirimler yalnız uygulama içinde görünür. |
| `HC_INTEGRATION_ALLOW_PRIVATE` | Hayır (yalnız geliştirme) | Yok | `true` ise admin entegrasyon adreslerinde iç ağ (localhost/özel IP) engeli kalkar — yalnız yerel köprü/MinIO denemesi için. **Üretimde tanımlanırsa sunucu açılmaz.** |
| `HC_S3_*` | Fotoğraf için evet | Yok | Kimlik bilgisinin `PutObject`, `GetObject` **ve `DeleteObject`** yetkisi olmalı (fiziksel dosya silme). |

### Arka plan işleri (kilitli; çok örnekte yalnız biri çalışır)

`ilan_suresi`, `talep_suresi`, `hesap_silme`, `dosya_temizligi` (silinen ilan/hesap dosyalarını depodan siler; başarısızlık `storage_objects.delete_error` ve denetim kaydında `storage.delete.failed`), `push_gonderimi` (bekleyen bildirimleri FCM ile gönderir; geçersiz jetonu siler, geçici hatayı en fazla 5 kez yeniden dener).

### Yedekleme ve geri yükleme

- **Yedek al:** `HC_DATABASE_URL=… ./scripts/yedek_al.sh /güvenli/klasör` → `pg_dump` özel biçim + içerik listesi + SHA-256. Yedek kişisel veri içerir: şifreli depolayın, erişimi kısıtlayın, saklama süresini belirleyin.
- **Önerilen sıklık:** günlük tam yedek + sağlayıcının noktasal geri dönüşü (PITR) açık.
- **Geri yükleme provası (en az ayda bir):** boş bir veritabanına `HC_RESTORE_URL=… ./scripts/yedek_geri_yukle.sh dosya.dump`; betik hedef boş değilse DURUR, sonunda son göç, kullanıcı ve kategori sayısını yazar.
- **Göçten önce:** her sürüm yükseltmesinden önce `yedek_al.sh` çalıştırılır. Göçler yalnız EKLEME yapar (sütun/tablo); geri dönüş = önceki uygulama sürümüne dönmek (eklenen sütunları eski sürüm görmezden gelir). Veri bozulması durumunda: yedekten boş veritabanına geri yükle → doğrula → `HC_DATABASE_URL`'i yeni veritabanına çevir → uygulamayı yeniden başlat.

### Yeni göçler

`008_kategori_foto`, `009_dosya_silme`, `010_push_gonderimi` — hepsi yalnız sütun ekler; mevcut veriyi değiştirmez (010, göç öncesi bildirimleri push gönderilmeyecek olarak işaretler).

---

## Render kurulumu (sıralı)

> Bu bölüm canlı ortamda **henüz doğrulanmadı**; kod ve testlerle uyumlu
> kurulum adımlarıdır. Gerçek değerler yalnız Render panelinde girilir.

1. **PostgreSQL**: Render → New → PostgreSQL (16). Oluşunca *External
   Database URL* değerini kopyalayın. Sunucu TLS'i zorunlu ve sertifikayı
   doğrulayarak (`rejectUnauthorized`) bağlanır; bağlantı TLS/sertifika
   hatası verirse sağlayıcının CA sertifikasını `HC_DB_CA_PEM` ile verin.
   ⚠ İç (internal) adresin sertifika ad eşleşmesi canlıda denenmeden
   kullanılmamalıdır.
2. **Web Service**: New → Web Service → depo. *Runtime: Docker*,
   *Dockerfile Path:* `backend/Dockerfile`, *Docker Build Context:* depo
   kökü (`.`). *Health Check Path:* `/healthz`. `PORT`'u Render verir.
   ⚠ İmaj `package-lock.json` olmadan **bilerek** derlenmez
   (docs/kilit_dosyalari.md). Kilit, backend CI'ının ilk koşusunda
   `backend-package-lock` ürünü olarak üretilir; indirip
   `backend/package-lock.json` olarak depoya işleyin.
3. **Environment** sekmesi: `NODE_ENV=production`, `HC_DB_DRIVER=postgres`,
   `HC_DATABASE_URL`, `HC_MASTER_KEY` (`openssl rand -base64 32`),
   `HC_JWT_SECRET` (en az 32 karakter), `HC_FIREBASE_PROJECT_ID`,
   `HC_CORS_ORIGINS` (web kökeni/kökenleri, virgülle; ör. Netlify'ın özel alan
   adı. GitHub Pages test sitesi bu sunucuya bağlanıyorsa
   `https://onur3525.github.io` da eklenmeli — yoksa tarayıcı istekleri engeller),
   `HC_FIREBASE_WEB_API_KEY` (AÇIK web anahtarı; tanımsızsa giriş yalnız yerel
   şifre özetine bakar ve e-posta ile yapılan Firebase şifre sıfırlaması
   girişe yansımaz).
4. **Secret Files** sekmesi: Firebase konsolu → Proje ayarları → Hizmet
   hesapları → *Yeni özel anahtar oluştur* ile indirilen JSON'u ekleyin
   (dosya adı ör. `firebase-servis-hesabi.json`). Environment'a
   `HC_FCM_SERVICE_ACCOUNT_FILE=/etc/secrets/firebase-servis-hesabi.json`
   yazın. `HC_FCM_SERVICE_ACCOUNT`'u **tanımlamayın** (ikisi birden
   reddedilir). ⚠ `google-services.json` (istemci dosyası) servis hesabı
   DEĞİLDİR; verilirse "private_key eksik" hatasıyla reddedilir.
5. **SMS / e-posta**: gerçek sağlayıcı köprüsü varsa
   `HC_SMS_PROVIDER=webhook` + `HC_SMS_WEBHOOK_URL` (https) +
   `HC_SMS_WEBHOOK_TOKEN` (e-posta için `HC_EMAIL_*`). Yoksa bu değişkenleri
   **hiç tanımlamayın** (boş/rastgele değer girmeyin); sağlayıcı sonradan
   admin paneli → Entegrasyonlar'dan eklenebilir. Bu durumda açılışta uyarı
   yazılır, gönderimler `outbound_messages`'a FAILED düşer, sunucu OTP
   isteği 503 döner. Uygulamadaki telefon doğrulaması Firebase
   Authentication ile yapılır; bu kanal sunucu OTP'si ve hesap bildirimleri
   (askı/ban, destek yanıtı) içindir.
6. **Depolama**: `HC_S3_*` (dördü birlikte) ya da admin paneli →
   Entegrasyonlar → Depolama. Kimlik bilgisi Put/Get/Delete yetkili olmalı.
7. **İlk dağıtım sonrası**: katalog, bölge, yasal metin ve destek tabloları
   BOŞSA sunucu açılışta bunları uygulamanın kendi verisinden doldurur
   (günlükte "Başlangıç verisi aktarıldı" satırı; kapatmak için
   `HC_OTOMATIK_TOHUM=false`, elle: `npm run seed`). Katalog boşken ilan
   açılamaz ("Geçerli bir hizmet seçiniz"). İlk yönetici için (kabuk erişimi
   gerekir): `HC_ADMIN_PASSWORD=… npm run admin:create -- <e-posta> "<Ad Soyad>"`.
8. **`HC_TRUST_PROXY_HOPS`**: "İstemci IP'si" bölümündeki ölçüm adımıyla
   belirleyin; ölçmeden değer vermeyin (tanımsız = başlığa güvenilmez).
9. **Alan adı**: Render → Custom Domains → `api.hizmetcep.com` (Flutter
   release derlemeleri bu adresi kullanır: `API_BASE_URL=https://api.hizmetcep.com/api/v1`).
10. **Doğrulama**: `https://api.hizmetcep.com/healthz` → `{"ok":true}`;
    günlükte "HizmetCep backend dinliyor" satırı; SMS/e-posta uyarısı
    varsa bilinçli olmalı.

### Önceki Render hatalarının kök nedeni

- **"Üretimde HC_FCM_SERVICE_ACCOUNT zorunludur."** — Servis hesabı Render'a
  *Secret File* olarak eklenmişti; kod yalnız `HC_FCM_SERVICE_ACCOUNT`
  ortam DEĞERİNİ okuyordu, dosya yolunu hiç okumuyordu. Düzeltme: tek okuyucu
  (`src/servis_hesabi.js`), `HC_FCM_SERVICE_ACCOUNT_FILE` desteği; config ve
  FCM gönderici aynı okuyucuyu kullanır. Zorunluluk **korundu** (push ürünün
  parçası; eksikse bildirimler sessizce kaybolurdu).
- **"HC_SMS_PROVIDER log ya da webhook olmalıdır."** — Üretimde değişken
  tanımsızken boş değer "geçersiz" sayılıyordu; oysa bu belge admin
  entegrasyonunu da geçerli yol sayıyordu (kod ile belge çelişkiliydi).
  Düzeltme: tanımsız değer üretimde izinli (admin entegrasyonu ya da açık
  FAILED/503); `log` üretimde hâlâ yasak, geçersiz değer hâlâ reddedilir.
