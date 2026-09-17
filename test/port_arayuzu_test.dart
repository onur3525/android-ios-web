import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PORT ARAYÜZÜ BÜTÜNLÜĞÜ
///
/// ── ⚠ NİÇİN VAR ──
///
/// Paket 1'de `withdrawOffer` bildirimini `OfferPort`'tan silerken
/// pencere fazla geniş kaldı ve `placeOffer` ile `selectOffer`
/// bildirimleri de gitti. Uygulamalar (mock/api) metotları taşımaya
/// devam ettiği için KAYNAK METİN TESTLERİ bunu görmedi; hata ancak
/// derlemede ortaya çıktı:
///
///   The method 'placeOffer' isn't defined for the type 'OfferPort'.
///
/// Bu dosya o boşluğu kapatır: controller'ların çağırdığı her port
/// metodunun arayüzde BİLDİRİLMİŞ olduğunu doğrular.
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

/// Arayüz adı → bildirilen metot adları.
Map<String, Set<String>> _arayuzler() {
  final s = _kodu('lib/data/ports/repository_ports.dart');
  final out = <String, Set<String>>{};
  for (final m in RegExp(r'abstract class (\w+) extends ChangeNotifier \{(.*?)\n\}',
          dotAll: true)
      .allMatches(s)) {
    out[m.group(1)!] = RegExp(r'\b(\w+)\s*\(')
        .allMatches(m.group(2)!)
        .map((x) => x.group(1)!)
        .toSet();
  }
  return out;
}

/// `ChangeNotifier`'dan miras gelenler — arayüzde bildirilmeleri
/// gerekmez.
const _miras = {
  'dispose',
  'notifyListeners',
  'addListener',
  'removeListener',
  'hasListeners',
};

void main() {
  group('⚠ DOMAIN HATA KAPSAMI', () {
    // ── NİÇİN VAR ──
    //
    // `hataBilgisi()` bir EXHAUSTIVE switch: yeni bir `DomainError`
    // alt tipi eklenip dal yazılmazsa DERLEME KIRILIR:
    //
    //   The type 'DomainError' is not exhaustively matched by the
    //   switch cases since it doesn't match 'IletisimZatenAcikError()'
    //
    // Bu tam olarak yaşandı: Paket 3'te `IletisimZatenAcikError`
    // eklendi ama çeviri dalı yazılmadı. Kaynak metin testleri bunu
    // göremez; ancak derleyici yakalar. Test o boşluğu kapatır.
    test('her DomainError alt tipinin çeviri dalı VAR', () {
      final tipler = RegExp(r'class (\w+) extends DomainError')
          .allMatches(_kodu('lib/domain/failures.dart'))
          .map((m) => m.group(1)!)
          .toSet();
      final kapsanan = RegExp(r'case (\w+)\(\)')
          .allMatches(_kodu('lib/domain/hata_mesajlari.dart'))
          .map((m) => m.group(1)!)
          .toSet();
      expect(tipler, isNotEmpty, reason: 'hata tipleri okunamadı');
      final eksik = tipler.difference(kapsanan);
      expect(eksik, isEmpty,
          reason: 'çeviri dalı olmayan hata tipi — DERLEME KIRILIR: $eksik');
    });

    test('switch\'te tanımsız tip yok', () {
      final tipler = RegExp(r'class (\w+) extends DomainError')
          .allMatches(_kodu('lib/domain/failures.dart'))
          .map((m) => m.group(1)!)
          .toSet();
      final kapsanan = RegExp(r'case (\w+)\(\)')
          .allMatches(_kodu('lib/domain/hata_mesajlari.dart'))
          .map((m) => m.group(1)!)
          .toSet();
      expect(kapsanan.difference(tipler), isEmpty);
    });
  });

  group('PORT ARAYÜZÜ', () {
    test('sekiz port arayüzü tanımlı', () {
      final a = _arayuzler();
      for (final ad in const [
        'AuthPort',
        'ListingPort',
        'OfferPort',
        'ContactPort',
        'ChatPort',
        'ReviewPort',
        'NotificationPort',
      ]) {
        expect(a.containsKey(ad), isTrue, reason: 'eksik arayüz: $ad');
      }
    });

    test('⚠ CONTROLLER\'LARIN ÇAĞIRDIĞI HER METOT ARAYÜZDE BİLDİRİLMİŞ',
        () {
      final arayuz = _arayuzler();
      final eksik = <String>[];

      for (final f in Directory('lib/data/controllers')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final s = _kodu(f.path);
        // Alan adı → port tipi (`final OfferPort _offers;`).
        final tipOf = <String, String>{};
        for (final m in RegExp(r'final (\w+Port) (\w+);').allMatches(s)) {
          tipOf[m.group(2)!] = m.group(1)!;
        }
        for (final m in RegExp(r'\b(\w+)\.(\w+)\(').allMatches(s)) {
          final tip = tipOf[m.group(1)!];
          final metot = m.group(2)!;
          if (tip == null || !arayuz.containsKey(tip)) continue;
          if (_miras.contains(metot)) continue;
          if (!arayuz[tip]!.contains(metot)) {
            eksik.add('${f.path.split('/').last}: $tip.$metot()');
          }
        }
      }
      expect(eksik, isEmpty,
          reason: 'arayüzde bildirilmemiş port çağrısı — DERLEME KIRILIR:\n'
              '${eksik.join('\n')}');
    });

    test('OfferPort temel metotları bildirir', () {
      // ⚠ Kaldırılan `withdrawOffer` ile birlikte gitmişlerdi.
      final o = _arayuzler()['OfferPort']!;
      for (final metot in const [
        'placeOffer',
        'selectOffer',
        'offersForListing',
        'myOfferFor',
        'loadMine',
      ]) {
        expect(o.contains(metot), isTrue, reason: 'OfferPort.$metot() yok');
      }
    });

    test('⚠ withdrawOffer GERİ GELMEDİ', () {
      expect(_arayuzler()['OfferPort']!.contains('withdrawOffer'), isFalse);
    });

    test('ListingPort\'ta start/complete/cancel YOK', () {
      final l = _arayuzler()['ListingPort']!;
      for (final metot in const ['startWork', 'completeWork', 'cancel']) {
        expect(l.contains(metot), isFalse, reason: 'ListingPort.$metot()');
      }
      // Kanonik silme duruyor.
      expect(l.contains('delete'), isTrue);
    });
  });
}
