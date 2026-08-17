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

  group('Değerlendirme', () {
    test('TEK SEFERLİK — gönderilmiş değerlendirme değiştirilemez', () {
      expect(degerlendirme.contains('Değiştirilemez ve silinemez'), isTrue);
      // Teklif detayındaki düğme iki kilitle korunur.
      expect(teklifDetay.contains('!reviewed &&'), isTrue);
      expect(teklifDetay.contains('ListingStatus.completed'), isTrue);
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
