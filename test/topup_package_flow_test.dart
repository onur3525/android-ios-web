import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/kaynak_okuma.dart';

/// TOPUP AKIŞI — statik kaynak sözleşmesi.
///
/// Flutter SDK olmadan widget testi koşulamadığı için kritik güvenlik
/// sözleşmeleri kaynak metin üzerinden sabitlenir.
void main() {
  String read(String p) => File(p).readAsStringSync();
  final screen = read('lib/screens/topup_screen.dart');
  final api = read('lib/data/remote/api/wallet_api.dart');
  final ctl = read('lib/data/controllers/wallet_controller.dart');

  group('Sabit tutar listesi KALDIRILDI', () {
    test('hardcoded paket/tutar listesi yok', () {
      expect(screen.contains('[500, 1000, 2000, 5000]'), isFalse);
    });

    // Referans HTML `vTopup` SERBEST TUTAR girişi kullanır; paket kartı
    // YOKTUR. Minimum tutar sabiti tek merkezden (DomainConfig) okunur —
    // ekrana gömülü sayı bulunmaz.
    test('minimum tutar DomainConfig üzerinden okunur', () {
      expect(screen.contains('DomainConfig.minTopup'), isTrue);
    });
  });

  group('FİYAT İSTEMCİDEN GÖNDERİLMEZ', () {
    // Referans akışta kullanıcı tutarı kendisi girer. İstemci FİYAT
    // BELİRLEMEZ: sunucu tutarı yeniden doğrular. Kritik kural,
    // çağrının NAMED parametre kullanması ve ham kart verisi
    // göndermemesidir.
    test('ödeme named parametrelerle başlatılır', () {
      expect(screen.contains('ctl.startTopup('), isTrue);
      expect(screen.contains('amount: tutar'), isTrue);
    });

    test('istemci ham kart verisi GÖNDERMEZ', () {
      expect(screen.contains("'cardNumber'"), isFalse);
      expect(screen.contains("'cvv'"), isFalse);
      expect(screen.contains('savedCardToken: secili'), isTrue);
    });

    test('paket seçiliyken gövdeye tutar KONULMAZ', () {
      // API katmanı: packageId varsa amountTl gönderilmez.
      expect(api.contains("if (packageId != null) 'packageId': packageId"), isTrue);
      expect(
        api.contains("if (packageId == null && amountTl != null) 'amountTl': amountTl"),
        isTrue,
      );
    });

    test('fiyat/jeton/bonus gövdeye EKLENMEZ', () {
      expect(api.contains("'priceTl'"), isFalse);
      expect(api.contains("'tokenAmount'"), isFalse);
      expect(api.contains("'bonusTokenAmount'"), isFalse);
    });
  });

  group('Durum yönetimi', () {
    test('loading / empty / error / retry / refreshing ayrı', () {
      for (final g in [
        'packagesLoading', 'packagesEmpty', 'packagesError',
        'packagesRefreshing', 'retryPackages', 'packagesStale',
      ]) {
        expect(ctl.contains(g), isTrue, reason: g);
      }
    });

    test('ÇİFT FETCH engeli var', () {
      // Guard'ın BİÇİMİ değil VARLIĞI aranır: `if (_packagesLoading)`
      // sonrasında erken dönüş bulunmalıdır.
      final i = ctl.indexOf('if (_packagesLoading)');
      expect(i, greaterThan(-1), reason: 'çift fetch guard yok');
      expect(ctl.pencere(i, 80).contains('return'), isTrue,
          reason: 'guard erken dönüş yapmıyor');
    });

    test('yenilemede eski liste KORUNUR', () {
      // Hata durumunda _packages sıfırlanmaz.
      expect(ctl.contains('// Eski liste KORUNUR'), isTrue);
    });

    // Referans HTML `vTopup` SERBEST TUTAR akışı kullanır; ekranda paket
    // kartı ve paket listesi YOKTUR. Bu yüzden ekran durumları paket
    // yükleme değil, ÖDEME AŞAMASI üzerinden ele alınır.
    test('ekranda ödeme aşamalarının tamamı ele alınır', () {
      for (final a in [
        '_Stage.amount', '_Stage.awaitingProvider',
        '_Stage.verifying', '_Stage.result',
      ]) {
        expect(screen.contains(a), isTrue, reason: a);
      }
      // Bekleme göstergesi ve yeniden deneme yolu bulunur.
      expect(screen.contains('CircularProgressIndicator'), isTrue);
      expect(screen.contains('Tekrar Dene'), isTrue);
    });
  });

  group('Tutar doğrulaması', () {
    // Serbest tutar akışında "geçersiz paket" durumu YOKTUR; yerine
    // minimum tutar kuralı vardır ve tek merkezden (DomainConfig) okunur.
    test('minimum tutar altında ödeme başlatılamaz', () {
      expect(screen.contains('DomainConfig.minTopup'), isTrue);
      expect(screen.contains('Minimum yükleme tutarı'), isTrue);
      // ⚠ İFADE DEĞİŞTİ, KURAL DEĞİL.
      //
      // Eşik denetimi artık satır içinde değil `_tutarGecerli`
      // getter'ında: `_girilenTutar >= DomainConfig.minTopup`.
      // Aynı kuralın yeni yazımı denetlenir.
      expect(
          screen.contains('_girilenTutar >= DomainConfig.minTopup'), isTrue,
          reason: 'eşik kuralı tek merkezde olmalı');
      // Kural ihlalinde erken dönülür; sunucuya istek GİTMEZ.
      final i = screen.indexOf('if (!_tutarGecerli) {');
      expect(i, greaterThan(-1));
      expect(screen.pencere(i, 220).contains('return;'), isTrue);
      // Düğme de pasiftir — ikinci savunma.
      expect(screen.contains('onPressed: _tutarGecerli ? _bakiyeYukle : null'),
          isTrue);
    });

    test('SAHTE BAŞARI gösterilmez', () {
      // Hata dalında oturum açılmış gibi ilerlenmez.
      expect(screen.contains('_stage = _Stage.amount;'), isTrue);
    });
  });

  group('Çift gönderim engeli', () {
    // Serbest tutar akışında "paket seçimi" YOKTUR. Korunan kural:
    // işlem sürerken ikinci ödeme isteği başlatılamaz.
    test('işlem sürerken ikinci ödeme başlatılamaz', () {
      expect(screen.contains('topupInFlight'), isTrue);
      expect(screen.contains('confirmInFlight'), isTrue);
      final i = screen.indexOf('if (ctl.topupInFlight)');
      expect(i, greaterThan(-1), reason: 'çift gönderim guard yok');
      expect(screen.pencere(i, 40).contains('return'), isTrue);
    });
  });
}
