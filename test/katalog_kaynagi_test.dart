import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KATALOG KAYNAĞI — NİHAİ KARARIN KİLİDİ
///
/// ⚠ KARAR: katalogun tek otoritatif kaynağı BACKEND'dir.
/// Kanonik uç `GET /categories`; Android, iOS ve Web aynı ucu
/// kullanır. İstemcideki liste YALNIZCA CACHE'tir.
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

String _sozlesme() => File('docs/openapi.yaml').readAsStringSync();

/// Sözleşmedeki yollar (ham YAML'dan; paket bağımlılığı yok).
Set<String> _sozlesmeYollari() {
  final sonuc = <String>{};
  for (final l in File('docs/openapi.yaml').readAsLinesSync()) {
    final m = RegExp(r'^  (/[^:]*):\s*$').firstMatch(l);
    if (m != null) sonuc.add(m.group(1)!);
  }
  return sonuc;
}

void main() {
  group('1 — KANONİK UÇ', () {
    test('GET /categories sözleşmede tanımlı', () {
      expect(_sozlesmeYollari().contains('/categories'), isTrue);
    });

    test('⚠ ALTERNATİF KATALOG UCU YOK', () {
      // `/categories/me`, `/my/categories`, `/mobile/categories` gibi
      // karşılıklar aynı veriyi ikinci bir adla sunmak olurdu.
      final yollar = _sozlesmeYollari();
      for (final yasak in const [
        '/categories/me',
        '/my/categories',
        '/mobile/categories',
        '/catalog',
        '/services',
      ]) {
        expect(yollar.contains(yasak), isFalse, reason: 'alternatif uç: $yasak');
      }
      // Katalog için yol sayısı TEK olmalı.
      final katalogYollari =
          yollar.where((y) => y.contains('categor')).toList();
      expect(katalogYollari, ['/categories']);
    });

    test('istemci alternatif kategori ucu ÇAĞIRMIYOR', () {
      final klasor = Directory('lib/data/remote/api');
      for (final f in klasor.listSync().whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final k = _kodu(f.path);
        for (final yasak in const [
          "'/categories/me'",
          "'/my/categories'",
          "'/mobile/categories'",
          "'/catalog'",
        ]) {
          expect(k.contains(yasak), isFalse, reason: '${f.path}: $yasak');
        }
      }
    });
  });

  group('2 — OTORİTE BACKEND', () {
    final y = _sozlesme();

    test('sözleşme katalog otoritesini backend olarak tanımlar', () {
      expect(y.contains('KATALOG OTORİTESİ BACKEND\'DİR'), isTrue);
      expect(y.contains('KANONİK KATALOG KAYNAĞI'), isTrue);
    });

    test('⚠ İSTEMCİ LİSTESİ CACHE OLARAK İŞARETLİ', () {
      // Uygulamaya gömülü listenin otorite sayılması, admin
      // yönetimini etkisiz kılardı.
      final k = File('lib/data/category_tree.dart').readAsStringSync();
      expect(k.contains('OTORİTESİ DEĞİLDİR — YALNIZCA CACHE'), isTrue);
      expect(k.contains('GET /categories'), isTrue);
    });

    test('üç platform AYNI ucu kullanır', () {
      // Tek Flutter kod tabanı Android, iOS ve Web'i besliyor;
      // platforma özel katalog dosyası bulunmamalı.
      expect(y.contains('Android, iOS ve Web AYNI ucu'), isTrue);
      final platformKatalogu = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.dart') &&
              RegExp(r'categor.*(android|ios|web)|(android|ios|web).*categor',
                      caseSensitive: false)
                  .hasMatch(f.path))
          .toList();
      expect(platformKatalogu, isEmpty,
          reason: 'platforma özel katalog dosyası: $platformKatalogu');
    });

    test('yeni kategori için uygulama sürümü gerekmez', () {
      expect(y.contains('YENİ KATEGORİ İÇİN UYGULAMA SÜRÜMÜ GEREKMEZ'), isTrue);
    });
  });

  group('3 — BACKEND DOĞRULAMA ZORUNLULUĞU', () {
    final y = _sozlesme();

    test('sunucu referansı YENİDEN doğrular', () {
      expect(y.contains('BACKEND\'İN ZORUNLU KONTROLLERİ'), isTrue);
      expect(y.contains('aktif ve seçilebilir mi'), isTrue);
      expect(y.contains('İSTEMCİ DENETİMİ GÜVENLİK SAYILMAZ'), isTrue);
    });

    test('⚠ YENİ HATA KODU İCAT EDİLMEDİ', () {
      // Ret için mevcut sözleşme yeterli.
      expect(y.contains('YENİ hata kodu\n        tanımlanmadı'), isTrue);
    });

    test('pasif kategori yeni ilanda seçilemez', () {
      expect(y.contains('Pasifleştirilen kategori yeni ilanda'), isTrue);
    });

    test('⚠ GEÇMİŞ İLANLARIN REFERANSI İSTEMCİDE DEĞİŞMEZ', () {
      expect(y.contains('GEÇMİŞ İLANLARIN BÜTÜNLÜĞÜ KORUNUR'), isTrue);
      expect(y.contains('İSTEMCİ TARAFINDAN DEĞİŞTİRİLMEZ'), isTrue);
    });
  });

  group('4 — İSTEMCİ KİMLİK ÜRETMEZ', () {
    test('addan kimlik türetme yasağı yazılı', () {
      final k = File('lib/data/category_tree.dart').readAsStringSync();
      expect(k.contains('İSTEMCİ KATEGORİ KİMLİĞİ ÜRETMEZ'), isTrue);
    });

    test('⚠ MEVCUT DURUM DÜRÜSTÇE KAYITLI', () {
      // İstemci ucu henüz çağırmıyor; bu gerçek gizlenmiyor.
      expect(_sozlesme().contains('İstemci bu ucu HENÜZ ÇAĞIRMIYOR'), isTrue);
    });
  });
}
