# HESAP MODELİ KARARI — MEVCUT KOD DENETİMİ VE BACKEND SÖZLEŞMESİ

**Karar tarihi:** 14 Ağustos 2026 · **Belge:** kullanıcı hesap/giriş/kurtarma kararı
**Durum:** kod DEĞİŞTİRİLMEDİ — bu belge denetim ve sözleşme çıkarımıdır.

Bu belge iki şey yapar:
1. Mevcut Flutter kodunun karara ne kadar uyduğunu **koddan** çıkarır.
2. Backend'in sağlaması gereken uçları ve hata kodlarını yazar.

⚠ Backend bu depoda yok. Talimatın kendi kuralı geçerli: **Flutter'da
sahte başarı üretilmez**, eksik sözleşme açıkça raporlanır.

---

## 1. KARARA UYAN YANLAR (değiştirilmesi gerekmiyor)

### 1.1 Kimlik zaten userId

`Account.id` bir UUID (`_uuid.v4()`), telefon değil. Denetlediğim
bağlantı noktalarının **tamamı** userId taşıyor:

| Veri | Alan | Kaynak |
|---|---|---|
| İlan | `ownerId` | `me.id` (create_listing_screen) |
| Teklif | `providerId` | `me.id` (job_detail_screen) |
| Değerlendirme | `providerId` / `authorId` | hesap id |
| Cüzdan / ledger | hesap id | wallet_repository |
| Sohbet | katılımcı id | chat |

⚠ Telefonla ilişkilendirilen **hiçbir** kayıt bulamadım. Bu, kararın
en pahalı maddesinin (veri taşıma) **zaten karşılandığı** anlamına
geliyor. Telefon/e-posta değişikliği veri kaybı üretmez.

### 1.2 Telefon/e-posta zaten değiştirilebilir alan

`Account.phone` ve `Account.email` `final` değil; profil ekranı
ikisini de güncelliyor. Model karara uygun.

### 1.3 OTP zaten telefon doğrulama için var

`register` `otpVerified` olmadan hesap açmıyor. Kayıt akışındaki OTP
karara **uygun** ve korunacak.

---

## 2. KARARLA ÇELİŞEN YANLAR (değişmesi gerekiyor)

### 2.1 Giriş TELEFON + ŞİFRE ile yapılıyor — karar bunu yasaklıyor

`AuthRepository.login(String phone, String pass)` numarayı
`findByPhone` ile buluyor ve şifre doğruluyor.

Karar: telefonla girişte **şifre kullanılmaz**, SMS OTP kullanılır;
şifreli giriş **e-posta** ile yapılır.

Gereken:
- `login(email, password)` — e-posta ile
- `girisIcinKodGonder(phone)` + `girisiKodlaTamamla(phone, otp)` — telefonla
- `findByEmail(email)` — **şu an YOK**

### 2.2 E-posta benzersizliği DENETLENMİYOR

Kayıtta yalnız `findByPhone` çakışma denetimi var. E-posta için
hiçbir denetim yok: aynı e-posta iki hesaba girebilir.

Karar: "Aynı telefon veya aynı e-posta birden fazla aktif hesaba
bağlanamaz."

⚠ E-posta giriş kimliği olacaksa bu **güvenlik açığıdır**: iki hesap
aynı e-postaya sahipse "e-posta + şifre" hangi hesabı açacağı
belirsizdir.

### 2.3 Şifre sıfırlama TELEFON + OTP üzerinden

`forgotStart(phone)` → `findByPhone` → OTP. Karar: ana yol e-posta
reset link; telefon OTP yalnız **alternatif** kurtarma.

Ayrıca `forgotStart` hesap yoksa hata döndürüyor — bu **hesap
enumerasyonu**. Karar nötr cevap istiyor.

⚠ Bu daha önce bilinçli kabul edilmişti ("kullanıcı numara
enumerasyonunu kabul etti"). Yeni karar bunu **geri alıyor**.

### 2.4 E-posta doğrulama bağlantısı YOK

`emailVerified` alanı var ama doğrulama bağlantısı akışı yok;
`startEmailVerification` çağrılmayan sarmalayıcılardan biri.

---

## 3. BACKEND SÖZLEŞMESİ — GEREKEN UÇLAR

⚠ Hiçbiri Flutter'da taklit edilmeyecek. Sunucu sağlamadan bu akışlar
**mock'ta bile "başarılı" gösterilmeyecek**.

### 3.1 Giriş

```
POST /auth/login/email      { email, password }        → oturum
POST /auth/login/phone/start{ phone }                  → nötr cevap
POST /auth/login/phone/verify{ phone, code }           → oturum
```
İkisi de **aynı userId** için oturum döndürür.

### 3.2 Şifre sıfırlama (e-posta — ANA YOL)

```
POST /auth/password-reset/request  { email }   → NÖTR cevap
POST /auth/password-reset/validate { token }   → valid|expired|used|invalid
POST /auth/password-reset/confirm  { token, newPassword }
```
Token: süreli, tek kullanımlık, düz metin saklanmaz.

### 3.3 Hesap kurtarma (telefon — ALTERNATİF YOL)

```
POST /auth/account-recovery/start  { phone }        → nötr cevap
POST /auth/account-recovery/verify { phone, code }  → kısa ömürlü reset yetkisi
POST /auth/password-reset/confirm  { token, newPassword }
```
⚠ OTP burada **şifreyi doğrulamaz**, telefon sahipliğini doğrular.

### 3.4 İletişim bilgisi değişikliği

```
POST /me/phone/change/start  { newPhone }      → OTP gönder
POST /me/phone/change/verify { newPhone, code }→ bağla, eskisini çıkar
POST /me/email/change/start  { newEmail }      → doğrulama BAĞLANTISI
GET  /me/email/change/confirm?token=…          → bağla, eskisini çıkar
```
⚠ Yeni değer doğrulanmadan eskisi **kaldırılmaz**.

### 3.4b BEŞ EK SÖZLEŞME KURALI (14 Ağu, kullanıcı eklemesi)

Bu beş kural sözleşmenin ayrılmaz parçasıdır; hem istemci hem sunucu
uygulamak zorundadır.

**K1 — E-posta case-insensitive normalize edilerek unique olur.**
Karşılaştırma ve benzersizlik denetimi `trim().toLowerCase()`
sonrasında yapılır. `Onur@Gmail.com` ile `onur@gmail.com` AYNI
hesaptır; ikisi ayrı hesap açamaz, giriş ikisiyle de çalışır.

**K2 — Telefon OTP girişi ASLA otomatik hesap oluşturmaz.**
Numara kayıtlı değilse doğrulama başarısız sayılır. Kayıt yalnız
kayıt akışından yapılır. ⚠ Aksi hâlde "giriş" sessizce bir kayıt
yoluna dönüşür ve sözleşme onayı, e-posta, rol seçimi atlanır.

**K3 — Doğrulanmamış e-posta kurtarma kanalı DEĞİLDİR.**
`emailVerified == false` olan adrese şifre yenileme bağlantısı
gönderilmez. ⚠ Aksi hâlde yanlış yazılmış veya başkasına ait bir
adres hesabı ele geçirme yolu olur. Kullanıcının doğrulanmış
e-postası yoksa telefon OTP kurtarma yolu kullanılır.

**K4 — Değişiklikte eski değer, yeni değer doğrulanana kadar korunur;
geçiş TEK İŞLEMDE (transaction) olur.**
Yeni telefon/e-posta doğrulanmadan eskisi kaldırılmaz. Doğrulama
başarılı olduğu anda "eskisini çıkar + yenisini bağla" **bölünemez**
bir işlemdir. ⚠ Yarıda kalırsa hesap iletişimsiz kalır: ne eski ne
yeni numarayla girilebilir.

**K5 — Tüm kurtarma BAŞLANGIÇ uçlarında hesap enumeration engellenir.**
`password-reset/request` ve `account-recovery/start` hesap bulunsa da
bulunmasa da **aynı** nötr cevabı ve **benzer süreyi** döndürür.
Kullanıcıya "bu e-posta kayıtlı değil" / "bu numara kayıtlı değil"
DENMEZ.
⚠ Bu, daha önce bilinçli kabul edilmiş olan numara enumerasyonunu
(forgot_password'deki "Sisteme kayıtlı bir numara giriniz") GERİ
ALIR.

### 3.4c OTP CHALLENGE ALTYAPISI — KESİN KURALLAR

**C0 — TEK MODEL, TÜM AKIŞLAR.** Telefon sahipliği doğrulanan her
akış aynı challenge modelini kullanır:

| Akış | Amaç |
|---|---|
| Kayıt telefon doğrulama | `OtpAmac.kayit` |
| Telefonla giriş | `OtpAmac.giris` |
| Telefon numarası değişikliği | `OtpAmac.telefonDegisimi` |
| E-postaya erişilemeyen hesap kurtarma | `OtpAmac.hesapKurtarma` |

**C1 — EKRAN KARAR VERMEZ.** Nihai durumda `OtpScreen` hiçbir akışta
"6 hane doğruysa başarılı" demez. Ekran yalnız kodu TOPLAR; sonucu
ilgili use-case gerçek challenge doğrulamasından sonra belirler.
Eski fallback davranışı, ilgili paket dönüştürüldükçe TAMAMEN
kaldırılır.

**C2 — CHALLENGE ID TAHMİN EDİLEMEZ.** Kriptografik olarak güvenli
üretilir; artan sayaç, zaman damgası veya telefon türevi OLAMAZ.

**C3 — OTP DÜZ METİN SAKLANMAZ.** Production'da kod hash'lenerek
tutulur.

**C4 — ATOMİKLİK.** `attempt++`, doğrulama ve `consumed=true` tek bir
bölünemez işlemdir. ⚠ İki paralel istek aynı challenge ile İKİ KEZ
başarılı olamaz.

**C5 — SAAT OTORİTESİ SUNUCUDUR.** Süre backend saatine göre
değerlendirilir; istemci saati güvenlik otoritesi DEĞİLDİR.

**C6 — RATE-LIMIT.** OTP gönderme, OTP doğrulama ve challenge
oluşturma için telefon / IP / hesap bazlı ayrı limitler bulunur.
⚠ Bu limitler credential (şifre) deneme kilidinden AYRIDIR.

**C7 — YENİ KOD ESKİYİ İPTAL EDER.** Aynı amaç için yeni challenge
üretildiğinde önceki aktif challenge iptal edilir; iki challenge
aynı anda geçerli kalmaz.

**C8 — PURPOSE SUNUCUDA DOĞRULANIR.** `giris` challenge'ı telefon
değişikliğinde veya hesap kurtarmada KULLANILAMAZ. İstemcinin amaç
bildirmesi yeterli değildir.

**C9 — KAYITSIZ TELEFON.** Kullanıcıya görünen cevap nötr kalır ve
gerçekten SMS GÖNDERİLMEZ.

⚠ **C10 — MOCK GÜVENLİK DEĞİLDİR.** İstemcideki challenge uygulaması
geliştirme içindir ve production güvenliği gibi raporlanmaz. Gerçek
backend geldiğinde challenge üretimi, OTP saklama, rate-limit ve
atomiklik BACKEND OTORİTESİNE taşınır.

### 3.4d YETKİ BAĞLAMA KURALLARI (Y1-Y4)

OTP doğrulaması bir YETKİ üretir; yetkinin neye bağlı olduğu
güvenliğin kendisidir.

**Y1 — KAYIT YETKİSİ TEK BAŞINA TELEFONA BAĞLI DEĞİLDİR.**
Bağlar: `purpose=kayıt` · normalize telefon · **kayıt taslağı
kimliği** · expiry · consumed.
⚠ Başka bir taslak, farklı telefon veya sonradan değiştirilmiş form
aynı yetkiyi kullanamaz. Bu yetkiyle **başka bir telefona hesap
açılamaz**.

*OTP sonrası değiştirilebilen alanlar:* ad, soyad, e-posta, rol ve
adres — bunlar telefon sahipliğiyle ilgisizdir. **TELEFON
DEĞİŞTİRİLEMEZ**; değişirse yeni challenge ve yeni yetki gerekir.

**Y2 — KAYITSIZ TELEFON RECOVERY YETKİSİ ÜRETEMEZ.**
`hesapKurtarmaKodGonder` kayıtsız numarada nötr cevap verir ve dummy
challenge üretir; ama bu challenge **hiçbir koşulda** geçerli bir
kurtarma yetkisi doğurmaz. Kayıtsız telefon + herhangi bir kod/
challenge birleşimi → yetki YOK.

**Y3 — KURTARMA YETKİSİ KULLANICIYA BAĞLIDIR.**
Bağlar: `purpose=passwordRecovery` · userId · expiry · consumed.
Başka kullanıcıya uygulanamaz, ikinci kez kullanılamaz, süresi
dolduktan sonra şifre değiştiremez. `kurtarmaSifreBelirle` başarıyla
bittiğinde yetki TÜKETİLİR.
⚠ Şifre sıfırlama sonrası mevcut oturum/refresh token iptali BACKEND
güvenlik sözleşmesinde ayrıca uygulanacaktır.

**Y4 — TELEFON DEĞİŞİKLİĞİ CHALLENGE'I YENİ TELEFONA BAĞLI KALIR.**
Challenge üretildikten sonra arayüzdeki telefon değeri değişse bile
eski challenge yeni değeri doğrulayamaz. `telefonDegisimiDogrula`
**challenge içindeki** normalize numarayı esas alır; controller'ın o
anki alan değerini KULLANMAZ.

### 3.4e İŞLEMSEL GÜVENLİK (Y5-Y7)

**Y5 — YETKİ YALNIZ İŞLEM BAŞARIYLA BİTİNCE TÜKETİLİR.**

Kayıt sırası: yetkiyi doğrula → TÜM kayıt kurallarını doğrula →
Account oluştur → **başarılıysa** yetkiyi tüket.
Kurtarma sırası: yetkiyi doğrula → şifre politikasını doğrula →
şifreyi değiştir → **başarılıysa** yetkiyi tüket.

⚠ İşlem herhangi bir nedenle başarısız olursa yetki YAPILMIŞ GİBİ
tüketilmiş kalmaz; kullanıcı baştan SMS istemek zorunda bırakılmaz.
Gerçek backend'de "Account oluştur + yetkiyi tüket" TEK
TRANSACTION olacaktır.

**Y6 — TELEFON DEĞİŞİKLİĞİ ATOMİKTİR.**

Sıra: challenge doğrula → challenge içindeki yeni telefonu al →
benzersizlik denetle → userId'nin telefonunu değiştir → challenge'ı
tüket. Backend'de bunlar tek atomik işlemdir.

⚠ NİHAİ OTORİTE VERİTABANIDIR: normalize telefon üzerinde UNIQUE
constraint. İki kullanıcı aynı numarayı aynı anda almaya çalışırsa
yalnız biri başarılı olur.
⚠ Challenge doğrulanmış olsa BİLE benzersizlik başarısızsa başka
hesabın telefonu EZİLMEZ ve challenge tüketilmez.

**Y7 — ZAMAN TESTLERİ KIRILGAN OLMAZ.**

Depoya enjekte edilebilir saat (`nowProvider`) eklenir; süre dolumu
testleri gerçek zaman beklemeden deterministik koşar.
⚠ Production'da süre otoritesi BACKEND saatidir; Flutter saati
güvenlik kararı vermez (bkz. C5).

### 3.4f İLAN NUMARASI (ilanNo) — BACKEND SÖZLEŞMESİ

⚠ İKİ AYRI ALAN, KARIŞTIRILMAZ:

| Alan | Rol |
|---|---|
| `listingId` / `id` (UUID) | teknik ana kimlik; **tüm ilişkiler** (teklif, mesaj, ödeme, şikâyet) bunun üzerinden |
| `ilanNo` | kullanıcı/hizmet veren/admin/destek için okunabilir referans |

**N1 — ÜRETİM OTORİTESİ BACKEND.** İstemci numara üretmez.
Veritabanı sequence/identity ile atomik üretir.

**N2 — UNIQUE KISIT ZORUNLU.** `ilanNo` üzerinde UNIQUE constraint
bulunur. ⚠ "Önce kontrol et, sonra yaz" YETERSİZDİR: iki paralel
istek kontrolü aynı anda geçebilir. Nihai otorite veritabanıdır.

**N3 — DEĞİŞMEZ.** Düzenleme, teklif alma, kapanma, geçmişe taşınma
ve durum değişikliklerinde aynı kalır.

**N4 — YENİDEN KULLANILMAZ.** Silinen/kapanan ilanın numarası başka
bir ilana verilmez; sayaç geri alınmaz.

**N5 — FOREIGN KEY DEĞİLDİR.** Hiçbir tablo ilişkisi bu alan
üzerinden kurulmaz.

**N6 — ARAMA.** Tam numarayla sorgu desteklenir; metin araması ile
çakışmaz.

**N7 — HATA DURUMU.** Numara üretilemez veya benzersiz kaydedilemezse
ilan oluşturma SAHTE BAŞARIYLA tamamlanmış gösterilmez; işlem
transaction içinde geri alınır.

**N8 — KULLANICIYA UUID GÖSTERİLMEZ.** Arayüzde yalnız `ilanNo`.

### 3.5 Zorunlu hata kodları (makine tarafından okunabilir)

```
INVALID_CREDENTIALS
ACCOUNT_LOCKED                 (+ kalan süre alanı)
PHONE_ALREADY_IN_USE
EMAIL_ALREADY_IN_USE
OTP_INVALID / OTP_EXPIRED / OTP_RATE_LIMITED
PASSWORD_RESET_TOKEN_INVALID / _EXPIRED / _USED
PASSWORD_RESET_RATE_LIMITED
EMAIL_VERIFICATION_TOKEN_INVALID / _EXPIRED / _USED
NETWORK_ERROR / TIMEOUT
```

⚠ **Türkçe mesaj içinde kelime arayarak davranış belirlenmeyecek.**
Bugün `login` ekranı sunucunun `message` alanını doğrudan gösteriyor;
kilit süresi de metne gömülüydü (düzeltildi). Aynı hata tekrarlanmasın
diye kod alanı zorunludur.

⚠ `ACCOUNT_LOCKED` yanıtında **kalan süre saniye olarak** dönmeli.
İstemcide canlı geri sayım var ve API modunda şu an `0` döndürüyor
(uydurmuyor) — sunucu vermezse geri sayım gösterilemez.

---

## 4. UYGULAMA SIRASI (öneri)

Her paket ayrı teslim, ayrı test, ayrı onay:

1. **Model + depo**: `findByEmail`, e-posta benzersizliği,
   `login(email, password)`, telefon OTP giriş yolu — mock'ta çalışır,
   API modunda uçlara bağlanır
2. **Giriş ekranı**: iki net sekme — "E-posta ile Giriş" /
   "Telefon ile Giriş". ⚠ İki çelişkili model aynı anda bırakılmaz
3. **Şifremi Unuttum**: e-posta formu + nötr cevap + "E-postama
   erişemiyorum" alternatifi
4. **Yeni Şifre Belirle**: deep link + token, OTP alanı YOK
5. **Telefon/e-posta değişikliği**: profil ekranı, iki akış ayrı
6. **Kayıt**: userId + telefon OTP + e-posta doğrulama bağlantısı

---

## 5. AÇIK RİSKLER

1. **Mevcut kullanıcılar.** Bugün hesaplar telefonla açılıyor ve
   e-posta doğrulanmamış olabilir. E-posta giriş kimliği olunca,
   e-postası boş/yanlış olan kullanıcı **e-posta ile giremez** —
   telefon OTP yolu bu yüzden zorunlu, isteğe bağlı değil.
2. **E-posta çakışması.** Benzersizlik denetimi eklenmeden önce
   veritabanında aynı e-postaya sahip birden çok hesap olabilir;
   geçiş sırasında temizlik gerekir. Bu **backend işi**.
3. **Deep link.** `hizmetcep://` şeması Info.plist'te kayıtlı, Android
   tarafı da var; ama reset/e-posta doğrulama yolları henüz
   tanımlanmadı.
4. **Testler koşulamıyor.** Bu ortamda Flutter SDK yok; kabul
   senaryoları yazılır, sonucu Codemagic'te alınır.
