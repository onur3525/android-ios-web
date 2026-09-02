# Flutter Platform İskeleti — Kurulum Notları

**2026-07-31**

Bu belge, teslim paketindeki platform yapısını ve **elde edilmesi
gereken iki binary dosyayı** açıklar.

---

## ⚠ PAKETTE EKSİK OLAN TEK DOSYA

**iOS AppIcon PNG'leri artık pakettedir** — gerçek HizmetCep logosundan
üretildi (aşağıya bakınız).

Eksik kalan **tek** dosya `gradle-wrapper.jar`'dır:

### 1. `android/gradle/wrapper/gradle-wrapper.jar`

`gradle-wrapper.properties` pakette **vardır** ve Gradle 8.13'ü işaret
eder. Eksik olan yalnız `.jar` dosyasıdır.

**Elde etme (üç yoldan biri):**

```bash
# A) Gradle kuruluysa — wrapper'ı yeniden üretir
cd flutter/android && gradle wrapper --gradle-version 8.13

# B) Flutter SDK ile — eksik platform dosyalarını tamamlar
cd flutter && flutter create --platforms=android .

# C) Doğrudan indirme
curl -L -o android/gradle/wrapper/gradle-wrapper.jar \
  https://raw.githubusercontent.com/gradle/gradle/v8.13.0/gradle/wrapper/gradle-wrapper.jar
```

### Uygulama simgeleri — PAKETTE MEVCUT

**iOS:** 9 AppIcon + 3 LaunchImage PNG'si `assets/logo/logo.png`
(512×512 RGB) kaynağından üretildi ve pakete eklendi.

| Dosya | Ölçü |
|---|---|
`Icon-App-20x20@2x.png` | 40×40 |
`Icon-App-20x20@3x.png` | 60×60 |
`Icon-App-29x29@2x.png` | 58×58 |
`Icon-App-29x29@3x.png` | 87×87 |
`Icon-App-40x40@2x.png` | 80×80 |
`Icon-App-40x40@3x.png` | 120×120 |
`Icon-App-60x60@2x.png` | 120×120 |
`Icon-App-60x60@3x.png` | 180×180 |
`Icon-App-1024x1024@1x.png` | 1024×1024 |

Tümü **RGB** (alfa kanalı yok — App Store şartı), kare, LANCZOS ile
yeniden boyutlandırıldı, en-boy oranı korundu.

**Android:** PNG **gerekmez.** Adaptive icon (vektör) kullanıldı:
`mipmap-anydpi-v26/ic_launcher.xml` + `drawable/ic_launcher_foreground.xml`.
Android 8.0 öncesi için `mipmap-*/ic_launcher.xml` yedekleri de vektördür.

---

## İlk build öncesi

```bash
cd flutter
flutter pub get          # ios/Flutter/Generated.xcconfig üretir
cd ios && pod install    # Runner.xcworkspace'i tamamlar
```

`Generated.xcconfig` ve `Pods/` **kaynak kontrolüne girmez**;
`flutter pub get` ve `pod install` bunları üretir.

---

## Korunan proje kararları

| Ayar | Değer |
|---|---|
Android `applicationId` | `com.hizmetcep.app` |
Android `namespace` | `com.hizmetcep.app` |
iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.hizmetcep.app` |
Derin bağlantı şeması | `hizmetcep://payment/...` |
Minimum iOS | 12.0 |
Gradle | 8.13 |
AGP | 8.11.1 |
Kotlin | 2.1.0 |
JDK | 17 |

---

## Paket izinleri — karşılaştırma

| Paket | Android | iOS |
|---|---|---|
`image_picker` | `CAMERA` | `NSCameraUsageDescription` · `NSPhotoLibraryUsageDescription` · `NSPhotoLibraryAddUsageDescription` |
`url_launcher` | `<queries>` https + market | `LSApplicationQueriesSchemes` |
`google_sign_in` | — (Gradle eklentisi) | `CFBundleURLTypes` → **`REVERSED_CLIENT_ID_BURAYA`** ⚠ |
`flutter_secure_storage` | — (EncryptedSharedPreferences) | `NSFaceIDUsageDescription` |
`connectivity_plus` | `ACCESS_NETWORK_STATE` (eklenti manifest'i) | `NSLocalNetworkUsageDescription` |
`socket_io_client` | `INTERNET` | — |

> ⚠ `REVERSED_CLIENT_ID_BURAYA` yer tutucudur. Google Cloud Console'dan
> alınan `GoogleService-Info.plist` içindeki gerçek değerle
> **değiştirilmelidir**. Aksi hâlde iOS'ta Google girişi çalışmaz.

---

## Kart tokenizasyon kanalı

`MethodChannel('hizmetcep/card_tokenizer')` **her iki platformda da
kayıtlıdır**:

| Platform | Dosya | Durum bayrağı |
|---|---|---|
Android | `MainActivity.kt` | `CARD_TOKENIZER_READY = false` |
iOS | `AppDelegate.swift` | `cardTokenizerReady = false` |

Her iki taraf da `ping` çağrısına **`false`** döner; Dart tarafı
`UnconfiguredCardTokenizer` kullanır ve kart kaydı açık hata verir.

**Sağlayıcı seçildiğinde:** bayrağı `true` yapıp `tokenize` gövdesine
sağlayıcı SDK çağrısını ekleyin. Beklenen dönüş:

```
{ "paymentToken": "...", "masked": "**** **** **** 4242", "brand": "Mastercard" }
```

**Dart tarafında hiçbir dosya değişmez.**

---

## Release imzalama

`android/key.properties` gereklidir — bkz. `canli-kurulum/ANDROID_YAYINLAMA.md`.
Dosya yoksa release build **açık hata ile durur**, debug anahtara düşmez.
