# PLAY STORE YAYINI — ADIM ADIM

⚠ Bu belge, mağazaya çıkarken yapılacakları sırayla anlatır. Kod
tarafı hazırdır; buradaki adımlar SİZDE.

## 1. İmzalama anahtarı — BİR KEZ üretilir

⚠ **Anahtar kaybolursa aynı uygulama bir daha güncellenemez.** Yeni
anahtarla yükleme kabul edilmez, kullanıcılar taşınamaz.

    keytool -genkey -v -keystore hizmetcep.jks \
      -keyalg RSA -keysize 2048 -validity 10000 -alias hizmetcep

Sorulan bilgiler: iki parola (depo + anahtar), ad, kurum, şehir, ülke.

⚠ SAKLAMA:
- `.jks` dosyası ve parolalar depoya KONMAZ (`android/.gitignore`
  bunları zaten dışlar)
- en az iki ayrı yerde yedeklenir (biri çevrimdışı)
- parolalar parola yöneticisinde tutulur

⚠ Play App Signing AÇIK bırakılmalıdır: Google dağıtım anahtarını
kendi tutar, sizinki yalnız "yükleme anahtarı" olur. Yükleme anahtarı
kaybolursa Google sıfırlayabilir — dağıtım anahtarı kaybolursa
kimse kurtaramaz.

## 2. Yerel derleme için

`android/key.properties` oluşturun (bu dosya depoya GİTMEZ):

    storeFile=/mutlak/yol/hizmetcep.jks
    storePassword=<depo parolası>
    keyAlias=hizmetcep
    keyPassword=<anahtar parolası>

⚠ Dosya yoksa sürüm derlemesi KIRILIR. Bilerek böyledir: sessizce
hata ayıklama anahtarıyla imzalanmış paket üretilmez.

## 3. CI için (Codemagic)

Environment variables → hepsi "secure" işaretli:

| Değişken | Değer |
|---|---|
| `KEYSTORE_B64` | `base64 -w0 hizmetcep.jks` çıktısı |
| `KEYSTORE_PASSWORD` | depo parolası |
| `KEY_ALIAS` | `hizmetcep` |
| `KEY_PASSWORD` | anahtar parolası |
| `API_BASE_URL` | `https://...` (release'te https zorunlu) |
| `CERT_PINS` | İSTEĞE BAĞLI (29 Eki: Render'da pinsiz yayın). Verilirse en az iki pin, virgülle (`sha256/<SPKI base64>`) |
| `STORAGE_HOSTS` | izinli depolama alan adları, virgülle (boşsa yükleme reddedilir) |
| `APK_SIGNATURE_SHA256` | Google'ın imza anahtarının özeti (aşağıda) |
| `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | Play'deki son derleme numarasını okumak için servis hesabı (bölüm 5) |

⚠ İmza özeti YÜKLEME ANAHTARINIZDAN ALINMAZ. Play App Signing açıkken
kullanıcının telefonuna giden paketi Google'ın "uygulama imzalama
anahtarı" imzalar. Uygulama da çalışırken bu imzayı okur. Yükleme
anahtarının özeti verilirse imza denetimi mağazadan indiren HERKESTE
başarısız olur.

İmza özetini almak:

1. Play Console → uygulama → Test ve yayınlama → Uygulama bütünlüğü →
   Play uygulama imzalama → "Uygulama imzalama anahtarı sertifikası"
2. Oradaki SHA-256 değerini kopyalayın (iki nokta ayraçlı onaltılık)
3. base64'e çevirin:

       echo "AA:BB:...:FF" | tr -d ':' | xxd -r -p | base64

⚠ Uygulama base64 bekler. Onaltılık biçim olduğu gibi verilirse imza
denetimi HER ZAMAN başarısız olur.

⚠ Aynı sayfadaki SHA-1 ve SHA-256 değerleri Firebase Console → Proje
ayarları → Android uygulaması (`com.hizmetcep.app`) → "Parmak izi
ekle" bölümüne de eklenmelidir; yükleme anahtarınınkiler de eklenir.
Eksikse mağazadan indiren kullanıcılar SMS koduyla giriş yapamaz.

## 4. Paket üretimi

`release-hardened` iş akışı elle tetiklenir ve yalnız mağaza paketini
üretir:

    flutter build appbundle --release --build-number=<otomatik> --obfuscate ...

Çıktı: `.aab` → **mağazaya yüklenen**

⚠ Release APK BİLEREK ÜRETİLMEZ. Yükleme anahtarıyla imzalanmış bir
APK'yı kuran kişi, mağazadan güncelleme alırken "paket mevcut bir
paketle çakışıyor" hatası alır ve uygulamayı silmek zorunda kalır.
Gerçek cihaz testi Play Console → "Dahili test" kanalıyla yapılır;
oradan kurulan paket mağaza sürümüyle aynı imzayı taşır.

⚠ `build/symbols` klasörü SAKLANIR. Karartma açık olduğu için çökme
raporları bu dosyalar olmadan okunamaz. Her sürüm için ayrı saklayın.

## 5. Sürüm numarası

`pubspec.yaml` → `version: 1.0.0+1`

Soldaki kısım (`1.0.0`) kullanıcının gördüğü sürümdür ve elle
değiştirilir. Sağdaki sayı (versionCode) CI'da OTOMATİK verilir:
Play'deki en son numara ile Codemagic sayacının büyüğünün bir fazlası.
Elle artırmaya gerek yoktur.

⚠ Play aynı numarayı iki kez kabul etmez ve numara geri alınamaz.

⚠ Play'deki son numarayı okumak için Codemagic'te
`GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` (Play Console'a erişimi olan
Google Cloud servis hesabının JSON anahtarı, "secure") tanımlanmalıdır.
Tanımlı değilse yalnız Codemagic sayacı kullanılır; o da her derlemede
arttığı için numara yine geriye gitmez.

## 6. Play Console'da beyan edilecekler

⚠ Kodla ilgisi yok ama yükleme bunlarsız tamamlanmaz:

- **Gizlilik politikası** — yayınlanmış bir adreste durmalı
- **Veri güvenliği formu** — uygulama şunları topluyor:
  telefon numarası, ad-soyad, e-posta, konum (ilçe/mahalle),
  fotoğraf
- **Kamera izni gerekçesi** — ilan fotoğrafı çekimi
- Uygulama kategorisi, ekran görüntüleri, açıklama

## 7. Yayın öncesi son kontrol

- [ ] `key.properties` / CI değişkenleri hazır
- [ ] `API_BASE_URL` gerçek sunucuyu gösteriyor ve `https://`
- [ ] `CERT_PINS` boş (pinsiz yayın kararı) ya da verildiyse en az iki pin
- [ ] `APK_SIGNATURE_SHA256` doğru biçimde (base64)
- [ ] `.aab` üretildi ve `build/symbols` saklandı
- [ ] Gizlilik politikası yayında
- [ ] Veri güvenliği formu dolduruldu
