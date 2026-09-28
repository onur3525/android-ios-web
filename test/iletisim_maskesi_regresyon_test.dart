import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/iletisim_maskesi.dart';

/// İLETİŞİM MASKELEME — KALICI REGRESYON TESTLERİ
///
/// ⚠ Bu dosya daha önce YAŞANMIŞ açıkları kilitler. Bir madde
/// gevşetilecekse önce niçin eklendiği okunmalıdır.
void main() {
  bool m(String s) => iletisimIceriyor(s);

  group('⚠ MAHALLE FALSE-POSITIVE (regresyon)', () {
    // Mahalle GÜÇLÜ işaret listesindeydi ve tek başına adres
    // sayılıyordu; normal ilan cümleleri maskeleniyordu.
    test('genel bölge SERBEST', () {
      for (final t in const [
        "Karşıyaka Girne Mahallesi'nde hizmet almak istiyorum.",
        "İş Girne Mahallesi'nde.",
        'Karşıyaka / Girne Mahallesi',
        "Karşıyaka'da hizmet almak istiyorum.",
      ]) {
        expect(m(t), isFalse, reason: t);
      }
    });

    test('spesifik adres MASKELİ', () {
      for (final t in const [
        'Girne Mahallesi, X Sokak, No:25.',
        'Girne Mahallesi, X Caddesi, No: 10, Daire 4',
      ]) {
        expect(m(t), isTrue, reason: t);
      }
    });
  });

  group('⚠ SATIR SONU BİRLEŞMESİ (regresyon)', () {
    // Telefon bloğu ayraç olarak `\s` kullanıyordu; alt alta yazılan
    // numaralar TEK BLOĞA birleşip 31 haneye çıkıyor ve hiçbiri
    // maskelenmiyordu.
    test('alt alta üç numara — hepsi maskeli', () {
      const t = '5555631993\n555 563 1993\n0555 5 6 3 1 9 9 3';
      final c = maskele(t);
      expect(c.contains('5555631993'), isFalse);
      expect(c.contains('555 563 1993'), isFalse);
      expect(m(t), isTrue);
    });
  });

  group('⚠ ÇOKLU TELEFON — ÜST SINIR YOK', () {
    String uret(int n) => List.generate(
        n, (i) => '05${(i % 5) + 3}0 ${100 + i} ${20 + i} ${30 + i}').join('\n');

    test('10 telefonun tamamı maskeli', () {
      final c = maskele(uret(10));
      expect(RegExp(r'\d{3}').hasMatch(c), isFalse,
          reason: 'ham rakam kalmış');
    });

    test('⚠ 50 TELEFONUN 50\'Sİ DE MASKELİ', () {
      final c = maskele(uret(50));
      expect(RegExp(r'\d{3}').hasMatch(c), isFalse,
          reason: 'ham rakam kalmış');
      // Etiket sayısı numara sayısına eşit olmalı.
      expect(kMaskeEtiketi.allMatches(c).length, 50);
    });

    test('aynı satırda arka arkaya', () {
      const t = '0555 111 22 33 0532 444 55 66 0544 777 88 99';
      expect(m(t), isTrue);
    });
  });

  group('⚠ BİTİŞİK TÜRKÇE SAYI TELEFONU (regresyon)', () {
    // Basit "sözcük başına rakam" yöntemi "beşyüz"ü 500 değil 5+00
    // okuyordu; gerçek sayı okunuşu çözümlenir hâle getirildi.
    test('bitişik yazım maskeli', () {
      for (final t in const [
        'beşyüzellibeşbeşyüzaltmışüçondokuzdoksanüç',
        'beşyüzellibeşbeşyüzatmışüçondokuzdoksanüç',
      ]) {
        expect(m(t), isTrue, reason: t);
      }
    });

    test('⚠ AYRAÇLA PARÇALAMA VARYASYONLARI (20 madde)', () {
      // Saldırgan sayı sözcüklerini boşluk/nokta/tire/slash/parantez/
      // virgül/satır sonu ile parçalayarak kaçıyordu. Bölge tabanlı
      // çözümleme hepsini aynı sonuca indirger.
      for (final t in const [
        'Beş yüz elli beş beş yüz altmış üç on dokuz doksan üç',
        'Beşyüzellibeşbeşyüzaltmışüçondokuzdoksanüç',
        'Beşyüz ellibeşbeşyüz atmışüç on dokuzdoksanüç',
        'Beşyüz.ellibeş.beşyüz.atmışüç.ondokuz.doksanüç',
        'Beşyüz-ellibeş-beşyüz-atmışüç-on-dokuz-doksanüç',
        'Beşyüz/ellibeş/beşyüz/atmışüç/ondokuz/doksanüç',
        'Beşyüz, ellibeş, beşyüz, atmışüç, ondokuz, doksanüç',
        'Beş   yüz   elli   beş   beş   yüz   altmış   üç   '
            'on   dokuz   doksan   üç',
        'Beş yüz elli beş\nbeş yüz altmış üç\non dokuz\ndoksan üç',
        'BEŞYÜZELLİBEŞBEŞYÜZALTMIŞÜÇONDOKUZDOKSANÜÇ',
        '(beşyüz) ellibeş (beşyüz) atmışüç ondokuz doksanüç',
        '0555beşyüzatmışüç1993',
      ]) {
        expect(m(t), isTrue, reason: t);
      }
    });

    test('⚠ SAYI OKUNUŞU DOĞRU ÇÖZÜLÜR (genel, hard-code değil)', () {
      // Normal sayı okunuşları çözümlenir ama telefon kalıbına
      // uymadıkları için MASKELENMEZ.
      for (final t in const [
        'yüz yirmi beş TL',
        'iki yüz elli metre',
        'bin iki yüz otuz dört adet',
        '150 m2 ev',
        '2-3 petek daha',
      ]) {
        expect(m(t), isFalse, reason: t);
      }
    });

    test('boşluklu yazım maskeli', () {
      for (final t in const [
        'beş beş beş beş altı üç bir dokuz dokuz üç',
        'beşyüzellibeş beşyüzaltmışüç ondokuz doksanüç',
      ]) {
        expect(m(t), isTrue, reason: t);
      }
    });

    test('⚠ NORMAL SAYI İÇERİĞİ MASKELENMEZ', () {
      for (final t in const [
        'üç odalı',
        'beş metre',
        'yüz elli TL',
        'iki adet',
        'on adet petek',
        'üç oda iki banyo',
        'otuz metre kablo',
      ]) {
        expect(m(t), isFalse, reason: t);
      }
    });
  });

  group('TELEFON BİÇİMLERİ', () {
    test('rakamla yazılan biçimler', () {
      for (final t in const [
        '05555631993',
        '0555 563 19 93',
        '0555-563-19-93',
        '0555.563.19.93',
        '0 5 5 5 5 6 3 1 9 9 3',
        '+90 555 563 19 93',
        '555a563b19c93',
      ]) {
        expect(m(t), isTrue, reason: t);
      }
    });
  });

  group('IBAN', () {
    test('IBAN maskeli', () {
      expect(m('TR12 0000 6100 5190 0078 0000 12'), isTrue);
      expect(m('TR120000610051900078000012'), isTrue);
    });
  });

  group('SOSYAL MEDYA / KANAL', () {
    test('⚠ YALNIZ YÖNLENDİRME CÜMLESİ SERBEST', () {
      // Ürün kararı: yönlendirme ifadesi tek başına yasaklı değildir;
      // yasaklı olan GERÇEK iletişim bilgisidir.
      for (final t in const [
        "WhatsApp'tan yazabilirsiniz.",
        "Instagram'dan ulaşabilirsiniz.",
        'Beni ara.',
        'Numaram profilimde.',
      ]) {
        expect(m(t), isFalse, reason: t);
      }
    });

    test('somut bilgi MASKELİ', () {
      for (final t in const [
        'WhatsApp: 0555 123 45 67',
        'Instagram: @ornekhesap',
        'ornek@gmail.com',
        'https://example.com',
        'www.example.com',
      ]) {
        expect(m(t), isTrue, reason: t);
      }
    });
  });

  group('⚠ YAZIYLA ADRES NUMARASI (regresyon)', () {
    // "No yirmi beş", "Kat iki" rakam içermediği için adres
    // kalıplarına takılmıyordu.
    //
    // ⚠ AYRIM İŞARETTEDİR, SAYIDA DEĞİL: bir adres işaretinin HEMEN
    // ARDINDAN gelen sayı adres numarasıdır. Bütün yazıyla sayılar
    // adres sayılmaz.
    test('adres işareti + sayı MASKELİ', () {
      for (final t in const [
        'No 25',
        'No yirmi beş',
        'Kapı No 25',
        'Kapı numarası yirmi beş',
        'Kapı numarası yirmi beş, kat iki',
        'Kat 2',
        'Kat iki',
        'Daire 4',
        'Daire dört',
        'Bina 12',
        'Bina on iki',
        'Girne Mahallesi, X Sokak, No yirmi beş',
        'Girne Mahallesi, X Sokak, No 25, Kat iki',
      ]) {
        expect(m(t), isTrue, reason: t);
      }
    });

    test('⚠ İŞARETSİZ SAYI SERBEST', () {
      for (final t in const [
        'iki oda',
        'üç petek',
        'beş metre kablo',
        'on adet petek',
        'üç odalı iki banyolu',
        'yüz elli TL',
        '2+1 daire',
        '3 oda 2 banyo',
        '150 TL',
        '2019 model',
      ]) {
        expect(m(t), isFalse, reason: t);
      }
    });
  });

  group('ADRES VE KONUM TARİFİ', () {
    test('spesifik konum MASKELİ', () {
      for (final t in const [
        "McDonald's'ın üstü.",
        'X Sokak No: 25',
        'D4 dairesindeyim',
      ]) {
        expect(m(t), isTrue, reason: t);
      }
    });
  });

  group('⚠ NORMAL İŞ İÇERİĞİ MASKELENMEZ', () {
    test('miktar, ölçü, model', () {
      for (final t in const [
        '3 odalı, 2 banyolu, 150 m².',
        '1 adet petek, gerekirse 2-3 petek daha.',
        '2019 model kombi, 120 cm petek.',
        'Doğalgaz tesisatı ve kombi bakımı gerekiyor.',
        'Merhaba 1 adet peteğim değişecek.',
      ]) {
        expect(m(t), isFalse, reason: t);
      }
    });
  });

  group('⚠ SPAM İLAN GÖNDERİMİNİ BLOKE ETMEZ', () {
    test('ilan oluşturma ekranında doğrulama YOK', () {
      // Ürün kararı: anlamsız metin kullanıcıyı ENGELLEMEZ.
      final k = File('lib/screens/create_listing_screen.dart')
          .readAsStringSync();
      expect(k.contains('iletisim_maskesi'), isFalse);
      expect(k.contains('anlamsiz'), isFalse);
    });
  });
}
