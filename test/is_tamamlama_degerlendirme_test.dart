import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/kaynak_okuma.dart';

/// Kaynak dosyayı okur — `incelenen_ilan_test` ile aynı yaklaşım.
String read(String p) => File(p).readAsStringSync();

/// İŞ TAMAMLAMA → DEĞERLENDİRME AKIŞI — EKRAN SÖZLEŞMESİ
///
/// ⚠ Bu testler DAVRANIŞ KURALLARINI kaynak metin üzerinden kilitler.
/// İş kuralı testleri (`business_rules_test`) durum makinesini ve
/// cüzdan etkilerini ayrıca doğrular; burada denetlenen şey, o
/// kuralların EKRANDA doğru bağlanmış olmasıdır.
void main() {
  final ilanDetay = read('lib/screens/listing_detail_screen.dart');
  final teklifDetay = read('lib/screens/offer_detail_screen.dart');
  final degerlendirme = read('lib/screens/review_screen.dart');

  group('İş tamamlama', () {
    test('AYRI "İşi Başlat" adımı YOKTUR', () {
      // ⚠ Ürün kararı: teklif seçildikten sonra iş fiilen başlamıştır.
      // Ayrı bir başlatma adımı unutulduğunda ilan tamamlanamaz
      // duruma düşüyordu.
      expect(ilanDetay.contains("'İşi Başlat'"), isFalse,
          reason: 'ara adım kaldırıldı');
      expect(ilanDetay.contains('startWork('), isFalse,
          reason: 'ekran artık startWork çağırmaz');
    });

    test('tek aksiyon: İşi Tamamla — iki durumdan da görünür', () {
      expect(ilanDetay.contains("SysButton('İşi Tamamla'"), isTrue);
      // Seçim sonrası doğrudan tamamlanabilir; `inProgress` de
      // desteklenir (eski kayıt / backend uyumu).
      expect(
          ilanDetay.contains('l.status == ListingStatus.providerSelected ||'),
          isTrue);
      expect(ilanDetay.contains('l.status == ListingStatus.inProgress'), isTrue);
      expect(ilanDetay.contains('completeWork('), isTrue);
    });

    test('tamamlama sonrası DEĞERLENDİRME ekranı otomatik açılır', () {
      final i = ilanDetay.indexOf("SysButton('İşi Tamamla'");
      expect(i, greaterThan(0));
      // ⚠ PENCERE BÜYÜTÜLDÜ: lifecycle düzeltmesinde eklenen açıklama
      // yorumları araya girdi ve 2200 karakter yetmez oldu.
      final blok = ilanDetay.pencere(i, 3200);
      expect(blok.contains('ReviewScreen('), isTrue,
          reason: 'kullanıcı "şimdi nereye?" ile baş başa kalmamalı');
      expect(blok.contains('l.selectedOfferId'), isTrue);
    });

    test('seçili teklif yoksa SESSİZCE ATLANMAZ — açık hata döner', () {
      // ⚠ Önceki hâl `if (secili != null)` ile atlıyordu: kullanıcı
      // "İşiniz tamamlandı" görüyor ama değerlendirme ekranı hiç
      // açılmıyordu; ne olduğunu anlamanın yolu yoktu.
      final i = ilanDetay.indexOf("SysButton('İşi Tamamla'");
      final blok = ilanDetay.pencere(i, 2200);
      expect(blok.contains('secili == null || secili.isEmpty'), isTrue,
          reason: 'boş seçim açıkça yakalanmalı');
      expect(blok.contains('seçilmiş teklif bulunamadı'), isTrue,
          reason: 'kullanıcıya açık hata gösterilmeli');
      // Sessiz atlama deseni GERİ GELMEMELİ.
      expect(blok.contains('if (secili != null) {'), isFalse,
          reason: 'sessiz atlama kaldırıldı');
    });
  });

  group('SEÇİLMİŞ TEKLİFTE "İletişimi Aç" ÇIKMAZ', () {
    test('open bayrağı ilan durumuna BAĞLANMAZ', () {
      // ⚠ Önce `l.status == completed` şartı vardı; seçim yapılmış
      // ESKİ kayıtlarda ilan `providerSelected` kalabildiği için o
      // ilanlarda düğme yeniden çıkıyordu. Belirleyici olan tek şey
      // SEÇİLMİŞ OLMAKTIR — seçim ancak iletişim açıkken yapılır.
      expect(teklifDetay.contains('l.selectedOfferId == offer.id ||'), isTrue);
      expect(teklifDetay.contains('offer.status == OfferStatus.selected;'),
          isTrue);
      expect(
          teklifDetay.contains(
              "l.selectedOfferId == offer.id &&\n            l.status == ListingStatus.completed"),
          isFalse,
          reason: 'durum şartı geri gelmiş');
    });

    test('seçilmiş teklifte düğme YORUM dalına düşer', () {
      // Zincir: `if (!open)` → `else if (ilan açık && teklif aktif)`
      // → `else if (teklif seçili)`. Seçilmiş teklifte `open` daima
      // true olduğu için ilk dal ATLANIR.
      final i = teklifDetay.indexOf('if (!open) ...[');
      final j = teklifDetay.indexOf('else if (offer.status == OfferStatus.selected)');
      expect(i, greaterThan(0));
      expect(j, greaterThan(i), reason: 'yorum dalı zincirin sonunda olmalı');
      expect(teklifDetay.contains("'Yorum Yaz'"), isTrue);
      expect(teklifDetay.contains("'Yorum Yapıldı "), isTrue);
    });
  });

  group('Değerlendirme', () {
    test('TEK SEFERLİK — gönderilmiş değerlendirme değiştirilemez', () {
      expect(degerlendirme.contains('Değiştirilemez ve silinemez'), isTrue);
      // ⚠ TEK KİLİT KALDI: `reviewed`.
      //
      // Referans `vOffer`: `reviewed ? "Değerlendirme" : "Teklifi Seç"`.
      // Durum koşulu YOK — çünkü "Teklifi Seç" düğmesi zaten yalnız
      // iletişim AÇIKKEN çiziliyor ve değerlendirme gönderimi ilanı o
      // anda tamamlıyor (`submitReviewDo`).
      expect(teklifDetay.contains('onPressed: !reviewed'), isTrue);
    });

    test('YORUM SATIRINDA "5 puan", ortalamada "5.0"', () {
      // ⚠ İKİ AYRI SAYI, İKİ AYRI BİÇİM.
      //
      // Yorumun kendi puanı TAM SAYIDIR (1-5): "5 puan". Ondalıklı
      // yazılınca ("5.0") ortalama sanılıyor ve satır "bu yorumu
      // yapanın puanı 5.0" diye okunuyordu — oysa hizmet alanların
      // puanı diye bir kavram YOK, yalnız hizmet verenler puanlanır.
      //
      // Hizmet verenin ORTALAMASI ise ondalıklı kalır: 4 ve 5'ten
      // 4.5 çıkabilir.
      expect(teklifDetay.contains("'\${review.stars} puan'"), isTrue,
          reason: 'yorum puanı tam sayı olarak yazılmalı');
      expect(teklifDetay.contains('review.stars.toStringAsFixed(1)'), isFalse,
          reason: 'yorum puanı yine ondalıklı yazılmış');
      // Ortalama gösterimleri KORUNUR.
      expect(teklifDetay.contains('avg.toStringAsFixed(1)'), isTrue);
      expect(teklifDetay.contains('ortalama!.toStringAsFixed(1)'), isTrue);
    });

    test('puan ZORUNLU, yorum İSTEĞE BAĞLI, en fazla 500 karakter', () {
      expect(degerlendirme.contains('(İsteğe Bağlı)'), isTrue);
      expect(degerlendirme.contains('maxLength: 500'), isTrue);
      expect(degerlendirme.contains('/500'), isTrue);
    });

    test('referans ölçüleri: 42px yıldız, 26px başlık, 16.5px bölüm', () {
      // ⚠ `bigStar()` referansta 42×42'dir; 40 idi.
      expect(degerlendirme.contains('boyut: 42'), isTrue,
          reason: 'seçim yıldızı 42px');
      expect(degerlendirme.contains('boyut: 20'), isTrue,
          reason: 'gönderilmiş görünümdeki yıldız 20px');
      expect(degerlendirme.contains('size: 26'), isTrue,
          reason: '.rv-title 26px');
      expect(degerlendirme.contains('size: 16.5'), isTrue,
          reason: '.rv-h3 16.5px');
      expect(degerlendirme.contains('size: 19'), isTrue,
          reason: '.rv-pname 19px');
    });

    test('referans metinleri birebir', () {
      for (final metin in [
        'Hizmeti Değerlendir',
        'Aldığınız hizmet için puan ve yorumunuzu paylaşın.',
        'Puanınız',
        'Hizmet kalitesini puanlayın',
        '1 yıldız çok kötü, 5 yıldız mükemmel',
        'Yorumunuz',
        'Deneyiminizi paylaşabilirsiniz...',
        'Değerlendirmeyi Gönder',
        'Yorum eklenmedi.',
      ]) {
        expect(degerlendirme.contains(metin), isTrue, reason: metin);
      }
    });
  });
}
