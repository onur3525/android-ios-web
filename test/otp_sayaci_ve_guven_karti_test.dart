import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// OTP SAYACI VE ANA SAYFA GÜVEN KARTI — REGRESYON KİLİTLERİ
///
/// İkisi de cihazda görülen, kaynak testlerinin kaçırdığı hatalardı.
String _kod(String p) => File(p)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('1 — OTP SAYACI SIFIRDA TAKILMAZ', () {
    final o = _kod('lib/screens/otp_screen.dart');

    test('sıfıra düşen tetiklemede de çizim istenir', () {
      // ⚠ ESKİ HATA: `if (_left > 0) setState(...)`.
      //
      // Sayaç 1'den 0'a düştüğü tetiklemede koşul yanlış oluyor ve
      // ekran HİÇ ÇİZİLMİYORDU: son çizilen "00:01" asılı kalıyor,
      // "Kod gelmedi mi?" / "Numaranızın doğru olduğundan emin olun."
      // / "Tekrar Gönder" hiç görünmüyordu.
      expect(o.contains('if (_left > 0) {'), isFalse,
          reason: 'koşullu çizim geri gelmiş — sayaç 00:01\'de donar');
      final i = o.indexOf('Timer.periodic');
      expect(i, greaterThan(0));
      final govde = o.substring(i, i + 400);
      expect(govde.contains('setState(() {});'), isTrue,
          reason: 'tetiklemede çizim istenmiyor');
    });

    test('sıfırdan sonra zamanlayıcı durur', () {
      final i = o.indexOf('Timer.periodic');
      final govde = o.substring(i, i + 400);
      expect(govde.contains('if (_left <= 0)'), isTrue);
      expect(govde.contains('_timer?.cancel()'), isTrue,
          reason: 'bitmiş sayaç için saniyede bir uyanılıyor');
    });

    test('TEKRAR GÖNDER sayacı yeniden kurar', () {
      // ⚠ Zamanlayıcı sıfırda durduruluyor; yeni süre verilince
      // YENİDEN kurulmazsa sayaç hiç saymaz ve ekran 02:00'de DONAR.
      expect(o.contains('void _sayaciBaslat()'), isTrue,
          reason: 'kurulum tek yardımcıda toplanmamış');
      final r = o.indexOf('Future<void> _resend()');
      expect(r, greaterThan(0));
      final govde = o.substring(r, o.indexOf('\n  }', r));
      expect(govde.contains('_sayaciBaslat()'), isTrue,
          reason: 'tekrar gönderimde zamanlayıcı kurulmuyor');
    });

    test('sayaç bitince gösterilecek metinler yerinde', () {
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(w.contains("'Kod gelmedi mi?'"), isTrue);
      expect(w.contains('Numaranızın doğru olduğundan emin olun.'), isTrue);
      expect(w.contains("'Tekrar Gönder'"), isTrue);
      // ⚠ Cümle GİRİLEN NUMARA hakkında bir şey söylemez (enumeration).
      expect(w.contains('kayıtlı değil'), isFalse);
    });
  });

  group('2 — GÜVEN KARTI METNİ KESİLMEZ', () {
    final h = _kod('lib/screens/home_screen.dart');

    test('metin AYNEN duruyor', () {
      // ⚠ Ürün kararı: cümle kısaltılmadı, değiştirilmedi.
      expect(
          h.contains('Binlerce memnun kullanıcı deneyimiyle hizmet '
              'kalitesini güvence altına alın.'),
          isTrue,
          reason: 'kart metni değişmiş');
    });

    test('açıklamada SABİT YÜKSEKLİK ve maxLines YOK', () {
      // ⚠ ESKİ HATA: açıklama beş satırlık sabit alandaydı ve
      // `maxLines: 5` ile kesiliyordu ("…güvence altına" diye
      // bitiyordu).
      //
      // ⚠ Satır sayısını ARTIRMAK çözüm değil: alan üç sütunda
      // ORTAK, büyütünce kısa metinli kartların altında boşluk kalır;
      // ayrıca gereken satır sayısı ekran genişliğine ve kullanıcının
      // yazı boyutu ayarına göre değişir.
      expect(h.contains('_kAciklamaSatiri'), isFalse,
          reason: 'açıklamaya sabit satır sınırı geri gelmiş');
      expect(h.contains('_aciklamaAlani'), isFalse,
          reason: 'açıklamaya sabit yükseklik geri gelmiş');
    });

    test('BAŞLIK sabit alanda KALIR', () {
      // Üç sütunun açıklamaları aynı hizadan başlasın diye gerekli.
      expect(h.contains('_kBaslikSatiri'), isTrue);
      expect(h.contains('height: _baslikAlani(context)'), isTrue);
    });
  });
}
