import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  // ── 4 Kas: ÜRÜN KARARI DEĞİŞTİ — Google ve Apple ile giriş EKLENDİ ──
  //
  // Önceki grup "Google/Apple girişi yok" kararını kilitliyordu; kullanıcı
  // Google ve Apple girişini istedi (4 Kas). Grup yeni kararı kilitler:
  // kimliği Firebase doğrular, ekranlar tek kaynak bileşeni kullanır, eski
  // Google servis dosyası ve `googleSub`/`googleLogin` izleri geri gelmez.
  group('GOOGLE / APPLE GİRİŞİ — TEK KAYNAK', () {
    test('⚠ giriş ve kayıt ekranı yalnız ortak bileşeni kullanır', () {
      for (final yol in const [
        'lib/screens/login_screen.dart',
        'lib/screens/register_screen.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains('SosyalGirisDugmeleri('), isTrue, reason: yol);
        // Ekran kendi Google/Apple çağrısını yazmaz.
        expect(k.contains('GoogleSignIn'), isFalse, reason: yol);
        expect(k.contains('AppleAuthProvider'), isFalse, reason: yol);
      }
    });

    test('eski Google servis dosyası geri gelmedi', () {
      expect(File('lib/data/services/google_auth_service.dart').existsSync(),
          isFalse);
    });

    test('⚠ veri ve port katmanında eski iz yok', () {
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

    test('paketler: google_sign_in var, Apple firebase_auth ile', () {
      final p = File('pubspec.yaml').readAsLinesSync().where(
          (l) => !l.trimLeft().startsWith('#')).join('\n');
      expect(p.contains('google_sign_in'), isTrue);
      expect(p.contains('sign_in_with_apple'), isFalse);
    });

    test('⚠ sözleşmede eski uç yok, Firebase kayıt ucu var', () {
      final y = File('docs/openapi.yaml').readAsLinesSync().where(
          (l) => !l.trimLeft().startsWith('#')).join('\n');
      expect(y.contains('/auth/google'), isFalse);
      expect(y.contains('/auth/firebase/register'), isTrue);
    });

    test('platform kapısı gereksiz kaldı', () {
      final k = _kodu('lib/core/platform_kapilari.dart');
      expect(k.contains('googleGirisiGosterilir'), isFalse);
    });

    test('⚠ platform ayrımı web-güvenli (Platform.isIOS yok)', () {
      for (final yol in const [
        'lib/core/firebase/sosyal_giris_ayarlari.dart',
        'lib/data/remote/firebase_kimlik.dart',
        'lib/ui/sosyal_giris_dugmeleri.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains('Platform.is'), isFalse, reason: yol);
        expect(k.contains("dart:io"), isFalse, reason: yol);
      }
    });

    test('⚠ iOS\'ta Google, Apple olmadan gösterilmez (App Review 4.8)', () {
      final k = _kodu('lib/core/firebase/sosyal_giris_ayarlari.dart');
      expect(k.contains('if (_ios && !s.contains(SosyalSaglayici.apple))'),
          isTrue);
    });

    test('şifresiz hesapta kritik işlem aynı sağlayıcıyla doğrulanır', () {
      final k = _kodu('lib/ui/sifre_dogrulama_paneli.dart');
      expect(k.contains('sifresiVar == false'), isTrue);
      expect(k.contains('sosyalKimlikKaniti()'), isTrue);
      final r = _kodu('lib/screens/role_switch_screen.dart');
      expect(r.contains('sosyalIleDogrula('), isTrue);
    });
  });

  group('HİZMET VEREN BESLEMESİ', () {
    final k = _kodu('lib/screens/jobs_screen.dart');

    test('⚠ TAMAMLANMIŞ İŞ BESLEMEDE GÖRÜNMEZ', () {
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
