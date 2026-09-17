# HİZMETCEP — WEB DÖNÜŞÜM PLANI

Tarih: 15 Ağustos 2026
Referans: onaylı Android sürümü (MD5 `a9a996dd…`, 624 dosya) + Paket 1
iOS eklemeleri. Web bunun **üzerine** eklenecek.

⚠ **Değişmez kural:** Android ve iOS davranışı değişmeyecek. Ortak
kodda yapılan her değişiklik, mobil dalı **aynen bırakıp** yanına web
dalı ekleyecek.

---

# 1. PAKET SIRASI (riske göre, en güvenliden)

| # | Paket | Ortak koda dokunuyor mu? | Risk |
|---|---|---|---|
| **W1** | `web/` iskeleti + responsive temel (yalnız YENİ dosya) | ❌ Hayır | 🟢 |
| **W2** | `dart:io` izolasyonu — düşük riskli 4 dosya | ✅ Evet | 🟡 |
| **W3** | Fotoğraf: byte tabanlı web yolu | ✅ Evet | 🟠 |
| **W4** | Ağ katmanı + **sertifika sabitleme** | ✅ Evet | 🔴 |
| **W5** | MethodChannel web karşılıkları | ✅ Evet | 🟡 |
| **W6** | Masaüstü arayüz dönüşümü (ekranlar) | ✅ Evet | 🟠 |
| **W7** | secure storage · Google · WebSocket · deep link | ✅ Evet | 🟡 |

⚠ Her paketten sonra Android regresyonu (`android-debug`) koşulacak.
⚠ W4 **tek başına** yapılacak — sessiz bozulma riski en yüksek yer.

---

# 2. ORTAK KODDA DEĞİŞECEK DOSYALAR (tam liste)

## 2.1 `dart:io` taşıyan 12 dosya

| Dosya | Kullanım | Paket |
|---|---|---|
| `lib/data/store_links.dart` | `Platform.isIOS` | W2 |
| `lib/core/boot.dart` | `Platform.isIOS/isAndroid` | W2 |
| `lib/data/controllers/pending_listing_controller.dart` | `File(...)` | W2 |
| `lib/screens/widgets/foto_goruntuleyici.dart` | `Image.file` | W3 |
| `lib/screens/widgets/photo_picker.dart` | `File`, `localPath` | W3 |
| `lib/screens/listing_detail_screen.dart` | `Image.file` | W3 |
| `lib/screens/job_detail_screen.dart` | `Image.file` | W3 |
| `lib/screens/profile_screen.dart` | `Image.file` | W3 |
| `lib/screens/create_listing_screen.dart` | `File(...)` | W3 |
| `lib/screens/register_screen.dart` | `File(...)` | W3 |
| `lib/data/remote/api_client.dart` | `SocketException` | W4 |
| `lib/data/remote/sertifika_sabitleme.dart` | `HttpClient`, `X509` | **W4** |

## 2.2 MethodChannel taşıyan 5 dosya (W5)

`deep_links.dart` · `ekran_korumasi.dart` · `cihaz_butunlugu.dart` ·
`native_splash.dart` · `card_tokenization_bridge.dart`

⚠ Üçü (`cihaz_butunlugu`, `native_splash`, `ekran_korumasi`) **zaten
`kIsWeb` ile korumalı** — web'de çağrı yapılmıyor. Bunlarda iş yok.
Gerçek iş `deep_links` ve `card_tokenization_bridge`'de.

## 2.3 Ekranlar (W6)

41 ekran dosyası. ⚠ Ama **hepsine dokunulmayacak**: masaüstü kabuğu
ve genişlik sınırı ortak bileşenden gelecek, ekranlar tek tek
sarmalanacak.

---

# 3. KRİTİK ALANLAR — NEDEN VE NASIL

## K1 — Sertifika sabitleme (🔴 en tehlikeli)

`SertifikaSabitleme` `HttpClient` + `X509Certificate` +
`badCertificateCallback` üzerine kurulu; üçünün de web karşılığı yok.
`api_client.dart:58-60` istemciyi buna göre seçiyor.

**Yöntem:** koşullu import ile iki uygulama —
`sertifika_sabitleme_io.dart` (bugünkü kod **aynen**) ve
`sertifika_sabitleme_web.dart` (etkin değil, `http.Client` döner).
⚠ Mobil dosyanın içeriği **tek satır değişmeyecek**.

**Kanıt şartı:** değişiklikten sonra mobilde pin denetiminin hâlâ
etkin olduğu testle gösterilecek.

## K2 — Fotoğraf modeli (🟠)

`PhotoItem.localPath` dosya yolu varsayıyor; yedi dosyaya yayılmış.

**Yöntem:** `localPath` **kaldırılmayacak**. Modele opsiyonel bir
byte alanı eklenecek ve gösterim tek bir ortak bileşene toplanacak:
mobilde `Image.file`, web'de `Image.memory`. ⚠ Mobil akış aynen
çalışmaya devam edecek.

## K3 — 64 kaynak-metin testi (🔴 CI riski)

Testlerin 64'ü lib kaynağının ham metnini okuyor. En çok kilitlenen:
`register_screen` (42 iddia), `create_listing_screen` (26),
`login_screen` (22).

**Yöntem:** iddialar **gevşetilmeyecek**. Koşullu import satırı
eklenen her dosyadan sonra ilgili testler kontrol edilecek; iddia
yeni sözleşmeye göre **sıkılaştırılarak** güncellenecek.

## K4 — `pubspec.yaml`

⚠ **Yeni paket eklenmeyecek.** Kontrol ettim: web için gereken her
şey mevcut paketlerle karşılanıyor —
`image_picker` web destekliyor (XFile → bytes),
`flutter_secure_storage` web destekliyor,
`url_launcher` web destekliyor,
`socket_io_client` web destekliyor,
`google_sign_in` web için ayrı yapılandırma ister ama paket aynı.
`flutter_web_plugins` Flutter SDK içinde gelir, ayrı paket değildir.

---

# 4. WEB ARAYÜZ İLKELERİ

⚠ Web, telefonun büyütülmüş hâli olmayacak.

**Kırılma noktaları:** `<600` mobil · `600-1023` tablet ·
`1024-1439` laptop · `≥1440` geniş masaüstü.

**İçerik genişliği:** okunabilirlik için üst sınır (form ve metin
sütunları ~560-720 px), sayfa geniş ekranda **ortalanır**.
⚠ Sağa sola devasa boşluk bırakılmayacak: liste ve ızgaralar
genişledikçe **sütun sayısı artacak**, kartlar gerilmeyecek.

**Görseller:** ilan fotoğrafı, profil görseli ve kategori görselleri
masaüstünde büyütülecek; **en-boy oranı korunacak** (`AspectRatio`),
küçük karta sıkıştırılmayacak.

**Tipografi:** masaüstünde gövde metni büyütülecek; mobil ölçüler
aynen kalacak.

**Dokunma hedefleri:** masaüstünde düğmeler küçülmeyecek; imleç ve
odak durumları eklenecek.

⚠ Bunların hiçbiri mobil değerleri değiştirmeyecek — hepsi
**genişliğe bağlı** dallar olacak.

---

# 5. BU PAKETTE (W1) YAPILANLAR

Yalnız **yeni dosya**. Mevcut hiçbir dosya değişmedi.

1. `web/index.html`, `web/manifest.json`, ikonlar, favicon
2. `lib/ui/olcu.dart` — kırılma noktaları ve genişlik yardımcıları
3. `lib/ui/web_kabuk.dart` — masaüstü kabuğu (ortalama + üst sınır)
4. `test/web_olcu_test.dart` — kırılma noktası kilidi
5. `codemagic.yaml` — web iş akışı (dosya SONUNA ekleme)

⚠ W1'den sonra web **henüz derlenmez**: `dart:io` engeli duruyor.
Bu beklenen durumdur — ilk derleme kırılan dosyaların gerçek
listesini verecek ve W2 o listeye göre yapılacak.
