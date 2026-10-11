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
    test('⚠ TEKLİF KARTI DURUYOR — ARTIK ORTAK BİLEŞEN', () {
      // Kullanıcı yalnız kartın İÇİNDEKİ iki satırı kaldırmak
      // istedi; kartın kendisi kalmalı.
      //
      // ── ⚠ SÖZLEŞME DEĞİŞTİ (12 Eyl, kullanıcı isteği) ──
      //
      // Kart elle çiziliyordu ve Bul akışındaki ikizinden üç yerde
      // ayrışıyordu: başlık metni, başlık ölçüsü ve tutarın punto/
      // rengi. Artık `TeklifTutarKarti` — ölçü ve renk tek yerde.
      expect(k.contains('TeklifTutarKarti(mine.amount)'), isTrue);
      expect(k.contains("Text('Verdiğiniz Teklif'"), isFalse,
          reason: 'kart yine elle çiziliyor');
    });

    test('⚠ ALTTAKİ TUTAR/DURUM KUTUSU KALDIRILDI (10 Eyl)', () {
      // Telefon/mesaj kutularının hemen üstünde "5.000 TL · Aktif"
      // yazan çerçeveli bir kutu vardı. Tutar zaten ÜSTÜNDEKİ mavi
      // kartta büyük puntoyla yazıyordu; aynı sayı aynı ekranda iki
      // kez görünüyordu.
      expect(k.contains('StatusChip(oLabel, oColor)'), isFalse);
      expect(k.contains('offerStatusUi(mine.status)'), isFalse);
      // ── ⚠ TEKLİF NOTU GERİ GELDİ (12 Eyl, kullanıcı isteği) ──
      //
      // O turda not da kaldırılmıştı; gerekçe "kendi yazdığını
      // kendine okutmak bilgi taşımıyor" idi. Bul akışının aynı
      // ekranında "Notunuz" kartı hep duruyordu — iki akış birebir
      // aynı olmalı.
      //
      // ⚠ KALDIRILAN ŞEY KUTUNUN KENDİSİYDİ: "5.000 TL · Aktif"
      // satırı geri gelmedi (yukarıdaki iki iddia bunu kilitliyor).
      expect(k.contains("baslik: 'Notunuz'"), isTrue);
      expect(k.contains('if (mine.note.trim().isNotEmpty)'), isTrue,
          reason: 'not boşken de çerçeve çiziliyor');
    });

    test('⚠ TUTAR EKRANDA TEK KEZ', () {
      // ⚠ Tutar kartı ortak bileşene taşındı (`TeklifTutarKarti`);
      // biçim yine `tutarMetni` ile, bileşenin içinde.
      expect(RegExp(r'TeklifTutarKarti\(mine\.amount\)').allMatches(k).length,
          1);
      expect(RegExp(r'tutarMetni\(mine\.amount\)').allMatches(k).length, 0);
      expect(_kodu('lib/screens/widgets/teklif_tutar_karti.dart')
          .contains('tutarMetni(tutar)'), isTrue);
    });

    test('⚠ İLAN NUMARASI KARTIN EN ÜSTÜNDE (10 Eyl)', () {
      // Önceden kartın ORTASINDA, kategori ikonunun yanındaki
      // sütunun içindeydi; o sütun `Expanded` olduğu için numara
      // kartın gerçek sağ kenarına değil sütunun sağına yaslanıyor
      // ve ikonun hizasını da bozuyordu.
      // ⚠ Bileşen artık numarayı alır (`IlanNoEtiketi(l.ilanNo)`);
      // sahip kartı ortak `SahipKarti`.
      expect(RegExp(r'IlanNoEtiketi\(').allMatches(k).length, 1,
          reason: 'numara birden fazla yerde çiziliyor');
      expect(k.contains('IlanNoEtiketi(l.ilanNo)'), isTrue);
      final iSahip = k.indexOf('SahipKarti(');
      expect(iSahip, greaterThan(-1));
      expect(k.indexOf('IlanNoEtiketi('), lessThan(iSahip),
          reason: 'numara kartın en üstünde değil');
    });

    test('⚠ KATEGORİ İKONU METİNLE YAN YANA', () {
      // Hiza `start` olduğu için ikon metnin ÜSTÜNDE kalıyordu.
      //
      // ⚠ Satır ortak bileşene taşındı (`IlanBaslikSatiri`); hiza
      // orada tek yerde.
      expect(k.contains('IlanBaslikSatiri('), isTrue);
      final b = _kodu('lib/screens/widgets/ilan_baslik_satiri.dart');
      final iRow = b.indexOf('return Row(');
      expect(iRow, greaterThan(-1));
      expect(b.indexOf('crossAxisAlignment: CrossAxisAlignment.center', iRow),
          lessThan(b.indexOf('children:', iRow)));
      expect(b.indexOf('crossAxisAlignment: CrossAxisAlignment.center', iRow),
          greaterThan(iRow));
    });

    test('⚠ "Kategori" SATIRI KALKTI', () {
      // Aynı bilgi kartın üstünde, kategori ikonunun yanında ZATEN
      // yazıyor; alt tabloda ikinci kez tekrar ediyordu.
      expect(k.contains("etiket: 'Kategori'"), isFalse);
      expect(k.contains("etiket: 'İl / İlçe / Mahalle'"), isTrue,
          reason: 'öteki bilgi satırları korunmalı');
      expect(k.contains("etiket: 'İlan Tarihi'"), isTrue);
    });
  });

  group('3 — TUTAR BİÇİMİ', () {
    test('⚠ ESKİ BİÇİMLENDİRİCİ GERİ GELMEDİ', () {
      // `tl()` "₺5000" yazıyordu; uygulamanın geri kalanı
      // "5.000 TL" gösteriyor.
      expect(k.contains('tl(mine.amount)'), isFalse);
    });
  });
}
