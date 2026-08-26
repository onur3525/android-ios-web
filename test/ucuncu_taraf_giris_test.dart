import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ÜÇÜNCÜ TARAF GİRİŞİ TAMAMEN KALDIRILDI
///
/// ⚠ Ürün kararı: hesap açma ve giriş YALNIZCA kendi hesap
/// sistemimizle yapılır — telefon/e-posta + şifre, telefonla girişte
/// SMS OTP.
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('GOOGLE / APPLE GİRİŞİ YOK', () {
    test('⚠ HİÇBİR EKRANDA DÜĞME YOK', () {
      for (final yol in const [
        'lib/screens/login_screen.dart',
        'lib/screens/register_screen.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.toLowerCase().contains('google'), isFalse, reason: yol);
        expect(k.toLowerCase().contains('apple'), isFalse, reason: yol);
      }
    });

    test('servis dosyası SİLİNDİ', () {
      expect(File('lib/data/services/google_auth_service.dart').existsSync(),
          isFalse);
    });

    test('⚠ VERİ VE PORT KATMANINDA İZ YOK', () {
      for (final yol in const [
        'lib/data/models/account.dart',
        'lib/data/controllers/auth_controller.dart',
        'lib/data/repositories/auth_repository.dart',
        'lib/data/ports/repository_ports.dart',
        'lib/data/ports/api_ports.dart',
        'lib/data/ports/mock_ports.dart',
        'lib/data/remote/api/auth_api.dart',
        'lib/data/remote/repositories/api_repositories.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains('googleSub'), isFalse, reason: yol);
        expect(k.contains('googleLogin'), isFalse, reason: yol);
      }
    });

    test('paket bağımlılığı KALDIRILDI', () {
      final p = File('pubspec.yaml').readAsLinesSync().where(
          (l) => !l.trimLeft().startsWith('#')).join('\n');
      expect(p.contains('google_sign_in'), isFalse);
      expect(p.contains('sign_in_with_apple'), isFalse);
    });

    test('⚠ SÖZLEŞMEDEN DE ÇIKARILDI', () {
      // İstemcinin çağırmadığı bir ucu sözleşmede bırakmak,
      // backend'in gereksiz yere uygulamasına yol açardı.
      final y = File('docs/openapi.yaml').readAsLinesSync().where(
          (l) => !l.trimLeft().startsWith('#')).join('\n');
      expect(y.contains('/auth/google'), isFalse);
    });

    test('platform kapısı gereksiz kaldı', () {
      final k = _kodu('lib/core/platform_kapilari.dart');
      expect(k.contains('googleGirisiGosterilir'), isFalse);
    });
  });

  group('HİZMET VEREN BESLEMESİ', () {
    final k = _kodu('lib/screens/jobs_screen.dart');

    test('⚠ TAMAMLANMIŞ İŞ BESLEMEDE GÖRÜNMEZ', () {
      // Seçim ilanın durumunu değiştirmiyor; yalnız `status` bakan
      // süzgeç bitmiş işleri "yeni iş" gibi gösteriyordu.
      expect(k.contains('l.acceptsOffers && l.ownerId != me.id'), isTrue);
      expect(k.contains('l.status == ListingStatus.active && l.ownerId'),
          isFalse, reason: 'eski süzgeç geri gelmiş');
    });

    test('⚠ TEKLİF VERDİĞİM İLAN "YENİ İŞLER"DE GÖRÜNMEZ', () {
      // Aynı ilana ikinci teklif verilemez (§1).
      expect(k.contains('bool teklifVermedim(Listing l)'), isTrue);
      expect(k.contains('teklifVermedim(l)'), isTrue);
    });
  });

  group('HESABI DONDUR', () {
    final k = _kodu('lib/screens/account_settings_screen.dart');

    test('⚠ TAMAMLANMIŞ İŞ DONDURMAYI ENGELLEMEZ', () {
      // Yorum bunu söylüyordu ama kod uygulamıyordu: koşul yalnız
      // `status == active` idi ve tamamlanmış ilan da active kalıyor.
      expect(k.contains('!l.isTamamlanmisIs'), isTrue,
          reason: 'tamamlanmış ilan hâlâ engel sayılıyor');
    });

    test('⚠ SEÇİLMİŞ TEKLİF DEVAM EDEN İŞ DEĞİLDİR', () {
      expect(k.contains('o.status == OfferStatus.active'), isTrue);
      expect(k.contains('OfferStatus.active, OfferStatus.selected'), isFalse,
          reason: 'seçilmiş teklif hâlâ engel sayılıyor');
    });
  });
}
