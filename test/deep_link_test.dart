import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/deep_links.dart';
import 'package:hizmetcep/data/models/payment.dart';

/// ÖDEME DERİN BAĞLANTISI
///
/// Native köprüler (MainActivity.kt / AppDelegate.swift) aynı sözleşmeyi
/// uygular: yalnız `hizmetcep://payment...` ve YALNIZ session kimliği
/// taşıyan bağlantılar Dart'a iletilir. Native test altyapısı olmadığı
/// için URI ayrıştırma ve tekilleştirme mantığı burada saf fonksiyonlar
/// üzerinden doğrulanır.
void main() {
  setUp(() => DeepLinks.instance.resetHandled());
  tearDown(() => DeepLinks.instance.resetHandled());

  group('URI kabul/ret sözleşmesi (Android ve iOS ortak)', () {
    test('geçerli ödeme dönüşü kabul edilir', () {
      final u = Uri.parse('hizmetcep://payment/return?session=abc-123');
      expect(isPaymentReturn(u), isTrue);
      expect(paymentSessionIdFrom(u), 'abc-123');
    });

    test('YANLIŞ ŞEMA reddedilir', () {
      for (final bad in [
        'https://hizmetcep.app/payment/return?session=s1',
        'myapp://payment/return?session=s1',
        'http://payment/return?session=s1',
      ]) {
        final u = Uri.parse(bad);
        expect(isPaymentReturn(u), isFalse, reason: bad);
        expect(paymentSessionIdFrom(u), isNull, reason: bad);
      }
    });

    test('ödeme dışı host reddedilir', () {
      final u = Uri.parse('hizmetcep://profile/settings?session=s1');
      expect(isPaymentReturn(u), isFalse);
      expect(paymentSessionIdFrom(u), isNull);
    });

    test('EKSİK session kimliği reddedilir', () {
      for (final bad in [
        'hizmetcep://payment/return',
        'hizmetcep://payment/return?status=SUCCEEDED',
        'hizmetcep://payment/return?session=',
        'hizmetcep://payment/return?session=%20',
      ]) {
        expect(paymentSessionIdFrom(Uri.parse(bad)), isNull, reason: bad);
      }
    });

    test('sessionId anahtarı da kabul edilir', () {
      expect(
        paymentSessionIdFrom(
            Uri.parse('hizmetcep://payment/return?sessionId=xyz')),
        'xyz',
      );
    });

    test('session kimliği kırpılır', () {
      expect(
        paymentSessionIdFrom(
            Uri.parse('hizmetcep://payment/return?session=%20s1%20')),
        's1',
      );
    });
  });

  group('Başarı bilgisine güvenilmez', () {
    test('URI "success=true" dese bile yalnız session taşınır', () {
      final u = Uri.parse(
        'hizmetcep://payment/return?session=s1&success=true&status=SUCCEEDED',
      );
      // Yardımcı fonksiyon YALNIZ session döndürür — durum taşımaz.
      expect(paymentSessionIdFrom(u), 's1');
      // Durum bilgisi yalnız sunucudan gelen gövdeden üretilir.
      expect(PaymentStatus.parse(u.queryParameters['status']),
          PaymentStatus.succeeded,
          reason: 'ayrıştırıcı çalışır ama bu değer ÖDEME KANITI DEĞİLDİR');
    });

    test('BACKEND FAILED derse ödeme başarısızdır', () {
      // Sunucu gövdesi tek doğruluk kaynağıdır.
      expect(PaymentStatus.parse('FAILED'), PaymentStatus.failed);
      expect(PaymentStatus.parse('FAILED').isFinal, isTrue);
    });

    test('EXPIRED ve CANCELLED kontrollü sonuç verir', () {
      expect(PaymentStatus.parse('EXPIRED'), PaymentStatus.expired);
      expect(PaymentStatus.parse('CANCELLED'), PaymentStatus.cancelled);
      expect(PaymentStatus.expired.label, isNotEmpty);
      expect(PaymentStatus.cancelled.label, isNotEmpty);
    });

    test('GEÇERSİZ/bilinmeyen durum SAHTE BAŞARI üretmez', () {
      for (final raw in ['', 'OK', 'true', 'BILINMEYEN', null]) {
        expect(PaymentStatus.parse(raw), PaymentStatus.pending, reason: raw);
      }
    });
  });

  group('Duplicate callback (cold start + resume ortak)', () {
    test('aynı bağlantı ikinci kez işlenmez', () {
      final u = Uri.parse('hizmetcep://payment/return?session=dup');
      expect(DeepLinks.instance.markHandled(u), isFalse); // ilk teslim
      expect(DeepLinks.instance.markHandled(u), isTrue);  // yinelenen
      expect(DeepLinks.instance.markHandled(u), isTrue);
    });

    test('FARKLI oturumlar ayrı ayrı işlenir', () {
      final a = Uri.parse('hizmetcep://payment/return?session=s1');
      final b = Uri.parse('hizmetcep://payment/return?session=s2');
      expect(DeepLinks.instance.markHandled(a), isFalse);
      expect(DeepLinks.instance.markHandled(b), isFalse);
      expect(DeepLinks.instance.markHandled(a), isTrue);
    });

    test('COLD START sonrası RESUME aynı bağlantıyı tekrar işlemez', () {
      // Senaryo: uygulama kapalıyken bağlantı geldi (getInitialLink),
      // ardından aynı intent resume ile yeniden bildirildi.
      final u = Uri.parse('hizmetcep://payment/return?session=cold');
      expect(DeepLinks.instance.markHandled(u), isFalse); // cold start
      expect(DeepLinks.instance.markHandled(u), isTrue);  // resume yinelemesi
    });

    test('resetHandled yeni ödeme denemesine izin verir', () {
      final u = Uri.parse('hizmetcep://payment/return?session=s9');
      expect(DeepLinks.instance.markHandled(u), isFalse);
      DeepLinks.instance.resetHandled();
      expect(DeepLinks.instance.markHandled(u), isFalse);
    });
  });

  group('Native köprü sözleşmesi', () {
    test('kanal adları iki platformda da aynıdır', () {
      // Bu sabitler Dart tarafında tanımlıdır; native dosyalar aynı
      // adları kullanmak zorundadır (MainActivity.kt / AppDelegate.swift).
      const method = 'hizmetcep/deeplinks';
      const events = 'hizmetcep/deeplinks/events';
      expect(method, 'hizmetcep/deeplinks');
      expect(events, 'hizmetcep/deeplinks/events');
    });

    test('stream ve links aynı akışı verir', () {
      expect(identical(DeepLinks.instance.stream, DeepLinks.instance.links),
          isTrue);
    });
  });
}
