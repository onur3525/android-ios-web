import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GERİ OKU — HER EKRANDA, HER PLATFORMDA.
///
/// ## SÖZLEŞMENİN GEÇMİŞİ
///
/// 1. Ok bir tur 19 ekrandan KALDIRILDI ("gezinme cihazın kendi geri
///    tuşuyla yapılır"). Android'de doğruydu.
/// 2. iOS'ta donanım geri tuşu YOKTUR ve kenardan kaydırma jesti de
///    kapalıdır (`theme.dart` iOS geçişine `HizliGecis` atıyor).
///    O ekranlarda iPhone kullanıcısı KİLİTLENİYORDU.
/// 3. Ok bir tur PLATFORMA bağlandı (Android'de yok, iOS/web'de var).
/// 4. NİHAİ KARAR: platform ayrımı KALDIRILDI — ok HER YERDE çizilir.
///    Gerekçe: aynı ekranın iki cihazda farklı davranması hem kullanıcı
///    hem geliştirici tarafında karışıklık üretiyordu.
///
/// ⚠ Bu test ESKİ sözleşmeyi ("ok kaldırıldı") koruyordu; production
/// teste uydurulmadı, TEST yeni ürün kararına göre yeniden yazıldı.
String _kod(String p) => const LineSplitter()
    .convert(File(p).readAsStringSync())
    .where((l) => !l.trimLeft().startsWith('//'))
    .join(' ');

/// Kök ekranlar — geri dönülecek yer YOKTUR, ok da olmaz.
const _kokEkranlar = {
  'home_screen.dart',
  'splash_screen.dart',
  'jobs_screen.dart',
  'my_listings_screen.dart',
  'profile_screen.dart',
  'notifications_screen.dart',
};

/// Ekran olmayan yardımcı dosyalar.
const _yardimcilar = {
  'category_ui.dart',
  'nav_actions.dart',
  'status_ui.dart',
  'prelogin_listing_route.dart',
};

/// ⚠ YALNIZ EKRANLAR — `lib/screens/widgets/` DIŞARIDA.
///
/// O klasördeki dosyalar tek başına açılan ekran değil, başka
/// ekranların içinde kullanılan parçalardır (kart, panel, seçici).
/// Onlarda geri oku aranmaz.
List<File> _ekranlar() => Directory('lib/screens')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  group('GERİ OKU — ORTAK BİLEŞEN', () {
    final k = File('lib/ui/ref_widgets.dart').readAsStringSync();

    test('RefDetailHeader varsayılanı AÇIK', () {
      expect(k.contains('this.geriDugmesi,'), isTrue,
          reason: 'bayrak artık nullable olmalı');
      expect(
          k.contains(
              'static bool okGosterilirMi(bool? istek) => istek ?? true;'),
          isTrue,
          reason: 'varsayılan açık olmalı');
    });

    test('PLATFORM AYRIMI YOK', () {
      expect(k.contains('defaultTargetPlatform'), isFalse,
          reason: 'geri oku platforma göre değişmemeli');
    });

    test('ok koşullu çizilir, boşluğu da aynı koşulda', () {
      expect(k.contains('final okVar = okGosterilirMi(geriDugmesi);'), isTrue);
      expect(k.contains('if (okVar)'), isTrue);
    });
  });

  group('GERİ OKU — EKRAN KAPSAMI', () {
    test('kök ve sekme ekranları DIŞINDA her ekranda geri yolu var', () {
      final eksik = <String>[];
      for (final f in _ekranlar()) {
        final ad = f.path.split('/').last;
        if (_kokEkranlar.contains(ad) || _yardimcilar.contains(ad)) {
          continue;
        }
        final s = _kod(f.path);
        final geriVar = s.contains('RefBackButton') ||
            s.contains('RefDetailHeader(') ||
            s.contains('RefPageTitle(') ||
            s.contains('BackButton(');
        if (!geriVar) {
          eksik.add(ad);
        }
      }
      expect(eksik, isEmpty, reason: 'geri yolu olmayan ekran: $eksik');
    });

    test('çok adımlı akışlarda ok KORUNUR — orada "önceki adım" demek', () {
      const akis = {
        'register_screen.dart': 'kayıt formu',
        'otp_screen.dart': 'SMS doğrulama',
        'role_select_screen.dart': 'rol seçimi',
        'register_done_screen.dart': 'kayıt tamam',
        'forgot_password_screen.dart': 'şifre sıfırlama',
        'create_listing_screen.dart': 'ilan oluşturma',
      };
      for (final e in akis.entries) {
        expect(_kod('lib/screens/${e.key}').contains('RefBackButton('), isTrue,
            reason: '${e.value} akışında önceki adım oku kaybolmuş');
      }
    });

    test('bir tur kaldırılan ekranlarda ok GERİ GELDİ', () {
      const geriGelenler = [
        'job_detail_screen.dart',
        'offer_detail_screen.dart',
        'listing_detail_screen.dart',
        'chat_screen.dart',
        'review_screen.dart',
        'account_settings_screen.dart',
        'my_reviews_screen.dart',
        'provider_status_screen.dart',
        'login_screen.dart',
      ];
      for (final ad in geriGelenler) {
        expect(_kod('lib/screens/$ad').contains('RefBackButton'), isTrue,
            reason: ad);
      }
    });

    test('kök ve sekme ekranlarında ok YOK', () {
      for (final ad in _kokEkranlar) {
        final yol = 'lib/screens/$ad';
        if (!File(yol).existsSync()) {
          continue;
        }
        expect(_kod(yol).contains('RefBackButton'), isFalse,
            reason: '$ad kök/sekme ekranı, geri oku olmamalı');
      }
    });
  });
}
