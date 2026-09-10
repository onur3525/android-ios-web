// TAMAMLANAN İŞ SAYISI — İZLEYENDEN BAĞIMSIZ (KİLİT)
//
// ⚠ KULLANICI BULGUSU (9 Eyl): "Yeni hesap açan bir hizmet alan,
// hizmet verenin güncel iş bitirme sayısını kartlarda göremiyor."
//
// ⚠ KÖK NEDEN: sayı YALNIZ türetiliyordu — izleyenin GÖREBİLDİĞİ
// ilan ve teklifler taranıyordu. Yeni açılmış bir hesabın hiç ilanı
// yoktur, dolayısıyla sonuç DAİMA 0 çıkıyordu. Hizmet veren yüz iş
// bitirmiş olsa bile.
//
// Bir kişinin geçmişi, ona BAKAN kişinin verisinden hesaplanamaz.
//
// ⚠ ÇÖZÜM: sayaç kişinin KENDİ hesabında tutulur
// (`Account.tamamlananIs`) ve iş tamamlandığında oraya yazılır.
// Türetim kaldırılmadı; `tamamlananIsSayisi` ikisinin BÜYÜĞÜNÜ
// döndürür, böylece sayacın işlenmediği eski kayıtlarda ilan sahibi
// kendi doğru sayısını görmeye devam eder ve toplama yapılmadığı
// için mükerrer sayım imkânsızdır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

Account _hesap({int tamamlanan = 0}) => Account(
      id: 'u1',
      phone: '05551112233',
      passwordHash: 'h',
      salt: 's',
      tamamlananIs: tamamlanan,
    );

void main() {
  group('1 — HESAPTA SAKLANIR', () {
    test('yeni hesapta sıfır', () {
      expect(_hesap().tamamlananIs, 0);
    });

    test('⚠ KALICI: JSON turunda kaybolmaz', () {
      // APK testlerinde uygulama kapanıp açılınca sayaç
      // sıfırlanmamalı.
      final a = _hesap(tamamlanan: 7);
      final geri = Account.fromJson(a.toJson());
      expect(geri.tamamlananIs, 7);
    });

    test('⚠ ESKİ KAYITTA ALAN YOK — 0 OKUNUR, ÇÖKMEZ', () {
      final ham = _hesap(tamamlanan: 3).toJson()..remove('tamamlananIs');
      expect(Account.fromJson(ham).tamamlananIs, 0);
    });
  });

  group('2 — SAYAÇ İŞ TAMAMLANINCA ARTAR', () {
    test('ilan akışı: teklif seçilince', () {
      final k = _kodu('lib/data/ports/mock_ports.dart');
      expect(k.contains('saglayiciHesabi.tamamlananIs += 1'), isTrue,
          reason: 'ilan tamamlandığında sayaç yazılmıyor');
    });

    test('"Bul" akışı: talep tamamlanınca', () {
      final k = _kodu('lib/data/ports/teklif_talebi_port.dart');
      expect(k.contains('hesap.tamamlananIs += 1'), isTrue,
          reason: 'kazanılan talep sayaca yazılmıyor');
    });

    test('⚠ MÜKERRER SAYIM KORUMASI', () {
      // Zaten `tamamlandi` olan bir talep ikinci kez tamamlanırsa
      // sayaç YANLIŞ artardı.
      final k = _kodu('lib/data/ports/teklif_talebi_port.dart');
      expect(k.contains('oncekiDurum != TeklifTalebiDurumu.tamamlandi'),
          isTrue);
    });
  });

  group('3 — OKUMA İZLEYENE BAĞLI DEĞİL', () {
    final k = _kodu('lib/domain/saglayici_ozeti.dart');

    test('hesaptaki sayaç okunur', () {
      expect(k.contains('?.tamamlananIs'), isTrue,
          reason: 'sayı hâlâ yalnız türetiliyor — yeni hesap 0 görür');
    });

    test('⚠ TÜRETİM KALDIRILMADI, BÜYÜĞÜ ALINIR', () {
      // Toplama yapılsaydı ilan sahibi kendi işlerini İKİ KEZ
      // sayardı.
      expect(k.contains('saklanan > turetilen ? saklanan : turetilen'),
          isTrue);
      expect(k.contains('saklanan + turetilen'), isFalse,
          reason: 'toplama mükerrer sayım üretir');
    });
  });
}
