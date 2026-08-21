// TÜM FORMLARDA İKİ KURAL
//
// K-A  BOŞ ALAN UYARI ÜRETMEZ.
//      Kullanıcı bir alanı doldurup silerse ekranda uyarı KALMAZ.
//      Hiçbir alanda bilgi yokken hiçbir uyarı görünmez.
//
// K-B  EKSİK ALAN VARKEN GÖNDERİM DÜĞMESİ PASİFTİR.
//      Zorunlu alanların hepsi dolunca aktif olur. Yanlış yazılmış
//      alan varsa uyarı YALNIZ o alanda çıkar.
//
// ⚠ İkisi birlikte çalışır: düğme pasif olduğu için "Bu alan
// zorunludur" uyarısı zaten hiç tetiklenmez.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) =>
          !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

/// Kural uygulanan form ekranları.
const _formEkranlari = <String>[
  'lib/screens/login_screen.dart',
  'lib/screens/register_screen.dart',
  'lib/screens/change_password_screen.dart',
  'lib/screens/forgot_password_screen.dart',
  'lib/screens/yeni_sifre_screen.dart',
  'lib/screens/profile_info_screen.dart',
];

void main() {
  group('K-A — BOŞ ALAN UYARI ÜRETMEZ', () {
    test('her form ekranında boş-alan kapısı var', () {
      final eksik = <String>[];
      for (final f in _formEkranlari) {
        final k = _kod(f);
        // ⚠ İKİ YAZIM DA GEÇERLİ: bazı ekranlar `trim()` uygular,
        // bazıları uygulamaz; kayıt ekranı ayrıca `_bosUyariGoster`
        // kapısıyla birleştirir. Aranan şey BOŞ DEĞER DENETİMİDİR.
        final bosKurali = k.contains("(v ?? '').isEmpty") ||
            k.contains("(v ?? '').trim().isEmpty");
        if (!bosKurali) {
          eksik.add(f.split('/').last);
        }
      }
      expect(eksik, isEmpty, reason: 'boş-alan kapısı yok: $eksik');
    });

    test('boş kural KAPININ İÇİNDE — gönderimde zorunluluk yine işler', () {
      // Kapı `_gonderimAninda` denetiminin içindedir; gönderim anında
      // atlanır ve boş alan yine reddedilir.
      for (final f in const [
        'lib/screens/change_password_screen.dart',
        'lib/screens/yeni_sifre_screen.dart',
        'lib/screens/profile_info_screen.dart',
      ]) {
        final k = _kod(f);
        final i = k.indexOf('if (!_gonderimAninda) {');
        final j = k.indexOf('return asil(v);', i);
        expect(i, greaterThan(-1), reason: f);
        final govde = k.substring(i, j);
        expect(
            govde.contains("').isEmpty) {") ||
                govde.contains("').trim().isEmpty) {"),
            isTrue,
            reason: '$f: boş denetimi kapının dışına çıkmış');
      }
    });

    test('kayıt formunda boş alan YALNIZ gönderimde uyarır', () {
      // ⚠ ESKİ KURAL KALDIRILDI. Kayıt formu iki durumda daha
      // uyarıyordu: alan terk edilmişse ya da SONRASI doldurulmuşsa
      // (atlanmış alan). Yeni ürün kuralı bunu yasakladı; eksik alan
      // artık uyarıyla değil DÜĞMEYİ PASİF TUTARAK bildiriliyor.
      final r = _kod('lib/screens/register_screen.dart');
      expect(
          r.contains(
              'bool _bosUyariGoster(TextEditingController c) => _gonderimAninda;'),
          isTrue);
      expect(r.contains('_terkEdilen.contains(c) || _sonrasiDolu(c)'), isFalse,
          reason: 'eski boş-uyarı kuralı geri gelmiş');
    });

    test('giriş ekranında da aynı kapı var', () {
      // Giriş ekranı bir tur bu kuralın DIŞINDA kalmıştı: alan
      // doldurulup silinince "Geçerli bir e-posta adresi giriniz"
      // ekranda asılı kalıyordu.
      final l = _kod('lib/screens/login_screen.dart');
      final i = l.indexOf('String? _kural(');
      final govde = l.substring(i, l.indexOf('\n  }', i));
      expect(govde.contains('if (odak.hasFocus) {'), isTrue);
      expect(govde.contains('!_terkEdilen.contains(alan)'), isTrue);
      expect(govde.contains("if ((v ?? '').trim().isEmpty) {"), isTrue);
      // Üç alanın üçü de kapıdan geçer (şifre çağrısı satır
      // kırıldığı için ad ayrı satırda: `_kural(\n 'sifre'`).
      expect("_kural(".allMatches(l).length, 4); // 1 tanım + 3 çağrı
      for (final alan in const ["'eposta'", "'telefon'", "'sifre'"]) {
        expect(l.contains(alan), isTrue, reason: alan);
      }
      // Ham validator ATANMAZ.
      expect(l.contains('validator: Validators.email,'), isFalse);
      expect(l.contains('validator: Validators.phone,'), isFalse);
      expect(l.contains('validator: Validators.loginPassword,'), isFalse);
    });

    test('giriş formu canlı doğrulama kipinde', () {
      // Kip olmadan hata bir kez basılıp EKRANDA DONUYORDU: alan
      // silinse bile yeniden değerlendirilmiyordu.
      final l = _kod('lib/screens/login_screen.dart');
      expect(l.contains('autovalidateMode: AutovalidateMode.always'), isTrue);
    });
  });

  group('K-B — EKSİK ALAN VARKEN DÜĞME PASİF', () {
    test('giriş: zorunlular GEÇERLİ olmadan düğme aktif olmaz', () {
      final l = _kod('lib/screens/login_screen.dart');
      expect(l.contains('bool get _zorunlularDolu =>'), isTrue);
      // ⚠ Google giriş kaldırıldı; koşulda `_busyGoogle` yok.
      expect(l.contains('onPressed: (!_zorunlularDolu)'), isTrue);
      // ⚠ KURAL SIKILAŞTIRILDI: "dolu mu" YETMEZ, "geçerli mi" aranır.
      //
      // Eskiden yalnız alanın boş olmadığına bakılıyordu; kullanıcı
      // e-posta yerine `abc`, telefon yerine `53` yazdığında düğme
      // AKTİF kalıyor ve sunucuya geçersiz istek gidiyordu.
      final i = l.indexOf('bool get _zorunlularDolu =>');
      final govde = l.substring(i, i + 260);
      expect(govde.contains('Validators.email(_email.text) == null'), isTrue,
          reason: 'e-posta modunda BİÇİM denetlenmiyor');
      expect(govde.contains('Validators.phone(_phone.text) == null'), isTrue,
          reason: 'telefon modunda BİÇİM denetlenmiyor');
      // ⚠ ŞİFREDE YALNIZ DOLULUK ARANIR — bilerek. Şifre kuralı
      // değişirse eski şifreli kullanıcı kendi hesabından kilitlenmez.
      expect(govde.contains('_pass.text.trim().isNotEmpty'), isTrue);
      // Eski gevşek kural geri gelmemeli.
      expect(govde.contains('_email.text.trim().isNotEmpty'), isFalse,
          reason: 'doluluk kuralı geri gelmiş');
      expect(govde.contains('_phone.text.trim().isNotEmpty'), isFalse,
          reason: 'doluluk kuralı geri gelmiş');
    });

    test('şifremi unuttum: alan boşken düğme pasif', () {
      final f = _kod('lib/screens/forgot_password_screen.dart');
      expect(f.contains('bool get _zorunluDolu =>'), isTrue);
      expect(f.contains('onPressed: _zorunluDolu ? _baglantiGonder : null'),
          isTrue);
      expect(f.contains('onPressed: _zorunluDolu ? _telefonKodIste : null'),
          isTrue);
    });

    test('yeni şifre: iki alan da dolmadan düğme pasif', () {
      final y = _kod('lib/screens/yeni_sifre_screen.dart');
      expect(y.contains('bool get _zorunlularDolu =>'), isTrue);
      expect(y.contains('onPressed: _zorunlularDolu ? _kaydet : null'), isTrue);
    });

    test('profil bilgileri: geçerlilik + değişiklik şartı korunuyor', () {
      final p = _kod('lib/screens/profile_info_screen.dart');
      expect(
          p.contains(
              'onPressed: (_formGecerli && _degisiklikVar) ? _save : null'),
          isTrue);
    });

    test('değer değişince düğme durumu TAZELENİR', () {
      // `onChanged` olmadan doluluk değişse bile düğme pasif kalırdı.
      for (final f in const [
        'lib/screens/login_screen.dart',
        'lib/screens/forgot_password_screen.dart',
        'lib/screens/yeni_sifre_screen.dart',
      ]) {
        expect(_kod(f).contains('onChanged:'), isTrue, reason: f);
      }
    });
  });
}
