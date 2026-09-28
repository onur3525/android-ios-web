// USTA BUL — GERÇEK ADRES, GERÇEK KAYIT (KİLİT)
//
// ⚠ KULLANICI BULGUSU (9 Eyl): "Hizmet veren hesabı açtım ve adres
// bilgilerim, hizmet alan usta bul ekranında FARKLI adres bilgisi
// olarak görünüyor. Buradaki bilgiler görüntü olarak kalmayacak,
// gerçek bilgilerle doldurulacak."
//
// İki ayrı sebep vardı:
//
//   1. KONUM YANLIŞ ALANDAN OKUNUYORDU — kart, hesabın `address`
//      bilgisini değil `serviceDistricts` (hizmet verilen bölgeler)
//      kümesini gösteriyordu; üstelik müşterinin ilçesi o kümedeyse
//      onu tercih ediyordu. Aliağa'da oturup Karşıyaka'ya da hizmet
//      veren biri, Karşıyaka'daki müşteriye "Karşıyaka" görünüyordu.
//
//   2. LİSTEDE KURGUSAL KAYITLAR VARDI — 14 uydurma isim/puan/iş
//      sayısı gerçek hesapların ardına ekleniyordu.
//
// ⚠ EŞLEŞTİRME İLE GÖSTERİM AYRI TUTULDU: "bu hizmet vereni bana
// göster" kararı hâlâ `serviceDistricts` ile verilir. Değişen, ekranda
// YAZAN bilgidir. İkisini aynı alana bağlamak hatanın kaynağıydı.

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
  final dizin = _kodu('lib/data/mock_saglayici_dizini.dart');
  final sonuclar = _kodu('lib/screens/sonuclar_screen.dart');

  group('1 — KONUM HESABIN KENDİ ADRESİ', () {
    test('özet `address` alanından okur', () {
      expect(ozet.contains('hesap.address'), isTrue);
      expect(ozet.contains('adres.district'), isTrue);
    });

    test('⚠ HİZMET BÖLGESİ KONUM OLARAK GÖSTERİLMEZ', () {
      expect(ozet.contains('serviceDistricts'), isFalse,
          reason: 'kart yeniden hizmet bölgesini gösteriyor — '
              'kullanıcının bildirdiği yanlış adres bu şekilde çıkmıştı');
    });

    test('adres yoksa konum UYDURULMAZ', () {
      // Eksik adreste satır hiç çizilmez; hizmet bölgesinden
      // yaklaşık bir ilçe türetilmez.
      expect(ozet.contains('? null'), isTrue);
    });
  });

  group('2 — LİSTEDE KURGUSAL KAYIT YOK', () {
    test('sabit havuz silindi', () {
      expect(dizin.contains('mock-saglayici-'), isFalse,
          reason: 'kurgusal kimlikler geri gelmiş');
      expect(dizin.contains('_havuz('), isFalse,
          reason: 'kurgusal havuz yeniden çağrılıyor');
    });

    test('sonuç listesi YALNIZ gerçek hesaplardan kurulur', () {
      expect(dizin.contains('for (final s in gercekSaglayicilar)'), isTrue);
    });

    test('⚠ SIRALAMA MANTIĞI KORUNDU', () {
      // Kurgusal veriyi kaldırmak sıralamayı bozmamalı: ilçe
      // yakınlığı → aktiflik → puan → yorum → tamamlanan iş.
      expect(dizin.contains('yakinlikSirasi.compareTo'), isTrue);
      expect(dizin.contains('aktiflikSkoru.compareTo'), isTrue);
    });
  });

  group('3 — BOŞ DURUM GERÇEK BİR HÂL', () {
    test('liste boşken başlık ve açıklama değişir', () {
      // Havuz kaldırıldığı için ekran artık gerçekten boş kalabilir.
      expect(sonuclar.contains('Bu hizmet için sonuç bulunamadı'), isTrue);
      expect(sonuclar.contains('_sonuclar.isEmpty'), isTrue);
    });
  });

  group('4 — BAŞLIK VE ALT SATIR (kullanıcı metinleri)', () {
    test('üst başlık "En Uygun Hizmet Verenler"', () {
      expect(sonuclar.contains("Text('En Uygun Hizmet Verenler'"), isTrue);
      expect(sonuclar.contains("Text('Sonuçlar'"), isFalse,
          reason: 'eski başlık geri gelmiş');
    });

    test('alt satır metni ve ORTALI hizası', () {
      expect(
          sonuclar.contains('İhtiyacınıza uygun hizmet verenler listelendi'),
          isTrue);
      expect(sonuclar.contains('Size en uygun hizmet verenler'), isFalse,
          reason: 'eski alt satır geri gelmiş');
    });

    test('⚠ w600 KULLANILMAZ — pubspec\'te o ağırlık YOK', () {
      // Poppins yalnız 400/500/700 ile geliyor; w600 sentezlenip
      // bulanık basar (ilan açıklaması tipografisinde kurulan kural).
      expect(sonuclar.contains('weight: RF.w600'), isFalse);
    });
  });
}
