# iOS — TEST VE YAYIN

⚠ Bu belge kodda YAPILANLARI ve SENDE olan adımları ayırır.
Kod tarafı hazırdır; işaretli adımlar Apple hesabı ve altyapı ister.

## 0. Sıfır maliyetli ilk adım

`ios-simulator` iş akışı **Apple hesabı olmadan** çalışır. İmzasız,
simülatör hedefli bir derleme yapar. Amacı tek şeydir: iOS tarafının
gerçekten derlendiğini göstermek. Pod çakışması, eksik izin anahtarı
ve taban sürüm uyuşmazlığı burada çıkar.

⚠ Çıktı `.app` klasörüdür ve **gerçek telefona kurulamaz**. Cihazda
denemek için Apple Developer üyeliği şarttır — bunun ücretsiz yolu
yoktur.

## 1. Kodda yapılanlar

**Kenardan geri kaydırma düzeltildi.** `theme.dart` iOS geçişine de
`HizliGecis` atıyordu; bu `CupertinoPageTransitionsBuilder`ı eziyor
ve swipe-back jestini öldürüyordu. iOS artık Cupertino kullanır,
Android'in hızlı geçişi aynen kalır. Kilit:
`test/klavye_standardi_test.dart`.

**Gizlilik bildirimi eklendi.** `ios/Runner/PrivacyInfo.xcprivacy`
oluşturuldu ve **Xcode projesine kaydedildi** (dosyayı diske koymak
yetmez; hedefe ekli değilse pakete girmez). İçerik uygulamanın
gerçek davranışıdır: izleme yok, reklam yok.

**⚠ Taban sürüm DEĞİŞTİRİLMEDİ — karar ERTELENDİ.** Proje hâlâ iOS
12.0 tabanıyla yapılandırılmıştır (`Podfile`, `post_install` ve Xcode
projesindeki üç yapılandırma). Bağımlılıkların güncel sürümleri
(share_plus 12, image_picker 1.1, connectivity_plus 6,
google_sign_in 6.2) daha yüksek taban isteyebilir, ancak bu **tahmin
edilerek değil ölçülerek** kararlaştırılacak: ilk `pod install`
çıktısı görüldükten sonra, gerçek gereksinim neyse o yazılacak.

⚠ Taban sürüm değiştirilecekse **üç yer birden** güncellenmelidir:
`Podfile` başındaki `platform :ios`, `post_install` içindeki
`IPHONEOS_DEPLOYMENT_TARGET` ve Xcode projesindeki üç yapılandırma.
Biri geride kalırsa hata pod kurulumunda değil, derlemenin sonunda
çıkar. `ios-simulator` iş akışı bu üç değeri her koşuda yan yana
yazdırır.

**İki iş akışı eklendi:** `ios-simulator` ve `ios-testflight`.

## 2. Sende olanlar

### 2.1 Apple Developer Program

Yıllık ücretli üyelik. Bunsuz cihaza kurulum, TestFlight ve mağaza
yayını mümkün değildir.

### 2.2 App Store Connect API anahtarı

App Store Connect → Users and Access → Integrations → App Store
Connect API. Üç bilgi çıkar:

| Değer | Nereden |
|---|---|
| Issuer ID | anahtar listesinin üstünde |
| Key ID | oluşturulan anahtarın yanında |
| `.p8` dosyası | **yalnız bir kez indirilir** |

⚠ `.p8` dosyası bir daha indirilemez. Kaybolursa anahtar iptal edilip
yenisi üretilir.

Codemagic → Environment variables → `ios_signing` grubu (hepsi
secure):

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_PRIVATE_KEY` (`.p8` içeriği)
- `APP_STORE_APP_ID` (App Store Connect'teki sayısal uygulama kimliği)

### 2.3 Uygulama kimliği

`com.hizmetcep.app` hem Apple Developer portalında hem App Store
Connect'te kayıtlı olmalı. Android'deki `applicationId` ile aynıdır;
öyle kalması ileride işini kolaylaştırır.

### 2.4 Google ile giriş

`ios/Runner/Info.plist` içinde `REVERSED_CLIENT_ID_BURAYA` yer
tutucusu duruyor. Google Cloud Console'dan alınan
`GoogleService-Info.plist` içindeki `REVERSED_CLIENT_ID` değeriyle
değiştirilmeli.

⚠ Değiştirilmezse Google girişi iOS'ta **sessizce** çalışmaz: hata
çıkmaz, kullanıcı düğmeye basar ve hiçbir şey olmaz. `ios-testflight`
akışı bu yer tutucuyu bulursa derlemeyi durdurur.

## 3. App Store incelemesinin iki sert kuralı

### 3.1 Sign in with Apple — ⚠ KARAR BEKLİYOR

Apple, üçüncü taraf giriş sunan uygulamalarda Sign in with Apple'ı da
zorunlu tutar. Uygulamada `google_sign_in` var, Sign in with Apple
yok.

⚠ **TestFlight'ı engellemez, MAĞAZA İNCELEMESİNİ engeller.** Yani
test etmeye bugün başlayabilirsin; yayına çıkmadan önce çözülmeli.

İki yol vardır:

1. **Sign in with Apple eklenir.** Paket, ekran, sunucuda kimlik
   doğrulama ve hesap eşleştirme gerekir. ⚠ Apple'ın "e-postamı
   gizle" seçeneği takma bir adres üretir; hesap modelimiz kimliği
   `userId` üzerinden tuttuğu için bu sorun çıkarmaz, ama e-posta
   ile iletişim kurulamayacağı bilinmelidir.
2. **iOS'ta Google girişi kapatılır.** Geriye e-posta + şifre ve
   telefon + OTP kalır; ikisi de zaten var. Daha az iş, daha az risk.

### 3.2 Hesap silme — ✓ KARŞILANIYOR

Hesap oluşturan uygulamalarda uygulama içi hesap silme zorunludur.
Bizde var: üç aşamalı akış (açıklama → Devam Et → şifre doğrulama →
Hesabımı Sil).

⚠ Ancak sunucu tarafında bu **talep** olarak düşüyor ve bugün
talepleri görecek bir yüzey yok. İnceleme sırasında Apple silmenin
gerçekten sonuçlandığını görmek isteyebilir.

## 4. Kodda kalan iOS eksikleri

**Ekran koruması yok.** Android'de `FLAG_SECURE` teklif detayında
açık. iOS'ta karşılığı yoktur; oradaki önizleme karartması ayrı bir
iştir ve YAPILMAMIŞTIR.

**Push bildirim kurulmadı.** APNs anahtarı ve yetkilendirme
(capability) gerekir.

**Evrensel bağlantı (Universal Links) yok.** Ödeme dönüşü bugün
`hizmetcep://` özel şemasıyla çalışıyor. Para riski yoktur —
sonuç yalnız sunucudan doğrulanır — ama kalıcı çözüm
`apple-app-site-association` dosyasıdır ve alan adı gerektirir.

## 5. Sıra önerisi

1. `ios-simulator` koştur → derleniyor mu, gör. **Bugün yapılabilir.**
2. Apple üyeliği + API anahtarı + uygulama kimliği.
3. `ios-testflight` koştur → cihaza kur, gerçek testler.
4. Sign in with Apple kararı → mağaza incelemesi.

⚠ Adım 1 ile 3 arasında kod tarafında yapılacak bir şey yoktur;
bekleyen tek şey Apple hesabıdır.
