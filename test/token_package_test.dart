import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/token_package.dart';

/// JETON PAKETİ MODELİ — ayrıştırma ve dayanıklılık.
void main() {
  const valid = {
    'id': 'p1', 'name': '50 Jeton', 'tokenAmount': 50,
    'bonusTokenAmount': 5, 'priceTl': 50, 'currency': 'TRY', 'sortOrder': 2,
  };

  group('Ayrıştırma', () {
    test('geçerli paket doğru okunur', () {
      final p = TokenPackage.tryFromJson(valid)!;
      expect(p.id, 'p1');
      expect(p.name, '50 Jeton');
      expect(p.tokenAmount, 50);
      expect(p.bonusTokenAmount, 5);
      expect(p.priceTl, 50);
      expect(p.currency, 'TRY');
    });

    test('TOPLAM jeton = jeton + bonus', () {
      expect(TokenPackage.tryFromJson(valid)!.totalTokenAmount, 55);
    });

    test('bonussuz pakette toplam = jeton', () {
      final p = TokenPackage.tryFromJson({...valid, 'bonusTokenAmount': 0})!;
      expect(p.totalTokenAmount, 50);
      expect(p.hasBonus, isFalse);
    });

    test('bonus alanı YOKSA sıfır kabul edilir', () {
      final j = Map<String, dynamic>.from(valid)..remove('bonusTokenAmount');
      final p = TokenPackage.tryFromJson(j)!;
      expect(p.bonusTokenAmount, 0);
      expect(p.totalTokenAmount, 50);
    });

    test('NEGATİF bonus sıfıra çekilir', () {
      final p = TokenPackage.tryFromJson({...valid, 'bonusTokenAmount': -5})!;
      expect(p.bonusTokenAmount, 0);
    });

    test('para birimi yoksa TRY varsayılır', () {
      final j = Map<String, dynamic>.from(valid)..remove('currency');
      expect(TokenPackage.tryFromJson(j)!.currency, 'TRY');
    });

    test('sayısal alanlar STRING gelse de okunur', () {
      final p = TokenPackage.tryFromJson({
        ...valid, 'tokenAmount': '50', 'priceTl': '50',
      })!;
      expect(p.tokenAmount, 50);
      expect(p.priceTl, 50);
    });
  });

  group('Bozuk veri ÇÖKERTMEZ', () {
    test('zorunlu alanlar eksikse kayıt ELENİR', () {
      for (final key in ['id', 'name', 'tokenAmount', 'priceTl']) {
        final j = Map<String, dynamic>.from(valid)..remove(key);
        expect(TokenPackage.tryFromJson(j), isNull, reason: key);
      }
    });

    test('geçersiz jeton/fiyat elenir', () {
      expect(TokenPackage.tryFromJson({...valid, 'tokenAmount': 0}), isNull);
      expect(TokenPackage.tryFromJson({...valid, 'tokenAmount': -1}), isNull);
      expect(TokenPackage.tryFromJson({...valid, 'priceTl': 0}), isNull);
      expect(TokenPackage.tryFromJson({...valid, 'priceTl': -10}), isNull);
    });

    test('boş ad elenir', () {
      expect(TokenPackage.tryFromJson({...valid, 'name': '   '}), isNull);
    });

    test('liste ayrıştırmada BOZUK kayıt elenir, sağlamlar KALIR', () {
      final list = TokenPackage.listFrom([
        valid,
        {'id': 'bad'},                       // eksik alanlar
        'metin',                             // yanlış tip
        {...valid, 'id': 'p2', 'priceTl': 0}, // geçersiz fiyat
        {...valid, 'id': 'p3', 'sortOrder': 1},
      ]);
      expect(list.map((p) => p.id), ['p3', 'p1']); // sortOrder'a göre
    });

    test('boş liste boş sonuç verir', () {
      expect(TokenPackage.listFrom(const []), isEmpty);
    });
  });

  group('Sıralama', () {
    test('sortOrder, eşitse fiyat', () {
      final list = TokenPackage.listFrom([
        {...valid, 'id': 'c', 'sortOrder': 2, 'priceTl': 30},
        {...valid, 'id': 'a', 'sortOrder': 1, 'priceTl': 99},
        {...valid, 'id': 'b', 'sortOrder': 2, 'priceTl': 10},
      ]);
      expect(list.map((p) => p.id), ['a', 'b', 'c']);
    });
  });

  group('Sözleşme sabitleri', () {
    test('sunucu totalTokenAmount göndermez — istemci hesaplar', () {
      final j = Map<String, dynamic>.from(valid);
      expect(j.containsKey('totalTokenAmount'), isFalse);
      expect(TokenPackage.tryFromJson(j)!.totalTokenAmount, 55);
    });

    test('startsAt/endsAt gelmezse null kalır (sunucu döndürmüyor)', () {
      final p = TokenPackage.tryFromJson(valid)!;
      expect(p.startsAt, isNull);
      expect(p.endsAt, isNull);
    });
  });
}
