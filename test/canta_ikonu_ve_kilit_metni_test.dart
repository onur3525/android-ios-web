// ÇANTA İKONU + KISA KİLİT METNİ — KİLİT
//
// ⚠ İKİ AYRI KULLANICI KARARI (9 Eyl), tek dosyada kilitleniyor:
//
//   1. "iş tamamladı" satırlarının solundaki ikon ÇANTA olacak
//      (`ic_briefcase.svg`). Kalkan (`ic_shieldok.svg`) "doğrulanmış /
//      onaylı" anlatır; oradaki sayı ise YAPILAN İŞ sayısıdır.
//
//   2. Kilitli iletişim kartlarındaki "İletişim açılınca görünür."
//      cümlesi dar kartta kırpılıyordu ("İletişim açılınca görü…").
//      Yerine tek kelime: "Kilitli" — yanındaki kilit ikonuyla
//      örtüşür ve hiçbir ekranda kırpılmaz.
//
// ⚠ EN KRİTİK NOKTA KAPSAM: değişiklik "iş tamamladı" satırlarıyla
// SINIRLIDIR. `ic_shieldok`, anlamı gerçekten doğrulama/onay olan üç
// yerde KALIR: "Onaylı Hizmet Veren", "İletişim Açıldı" ve bildirim
// türü ikonu. Bu test her iki yönü de denetler — çantanın geldiğini
// VE kalkanın yanlış yerde silinmediğini.
//
// ⚠ YOKLUK DENETİMİ YORUMSUZ METİNDE YAPILIR: dosyalardaki açıklama
// yorumları eski ikon adını ve eski cümleyi ANLATIYOR; ham metinde
// aransaydı yanlış alarm verirdi.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

/// "iş tamamladı" yazan ve solunda ikon taşıyan ekranlar.
const _isTamamladiEkranlari = <String>[
  'lib/screens/teklif_istediklerim_screen.dart',
  'lib/screens/sonuclar_screen.dart',
  'lib/screens/job_detail_screen.dart',
  'lib/screens/teklif_talebi_detay_screen.dart',
  'lib/screens/teklif_iste_screen.dart',
  'lib/screens/teklif_istekleri_screen.dart',
];

/// `ic_shieldok` ANLAMI GEREĞİ KALAN ekranlar.
const _onayIkonuEkranlari = <String>[
  'lib/screens/listing_detail_screen.dart',
  'lib/screens/offer_detail_screen.dart',
  'lib/screens/notifications_screen.dart',
];

void main() {
  group('1 — ÇANTA İKONU', () {
    test('asset dosyası var ve kontur biçimi projeyle aynı', () {
      final f = File('assets/svg/ic_briefcase.svg');
      expect(f.existsSync(), isTrue, reason: 'ikon dosyası yok');
      final s = f.readAsStringSync();
      // ⚠ `currentColor`: ikon çağrıldığı yerin rengini alır. Sabit
      // renk yazılırsa `RefSvg(color: …)` etkisiz kalır.
      expect(s.contains('currentColor'), isTrue,
          reason: 'ikon sabit renkli — çağrıdaki renk uygulanmaz');
      expect(s.contains('viewBox="0 0 24 24"'), isTrue,
          reason: 'diğer ikonlarla aynı tuval değil');
      expect(s.contains('stroke-width="1.6"'), isTrue,
          reason: 'kontur kalınlığı ikon diliyle uyuşmuyor');
    });

    test('"iş tamamladı" yüzeylerinin hepsinde çanta kullanılıyor', () {
      for (final yol in _isTamamladiEkranlari) {
        expect(_kodu(yol).contains('assets/svg/ic_briefcase.svg'), isTrue,
            reason: '$yol hâlâ eski ikonu kullanıyor');
      }
    });

    test('⚠ "iş tamamladı" yanında KALKAN KALMADI', () {
      for (final yol in _isTamamladiEkranlari) {
        expect(_kodu(yol).contains('assets/svg/ic_shieldok.svg'), isFalse,
            reason: '$yol içinde kalkan kalmış');
      }
    });
  });

  group('2 — KAPSAM SINIRI: onay ikonu YERİNDE DURUYOR', () {
    test('Onaylı Hizmet Veren / İletişim Açıldı / bildirim ikonu', () {
      for (final yol in _onayIkonuEkranlari) {
        expect(_kodu(yol).contains('assets/svg/ic_shieldok.svg'), isTrue,
            reason: '$yol içindeki onay kalkanı yanlışlıkla değişmiş — '
                'orada anlam doğrulamadır, yapılan iş sayısı değil');
      }
    });
  });

  group('3 — KISA KİLİT METNİ', () {
    const ekranlar = <String>[
      'lib/screens/job_detail_screen.dart',
      'lib/screens/teklif_talebi_detay_screen.dart',
    ];

    test('kırpılan uzun cümle KALDIRILDI', () {
      for (final yol in ekranlar) {
        expect(_kodu(yol).contains('İletişim açılınca görünür.'), isFalse,
            reason: '$yol içinde kırpılan eski cümle geri gelmiş');
      }
    });

    test('yerine tek kelime: Kilitli', () {
      for (final yol in ekranlar) {
        expect(_kodu(yol).contains("'Kilitli'"), isTrue,
            reason: '$yol içinde kilit metni yok');
      }
    });
  });
}
