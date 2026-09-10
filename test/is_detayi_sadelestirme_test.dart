// İŞ DETAYI — SADELEŞTİRİLDİ (KİLİT)
//
// ⚠ KULLANICI İSTEĞİ (9 Eyl): "Bu kartta 'teklif verildi' yazısı
// kalksın, 'Tamamlandı' yazısı kalksın, ilan numarası sağ üst köşeye
// konumlandırılsın, 'İletişim Bilgileri Açıldı' ve altındaki kaç
// dakika önce verildiği bilgisi kalksın; alttaki tutar/durum kartı
// kalsın."
//
// ⚠ GEREKÇELER (her biri "neden gereksiz"):
//   • Teklif sayısı — hizmet veren KENDİ teklifini görüyor; ilanın
//     kaç teklif aldığı onun kararını ilgilendirmiyor.
//   • "Tamamlandı" — durumu zaten alttaki teklif kartı söylüyor;
//     üstelik rozet ilan numarasını sağ köşeden ittiriyordu.
//   • "İletişim Bilgileri Açıldı" — hemen alttaki telefon/mesajlaşma
//     kutuları bunu zaten gösteriyor (açıksa numara, kapalıysa
//     "Kilitli").
//   • "33 dk önce teklif verildi" — kararı etkilemiyor.
//
// ⚠ İLAN NUMARASI TAŞINMADI: `IlanNoEtiketi` zaten sağa yaslı.
// Sağ köşeye oturmasını engelleyen şey yanındaki durum rozetiydi; o
// kalkınca numara kendiliğinden köşeye geldi. Bileşene DOKUNULMADI.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final k = _kodu('lib/screens/job_detail_screen.dart');

  group('1 — KALDIRILANLAR', () {
    test('teklif sayısı rozeti yok', () {
      expect(k.contains('teklifSayisi'), isFalse,
          reason: 'rozet ya da onu besleyen alan kalmış');
    });

    test('durum rozeti ("Tamamlandı") yok', () {
      expect(k.contains('StatusChip(rozet'), isFalse);
      expect(k.contains('listingRozetiUi(l)'), isFalse,
          reason: 'artık kullanılmayan hesaplama duruyor');
    });

    test('iletişim durumu ve zaman satırı yok', () {
      expect(k.contains('İletişim Bilgileri Açıldı'), isFalse);
      expect(k.contains('Teklifiniz iletildi'), isFalse);
      expect(k.contains('teklif verildi'), isFalse);
    });
  });

  group('2 — KALANLAR', () {
    test('⚠ TEKLİF KARTI DURUYOR', () {
      // Kullanıcı yalnız kartın İÇİNDEKİ iki satırı kaldırmak
      // istedi; kartın kendisi kalmalı.
      expect(k.contains("Text('Verdiğiniz Teklif'"), isTrue);
    });

    test('⚠ ALTTAKİ TUTAR/DURUM KARTI DURUYOR', () {
      expect(k.contains('StatusChip(oLabel, oColor)'), isTrue);
    });

    test('ilan numarası ortak bileşenden, sağa yaslı', () {
      // Bileşene dokunulmadı; hizalama zaten onun içinde sabit.
      expect(k.contains('IlanNoEtiketi(l)'), isTrue);
    });
  });

  group('3 — TUTAR BİÇİMİ', () {
    test('⚠ AYNI EKRANDA İKİ TUTAR, TEK BİÇİM', () {
      // İkisi de `tl()` ile "₺5000" yazıyordu; uygulamanın geri
      // kalanı "5.000 TL" gösteriyor.
      expect(RegExp(r'tutarMetni\(mine\.amount\)').allMatches(k).length, 2);
      expect(k.contains('tl(mine.amount)'), isFalse);
    });
  });
}
