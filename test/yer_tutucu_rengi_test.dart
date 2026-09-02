import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/theme.dart';

/// YER TUTUCU RENGİ — TEMADA TANIMLI OLMALI
///
/// ⚠ SORUN NEYDİ: `inputDecorationTheme` içinde `hintStyle` yoktu.
/// Flutter kendi varsayılanını kullanıyor ve o renk KOYU olduğu için
/// yer tutucu, kullanıcının YAZDIĞI değerden ayırt edilemiyordu.
/// Kart formunda "Ad Soyad", "0000 0000 0000 0000", "AA/YY" ve "123"
/// metinleri alan doldurulmuş gibi görünüyordu.
///
/// ⚠ Kendi `hintStyle`'ını veren bileşenler (`RefTextField`,
/// `RefFormField`, kayıt ekranı, arama kutuları) temayı ezer ve bu
/// değişiklikten ETKİLENMEZ. Tema yalnız çıplak `InputDecoration`
/// kullanan yerler için geçerlidir.
void main() {
  group('1 — Tema yer tutucu stilini tanımlar', () {
    test('hintStyle var ve rengi açık gri', () {
      final h = HC.theme().inputDecorationTheme.hintStyle;
      expect(h, isNotNull, reason: 'temada hintStyle tanımlı değil');
      expect(h!.color, const Color(0xFF98A2B3),
          reason: 'yer tutucu rengi uygulamanın kendi tonuyla aynı olmalı');
      expect(h.fontWeight, FontWeight.w500);
      expect(h.fontFamily, 'Poppins');
    });

    test('yer tutucu, yazılan metinden DAHA AÇIK', () {
      // ⚠ ASIL KİLİT BU. İki renk birbirine yaklaşırsa aynı şikâyet
      // geri gelir: "hangisi benim yazdığım?"
      final hint = HC.theme().inputDecorationTheme.hintStyle!.color!;
      const yazilan = Color(0xFF16233D); // HC.dark — girilen değerin rengi
      double parlaklik(Color c) => c.computeLuminance();
      expect(parlaklik(hint), greaterThan(parlaklik(yazilan) + 0.25),
          reason: 'yer tutucu yeterince silik değil');
    });
  });

  group('2 — Kart formu temaya bağlı kalır', () {
    String kod(String p) => File(p)
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    test('dört alan da yer tutucusunu temadan alır', () {
      for (final h in const [
        "hintText: 'Ad Soyad'",
        "hintText: '0000 0000 0000 0000'",
        "hintText: 'AA/YY'",
      ]) {
        expect(s.contains(h), isTrue, reason: h);
      }
      // ⚠ Ekran kendi rengini VERMEZ: tek kaynak temadır. Buraya elle
      expect(s.contains('hintStyle:'), isFalse,
          reason: 'kart formu temayı eziyor');
    });
  });
}
