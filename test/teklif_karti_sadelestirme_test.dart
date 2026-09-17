// İLAN DETAYINDAKİ TEKLİF KARTI — SADELEŞTİRME (KİLİT)
//
// ⚠ KULLANICI İSTEĞİ (12 Eyl): hizmet alan kendi ilanına gelen
// teklifleri bu kartta karşılaştırıyor. Dört değişiklik istendi:
//
//   1. Hizmet verenin PUANI, YORUM SAYISI ve KAÇ İŞ BİTİRDİĞİ
//      görünmeli. Puan ve yorum sayısı zaten vardı; eksik olan iş
//      sayısıydı.
//   2. Not yazılmamışsa gri kutu HİÇ çizilmemeli.
//   3. Tırnak ('') simgesi kalkmalı.
//   4. "İletişim Açıldı" ve "Tamamlandı" yazıları kaldırılmalı.
//
// ⚠ ORTAK GEREKÇE — KART BİR KARŞILAŞTIRMA ARACIDIR: hizmet alan
// burada teklifler arasında seçim yapıyor. Karşılaştırmaya girmeyen
// her öğe (iletişim durumu, tamamlanmışlık, boş bir not kutusu, süs
// simgesi) kararı kolaylaştırmıyor, zorlaştırıyor.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final k = _kod('lib/screens/listing_detail_screen.dart');

  group('1 — ⚠ HİZMET VERENİN GEÇMİŞİ GÖRÜNÜR', () {
    test('puan ve yorum sayısı adın altında', () {
      expect(k.contains('ic_starb.svg'), isTrue, reason: 'puan yıldızı yok');
      // ⚠ "yorum" SÖZCÜĞÜ ZORUNLU (12 Eyl, kullanıcı isteği): tek
      // başına "(1)" neyin sayısı olduğunu söylemiyordu.
      expect(k.contains(r"'(${liste.length} yorum)'"), isTrue,
          reason: 'yorum sayısı eksik ya da sözcüksüz');
    });

    test('⚠ BİÇİM ÖTEKİ EKRANLARLA AYNI', () {
      // Aynı bilgi dört yüzeyde "(N yorum)" diye yazılır; biri
      // ayrışırsa aynı kişi kartlar arasında farklı görünür.
      for (final yol in const [
        'lib/screens/offer_detail_screen.dart',
        'lib/screens/review_screen.dart',
        'lib/screens/widgets/saglayici_ozet_satiri.dart',
      ]) {
        expect(_kod(yol).contains(' yorum)'), isTrue, reason: yol);
      }
    });

    test('⚠ TAMAMLANAN İŞ SAYISI EKLENDİ', () {
      // Yüksek puanlı ama tek işi olan biriyle, orta puanlı ama yirmi
      // işi olan biri aynı görünmemeli.
      expect(k.contains('iş tamamladı'), isTrue,
          reason: 'iş sayısı kartta yok');
      expect(k.contains('ic_briefcase.svg'), isTrue,
          reason: 'çanta ikonu yok — kalkan bu anlamı taşımaz');
    });

    test('⚠ SAYIM TEK KAYNAKTAN', () {
      // Ekran kendi sorgusunu yazarsa aynı kişi başka kartta başka
      // sayı gösterir.
      expect(k.contains('tamamlananIsSayisi(context, offer.providerId)'),
          isTrue);
    });
  });

  group('2 — ⚠ AVATAR ÇİZİLMEZ', () {
    // ── ⚠ KULLANICI İSTEĞİ (12 Eyl) ──
    //
    // "Gelen teklif kartlarında profil fotoğrafı kaldırılmalı."
    //
    // Kart bir karşılaştırma aracı: seçim fiyat, puan, yorum sayısı
    // ve tamamlanan işe göre yapılıyor. Avatar bu ölçütlerin hiçbirini
    // taşımıyordu ama satırın solunda 36 px yer kaplayıp adı ve puanı
    // sağa itiyordu.
    //
    // ⚠ AYNI KARAR `HizmetAlanOzetSatiri` için 10 Eyl'de verilmişti;
    // bu kart o turda atlanmıştı.

    test('kilitli/açık avatar kaldırıldı', () {
      expect(k.contains('ic_avlock'), isFalse);
      expect(k.contains('_basHarfler'), isFalse,
          reason: 'ölü yardımcı kalmış — avatar hâlâ çiziliyor izlenimi');
    });

    test('⚠ KİLİT KURALI DURUYOR', () {
      // Kilitli avatar gitti, MASKELEME gitmedi: ad iletişim
      // açılmadan önce hâlâ maskeli gösterilir.
      expect(k.contains('_ad(acik)'), isTrue);
    });
  });

  group('3 — ⚠ BOŞ NOT KUTUSU ÇİZİLMEZ', () {
    test('kutu koşula bağlı', () {
      // Not yazmak zorunlu değil; boş gri kutu, yazılmış ama
      // okunamayan bir mesaj izlenimi veriyordu.
      expect(k.contains('if (maskele(offer.note).trim().isNotEmpty) ...['),
          isTrue,
          reason: 'kutu her durumda çiziliyor');
    });

    test('⚠ TIRNAK SİMGESİ KALDIRILDI', () {
      expect(k.contains('ic_quote'), isFalse,
          reason: 'süs simgesi geri gelmiş');
    });

    test('not metni maskelenmeye devam eder', () {
      // Kart görünürken iletişim daima kapalıdır; not içindeki
      // telefon/adres maskeli kalmalı.
      expect(k.contains('maskele(offer.note)'), isTrue);
    });
  });

  group('4 — ⚠ TUTAR BİÇİMİ TEK KAYNAKTAN', () {
    test('kartta "6.000 TL" biçimi kullanılır', () {
      // ⚠ KULLANICI BULGUSU (12 Eyl): kartta "₺6000" yazıyordu —
      // para simgesi başta, binlik ayracı yok. Uygulamanın her
      // yerinde tutar `core/tutar_bicimi.dart`tan geliyor.
      expect(k.contains('tutarMetni(offer.amount)'), isTrue);
      expect(k.contains('tl(offer.amount)'), isFalse);
    });

    test('⚠ `tl()` TÜMÜYLE KALDIRILDI', () {
      // Fonksiyon dursaydı üçüncü bir çağrı yeri doğardı; bu kusur
      // dört turda dört ayrı ekranda tek tek düzeltilmişti.
      final su = _kod('lib/screens/status_ui.dart');
      expect(su.contains(r"String tl(int v)"), isFalse,
          reason: 'ham biçimlendirici geri gelmiş');
      final rev = _kod('lib/screens/review_screen.dart');
      expect(rev.contains('tutarMetni(offer.amount)'), isTrue,
          reason: 'değerlendirme ekranı hâlâ ham biçim kullanıyor');
    });
  });

  group('5 — ⚠ KALDIRILAN ROZETLER', () {
    test('"İletişim Açıldı" kartta yazmaz', () {
      expect(k.contains("'İletişim Açıldı'"), isFalse);
    });

    test('⚠ `acik` DEĞİŞKENİ DURUYOR — maskeleme ona bağlı', () {
      // Rozetle birlikte değişkeni de silmek, adı her durumda
      // maskesiz gösterirdi.
      expect(k.contains('_ad(acik)'), isTrue);
    });

    test('"Tamamlandı" rozeti çizilmez', () {
      expect(k.contains("'Tamamlandı'"), isFalse);
      expect(k.contains('if (tamamlandi || status == ListingStatus.active)'),
          isTrue,
          reason: 'tamamlanmış ilan yine rozet çiziyor');
    });

    test('⚠ ÖTEKİ DURUMLAR DURUYOR', () {
      // "Süresi Doldu" ve "Kapatıldı" başka hiçbir yerde
      // anlaşılmıyor; onlar kaldırılmadı.
      expect(k.contains("'Süresi Doldu'"), isTrue);
      expect(k.contains("'Kapatıldı'"), isTrue);
    });

    test('⚠ ONAY KALKANI YERİNDE — anlamı doğrulama', () {
      // "Onaylı Hizmet Veren" satırı kaldırılmadı: o bir geçmiş
      // bilgisidir, durum bildirimi değil.
      expect(k.contains('ic_shieldok.svg'), isTrue);
      expect(k.contains('Onaylı Hizmet Veren'), isTrue);
    });
  });
}
