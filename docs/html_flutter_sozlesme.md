# HTML → FLUTTER SÖZLEŞMESİ (v66-final)

Kaynak: hizmetcep-v66-final.html · MD5 6231e0545ff0ddb572b2dd0cd2cb0c19

1.291.423 bayt · 3.908 satır · 34 ekran · 435 CSS kuralı · 100 SVG ikonu


## 1. EKRAN LİSTESİ (navigate anahtarı → render)


| anahtar | render | navigate çağrısı |
|---|---|---|
| `addr` | `vAddr()` | 1 yerden |
| `apprate` | `vAppRate()` | 2 yerden |
| `chat` | `vChat()` | 1 yerden |
| `cust` | `vCust()` | 13 yerden |
| `forgot` | `vForgot()` | 1 yerden |
| `google` | `vGoogle()` | 0 yerden |
| `home` | `vHome()` | 6 yerden |
| `listing` | `vListing()` | 1 yerden |
| `login` | `vLogin()` | 2 yerden |
| `myareas` | `vMyAreas()` | 1 yerden |
| `mycats` | `vMyCats()` | 1 yerden |
| `myrevs` | `vMyRevs()` | 1 yerden |
| `notif` | `vNotif()` | 1 yerden |
| `offer` | `vOffer()` | 1 yerden |
| `passwd` | `vPasswd()` | 2 yerden |
| `pinfo` | `vPInfo()` | 2 yerden |
| `post` | `vPost()` | 2 yerden |
| `profile` | `vProfile()` | 2 yerden |
| `provlist` | `vProvListing()` | 1 yerden |
| `register` | `vRegister()` | 1 yerden |
| `review` | `vReview()` | 1 yerden |
| `search` | `vSearch()` | 1 yerden |
| `splash` | `vSplash()` | 1 yerden |
| `topup` | `vTopup()` | 2 yerden |
| `wallet` | `vWallet()` | 2 yerden |
| `wtx` | `vWTx()` | 1 yerden |

### Alt görünümler (ayrı navigate anahtarı YOK)

- `vPost` → `vPost1` / `vPost2` / `vPost3` (ilan oluşturma 3 adım)
- `vRegister` → `vRegStep1` / `vRegStep2` / `vRegStep3` (kayıt 3 adım)
- `vProfile` → `vProfileCust` / `vProfileProv` (role göre)

## 2. CSS AİLELERİ (ekran başına)

| aile | kural | Flutter karşılığı |
|---|---|---|
| `.rg-*` | 73 | kayıt/form bileşenleri — taşındı |
| `.po-*` | 46 | ilan oluşturma — taşındı |
| `.pr-*` | 43 | teklif detayı — taşındı |
| `.pl-*` | 27 | ilan/iş detayı — taşındı |
| `.rv-*` | 26 | değerlendirme — taşındı |
| `.pf-*` | 19 | profil — taşındı |
| `.mr-*` | 19 | Değerlendirmelerim — TAŞINMADI |
| `.tp-*` | 18 | bakiye yükleme — taşındı |
| `.of-*` | 15 | teklif kartı — taşındı |
| `.ld-*` | 14 | ilan kartı — taşındı |
| `.cust-*` | 13 | müşteri sekmeleri — taşındı |
| `.nt-*` | 13 | bildirimler — taşındı |
| `.ch-*` | 13 | Sohbet — TAŞINMADI |
| `.wl-*` | 12 | Cüzdan — TAŞINMADI |
| `.sys-*` | 11 | Sistem durumları — TAŞINMADI |
| `.cc-*` | 7 | ilan kartı meta — taşındı |
| `.lg-*` | 7 | giriş — taşındı |
| `.wx-*` | 6 | Cüzdan hareketleri — TAŞINMADI |
| `.mc-*` | 6 | Kategorilerim — TAŞINMADI |
| `.gs-*` | 6 | google giriş — taşındı |
| `.pc-*` | 6 | kategori seçimi — taşındı |
| `.ad-*` | 5 | adres — taşındı |
| `.pi-*` | 5 | profil bilgileri — taşındı |
| `.rs-*` | 4 | Rol seçimi — TAŞINMADI |
| `.hd-*` | 3 | ana sayfa başlık — taşındı |
| `.pw-*` | 3 | Şifre — TAŞINMADI |
| `.ma-*` | 3 | Bölgelerim — TAŞINMADI |
| `.sk-*` | 3 | iskelet — taşındı |
| `.rc-*` | 2 | — — taşındı |
| `.sq-*` | 2 | — — taşındı |
| `.btn-*` | 2 | — — taşındı |
| `.sp-*` | 1 | — — taşındı |
| `.is-*` | 1 | — — taşındı |
| `.iv-*` | 1 | — — taşındı |
