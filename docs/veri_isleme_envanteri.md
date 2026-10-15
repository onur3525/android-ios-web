# HizmetCep — Veri İşleme ve Yurt Dışı Aktarım Envanteri

Hazırlanma: 15 Ekim 2026 (güvenlik denetimi, karar 7). Bu belge **yalnız kaynak koddan** çıkarılmıştır. Bulut panellerinde (Firebase Console, Render Dashboard, Cloudflare Dashboard) yapılan ayarlar bu çalışmada **görülmemiştir**; "Panelde doğrulanmadı" yazan her satır işletmeci tarafından panelden kontrol edilmelidir. Bu belge hukuki görüş değildir; KVKK uyumu için bir hukukçuya danışılması önerilir.

## 1. Hizmet sağlayıcılar ve işlenen veri

| Hizmet | Ne için kullanılıyor (koddaki yeri) | İşlenen kişisel veri | Konum / bölge |
|---|---|---|---|
| Google Firebase Authentication | Telefon (SMS kodu) ve e-posta/şifre doğrulaması; e-posta doğrulama ve şifre sıfırlama e-postaları (`lib/data/remote/firebase_kimlik.dart`, `backend/src/firebase_token.js`) | Telefon numarası, e-posta, şifre (Google tarafında özetlenmiş), Firebase kullanıcı kimliği, SMS kodu gönderimi, istemci IP adresi | Google'ın küresel altyapısı; Firebase Authentication için bölge seçimi yok. **Yurt dışı (ABD dahil).** |
| Google Firebase Cloud Messaging | Anlık bildirim (`backend/src/fcm.js`, `fcm.googleapis.com`) | Cihaz bildirim jetonu, bildirim başlığı ve metni (ilan başlığı gibi içerik geçebilir) | Google küresel altyapısı. **Yurt dışı.** |
| Google OAuth / Identity Toolkit (servis hesabı) | Sunucunun Firebase'de şifre ayarlaması ve kullanıcı silmesi (`servis_hesabi.js`, `firebase_silme.js`) | Firebase kullanıcı kimliği, yeni şifre (aktarım sırasında) | Google küresel altyapısı. **Yurt dışı.** |
| Render (web hizmeti + PostgreSQL) | Backend API ve ana veritabanı (`hizmetcep-backend.onrender.com`) | Uygulamadaki bütün hesap ve iş verisi: ad, telefon, e-posta, adres (il/ilçe/mahalle), ilanlar, teklifler, mesajlar, yorumlar, destek talepleri, oturum IP ve cihaz bilgisi, yasal onay kayıtları, yönetici denetim kaydı | Render bölgeleri ABD, Avrupa (Frankfurt) ve Singapur'dur; Türkiye'de bölge yoktur. **Hangi bölgenin seçildiği panelde doğrulanmadı.** Her durumda **yurt dışı.** |
| Render yedekleri | PostgreSQL otomatik yedekleri (sağlayıcı özelliği; kodda değil) | Veritabanının tamamı | **Saklama süresi ve konumu panelde doğrulanmadı.** Silinen hesabın verisi yedek süresi dolana kadar yedekte kalır. |
| Cloudflare R2 | Fotoğraf depolama — profil, ilan, mesaj ve talep fotoğrafları; imzalı adreslerle erişim (`backend/src/entegrasyon.js`, `dosya_temizligi.js`) | Kullanıcının yüklediği fotoğraflar (yüz, ev içi, belge görüntüsü olabilir) | Kodda bölge `auto` (`HC_S3_REGION` verilmezse). Kova konumu / yargı alanı (ör. AB) **panelde doğrulanmadı.** **Yurt dışı.** |
| GitHub Pages | Test/web sitesinin statik dosyaları | Ziyaretçi IP adresi ve tarayıcı bilgisi (barındırma günlükleri) | GitHub (ABD). **Yurt dışı.** |
| SMS / e-posta webhook entegrasyonu | Yönetici bildirimleri (askıya alma vb.) için isteğe bağlı sağlayıcı (`backend/src/bildirim.js`) | Telefon numarası veya e-posta ve ileti metni | Sağlayıcı yönetici panelinden tanımlanır; **hangisinin etkin olduğu doğrulanmadı.** Üretimde "log" sağlayıcısı engellidir (numara günlüğe yazılmaz). |

## 2. Hesap silmede ne olur (kod, 15 Ekim)

30 günlük bekleme sonrasında (`silmeTalepleriniIsle`):

- Kaldırılan / anonimleşen: ad, telefon, e-posta, şifre, Firebase kimliği (Firebase'den silme kuyruğu ile), profil fotoğrafları ve kullanıcının bütün dosyaları (R2 silme kuyruğu), adres, hizmet veren profili, bildirim jetonları, bildirimler, uygulama geri bildirimi, OTP kayıtları, oturum kayıtları (IP/cihaz), kişinin yazdığı mesaj ve talep mesajları, ilan açıklaması/konumu/fotoğrafları, teklif notları, talep açıklaması/fotoğrafları, teklif açıklaması, red gerekçesi, yorum metinleri, silinen hizmet veren hakkındaki yorumlar (yayından kalkar), destek talebi konu/mesajı ve destek yanıtları, giden ileti kayıtlarındaki adres ve içerik, hesap taleplerinin gerekçe metni.
- **Gerekçeyle saklananlar:**
  - Yasal onay kayıtları (`legal_acceptances`): sözleşme ve aydınlatma metni onayının ispatı.
  - Yönetici denetim kaydı (`audit_log`) ve hesap durum geçmişi (`user_status_history`): yönetici işlemlerinin hesap verebilirliği. Bu tablolar değiştirilemez; içlerindeki önceki/sonraki değer alanları kişisel veri içerebilir. **Saklama süresi henüz tanımlı değil**, belirlenmesi önerilir.
  - Hesap silme talebinin kendisi (`account_requests`): talebin ne zaman alındığı ve uygulandığının kaydı.
  - Yıldız puanları ve iş satırları (kimlik numarası, tarih, durum): karşı tarafın geçmişi ve puan bütünlüğü için; kişiye bağlanamaz (hesap satırı anonim).
  - Karşı tarafın kendi yazdığı mesajlar: o kişinin verisidir.
  - Render yedekleri: sağlayıcının yedek süresi boyunca (panelde doğrulanmadı).

## 3. Yasal metinlerle karşılaştırma

- Kullanım Koşulları (Belge 1, yürürlük 15.10.2026) depoda bulunduğu için okundu: hizmet sağlayıcıları ve yurt dışı aktarımı **adıyla anmıyor**. "Telefon ve e-posta paylaşımı tarafların onayına bağlıdır" hükmü vardır; ilan akışında iletişimi artık yalnız ilan sahibi açabilir (karar 5).
- Gizlilik Politikası / KVKK aydınlatma metni canlı veritabanındadır; bu çalışmada okunamadı (sunucu otomatik okumaya kapalı). **Karşılaştırma yapılmadı.**
- Öneri: Aydınlatma metnine, yukarıdaki tablodaki sağlayıcıları (Google Firebase, Render, Cloudflare, GitHub), aktarılan veri türlerini, amaçları ve yurt dışı aktarımın dayanağını (KVKK md. 9 — 2024 değişikliğinden sonra standart sözleşme ve Kurul'a bildirim, ya da açık rıza gibi istisnalar) yazan bir bölüm eklenmesi. Metnin kesin hâli hukukçu tarafından belirlenmelidir.

## 4. Panelden doğrulanması gerekenler

1. Render: web hizmetinin ve PostgreSQL'in bölgesi; yedek saklama süresi.
2. Cloudflare R2: kova konumu ve yargı alanı ayarı; genel (public) erişimin kapalı olduğu.
3. Firebase: proje bölgesi (Firestore/Storage kullanılmıyor; Authentication bölgesizdir), etkin giriş yöntemleri, SMS bölge politikası.
4. Yönetici panelinde etkin SMS/e-posta entegrasyonunun hangi sağlayıcı olduğu ve konumu.
5. Sağlayıcılarla veri işleme sözleşmelerinin (DPA) kabul edildiği.
