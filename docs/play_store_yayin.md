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
| `CERT_PINS` | en az iki pin, virgülle |
| `APK_SIGNATURE_SHA256` | imza özeti (aşağıda) |

İmza özetini almak:

    keytool -list -v -keystore hizmetcep.jks -alias hizmetcep \
      | grep "SHA256:" 

⚠ `keytool` çıktısı iki nokta ayraçlı onaltılıktır; uygulama base64
bekler. Dönüştürme yapılmadan verilirse imza denetimi HER ZAMAN
başarısız olur — bu yüzden özet elde edilene kadar değişken BOŞ
bırakılmalıdır (boşken denetim kapalıdır).

## 4. Paket üretimi

`release-hardened` iş akışı elle tetiklenir. İçinde iki komut çalışır:

    flutter build apk --release --obfuscate ...        # test/elle kurulum
    flutter build appbundle --release --obfuscate ...  # MAĞAZAYA GİDEN

İki çıktı verir:

- `.aab` → **mağazaya yüklenen**
- `.apk` → elle kurulum ve test

⚠ `.aab` telefona doğrudan kurulamaz. Test için `.apk` kullanılır.

⚠ `build/symbols` klasörü SAKLANIR. Karartma açık olduğu için çökme
raporları bu dosyalar olmadan okunamaz. Her sürüm için ayrı saklayın.

## 5. Sürüm numarası

`pubspec.yaml` → `version: 1.0.0+1`

⚠ Sağdaki sayı her mağaza yüklemesinde MUTLAKA artar. Play aynı
numarayı iki kez kabul etmez ve numara geri alınamaz.

## 6. Play Console'da beyan edilecekler

⚠ Kodla ilgisi yok ama yükleme bunlarsız tamamlanmaz:

- **Gizlilik politikası** — yayınlanmış bir adreste durmalı
- **Veri güvenliği formu** — uygulama şunları topluyor:
  telefon numarası, ad-soyad, e-posta, konum (ilçe/mahalle),
  fotoğraf, ödeme bilgisi (sağlayıcıda saklanır)
- **Kamera izni gerekçesi** — ilan fotoğrafı çekimi
- Uygulama kategorisi, ekran görüntüleri, açıklama

## 7. Yayın öncesi son kontrol

- [ ] `key.properties` / CI değişkenleri hazır
- [ ] `API_BASE_URL` gerçek sunucuyu gösteriyor ve `https://`
- [ ] `CERT_PINS` en az iki pin içeriyor
- [ ] `APK_SIGNATURE_SHA256` doğru biçimde (base64)
- [ ] `.aab` üretildi ve `build/symbols` saklandı
- [ ] Gizlilik politikası yayında
- [ ] Veri güvenliği formu dolduruldu
