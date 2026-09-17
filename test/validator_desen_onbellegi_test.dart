// DOĞRULAYICI DESENLERİ BİR KEZ DERLENİR — KİLİT
//
// ⚠ KULLANICI BULGUSU (9 Eyl): "Ad/soyad/telefon girildikten sonra
// il-ilçe-mahalle seçimine gelindiğinde yavaşlama oluyor; hiç
// dokunmadan doğrudan seçime gidilirse kasma yok."
//
// ÖLÇÜLEN ZİNCİR:
//   1. Form `AutovalidateMode.onUserInteraction` — alanlara
//      DOKUNULANA KADAR doğrulayıcı koşmaz. Kasmanın yalnız
//      yazdıktan sonra başlamasının sebebi budur.
//   2. Dokunulduktan sonra HER yeniden çizim altı alanı doğrular.
//   3. Kayıt ekranının dolgusu `MediaQuery.viewInsetsOf`e bağlı;
//      klavye inip çıkarken 613 satırlık `build` ~15-20 kez koşar.
//
// ⚠ ASIL MALİYET: `RegExp(...)` her çağrıldığında deseni YENİDEN
// derler; Dart önbelleğe almaz. `name()` tek çağrıda dört desen
// kuruyordu, ad ve soyad ayrı alan olduğu için bir doğrulama turu
// dokuz desen derliyordu.
//
// ⚠ BU TEST DAVRANIŞI DA KİLİTLER: desenler taşınırken kural
// değişmediğinin kanıtı, doğrulama SONUÇLARININ aynı kalmasıdır.
// Aşağıdaki beklentiler taşımadan önceki davranıştır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/validators.dart';

void main() {
  group('1 — DESENLER ÖNCEDEN DERLENİR', () {
    final ham = File('lib/core/validators.dart').readAsStringSync();
    final kod = ham
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    test('⚠ METOT GÖVDESİNDE RegExp KURULMAZ', () {
      // Alan tanımları dışında `RegExp(` kalmamalı: kalan her tane,
      // her çağrıda yeniden derlenen bir desendir.
      final tumu = RegExp(r'RegExp\(').allMatches(kod).length;
      final alanlar =
          RegExp(r'static final RegExp \w+ =\s*\n?\s*RegExp\(').allMatches(kod).length;
      expect(tumu, alanlar,
          reason: 'metot içinde $tumu-$alanlar adet desen her çağrıda '
              'yeniden derleniyor');
    });

    test('⚠ static const DEĞİL static final', () {
      // `RegExp` sabit ifade olamaz; `const` derleme hatası verirdi.
      expect(kod.contains('static const RegExp'), isFalse);
    });
  });

  group('2 — KURALLAR DEĞİŞMEDİ', () {
    test('ad: geçerli olanlar', () {
      expect(Validators.name('Onur'), isNull);
      expect(Validators.name('Ayşe Nur'), isNull);
      expect(Validators.name('Bütün', min: 2, label: 'soyad'), isNull);
    });

    test('ad: reddedilenler', () {
      expect(Validators.name(''), isNotNull);
      expect(Validators.name('ab'), isNotNull, reason: 'asgari uzunluk');
      expect(Validators.name('test'), isNotNull, reason: 'engelli kelime');
      expect(Validators.name('aaaa'), isNotNull, reason: 'üç tekrar');
      expect(Validators.name('bcdf'), isNotNull, reason: 'dört sessiz');
      expect(Validators.name('Onur1'), isNotNull, reason: 'rakam');
    });

    test('e-posta', () {
      expect(Validators.email('onur@hotmail.com'), isNull);
      expect(Validators.email('onur@'), isNotNull);
      expect(Validators.email('onurhotmail.com'), isNotNull);
    });

    test('telefon', () {
      expect(Validators.phone('05551112233'), isNull);
      expect(Validators.phone('555'), isNotNull);
    });

    test('şifre', () {
      expect(Validators.password('a' * kPasswordMinLength), isNull);
      expect(Validators.password('a' * (kPasswordMinLength - 1)), isNotNull);
    });

    test('kart numarası biçimi — dörtlü gruplama', () {
      expect(Validators.cardNumFmt('4111111111111111'),
          '4111 1111 1111 1111');
    });

    test('⚠ AYNI GİRDİ ART ARDA AYNI SONUCU VERİR', () {
      // Paylaşılan `RegExp` nesnesi durum taşımaz; `allMatches` gibi
      // çağrılar sonraki çağrıyı ETKİLEMEMELİ.
      for (var i = 0; i < 3; i++) {
        expect(Validators.name('Onur'), isNull);
        expect(Validators.cardNumFmt('4111111111111111'),
            '4111 1111 1111 1111');
      }
    });
  });
}
