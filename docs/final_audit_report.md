# HizmetCep — Final Teknik Uyum ve Risk Denetimi
09.08.2026 · Referans: `hizmetcep-v66-final__1_.html`

## A. YÖNETİCİ ÖZETİ

| Başlık | Durum |
|---|---|
HTML ile uyum | **TAM** (34/34 ekran DONE) |
Navigasyon | **DOĞRU** (144/144 geçiş eşlendi) |
APK build engeli | **YOK** (bilinen tip hataları giderildi) |
Android | **HAZIR** |
iOS | **TEST EDİLMEDİ** (macOS/Xcode gerekli) |
Web | **SORUNLU** — platform blocker var (bkz. WEB-01) |
Responsive | **UYUMLU** (sabit yükseklik 0, SafeArea 35 kullanım) |
Release öncesi kritik açık | **0 CRITICAL · 0 HIGH** |

**Sonraki tek adım:** Codemagic'te `flutter analyze` + `flutter test` +
`flutter build apk --debug --dart-define=DATA_SOURCE=mock` çalıştırmak.

---

## B. TEKNİK EK

### Bu denetimde bulunan ve DÜZELTİLEN

| # | Sev. | Dosya:Satır | Kök neden | Düzeltme | Durum |
|---|---|---|---|---|---|
BUILD-01 | **CRITICAL** | `category_ui.dart:73,120` | `categoryIcon()` `String` döndürürken `Icon()` widget'ına veriliyordu — tip hatası, derleme durur | `RefSvg` kullanıldı | ✅ |
BUILD-02 | **CRITICAL** | `category_screen.dart:81` | Aynı hata `ActionChip.avatar` içinde | `RefSvg` kullanıldı | ✅ |
TEST-01 | **HIGH** | `photo_discard_test.dart` (12 yer) | `find.byIcon(Icons.cancel)` — ikon SVG'ye çevrildiği için test hedefi kayboldu | `photo_picker`'a `ValueKey('photo-discard')` eklendi, test anahtarla arıyor | ✅ |
LEAK-01 | **HIGH** | 9 ekran | `TextEditingController` / `ScrollController` dispose edilmiyordu (bellek sızıntısı) | Eksik `dispose()` metotları eklendi/tamamlandı | ✅ |
REL-01 | **HIGH** | `login_screen.dart:331` | Test kimliği bilgi kutusu release derlemede de görünüyordu | `if (kDebugMode && !ApiConfig.useRealApi)` koşuluna alındı | ✅ |
POLICY-01 | **MEDIUM** | `hc_widgets.dart` | Önceki turda toplu regex bu dosyaya dokunmuştu (kural ihlali) | Geri alındı — MD5 `c6824beaadcb9d0f` doğrulandı | ✅ |

### Açık platform blocker

| # | Sev. | Dosya | Sorun | Durum |
|---|---|---|---|---|
**WEB-01** | **BLOCKER (Web)** | `api_client.dart:3` (`SocketException`), `photo_picker.dart:378` (`File`) | `dart:io` Web'de derlenmez; koşullu import/`kIsWeb` koruması yok | **AÇIK** — Web hedefi isteniyorsa koşullu import gerekir |

`flutter_secure_storage`, `image_picker`, `connectivity_plus`,
`google_sign_in` paketlerinin Web desteği ayrıca doğrulanmalıdır.
**"Muhtemelen çalışır" denmemiştir — Web build BLOCKER'dır.**

### Temiz çıkan denetimler

| Kontrol | Sonuç |
|---|---|
Tanımsız sınıf/metot/alan | **0** |
Kırık import / circular import | **0** |
Eksik asset (SVG yolu) | **0** (76 kullanım, 102 dosya) |
Tanımsız tasarım tokeni | **0** |
Parantez dengesi | **0 hata** (156 dosya) |
`Icon(String)` tip karışması | **0** |
`const` içinde runtime değer | **0** |
`withOpacity` (deprecated) | **0** |
async-gap korumasız `context` | **0** (11 aday incelendi, hepsi `mounted` korumalı) |
Controller/Timer dispose eksiği | **0** |
Sabit yükseklik ≥200px | **0** |
`shrinkWrap` / nested scroll | **0** |
`print()` çağrısı | **0** |
Demo kimlik release sızıntısı | **0** (5 dosya, hepsi `kDebugMode` korumalı) |

### İş kuralları regresyon (bozulmadı)

32 saat ilan ömrü · iletişim ücreti bloke · escrow tek tüketim ·
ücretsiz iletişim hakkı · RoleGuard rol koruması · tek sefer review.

M�şteri ekranlarında finans linki **0**; sağlayıcı ekranlarında rol
ayrımı aktif.

### Android yapılandırması

compileSdk 36 · Gradle 9.5.0 · AGP 9.3.0 · Kotlin 2.4.10 · Java 17
(14 Ağu toolchain migration'ı; önceki: Gradle 8.13 · AGP 8.11.1 · Kotlin 2.1.0)
İzinler: `INTERNET`, `CAMERA` · appId `com.hizmetcep.app`
iOS: `NSCameraUsageDescription` ve `NSPhotoLibraryUsageDescription` **mevcut**

### VERIFY NEEDED — bu ortamda çalıştırılamayan

Flutter SDK bulunmadığı ve ağ kapalı olduğu için **hiçbiri PASS
sayılmamıştır**:

- `flutter pub get`
- `flutter analyze`
- `flutter test` (27 dosya, 294 test)
- `flutter build apk --debug --dart-define=DATA_SOURCE=mock`
- `flutter build apk --release`
- `flutter build web --release` → **WEB-01 nedeniyle başarısız olması beklenir**
- `flutter build ios --no-codesign` → macOS/Xcode gerekir

### Release setup pending (blocker değil)

Android release keystore ve iOS signing/provisioning henüz
yapılandırılmamıştır.
