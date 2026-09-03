// STANDART FORM METİNLERİ — TEK KAYNAK
//
// Aynı anlam uygulamada üç ayrı biçimde yazılıyordu:
//   "En az 1 hizmet kategorisi seçmelisiniz."
//   "En az bir hizmet kategorisi seçiniz"
//   "En az 1 kategori seçmeniz gerekmektedir."
// Kullanıcı aynı kuralı her ekranda başka bir dille duyuyordu.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/config.dart';
import 'package:hizmetcep/domain/form_mesajlari.dart';

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

/// lib altındaki tüm Dart kaynakları (mesaj dosyasının kendisi hariç).
List<String> _libDosyalari() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .map((f) => f.path)
    .where((p) => p.endsWith('.dart'))
    .where((p) => !p.endsWith('form_mesajlari.dart'))
    .toList();

void main() {
  group('DİL STANDARDI', () {
    test('metinler emir kipinde ve "Lütfen" ile başlamıyor', () {
      for (final m in const [
        FormMesaj.telefon,
        FormMesaj.eposta,
        FormMesaj.kategoriSec,
        FormMesaj.bolgeSec,
        FormMesaj.ilSec,
        FormMesaj.ilceSec,
        FormMesaj.mahalleSec,
        FormMesaj.puanSec,
        FormMesaj.ilanKategoriSec,
        FormMesaj.teklifTutari,
      ]) {
        expect(m.startsWith('Lütfen'), isFalse, reason: m);
        expect(m.endsWith('.'), isFalse, reason: '$m — nokta kullanılmaz');
      }
    });

    test('seçim metinleri AYNI kalıpta', () {
      expect(FormMesaj.kategoriSec, 'En az bir hizmet kategorisi seçiniz');
      expect(FormMesaj.bolgeSec, 'En az bir hizmet ilçesi seçiniz');
      expect(FormMesaj.ilSec, 'İl seçiniz');
      expect(FormMesaj.puanSec, 'Puan seçiniz');
      expect(FormMesaj.ilanKategoriSec, 'Kategori seçiniz');
    });

    test('kelime alt sınırı KURALDAN gelir, elle yazılmaz', () {
      // `kMinAciklamaKelime` değişirse metin de değişmeli.
      expect(FormMesaj.teklifAciklama,
          'Açıklamanız en az $kMinAciklamaKelime kelime olmalıdır');
      expect(FormMesaj.ilanAciklama, FormMesaj.teklifAciklama);
    });
  });

  group('AYRIŞIK YAZIMLAR KALDIRILDI', () {
    test('eski kalıplar kodda GEÇMİYOR', () {
      final kalan = <String>[];
      for (final p in _libDosyalari()) {
        final k = _kod(p);
        for (final eski in const [
          'seçmelisiniz',
          'seçmeniz gerekmektedir',
          'Lütfen bir puan seçin',
          'Lütfen bir kategori seçin',
          'En az 5 kelime ile açıklayınız',
          'Geçerli bir tutar giriniz',
        ]) {
          if (k.contains(eski)) {
            kalan.add('${p.split('/').last}: $eski');
          }
        }
      }
      expect(kalan, isEmpty, reason: 'ayrışık yazım kalmış: $kalan');
    });

    test('ekranlar metni TEK KAYNAKTAN çağırır', () {
      const beklenen = {
        'lib/screens/my_categories_screen.dart': 'FormMesaj.kategoriSec',
        'lib/screens/my_areas_screen.dart': 'FormMesaj.bolgeSec',
        'lib/screens/app_rate_screen.dart': 'FormMesaj.puanSec',
        'lib/screens/review_screen.dart': 'FormMesaj.puanSec',
        'lib/screens/create_listing_screen.dart': 'FormMesaj.ilanKategoriSec',
        'lib/screens/job_detail_screen.dart': 'FormMesaj.teklifTutari',
        'lib/screens/widgets/kategori_secim_paneli.dart':
            'FormMesaj.kategoriSec',
        'lib/data/repositories/auth_repository.dart': 'FormMesaj.kategoriSec',
      };
      beklenen.forEach((dosya, sabit) {
        expect(_kod(dosya).contains(sabit), isTrue, reason: dosya);
      });
    });

    test('⚠ TEKLİF EKRANINDA AÇIKLAMA ALANI YOK', () {
      // ── ÜRÜN KARARI (madde 3) ──
      //
      // Teklif verme ekranından açıklama alanı, karakter sayacı ve
      final j = _kod('lib/screens/job_detail_screen.dart');
      expect(j.contains('_noteError'), isFalse,
          reason: 'açıklama doğrulaması geri gelmiş');
      expect(j.contains('_note.text'), isFalse,
          reason: 'açıklama alanı geri gelmiş');
      expect(j.contains(r'/ 1000'), isFalse, reason: 'karakter sayacı kalmış');
      // ⚠ Teklif TUTARI korunur.
      expect(j.contains('_amtError'), isTrue);
    });

    test('⚠ KALDIRILAN BİLGİLENDİRMELER GERİ GELMEDİ', () {
      // Maddeler 4-7.
      final j = _kod('lib/screens/job_detail_screen.dart');
      expect(j.contains('Teklif vermek ücretsizdir'), isFalse);
      expect(j.contains('Bloke: '), isFalse);
      expect(j.contains('taraflardan biri açtığında'), isFalse);
      expect(j.contains("InfoBox(child: Text('Teklif verildi'))"), isFalse);
      // ⚠ KALDIRILMAYACAKLAR yerinde.
      expect(j.contains('Verdiğiniz Teklif'), isTrue);
      expect(j.contains('İletişim Bilgileri Açıldı'), isTrue);
    });
  });

  group('SİSTEM HATALARI AYRI SINIFTIR', () {
    test('ağ ve zaman aşımı metinleri tanımlı', () {
      expect(FormMesaj.baglantiYok.startsWith('Bağlantı kurulamadı'), isTrue);
      expect(FormMesaj.zamanAsimi.startsWith('Sunucu yanıt vermedi'), isTrue);
    });
  });

  group('ŞİFRE SIFIRLAMA METİNLERİ HAZIR', () {
    test('başarı metni hesap var/yok bilgisi SIZDIRMAZ', () {
      // Hesap bulunsa da bulunmasa da AYNI cümle gösterilir.
      expect(FormMesaj.sifirlamaGonderildi.contains('Eğer bu e-posta'), isTrue);
      expect(FormMesaj.sifirlamaGonderildi.contains('bulunamadı'), isFalse);
      expect(FormMesaj.sifirlamaGonderildi.contains('kayıtlı değil'), isFalse);
    });

    test('token hataları ayrı ayrı tanımlı', () {
      expect(FormMesaj.sifirlamaGecersiz, isNotEmpty);
      expect(FormMesaj.sifirlamaSuresiDoldu, isNotEmpty);
      expect(FormMesaj.sifirlamaKullanilmis, isNotEmpty);
      expect(FormMesaj.sifirlamaGecersiz,
          isNot(FormMesaj.sifirlamaSuresiDoldu));
    });
  });
}
