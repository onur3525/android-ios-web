import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/telefon_bicimi.dart';
import 'package:hizmetcep/core/validators.dart';

/// TELEFON GİRİŞİ VE GİRİŞ DÜĞMESİ — REGRESYON KİLİTLERİ
///
/// ⚠ BU DOSYA İKİ SAHA HATASINI KİLİTLER. İkisi de APK üzerinde
/// görüldü, kod okumasıyla kök nedene inildi ve onayla düzeltildi.
///
/// ── 1. HIZLI ARDIŞIK RAKAM GİRİŞİNDE RAKAM DÜŞMESİ ──
///
/// Biçimlendirici, ilk rakam girildiğinde metne otomatik `0`
/// ekliyordu: kullanıcı BİR tuşa basıyor, metin İKİ karakter
/// uzuyordu. Android IME bu uzamayı ancak bir sonraki güncellemeyle
/// öğrenir; kullanıcı o güncelleme ulaşmadan bir sonraki tuşa
/// basarsa IME ESKİ metin üzerinden düzenleme gönderir, imleç hesabı
/// kayar ve rakam düşer. Yavaş yazımda pencere kapandığı için sorun
/// görünmüyordu.
///
/// ⚠ ÇÖZÜM: biçimlendirici artık metin UZUNLUĞUNU DEĞİŞTİRMEZ.
/// Baştaki `0` yazma anında değil, normalize/gönderim aşamasında
/// üretilir (`Validators.phoneLocal`).
///
/// ── 2. GEÇERSİZ BİLGİYLE GİRİŞ DÜĞMESİNİN AKTİF KALMASI ──
///
/// `_zorunlularDolu` yalnız alanın boş olmadığına bakıyordu.
///
/// ⚠ Bu dosyadaki testler GEVŞETİLMEZ. Davranış değişecekse önce
/// ürün kararı alınır, sonra buradaki sözleşme güncellenir.
void main() {
  const b = TelefonBicimlendirici();

  /// Kullanıcının TEK TUŞA basmasını taklit eder.
  ///
  /// ⚠ Gerçek klavye davranışı budur: metin imlecin olduğu yere bir
  /// karakter ekler ve imleci bir ileri taşır. Doğrudan tam metin
  /// vermek (`yaz('5321112233')`) yapıştırmayı taklit eder, YAZMAYI
  /// değil — ve tam da bu yüzden saha hatasını yakalamazdı.
  TextEditingValue tusaBas(TextEditingValue mevcut, String rakam) {
    final imlec = mevcut.selection.baseOffset < 0
        ? mevcut.text.length
        : mevcut.selection.baseOffset;
    final yeniMetin =
        mevcut.text.substring(0, imlec) + rakam + mevcut.text.substring(imlec);
    return b.formatEditUpdate(
      mevcut,
      TextEditingValue(
        text: yeniMetin,
        selection: TextSelection.collapsed(offset: imlec + 1),
      ),
    );
  }

  /// Bir diziyi tuş tuş yazar.
  TextEditingValue diziYaz(String haneler) {
    var v = TextEditingValue.empty;
    for (final r in haneler.split('')) {
      v = tusaBas(v, r);
    }
    return v;
  }

  group('1 — HIZLI ARDIŞIK GİRİŞ: HİÇBİR RAKAM DÜŞMEZ', () {
    test('10 hane tuş tuş yazılır, tamamı alanda kalır', () {
      final v = diziYaz('5321112233');
      expect(v.text, '5321112233',
          reason: 'yazılan rakamlardan biri düşmüş');
      expect(v.text.length, 10);
    });

    test('imleç her tuştan sonra DOĞRU yerde', () {
      // ⚠ İmleç kaçarsa sonraki rakam yanlış konuma düşer; saha
      // hatasının ikinci yüzü buydu.
      var v = TextEditingValue.empty;
      var beklenen = 0;
      for (final r in '5321112233'.split('')) {
        v = tusaBas(v, r);
        beklenen++;
        expect(v.selection.baseOffset, beklenen,
            reason: '$beklenen. tuştan sonra imleç kaymış');
      }
    });

    test('her adımda uzunluk TAM BİR artar', () {
      // ⚠ ASIL KİLİT BU. Uzunluk bir tuşta ikiden fazla artarsa
      // (otomatik `0` geri gelmişse) IME uyumsuzluğu da geri gelir.
      var v = TextEditingValue.empty;
      var onceki = 0;
      for (final r in '5321112233'.split('')) {
        v = tusaBas(v, r);
        expect(v.text.length, onceki + 1,
            reason: 'biçimlendirici metin uzunluğunu değiştirmiş');
        onceki = v.text.length;
      }
    });

    test('0 ile başlayan 11 hane de tuş tuş yazılabilir', () {
      final v = diziYaz('05321112233');
      expect(v.text, '05321112233');
      expect(v.selection.baseOffset, 11);
    });
  });

  group('2 — SINIR: baştaki 0 varsa 11, yoksa 10', () {
    test('5 ile başlayan alanda 11. hane KABUL EDİLMEZ', () {
      final v = diziYaz('53211122339');
      expect(v.text, '5321112233',
          reason: '10 haneden fazlası alınmış — numara sessizce geçersiz olur');
    });

    test('0 ile başlayan alanda 12. hane KABUL EDİLMEZ', () {
      final v = diziYaz('053211122339');
      expect(v.text, '05321112233');
    });
  });

  group('3 — Düzenleme davranışı KORUNDU', () {
    TextEditingValue duzenle(String eski, String yeni, int imlec) =>
        b.formatEditUpdate(
            TextEditingValue(text: eski),
            TextEditingValue(
                text: yeni,
                selection: TextSelection.collapsed(offset: imlec)));

    test('ortadan silmede imleç yerinde kalır', () {
      final v = duzenle('5321112233', '532112233', 5);
      expect(v.text, '532112233');
      expect(v.selection.baseOffset, 5);
    });

    test('alan tamamen boşaltılabilir ve imleç GEÇERLİ kalır', () {
      final v = duzenle('5', '', 0);
      expect(v.text, '');
      expect(v.selection.baseOffset, 0);
    });

    test('sunucudan gelen 0\'lı numara düzenlenebilir', () {
      // `phoneLocal` alana `0532…` yazar; kullanıcı onu düzeltebilmeli.
      final v = duzenle('05321112233', '0532111223', 10);
      expect(v.text, '0532111223');
    });
  });

  group('4 — Backend sözleşmesi DEĞİŞMEDİ', () {
    test('0\'sız yazım da 0\'lı yazım da AYNI değere normalize olur', () {
      // ⚠ En kritik denetim: `0`ın yazma anında eklenmemesi gönderilen
      expect(Validators.phoneFmt('5321112233'), '5321112233');
      expect(Validators.phoneFmt('05321112233'), '5321112233');
      expect(Validators.phone('5321112233'), isNull);
      expect(Validators.phone('05321112233'), isNull);
    });

    test('gösterimde 0 gerektiğinde phoneLocal üretir', () {
      expect(Validators.phoneLocal('5321112233'), '05321112233');
      expect(TelefonBicimlendirici.gruplu('05321112233'), '0532 111 22 33');
    });
  });

  group('5 — GİRİŞ DÜĞMESİ: geçersiz bilgide PASİF', () {
    String kod(String p) => File(p)
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    test('kural BİÇİM denetler, doluluk değil', () {
      final l = kod('lib/screens/login_screen.dart');
      final i = l.indexOf('bool get _zorunlularDolu =>');
      expect(i, greaterThan(0));
      final govde = l.substring(i, i + 260);
      expect(govde.contains('Validators.email(_email.text) == null'), isTrue);
      expect(govde.contains('Validators.phone(_phone.text) == null'), isTrue);
      // ⚠ Eski gevşek kural geri gelmemeli.
      expect(govde.contains('_email.text.trim().isNotEmpty'), isFalse);
      expect(govde.contains('_phone.text.trim().isNotEmpty'), isFalse);
    });

    test('kuralın dayandığı doğrulayıcılar geçersizi REDDEDER', () {
      // Düğmenin pasif kalacağı gerçek girdiler.
      expect(Validators.email('abc'), isNotNull);
      expect(Validators.email('abc@'), isNotNull);
      expect(Validators.phone('53'), isNotNull);
      expect(Validators.phone('532111223'), isNotNull);
      // Geçerli girdide düğme açılır.
      expect(Validators.email('ali@ornek.com'), isNull);
      expect(Validators.phone('5321112233'), isNull);
    });

    test('şifrede YALNIZ doluluk aranır — bilerek', () {
      // ⚠ Şifre kuralı değişirse eski şifreli kullanıcı kendi
      // hesabından kilitlenmemeli; doğruluğa sunucu karar verir.
      final l = kod('lib/screens/login_screen.dart');
      final i = l.indexOf('bool get _zorunlularDolu =>');
      final govde = l.substring(i, i + 260);
      expect(govde.contains('_pass.text.trim().isNotEmpty'), isTrue);
      expect(govde.contains('Validators.password(_pass.text)'), isFalse);
    });
  });
}
