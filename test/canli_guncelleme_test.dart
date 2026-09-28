// HİZMET VEREN BİLGİLERİ ANINDA GÜNCELLENİR — KİLİT
//
// ⚠ KULLANICI SORUSU (10 Eyl): "Bir iş bitirildiğinde, bir yorum
// yazıldığında, adres değiştiğinde o kişinin bilgisi TÜM ekranlarda
// aynı anda güncelleniyor mu?"
//
// ⚠ DENETİM SONUCU — ÜÇ AYRI KOPUKLUK BULUNDU:
//
//   1. SAYAÇ BİLDİRİM GÖNDERMİYORDU: portlar
//      `hesap.tamamlananIs += 1` diye alanı YERİNDE değiştiriyordu.
//      Bu, deponun `notifyListeners` çağrısını tetiklemez; hiçbir
//      ekran "değişti" haberini almaz.
//
//   2. ORTAK KAYNAKLAR `read` KULLANIYORDU: `read` yalnız o anki
//      değeri okur, ABONELİĞE dönüşmez. Denetleyici bildirim
//      gönderse bile çağıran ekran yeniden çizilmiyordu.
//
//   3. BAZI EKRANLAR HİÇBİR ŞEY İZLEMİYORDU: Sonuçlar, Teklif İste,
//      Arama. `OfferController`/`ListingController` izleyen ekranlar
//      tesadüfen tazeleniyor, izlemeyenler eski değerde kalıyordu.
//
// ⚠ YORUM SAYISI ZATEN ÇALIŞIYORDU: ortak özet `ReviewController`ı
// `watch` ile okuyor. Bu test onu da kilitler ki geri gitmesin.
//
// ⚠ `initState` İSTİSNASI: `watch` yalnız `build` içinde geçerlidir.
// `sonuclar_screen` listesini `initState`te bir kez kurduğu için o
// çağrı `izle: false` geçer — bu bilinçli bir istisnadır ve testle
// korunur.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final ozet = _kodu('lib/domain/saglayici_ozeti.dart');
  final alan = _kodu('lib/domain/hizmet_alan_ozeti.dart');
  final konum = _kodu('lib/domain/kullanici_konumu.dart');
  final depo = _kodu('lib/data/repositories/auth_repository.dart');

  group('1 — SAYAÇ DEĞİŞİNCE BİLDİRİM GİDER', () {
    test('artırım tek kapıdan ve bildirimli', () {
      expect(depo.contains('void tamamlananIsArtir(String userId)'), isTrue);
      final i = depo.indexOf('void tamamlananIsArtir');
      expect(depo.substring(i).contains('notifyListeners()'), isTrue,
          reason: 'sayaç değişiyor ama kimse haber almıyor');
    });

    test('⚠ PORTLAR ALANI DOĞRUDAN DEĞİŞTİRMEZ', () {
      for (final yol in const [
        'lib/data/ports/mock_ports.dart',
        'lib/data/ports/teklif_talebi_port.dart',
      ]) {
        expect(_kodu(yol).contains('tamamlananIs += 1'), isFalse,
            reason: '$yol bildirimi atlayan doğrudan artırım yapıyor');
        expect(_kodu(yol).contains('tamamlananIsArtir('), isTrue);
      }
    });
  });

  group('2 — ORTAK KAYNAKLAR İZLER', () {
    test('hizmet veren özeti: hesap, ilan, teklif, yorum', () {
      expect(ozet.contains('listen: izle'), isTrue,
          reason: 'sayım denetleyicileri izlemiyor');
      expect(ozet.contains('context.watch<AuthController>()'), isTrue);
      expect(ozet.contains('context.watch<ReviewController>()'), isTrue);
    });

    test('hizmet alan özeti', () {
      expect(alan.contains('watch<ListingController>'), isTrue);
      expect(alan.contains('watch<TeklifTalebiController>'), isTrue);
      expect(alan.contains('context.watch<AuthController>()'), isTrue);
    });

    test('konum — adres değişince kart da değişir', () {
      expect(konum.contains('context.watch<AuthController>()'), isTrue);
      expect(konum.contains('context.read<AuthController>()'), isFalse);
    });
  });

  group('3 — `initState` İSTİSNASI KORUNUR', () {
    test('⚠ SONUÇLAR LİSTESİ `izle: false` GEÇER', () {
      // `watch` yapı dışında HATA ATAR; liste `initState`te bir kez
      // kurulup sıralanıyor. Ekrandaki KART ise ortak özetten okur
      // ve o izler.
      expect(_kodu('lib/screens/sonuclar_screen.dart').contains('izle: false'),
          isTrue);
    });

    test('varsayılan izlemedir', () {
      // Varsayılanı `false` yapmak, unutulan her çağrıyı sessizce
      // eski (canlı olmayan) davranışa döndürürdü.
      expect(ozet.contains('bool izle = true'), isTrue);
    });
  });

  group('4 — KOPYA SAYIMLAR KALMADI', () {
    test('ekranlar kendi döngüsünü kurmaz', () {
      // Her kopya, ortak kaynak `watch`a geçtiğinde geride kalır ve
      // o ekran güncellenmemeye devam ederdi.
      for (final yol in const [
        'lib/screens/teklif_istekleri_screen.dart',
        'lib/screens/teklif_istediklerim_screen.dart',
        'lib/screens/teklif_iste_screen.dart',
      ]) {
        expect(_kodu(yol).contains('isTamamlanmisIs'), isFalse,
            reason: '$yol kendi sayımını yapıyor');
      }
    });
  });
}
