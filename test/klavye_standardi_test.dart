import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String p) => File(p).readAsStringSync();

/// KLAVYE / FOCUS STANDARDI — SÖZLEŞME TESTLERİ
///
/// Amaç: klavye davranışının EKRANDAN EKRANA değişmemesi.
/// Kaynak düzeyinde denetlenir; widget testi cihaz gerektirir.
void main() {
  group('1 — Yapay gecikme ve zorla kaydırma YOK', () {
    final k = read('lib/core/klavye.dart');
    String kod(String x) => x
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//') &&
            !l.trimLeft().startsWith('///'))
        .join('\n');

    // ⚠ Alanları tek tek sarmalayan yapı KALDIRILDI: odak sırasında
    // sayfayı kaydırıp düzen sıçraması yaratıyordu.
    test('KlavyeGorunur sarmalayıcısı kullanılmıyor', () {
      expect(kod(k).contains('class KlavyeGorunur'), isFalse);
      final r = read('lib/ui/ref_widgets.dart');
      expect(r.contains('KlavyeGorunur('), isFalse,
          reason: 'form alanları sarmalanmamalı');
    });

    test('odak sırasında zorla kaydırma yok', () {
      expect(kod(k).contains('Scrollable.ensureVisible'), isFalse);
      expect(kod(k).contains('alignment:'), isFalse);
      expect(kod(k).contains('Duration(milliseconds: 120)'), isFalse);
    });

    // Sayfa geçişi hızlandırması KORUNUR — ama YALNIZ ANDROID'DE.
    //
    // ⚠ iOS'a `HizliGecis` atamak `CupertinoPageTransitionsBuilder`ı
    // eziyor ve KENARDAN GERİ KAYDIRMA jestini öldürüyordu. Hızlı
    // geçiş bir tercih, kenar jesti ise platform davranışıdır;
    // çakıştıklarında platform kazanır.
    test('hızlı sayfa geçişi Android\'de korundu', () {
      expect(k.contains('class HizliGecis'), isTrue);
      final t = read('lib/core/theme.dart');
      expect(t.contains('TargetPlatform.android: HizliGecis()'), isTrue,
          reason: 'Android geçişi hızlandırması kalkmış');
    });

    test('iOS geçişi CUPERTINO — kenar kaydırma jesti yaşar', () {
      final t = read('lib/core/theme.dart');
      expect(t.contains('TargetPlatform.iOS: CupertinoPageTransitionsBuilder()'),
          isTrue,
          reason: 'iOS geçişi Cupertino olmalı');
      expect(t.contains('TargetPlatform.iOS: HizliGecis()'), isFalse,
          reason: 'iOS blokeri geri gelmiş: swipe-back ölür');
    });
  });

  group('2 — Tuş başına TAM EKRAN rebuild YOK', () {
    final r = read('lib/screens/register_screen.dart');

    test('buton aktifliği lokal listenable ile', () {
      expect(r.contains('ValueNotifier<bool>'), isTrue);
      expect(r.contains('ValueListenableBuilder<bool>'), isTrue,
          reason: 'yalnız buton yeniden çizilmeli');
      // Alan değişimi doğrudan setState ÇAĞIRMAZ.
      expect(r.contains('onChanged: (_) => setState(() {})'), isFalse);
    });

    test('doğrulamanın ZAMANI çerçeveye bırakılmaz', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ — GEVŞETİLMEDİ, SIKILAŞTIRILDI.
      //
      // `onUnfocus` tek başına yetmiyordu: alan bir kez doğrulandıktan
      // sonra kullanıcı düzeltmeye döndüğünde İLK TUŞTA uyarı yeniden
      // beliriyordu. Karar artık `_kural` içinde verilir: doğrulama
      // her yeniden çizimde koşar (`always`) ama alan ODAKTAYSA veya
      // henüz TERK EDİLMEDİYSE `null` döner.
      expect(r.contains('AutovalidateMode.always'), isTrue);
      expect(r.contains('AutovalidateMode.onUserInteraction'), isFalse,
          reason: 'her tuşta tüm form doğrulanmamalı');
      expect(r.contains('_terkEdilen'), isTrue,
          reason: 'terk edilen alan kaydı olmadan zamanlama kontrol edilemez');
      // ⚠ `always` her TUŞTA koşmaz: alan değişimi `setState`
      // çağırmaz, yalnız `ValueNotifier` günceller.
      expect(r.contains('onChanged: (_) => setState(() {})'), isFalse);
    });

    // ⚠ SÖZLEŞME DEĞİŞTİ — GEREKÇESİ AYNI.
    //
    // Eski kural "giriş ekranında `autovalidateMode` OLMASIN" idi;
    // amaç tuş başına alan-altı uyarı çıkmamasıydı.
    //
    // Ortak form standardı bu amacı BAŞKA yoldan sağlıyor: doğrulama
    // her çizimde koşar ama `_kural` kapısı alan ODAKTAYKEN ve BOŞKEN
    // hiçbir uyarı DÖNDÜRMEZ. Yani kullanıcı yazarken ekranda uyarı
    // yine çıkmıyor; üstelik düğme de boş alanla pasif.
    test('giriş ekranında TUŞ BAŞINA uyarı çıkmaz', () {
      final l = read('lib/screens/login_screen.dart');
      expect(l.contains('Form('), isTrue, reason: 'Form yapısı korunmalı');
      // Kapı: odak + boş değer denetimi.
      final i = l.indexOf('String? _kural(');
      expect(i, greaterThan(0), reason: 'ortak kapı yok');
      final govde = l.substring(i, l.indexOf('\n  }', i));
      expect(govde.contains('odak.hasFocus'), isTrue);
      expect(govde.contains("(v ?? '').trim().isEmpty"), isTrue);
      // Üç alan da kapıdan geçmeli (şifre satır kırılmış hâlde
      // yazıldığı için sayım yerine tek tek aranır).
      expect(l.contains("_kural('eposta'"), isTrue);
      expect(l.contains("_kural('telefon'"), isTrue);
      expect(l.contains("'sifre', _fPass, v, Validators.loginPassword"), isTrue);
    });
  });

  group('3 — Focus/controller yaşam döngüsü SABİT', () {
    for (final f in const [
      'lib/screens/register_screen.dart',
      'lib/screens/forgot_password_screen.dart',
      'lib/screens/change_password_screen.dart',
      'lib/screens/widgets/ilan_kayit_adimi.dart',
    ]) {
      test('build() içinde FocusNode/Controller yaratılmaz — $f', () {
        final s = read(f);
        final i = s.indexOf('Widget build(BuildContext context)');
        expect(i, greaterThan(0), reason: f);
        final govde = s.substring(i);
        expect(govde.contains('FocusNode()'), isFalse,
            reason: 'build içinde FocusNode üretilmemeli');
        expect(govde.contains('TextEditingController()'), isFalse,
            reason: 'build içinde controller üretilmemeli');
        expect(govde.contains('UniqueKey()'), isFalse,
            reason: 'değişken Key alanı yeniden kurar');
      });
    }
  });

  group('4 — Enter/Next zinciri', () {
    final r = read('lib/screens/register_screen.dart');

    test('nihai sıra: Ad → Soyad → Telefon → E-posta → Şifre → Tekrar', () {
      // Her alanın KALICI odak düğümü var.
      for (final n in const [
        '_fFirst', '_fLast', '_fPhone', '_fEmail', '_fPass', '_fPass2',
      ]) {
        expect(r.contains('final $n = FocusNode();'), isTrue, reason: n);
        expect(r.contains('$n.dispose();'), isTrue, reason: '$n dispose');
      }
      // Zincir bağlantıları.
      //
      // ⚠ SÖZLEŞME GÜNCELLENDİ: `onFieldSubmitted` → `onEditingComplete`.
      // Nihai davranış Next geçişini `onEditingComplete` ile yapar;
      // production bu teste uydurmak için GERİ ALINMADI, test yeni
      // davranışa göre düzeltildi. Sıra değişmedi.
      expect(r.contains('onEditingComplete: () => _fLast.requestFocus()'),
          isTrue);
      expect(r.contains('onEditingComplete: () => _fPhone.requestFocus()'),
          isTrue);
      expect(r.contains('onEditingComplete: () => _fEmail.requestFocus()'),
          isTrue);
      expect(r.contains('onEditingComplete: () => _fPass.requestFocus()'),
          isTrue);
      expect(r.contains('onEditingComplete: () => _fPass2.requestFocus()'),
          isTrue);
    });

    test('ara alanlar next, son alan done', () {
      expect(r.contains('TextInputAction.next'), isTrue);
      expect(r.contains('TextInputAction.done'), isTrue);
      // Ara alanlarda done KULLANILMAZ (klavyeyi kapatır).
      expect(RegExp(r'TextInputAction\.done').allMatches(r).length, 1,
          reason: 'yalnız son alan klavyeyi kapatmalı');
    });
  });

  group('5 — Klavye kendiliğinden kapanmaz', () {
    test('kayıt ekranında unfocus çağrısı YOK', () {
      final r = read('lib/screens/register_screen.dart');
      expect(r.contains('unfocus()'), isFalse,
          reason: 'yazarken odak düşürülmemeli');
      expect(r.contains('primaryFocus'), isFalse);
    });
  });

  group('6 — Teşhis sistemi üretimi ETKİLEMEZ', () {
    final t = read('lib/core/teshis.dart');

    test('bayraklar varsayılan KAPALI', () {
      expect(t.contains("bool.fromEnvironment('FOCUS_LOG')"), isTrue);
      expect(t.contains("bool.fromEnvironment('NO_ONCHANGED')"), isTrue);
      expect(t.contains("bool.fromEnvironment('STATIC_REGION')"), isTrue);
    });

    test('kapalıyken dinleyici eklenmez, panel çizilmez', () {
      expect(t.contains('if (!Teshis.focusLog'), isTrue);
      expect(t.contains('return const SizedBox.shrink();'), isTrue);
    });
  });
}
