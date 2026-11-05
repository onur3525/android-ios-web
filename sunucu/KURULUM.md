# HizmetCep — Yerli Sunucu Kurulumu (Hosting Türkiye, Ubuntu 24.04)

Bu rehber backend'i Render'dan kendi sunucumuza taşır. Render'daki veriler
taşınmaz: yeni sunucu boş bir veritabanıyla başlar; katalog, il/ilçe ve
yasal metinler ilk açılışta kendiliğinden yüklenir.

Gizli değerler (root parolası, veritabanı parolası, anahtarlar, R2
bilgileri, Firebase servis hesabı) **yalnız sunucuda** durur. Hiçbirini
kimseyle, sohbet dahil, paylaşmayın.

---

## Adım 1 — Alan adı (DNS)

Netlify → hizmetcep.com → DNS ayarları → **Yeni kayıt**:

- Tür: `A`
- Ad: `api`
- Değer: sunucunun IP adresi (Hosting Türkiye'nin e-postasında)

`api.hizmetcep.com` şu an hiçbir yerde kullanılmadığı için bu kayıt
mevcut siteyi etkilemez. Uygulamalar yeni adrese ancak Adım 9'da geçer.

## Adım 2 — Sunucuya bağlanma

- **Windows:** Başlat → "PowerShell" → `ssh root@SUNUCU_IP`
- **Mac:** Terminal → `ssh root@SUNUCU_IP`
- **Telefon:** Termius uygulaması (Host: SUNUCU_IP, kullanıcı: root)

İlk bağlantıda "yes" yazın, root parolasını girin (yazarken görünmez).
Bağlanınca önce parolayı değiştirin:

```
passwd
```

## Adım 3 — Kurulum (tek komut, 5–10 dakika)

```
curl -fsSL https://raw.githubusercontent.com/onur3525/android-ios-web/main/sunucu/kurulum.sh -o kurulum.sh
bash kurulum.sh api.hizmetcep.com
```

Bitince "Kurulum tamamlandı" yazar. Servis bilerek henüz başlatılmaz.

## Adım 4 — Firebase servis hesabı ve fotoğraf depolama

**a) Firebase servis hesabı (push bildirimleri için zorunlu)**

Render'daki Secret File'ın içeriği ya da Firebase konsolu → Proje
ayarları → Hizmet hesapları → *Yeni özel anahtar oluştur* ile indirilen
JSON dosyası. Sunucuda:

```
nano /etc/hizmetcep/firebase-servis-hesabi.json
```

Dosyanın tüm içeriğini yapıştırın → `Ctrl+O`, `Enter`, `Ctrl+X`. Sonra:

```
chown root:hizmetcep /etc/hizmetcep/firebase-servis-hesabi.json
chmod 640 /etc/hizmetcep/firebase-servis-hesabi.json
```

⚠ `google-services.json` servis hesabı **değildir**; o dosya çalışmaz.

**b) Ortam dosyası**

```
nano /etc/hizmetcep/backend.env
```

Dosyanın altındaki "SİZİN DOLDURACAKLARINIZ" bölümü:

- `HC_S3_ENDPOINT`, `HC_S3_BUCKET`, `HC_S3_ACCESS_KEY_ID`,
  `HC_S3_SECRET_ACCESS_KEY`: Render → hizmetcep-backend → Environment
  sayfasındaki aynı adlı değerler (Cloudflare R2). Dördü birlikte.
- `HC_FIREBASE_WEB_API_KEY`: Render'daki aynı adlı değer. Yoksa satırı silin.

Üstteki otomatik üretilmiş satırlara **dokunmayın**.

## Adım 5 — Başlatma ve kontrol

```
systemctl start hizmetcep
systemctl status hizmetcep --no-pager
curl -s https://api.hizmetcep.com/healthz
curl -s https://api.hizmetcep.com/readyz
```

İki adres de `{"ok":true...}` dönmeli. HTTPS sertifikası ilk istekte
alınır; DNS kaydı yeni eklendiyse birkaç dakika bekleyip tekrar deneyin.

## Adım 6 — Yönetici hesabı ve entegrasyonlar

```
bash /opt/hizmetcep/uygulama/sunucu/yonetici_olustur.sh
```

Gösterilen doğrulama sırrını Google Authenticator'a ekleyin (bir kez
gösterilir). Panel: **https://api.hizmetcep.com/admin**

Veritabanı yeni olduğu için admin paneli → **Entegrasyonlar**'daki
ayarları (Resend e-posta vb.) yeniden girin.

## Adım 7 — İstemci IP ölçümü (hız sınırları ve 5651 kaydı için)

```
echo 'HC_IP_TESHIS=true' >> /etc/hizmetcep/backend.env
systemctl restart hizmetcep
```

Telefondan (Wi-Fi kapalı) `https://api.hizmetcep.com/teshis/ip` açın.
Kendi IP'nizi (herhangi bir "IP adresim" sitesinden) `sagdan` listesinde
bulun; o satırdaki `sira` değerini not edin (beklenen: 1). Sonra
`nano /etc/hizmetcep/backend.env` ile:

- `HC_IP_TESHIS=true` satırını **silin**,
- `# HC_TRUST_PROXY_HOPS=1` satırının başındaki `# ` işaretini kaldırıp
  değeri ölçtüğünüz sayı yapın.

```
systemctl restart hizmetcep
```

## Adım 8 — Yedek anahtarı (önemli)

```
cat /root/hizmetcep-yedek-anahtari.txt
```

Çıkan metnin tamamını şifre yöneticinize kaydedin. Yedekler bu anahtar
olmadan açılamaz. Yedeği hemen bir kez deneyin:

```
sudo -u hizmetcep /opt/hizmetcep/uygulama/sunucu/yedek_gunluk.sh
```

Yedekler her gece 03:30'da otomatik alınır, 14 gün saklanır
(`/var/backups/hizmetcep`). Haftada bir kendi bilgisayarınıza indirin
(PowerShell / Terminal):

```
scp root@SUNUCU_IP:/var/backups/hizmetcep/*.age .
```

## Adım 9 — Uygulamaların yeni adrese geçişi

Adım 5–8 sorunsuzsa web sitesi, admin MFA iş akışı ve mobil derlemeler
`https://api.hizmetcep.com/api/v1` adresine çevrilir (ayrı bir değişiklik;
onayla yapılır). Ardından:

- Resend'de gelen e-posta webhook'u Render adresini kullanıyorsa yeni
  adrese güncellenir.
- Her şey 1–2 gün sorunsuz çalışınca Render'daki web servisi ve
  veritabanı silinir.

---

## Adım 10 — Otomatik yayın (bir kez)

Bu adımdan sonra main dalına birleştirilen her değişiklik, backend
testleri geçince sunucuya **kendiliğinden** yüklenir (Render'daki gibi).
Test başarısızsa yayın yapılmaz; yeni sürüm açılmazsa sunucu önceki
sürüme kendiliğinden döner ve GitHub size e-posta gönderir.

1. Termius'ta önce sunucuyu güncelleyin, sonra anahtarı üretin:

   ```
   bash /opt/hizmetcep/uygulama/sunucu/guncelle.sh
   bash /opt/hizmetcep/uygulama/sunucu/yayin_anahtari_kur.sh
   ```

2. Ekrana iki değer yazılır. GitHub'da depo › **Settings** ›
   **Secrets and variables** › **Actions** › **New repository secret**
   ile iki gizli ekleyin:
   - `HC_SUNUCU_SSH_ANAHTARI` → uzun tek satır
   - `HC_SUNUCU_KIMLIGI` → `api.hizmetcep.com ssh-ed25519 …` satırı

   Bu değerleri kimseyle (sohbet dahil) paylaşmayın; ekran görüntüsü
   göndermeyin.

3. Deneme: GitHub › **Actions** › **sunucu-yayin** › **Run workflow**.
   Yeşil biterse kurulum tamamdır.

Anahtar sunucuda yalnız `guncelle.sh`'yi çalıştırabilir; kabuk açamaz,
dosya okuyamaz. İptal etmek için GitHub'daki gizliyi silmek ya da
sunucuda `sed -i '/ hizmetcep-github-yayin$/d' /root/.ssh/authorized_keys`
yeterlidir.

---

## Günlük işler

| İş | Komut |
|---|---|
| Yeni sürümü yayınla | Otomatik (Adım 10). Elle: `bash /opt/hizmetcep/uygulama/sunucu/guncelle.sh` |
| Değişiklik olmasa da yeniden kur | `bash /opt/hizmetcep/uygulama/sunucu/guncelle.sh --zorla` |
| Durum | `systemctl status hizmetcep caddy postgresql --no-pager` |
| Son günlükler | `journalctl -u hizmetcep -n 100 --no-pager` |
| Yeniden başlat | `systemctl restart hizmetcep` |
| Disk doluluğu | `df -h /` |

Güncelleme betiği değişiklik yoksa hiçbir şey yapmaz; varsa önce yedek
alır, uygulama 60 saniyede hazır olmazsa günlükleri yazar ve önceki
sürüme kendiliğinden döner.

**Kesinti bildirimi:** uptimerobot.com'da ücretsiz hesap açın →
*New monitor* → HTTP(s) → `https://api.hizmetcep.com/readyz` → 5 dakika →
bildirim e-postası onur@hizmetcep.com. Site kapanırsa e-posta gelir.

## Güvenlik özeti

- Güvenlik duvarı yalnız 22 (SSH), 80 ve 443'e izin verir; veritabanı ve
  uygulama portu dışarıya kapalıdır.
- fail2ban, art arda hatalı SSH girişlerini engeller.
- Güvenlik güncellemeleri otomatik kurulur.
- Uygulama ayrı ve yetkisiz bir kullanıcıyla çalışır.
- Veritabanı bağlantısı TLS ve sertifika doğrulamalıdır.
- Yedekler şifrelidir.
