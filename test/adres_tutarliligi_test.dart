// ADRES TÜM KARTLARDA AYNI — KİLİT
//
// ⚠ KULLANICI KURALI (9 Eyl): "Kullanıcının profilinde veya kayıt
// olurken girdiği adres bilgileri, bağlı olduğu TÜM kartlarda aynı
// olmalı; adres değişince buna bağlı olarak otomatikman tüm bilgiler
// değişmeli."
//
// ⚠ ÖLÇÜLEN İKİ AYRI SAPMA:
//
//   1. BİÇİM FARKI — her ekran konum metnini kendi kuruyordu; aynı
//      kişi bir kartta "Karşıyaka / İzmir", ötekinde
//      "Örnekköy, Karşıyaka / İzmir" görünüyordu.
//
//   2. DONMUŞ KOPYA — `Listing.location` ilan oluşturulurken yazılan
//      bir METİNDİR. Kullanıcı adresini sonradan değiştirdiğinde ilan
//      kartları ESKİ adresi göstermeye devam ediyordu: profil güncel,
//      kart eski. Bu, "adres değişince otomatik değişmeli" kuralının
//      doğrudan ihlaliydi.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/domain/kullanici_konumu.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

Address _adres({
  String mahalle = 'Örnekköy',
  String ilce = 'Karşıyaka',
  String il = 'İzmir',
}) =>
    Address(id: 'a1', city: il, district: ilce, neighborhood: mahalle);

void main() {
  group('1 — BİÇİM TEK YERDE', () {
    test('mahallesiz biçim', () {
      expect(konumMetni(_adres()), 'Karşıyaka / İzmir');
    });

    test('mahalleli biçim', () {
      expect(konumMetni(_adres(), mahalleDahil: true),
          'Örnekköy, Karşıyaka / İzmir');
    });

    test('⚠ BOŞ ALANLAR ARTIK GEREKSİZ AYRAÇ BIRAKMAZ', () {
      // Elle kurulan metinlerde "‚ Karşıyaka /" gibi kırık çıktılar
      // oluşuyordu.
      expect(konumMetni(_adres(mahalle: ''), mahalleDahil: true),
          'Karşıyaka / İzmir');
      expect(konumMetni(_adres(il: '')), 'Karşıyaka');
    });

    test('adres yoksa null — konum UYDURULMAZ', () {
      expect(konumMetni(null), isNull);
      expect(konumMetni(_adres(ilce: '', il: '')), isNull);
    });
  });

  group('2 — KARTLAR GÜNCEL ADRESTEN OKUR', () {
    // İlan sahibinin konumunu gösteren her yüzey.
    const ekranlar = <String>[
      'lib/screens/my_listings_screen.dart',
      'lib/screens/jobs_screen.dart',
      'lib/screens/job_detail_screen.dart',
      'lib/screens/listing_detail_screen.dart',
      'lib/screens/search_screen.dart',
    ];

    test('hepsi ortak çözücüyü kullanır', () {
      for (final yol in ekranlar) {
        expect(_kodu(yol).contains('kullaniciKonumu('), isTrue,
            reason: '$yol donmuş konumu gösteriyor');
      }
    });

    test('⚠ ELLE KURULAN KONUM METNİ KALMADI', () {
      // Özetler de kendi metnini kurmamalı.
      final ha = _kodu('lib/domain/hizmet_alan_ozeti.dart');
      expect(ha.contains('konumMetni(adres)'), isTrue);
      expect(ha.contains(r"'${adres.district} / ${adres.city}'"), isFalse,
          reason: 'özet kendi biçimini kuruyor');
    });
  });

  group('3 — YEDEK DAVRANIŞ', () {
    test('adres yoksa kayıtlı metne düşülür', () {
      // ⚠ `Listing.location` SİLİNMEDİ: sunucu sözleşmesinde duruyor
      // ve adres girilmemiş hesaplarda kart boş kalmasın diye yedek
      // olarak kullanılır.
      final k = _kodu('lib/screens/my_listings_screen.dart');
      expect(k.contains('?? \n                        listing.location') ||
              k.contains('listing.location'), isTrue,
          reason: 'yedek kaldırılmış — adressiz hesapta konum boş kalır');
    });
  });
}
