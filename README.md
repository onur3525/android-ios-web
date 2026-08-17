# HizmetCep — Flutter

HTML prototip (`hizmetcep-v66-final.html`) ile birebir iş kuralları; tam katmanlı mimari.

## Mimari
```
lib/
 ├─ main.dart                      # MultiProvider kablolama (repo → controller)
 ├─ core/                          # theme (HTML renk/tipografi), validators, sys_state (v56)
 ├─ data/
 │   ├─ models/                    # UUID kimlikli saf modeller
 │   │   ├─ account.dart           # ÇOK ROLLÜ: roles:Set<Role> + activeRole
 │   │   ├─ listing.dart           # open|providerSelected|inProgress|completed|cancelled|expired
 │   │   ├─ offer.dart             # ilan başına ÇOK teklif; teklif başına escrow (blocked/consumed)
 │   │   ├─ wallet.dart, chat.dart
 │   ├─ repositories/              # bellek-içi veri depoları (backend'de içi değişir, API'si kalır)
 │   │   ├─ auth_repository.dart      # hesap defteri + oturum + rol birleştirme
 │   │   ├─ wallet_repository.dart    # providerId→Wallet; block/consume/refund/topup
 │   │   ├─ listing_repository.dart   # UUID → index kaydırma YOK
 │   │   ├─ offer_repository.dart     # listingId/providerId sorguları
 │   │   ├─ contact_repository.dart   # ortak iletişim: offerId kümesi (tek doğruluk kaynağı)
 │   │   └─ chat_repository.dart      # offerId→mesajlar; ilk mesaj=teklif notu
 │   └─ controllers/               # iş kuralı orkestrasyonu (ChangeNotifier)
 │       ├─ auth_controller.dart, wallet_controller.dart
 │       ├─ offer_controller.dart     # placeOffer(bloke+yetersiz engel), selectOffer(iade)
 │       ├─ contact_controller.dart   # openShared: iki taraf + TEK tüketim
 │       ├─ listing_controller.dart   # publish/start/complete/cancel/expire/delete(iade+temizlik)
 │       └─ chat_controller.dart
 └─ screens/                       # splash + login (görsel tasarım DEĞİŞMEDİ)
test/                              # 4 dosya, 23 test: validators, auth, iş kuralları, sohbet
android/ ios/ web/                 # platform kaynakları (bkz. PLATFORM_SETUP.md)
```

## Kurulum ve doğrulama
```
flutter create . --platforms=android,ios,web --org com.hizmetcep   # eksik üretilen dosyaları tamamlar
flutter pub get
flutter analyze
flutter test
```

## Denetim düzeltmeleri (v3)
- Güvenlik: register OTP + mevcut hesap şifre doğrulaması; şifreler tuzlu SHA-256 (düz metin yok)
- Merkezi durum makinesi: `domain/listing_state_machine.dart` — completed uç durum (iptal/expire/silme yasak)
- Yetkilendirme: tüm mutasyonlar `actorId` alır; tip güvenli hatalar `domain/failures.dart` (sealed)
- Domain sabitleri `domain/config.dart` (tema yalnız görsel); test OTP yalnız `test/support/`
- Wallet repo bütünlük korumaları (negatif bakiye/karşılıksız işlem imkânsız); demo bakiye bayrağı, production 0/0
- Offer.createdAt (sıralama) + Listing.expiresAt

## İş kuralları (testlerle garanti altında)
- Teklif ücretsiz; verilirken 50 TL bloke (avail↓ blocked↑) · yetersiz bakiye → teklif yok
- Bir ilana birden fazla hizmet veren teklif verir; aynı usta ikinci teklifi veremez
- İletişim taraflardan biri açınca İKİ tarafta açılır; bloke YALNIZ BİR KEZ tüketilir
- Seçim: ilan providerSelected, diğer teklifler cancelled + açılmamış blokeler sahibine iade; tüketilen iade edilmez
- Durum akışı: providerSelected→inProgress→completed; cancel/expire açılmamış blokeleri iade eder
- Silme: iade + teklif/iletişim/sohbet temizliği; UUID sayesinde başka ilanların kayıtları asla kaymaz
- Müşteri hiçbir aşamada ödemez; ilan ücretsiz+sınırsız · Sohbetin ilk mesajı yalnız teklif notu
