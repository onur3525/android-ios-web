// HATA DİLİ — SÖZLEŞME
//
// ⚠ İKİ KURAL BİRLİKTE:
//   1. Metin TEK MERKEZDEN gelir; ekran kendi cümlesini yazmaz.
//   2. Hata YALNIZ gerçekten olduğunda görünür; yükleme sırasında,
//      hata yokken ya da ekranda veri varken ÇİZİLMEZ.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/domain/hata_mesajlari.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('GEREKSİZ UYARI GÖSTERİLMEZ', () {
    test('YÜKLEME sürerken hata çizilmez', () {
      // ⚠ İstek daha bitmedi; hata olduğunu söylemek erken.
      expect(
          hataGosterilsinMi(
              yukleniyor: true,
              hata: const NetworkError('x'),
              veriVar: false),
          isFalse);
    });

    test('HATA YOKKEN çizilmez', () {
      expect(
          hataGosterilsinMi(yukleniyor: false, hata: null, veriVar: false),
          isFalse);
    });

    test('EKRANDA VERİ VARSA tam ekran hata çizilmez', () {
      // ⚠ Kullanıcı eskisini görmeye devam eder; üstüne hata basılmaz.
      expect(
          hataGosterilsinMi(
              yukleniyor: false,
              hata: const NetworkError('x'),
              veriVar: true),
          isFalse);
    });

    test('BOŞ LİSTE hata DEĞİLDİR', () {
      // İstek başarılı döndü, kayıt yok: \"kayıt yok\" mesajı gösterilir.
      expect(
          hataGosterilsinMi(yukleniyor: false, hata: null, veriVar: false),
          isFalse);
    });

    test('GERÇEK HATA + veri yok → çizilir', () {
      expect(
          hataGosterilsinMi(
              yukleniyor: false,
              hata: const NetworkError('x'),
              veriVar: false),
          isTrue);
    });
  });

  group('TAŞIMA HATALARI KENDİ TÜRÜNDE', () {
    test('ağ/zaman aşımı/sunucu ValidationError DEĞİL', () {
      // ⚠ Eskiden üçü de ValidationError'dı; ekran form hatasıyla
      // ağ hatasını ayırt edemiyordu.
      expect(const NetworkError('x'), isNot(isA<ValidationError>()));
      expect(const TimeoutError('x'), isNot(isA<ValidationError>()));
      expect(const ServerError('x'), isNot(isA<ValidationError>()));
      expect(const MaintenanceError('x'), isNot(isA<ValidationError>()));
    });

    test('api_error_mapper 5xx ve 503 ayırır', () {
      final m = _kod('lib/data/remote/api_error_mapper.dart');
      expect(m.contains('status == 503'), isTrue);
      expect(m.contains('status >= 500'), isTrue);
      expect(m.contains('NetworkError networkError()'), isTrue);
      expect(m.contains('TimeoutError timeoutError()'), isTrue);
    });
  });

  group('HER DURUMDA KULLANICI NE YAPACAĞINI BİLİR', () {
    test('denenebilir hatalarda EYLEM var', () {
      for (final h in const <DomainError>[
        NetworkError('x'),
        TimeoutError('x'),
        UnauthorizedError('x'),
        NotFoundError('x'),
      ]) {
        final b = hataBilgisi(h);
        expect(b.eylem, isNotNull, reason: '$h için eylem yok');
        expect(b.eylem!.trim(), isNotEmpty);
        expect(b.denenebilir, isTrue);
      }
    });

    test('yapılabilecek bir şey YOKSA eylem sunulmaz', () {
      // ⚠ Sunucu hatasında \"tekrar dene\" demek kullanıcıyı boşuna
      // uğraştırır; açıklama ne olduğunu söyler.
      for (final h in const <DomainError>[
        ServerError('x'),
        MaintenanceError('x'),
      ]) {
        final b = hataBilgisi(h);
        expect(b.denenebilir, isFalse, reason: '$h için eylem önerilmiş');
        expect(b.aciklama.trim(), isNotEmpty,
            reason: '$h: eylem yoksa açıklama zorunlu');
      }
    });

    test('BAŞLIK boş olamaz', () {
      for (final h in const <DomainError>[
        NetworkError('x'),
        TimeoutError('x'),
        ServerError('x'),
        MaintenanceError('x'),
        UnauthorizedError('x'),
        NotFoundError('x'),
        ValidationError('alan hatası'),
      ]) {
        expect(hataBilgisi(h).baslik.trim(), isNotEmpty, reason: '$h');
      }
    });

    test('TEKNİK KOD kullanıcıya sızmaz', () {
      final k = _kod('lib/domain/hata_mesajlari.dart');
      for (final teknik in const [
        'SocketException',
        'TimeoutException',
        'statusCode',
        '500',
        '503',
      ]) {
        expect(k.contains("'$teknik"), isFalse, reason: teknik);
      }
    });
  });

  group('GÖSTERİM BİÇİMİ', () {
    test('form hataları ALAN ALTINDA', () {
      expect(hataBilgisi(const ValidationError('x')).bicim,
          HataBicimi.alanAlti);
      expect(hataBilgisi(const WrongPasswordError('x')).bicim,
          HataBicimi.alanAlti);
    });

    test('veri gelmeyen durumlar TAM EKRAN', () {
      expect(hataBilgisi(const NetworkError('x')).bicim, HataBicimi.tamEkran);
      expect(hataBilgisi(const ServerError('x')).bicim, HataBicimi.tamEkran);
    });
  });

  group('EKRAN — İLANLARIM', () {
    final k = _kod('lib/screens/my_listings_screen.dart');

    test('hata kapısını KULLANIR', () {
      expect(k.contains('hataGosterilsinMi('), isTrue);
      expect(k.contains('HataTamEkran('), isTrue);
    });

    test('BOŞ LİSTE dalı KORUNDU', () {
      // ⚠ Hata dalı boş liste dalının YERİNE geçmez; ikisi ayrı.
      expect(k.contains('_BosListe()'), isTrue);
    });

    test('yeniden deneme AYNI yükleme yolunu çağırır', () {
      expect(k.contains('onTekrar: _refresh'), isTrue);
    });

    test('ekran KENDİ hata cümlesini yazmaz', () {
      for (final cumle in const [
        'Bir hata oluştu',
        'İnternet bağlantısı yok',
        'Sunucuya ulaşılamıyor',
      ]) {
        expect(k.contains("'$cumle"), isFalse, reason: cumle);
      }
    });
  });


  group('BAKİYE YÜKLEME — RET SEBEBİ AYRIŞIR', () {
    test('KART bakiyesi yetersiz kendi mesajını verir', () {
      // ⚠ Cüzdan bakiyesiyle karıştırılmaz: bu KARTIN bakiyesidir.
      final b = hataBilgisi(const KartBakiyesiYetersizError('x'));
      expect(b.baslik, 'Kart bakiyeniz yetersiz');
      expect(b.aciklama.contains('Bakiyeniz değişmedi'), isTrue);
      expect(b.denenebilir, isTrue);
    });

    test('SUNUCU sorunu ayrı mesaj verir', () {
      expect(hataBilgisi(const NetworkError('x')).baslik,
          'Sunucuya ulaşılamıyor');
      expect(hataBilgisi(const ServerError('x')).baslik,
          'Şu an işlem yapılamıyor');
    });

    test('sağlayıcı ret kodu EŞLENMİŞ', () {
      final m = _kod('lib/data/remote/api_error_mapper.dart');
      expect(m.contains("'INSUFFICIENT_FUNDS'"), isTrue);
      expect(m.contains('KartBakiyesiYetersizError'), isTrue);
      // Cüzdan bakiyesi kodu AYRI kalmalı.
      expect(m.contains("'INSUFFICIENT_BALANCE'"), isTrue);
    });

    test('ekran hatanın TÜRÜNÜ saklar, yalnız metni değil', () {
      final t = _kod('lib/screens/topup_screen.dart');
      expect(t.contains('DomainError? _hata'), isTrue);
      expect(t.contains('hataBilgisi(_hata!)'), isTrue);
      // Sabit "Ödeme durumu okunamadı" başlığı kalktı.
      expect(t.contains("'Ödeme durumu okunamadı'"), isFalse);
    });
  });


  group('RET METNİ KISA', () {
    final t = _kod('lib/screens/topup_screen.dart');

    test('genel ret için TEK başlık', () {
      expect(t.contains("'Kart geçersiz'"), isTrue);
      expect(t.contains("'Ödeme alınamadı'"), isFalse,
          reason: 'eski uzun metin geri gelmiş');
      expect(t.contains('Bankanız işlemi onaylamadı'), isFalse);
      expect(t.contains('Bakiyeniz değişmedi. '), isFalse,
          reason: 'gereksiz cümle geri gelmiş');
    });

    test('YETERSİZ BAKİYE ayrı kalır', () {
      // Genel ret ile karıştırılmaz; kendi başlığı var.
      expect(hataBilgisi(const KartBakiyesiYetersizError('x')).baslik,
          'Kart bakiyeniz yetersiz');
    });
  });


  group('HATA DİLİ EKRANLARA YAYILDI', () {
    // ⚠ Kapsam: uzaktan veri çeken LİSTE ekranları. Veri gelmezse
    // kullanıcı boş ekranda kalmamalı; "Tekrar dene" sunulmalı.
    const ekranlar = [
      'lib/screens/my_listings_screen.dart',
      'lib/screens/jobs_screen.dart',
      'lib/screens/notifications_screen.dart',
      'lib/screens/invoices_screen.dart',
    ];

    test('hepsi MERKEZİ gösterimi kullanır', () {
      for (final y in ekranlar) {
        expect(_kod(y).contains('HataTamEkran('), isTrue, reason: y);
      }
    });

    test('hiçbiri KENDİ hata cümlesini yazmaz', () {
      for (final y in ekranlar) {
        final k = _kod(y);
        for (final cumle in const [
          'Bir hata oluştu',
          'yüklenemedi.',
          'Sunucuya ulaşılamıyor',
        ]) {
          // ⚠ Yorumlar `_kod` ile zaten elendi; ham arama yeterli.
          expect(k.contains(cumle), isFalse, reason: '$y → $cumle');
        }
      }
    });

    test('BOŞ DURUM dalları KORUNDU', () {
      // ⚠ Hata dalı boş durumun YERİNE geçmez; ikisi ayrı kalır.
      expect(_kod('lib/screens/jobs_screen.dart').contains('SysEmpty'), isTrue);
      expect(
          _kod('lib/screens/notifications_screen.dart')
              .contains('Henüz bildiriminiz yok'),
          isTrue);
      expect(_kod('lib/screens/invoices_screen.dart').contains('SysKind.empty'),
          isTrue);
    });

    test('yeniden deneme AYNI yükleme yolunu çağırır', () {
      expect(_kod('lib/screens/jobs_screen.dart').contains('onTekrar: _refresh'),
          isTrue);
      expect(
          _kod('lib/screens/notifications_screen.dart')
              .contains('onTekrar: _refresh'),
          isTrue);
    });

    test('FATURA denetleyicisi hatanın TÜRÜNÜ saklar', () {
      // Metin saklamak yetmiyordu: ağ sorunu ile sunucu arızası aynı
      // cümleye düşüyordu.
      final c = _kod('lib/data/controllers/invoice_controller.dart');
      expect(c.contains('DomainError? _lastError'), isTrue);
      expect(c.contains('on ApiFailure catch'), isTrue);
      // Eski sözleşme kırılmadı.
      expect(c.contains('String? get hata =>'), isTrue);
    });
  });
}
