// FORMLARDA ENTER/İLERİ TUŞU — ALAN GEÇİŞİ SÖZLEŞMESİ
//
// KURAL: çok alanlı bir formda Enter (klavyedeki İleri tuşu) bir
// SONRAKİ alana geçer. Kullanıcı alanları elle seçmek zorunda kalmaz.
//
//   • Ara alanlar : TextInputAction.next + onEditingComplete ile
//                   sonraki alanın odağı
//   • Son alan    : TextInputAction.done — klavye kapanır, form
//                   KENDİLİĞİNDEN GÖNDERİLMEZ
//   • Çok satırlı alanlar (maxLines > 1) BU KURALIN DIŞINDADIR:
//     orada Enter yeni satır açar, geçiş yapmaz.
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

/// Tek satırlık alan sayısı — çok satırlılar hariç.
int _tekSatirAlan(String kod) {
  final toplam = 'TextFormField('.allMatches(kod).length +
      'RefTextField('.allMatches(kod).length +
      RegExp(r'\bTextField\(').allMatches(kod).length;
  final cokSatirli = RegExp(r'maxLines: [2-9]').allMatches(kod).length;
  return toplam - cokSatirli;
}

void main() {
  group('PROFİL BİLGİLERİM — ZİNCİR TAM', () {
    final p = _kod('lib/screens/profile_info_screen.dart');

    test('dört alanın da ileri tuşu tanımlı', () {
      // Eskiden hiç `textInputAction` yoktu: varsayılan `done` olduğu
      // için Enter klavyeyi kapatıyordu.
      expect('textInputAction:'.allMatches(p).length, 4);
      expect('TextInputAction.next'.allMatches(p).length, 3);
      expect('TextInputAction.done'.allMatches(p).length, 1);
    });

    test('geçiş sırası GÖRSEL sırayla aynı', () {
      expect(p.contains('onEditingComplete: () => _fSoyad.requestFocus()'),
          isTrue);
      expect(p.contains('onEditingComplete: () => _fEposta.requestFocus()'),
          isTrue);
      expect(p.contains('onEditingComplete: () => _fTelefon.requestFocus()'),
          isTrue);

      final iAd = p.indexOf('_fSoyad.requestFocus()');
      final iSoyad = p.indexOf('_fEposta.requestFocus()');
      final iEposta = p.indexOf('_fTelefon.requestFocus()');
      expect(iAd, greaterThan(0));
      expect(iSoyad, greaterThan(iAd));
      expect(iEposta, greaterThan(iSoyad));
    });

    test('son alan form GÖNDERMEZ', () {
      // `done` yalnız klavyeyi kapatır; kaydetme düğmesi kendi
      // kuralıyla çalışır (form geçerli + değişiklik var).
      expect(p.contains('onFieldSubmitted'), isFalse,
          reason: 'son alan formu kendiliğinden gönderiyor');
    });
  });

  group('KART FORMU — ZİNCİR EKLENDİ', () {
    final k = _kod('lib/screens/widgets/saved_cards_section.dart');

    test('dört alanın da ileri tuşu tanımlı', () {
      expect('textInputAction:'.allMatches(k).length, 4);
      expect('TextInputAction.next'.allMatches(k).length, 3);
      expect('TextInputAction.done'.allMatches(k).length, 1);
    });

    test('odak düğümleri tanımlı ve BIRAKILIYOR', () {
      for (final f in const ['_fAd', '_fNumara', '_fSonKullanma', '_fCvv']) {
        expect(k.contains('final $f = FocusNode();'), isTrue, reason: f);
      }
      expect(k.contains('for (final f in [_fAd, _fNumara, _fSonKullanma, _fCvv])'),
          isTrue,
          reason: 'odak düğümleri dispose edilmiyor');
    });

    test('geçiş sırası: Ad → Numara → Son Kullanma → CVV', () {
      final i1 = k.indexOf('onEditingComplete: _fNumara.requestFocus');
      final i2 = k.indexOf('onEditingComplete: _fSonKullanma.requestFocus');
      final i3 = k.indexOf('onEditingComplete: _fCvv.requestFocus');
      expect(i1, greaterThan(0));
      expect(i2, greaterThan(i1));
      expect(i3, greaterThan(i2));
    });
  });

  group('ZATEN DOĞRU OLAN FORMLAR — BOZULMADI', () {
    test('kayıt formu altı alanda da zinciri korur', () {
      final r = _kod('lib/screens/register_screen.dart');
      expect('textInputAction:'.allMatches(r).length, 6);
      expect(r.contains('TextInputAction.next'), isTrue);
    });

    test('şifre değiştir üç alanda zinciri korur', () {
      final c = _kod('lib/screens/change_password_screen.dart');
      expect('textInputAction:'.allMatches(c).length, 3);
      expect(c.contains('onEditingComplete: () => _f_new1.requestFocus()'),
          isTrue);
      expect(c.contains('onEditingComplete: () => _f_new2.requestFocus()'),
          isTrue);
    });

    test('şifremi unuttum: tek alanlı formlar done ile biter', () {
      // ⚠ EKRAN BAŞTAN YAZILDI: şifre alanları buradan ÇIKTI,
      // Yeni Şifre Belirle ekranına taşındı. Bu ekranda artık her
      // dalda TEK alan var (e-posta veya telefon), dolayısıyla
      // geçilecek bir sonraki alan yok.
      final f = _kod('lib/screens/forgot_password_screen.dart');
      expect(f.contains('TextInputAction.done'), isTrue);
      expect(f.contains('TextInputAction.next'), isFalse,
          reason: 'geçilecek ikinci alan yok');
    });

    test('yeni şifre ekranı zinciri korur', () {
      final y = _kod('lib/screens/yeni_sifre_screen.dart');
      expect(y.contains('onEditingComplete: () => _fTekrar.requestFocus()'),
          isTrue);
      expect(y.contains('TextInputAction.next'), isTrue);
      expect(y.contains('TextInputAction.done'), isTrue);
    });

    test('kayıtsız ilan akışı zinciri korur', () {
      final i = _kod('lib/screens/widgets/ilan_kayit_adimi.dart');
      expect(i.contains('TextInputAction.next'), isTrue);
      expect(i.contains('onEditingComplete: () => _sonraki(id)'), isTrue);
    });
  });

  group('TEK SATIRLIK HER ALANIN İLERİ TUŞU TANIMLI', () {
    /// Çok satırlı alan içeren ekranlar bu denetimin dışındadır:
    /// orada Enter yeni satır açar.
    const cokSatirliEkranlar = {
      'review_screen.dart',
      'app_rate_screen.dart',
      'create_listing_screen.dart',
    };

    /// Metin girişi olmayan / arama-sohbet gibi tek amaçlı alanlar.
    const kapsamDisi = {
      'chat_screen.dart',
      'search_screen.dart',
      'inline_search_box.dart',
      'kategori_secim_paneli.dart',
      'region_picker.dart',
      'my_areas_screen.dart',
      'my_categories_screen.dart',
      'all_categories_screen.dart',
      'account_settings_screen.dart',
      'job_detail_screen.dart',
      'ilan_otp_adimi.dart',
      'hc_widgets.dart',
    };

    test('çok alanlı formlarda eksik ileri tuşu YOK', () {
      final eksik = <String>[];
      for (final d in [
        Directory('lib/screens'),
        Directory('lib/screens/widgets'),
      ]) {
        for (final f in d.listSync().whereType<File>()) {
          final ad = f.path.split('/').last;
          if (!ad.endsWith('.dart')) {
            continue;
          }
          if (cokSatirliEkranlar.contains(ad) || kapsamDisi.contains(ad)) {
            continue;
          }
          final kod = _kod(f.path);
          final alan = _tekSatirAlan(kod);
          if (alan < 2) {
            continue; // tek alanlı form — geçilecek yer yok
          }
          final action = 'textInputAction:'.allMatches(kod).length;
          if (action < alan) {
            eksik.add('$ad ($alan alan / $action ileri tuşu)');
          }
        }
      }
      expect(eksik, isEmpty, reason: 'ileri tuşu eksik form: $eksik');
    });
  });
}
