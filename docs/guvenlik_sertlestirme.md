# GÜVENLİK SERTLEŞTİRME — FLUTTER TARAFI

⚠ Bu belge, uygulamada YAPILANLARI ve SÜRÜM ALIRKEN yapılması
gerekenleri ayırır. Kod tarafı hazırdır; işaretli maddeler derleme
ve altyapı kararı bekler.

## 1. Ekran koruması (FLAG_SECURE) — YAPILDI

Teklif detayı ekranında açıktır. Kapsadığı: ekran görüntüsü, ekran
kaydı ve son uygulamalar listesindeki önizleme.

⚠ Yalnız Android. iOS'ta FLAG_SECURE karşılığı yoktur; oradaki
önizleme karartması ayrı bir iştir ve YAPILMAMIŞTIR.

⚠ Sayaç mantığı: iç içe ekranlarda koruma erken kapanmaz.

## 2. Teşhis bayrakları — YAPILDI

`FOCUS_LOG`, `NO_ONCHANGED`, `STATIC_REGION` artık `kReleaseMode`
ile AND'lenir. Sürüm paketinde hiçbir `--dart-define` bileşimi
teşhis panelini açamaz.

## 3. Kart alanlarında pano — YAPILDI

Kart numarası ve CVV alanlarında seçim ve kopyala/yapıştır menüsü
kapalıdır. Panoya alınan kart bilgisini cihazdaki başka uygulamalar
okuyabilir.

## 4. Sertifika sabitleme — ALTYAPI HAZIR, PİN BEKLİYOR

    flutter build apk --release \
      --dart-define=CERT_PINS=<pin1>,<pin2>

⚠ Pin verilmezse sabitleme DEVRE DIŞIDIR ve davranış değişmez.
Bilerek böyledir: yanlış pinle çıkılan sürüm uygulamayı tamamen
çalışmaz hâle getirir.

⚠ EN AZ İKİ PİN verilmelidir (mevcut + yedek). Tek pinli sürüm,
sertifika yenilendiği gün kırılır.

### Güvenlik turu 2 (30 Eyl) — SPKI, ad, süre, WebSocket, yükleme

- **Pin biçimi:** `sha256/<base64>` = açık anahtar (SPKI) pini; ÖNERİLEN.
  Aynı anahtarla yenilenen sertifikada kırılmaz. Değer:

      openssl x509 -in sertifika.pem -pubkey -noout \
        | openssl pkey -pubin -outform der \
        | openssl dgst -sha256 -binary | base64

  Öneksiz değerler eski biçimdir (tam sertifika özeti); geriye dönük
  uyumluluk için kabul edilir, yeni sürümlerde kullanılmamalıdır.
- **Hangi sertifikalar:** Sistem kökleri kapalıyken Dart, doğrulamanın
  başarısız olduğu zincir halkasını geri çağrıya verir (yaprak ya da ara
  sertifika olabilir). CERT_PINS hem yaprak hem ara sertifikanın SPKI
  pinini ve bir YEDEK anahtar pinini içermelidir. Pinler ilk sürümden
  önce gerçek sunucuya karşı bir test derlemesiyle DOĞRULANMALIDIR.
- **Ad denetimi:** Sabitlemeli istemci yalnız `API_BASE_URL`'in ana
  bilgisayar adına bağlanır; başka ad pin tutsa bile reddedilir.
- **Süre denetimi:** Süresi dolmuş/başlamamış sertifika reddedilir.
- **WebSocket:** REST ile aynı pin + ad + süre denetimi
  (`sabitliBolgede`, `HttpOverrides.runZoned`). `HttpOverrides.global`
  KULLANILMAZ.
- **Dosya yükleme:** Depolama sağlayıcısının sertifikası farklı olduğu
  için API pinleri uygulanmaz. Bunun yerine: yalnız https, izinli alan
  adı (`--dart-define=STORAGE_HOSTS=...`, virgülle; `.` ile başlayan
  değer sonek), SigV4 imzalı ve süresi geçerli adres. Release'te
  `STORAGE_HOSTS` boşsa yükleme REDDEDİLİR.
- **Web:** Sabitleme yapılamaz; tarayıcının TLS modeli geçerlidir.

Pin üretimi (sunucu canlıya çıktıktan sonra):

    openssl s_client -connect api.hizmetcep.com:443 -showcerts </dev/null \
      | openssl x509 -outform DER | openssl dgst -sha256 -binary | base64

## 5. Karartma (obfuscation) — SÜRÜM KOMUTUNA EKLENECEK

    flutter build apk --release \
      --obfuscate --split-debug-info=build/symbols

⚠ Sembol dosyaları SAKLANMALIDIR; yoksa çökme raporları okunamaz.

⚠ Karartma yalnız Dart kodunu kapsar; uç nokta adresleri ve iş
kuralları yine de tersine mühendislikle çıkarılabilir. Sunucu
tarafı doğrulama bunun yerine geçmez.

## 6. Ödeme dönüş bağlantısı — KISMEN

Bugün `hizmetcep://payment/return` özel şeması kullanılır. Başka bir
uygulama aynı şemayı kaydedip dönüşü yakalayabilir.

⚠ Para riski YOKTUR: sonuç yalnız sunucudan doğrulanır ve oturum
kimliği uygulamanın kendi belleğinden okunur; bağlantıdan gelen
değer kullanılmaz.

Kalıcı çözüm doğrulanmış App Links'tir ve ALTYAPI GEREKTİRİR:

- `https://hizmetcep.com/.well-known/assetlinks.json` yayınlanmalı
- imza parmak izi (SHA-256) bu dosyada yer almalı
- manifest'e `autoVerify="true"` ile https intent-filter eklenmeli

Alan adı ve imzalama anahtarı kesinleşmeden yapılamaz.

## 7. İstemci-only kurallar — SUNUCU BEKLİYOR

Aşağıdaki kurallar YALNIZ uygulamada uygulanıyor. Değiştirilmiş bir
istemci bunları atlayabilir:

- çıkar çatışması (kendi kategorisinde ilan açma yasağı)
- ilan ömrü ve durum geçişleri
- aynı ilana ikinci teklif verilememesi

⚠ Hiçbiri Flutter'da çözülemez; sunucuda TEKRAR uygulanmalıdır.
