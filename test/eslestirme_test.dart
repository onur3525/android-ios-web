// İLAN ↔ HİZMET VEREN EŞLEŞTİRMESİ
//
// KARARLAR:
//   1. İki kademe: 0 = DOĞRUDAN (hizmet verenin seçtiği hizmet),
//      1 = AİLE (seçtiği ana kategoriyle aynı aileden gelen iş).
//      Doğrudan eşleşenler listede ÖNCE gelir.
//   2. Yön düzeltmesi: taraflardan biri ANA kategori seçtiyse eşleşir.
//      İki farklı ALT hizmet birbirine AÇILMAZ.
//   3. Aile genişlemesi YALNIZ ana kategori seçene uygulanır.
//   4. ⚠ KULLANICIYA HİÇBİR ŞEY GÖSTERİLMEZ: "yakın kategori" etiketi,
//      başlığı, açıklaması ya da ayarı YOKTUR. Tek etki sıralamadır.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/domain/eslestirme.dart';

String _kod(String yol) {
  final f = File(yol);
  // ⚠ BURADA `expect` KULLANILMAZ.
  //
  // Bu yardımcı `group(...)` gövdesinde de çağrılıyor; `expect` bir
  // test gövdesi dışında çalışınca `OutsideTestException` atar ve
  // DOSYANIN TAMAMI yüklenemez ("Failed to load"). Eksik dosya
  // durumu düz bir istisnayla bildirilir.
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

void main() {
  group('AİLE HARİTASI', () {
    test('13 aile · 42 kategori · hepsi katalogda', () {
      expect(kKategoriAileleri.length, 13);
      final uyeler = <String>[];
      for (final a in kKategoriAileleri) {
        uyeler.addAll(a);
      }
      // ⚠ 41 → 42: kombi ikiye ayrıldı, ikisi de ısıtma ailesinde.
      expect(uyeler.length, 42);
      // ⚠ TEKİL SAYI DA 42: kombi iki kategoriye ayrıldı ve İKİSİ DE
      // ısıtma ailesinde. Bu iddia tekrarı yakalar — sayı listeyle
      // aynı olmalı.
      expect(uyeler.toSet().length, 42, reason: 'bir kategori iki ailede');
      for (final c in uyeler) {
        expect(kCategoryTree.containsKey(c), isTrue, reason: '$c katalogda yok');
      }
    });

    test('aile dışındaki kategorilerin kapsamı GENİŞLEMEZ', () {
      final ailede = kAileHaritasi.keys.toSet();
      final yalnizlar =
          kTreeCategories.where((c) => !ailede.contains(c)).toList();
      // ⚠ SAYI GÖMÜLMEZ: katalog büyüdükçe aile dışı kategori sayısı
      // değişir (13 → 16). Asıl kural sayı değil, DAVRANIŞ: ailesi
      // olmayan kategoriye aileden ilan düşmez.
      expect(yalnizlar, isNotEmpty);
      for (final c in yalnizlar) {
        // Kendi ailesi olmadığı için hiçbir yabancı ilan aileden düşmez.
        for (final baska in kTreeCategories) {
          if (baska == c) {
            continue;
          }
          expect(aileEslesir(c, baska), isFalse, reason: '$c ← $baska');
        }
      }
    });
  });

  group('KADEME 0 — DOĞRUDAN', () {
    test('aynı ad eşleşir', () {
      expect(dogrudanEslesir('Kombi Bakımı', 'Kombi Bakımı'), isTrue);
      expect(dogrudanEslesir('Su Tesisatı', 'Su Tesisatı'), isTrue);
    });

    test('ANA kategori seçen, alt hizmet ilanını görür', () {
      expect(dogrudanEslesir('Su Tesisatı', 'Tıkanıklık Açma'), isTrue);
      expect(dogrudanEslesir('Tadilat ve Yenileme', 'Ev Tadilatı'), isTrue);
    });

    test('ALT hizmet seçen, kendi ANA kategorisinin ilanını görür', () {
      // ⚠ ESKİ KURALIN KIRIK OLDUĞU YER: 251 alt hizmetin 250'si
      // kendi ana kategorisiyle verilmiş ilanı görmüyordu.
      var sayac = 0;
      for (final e in kCategoryTree.entries) {
        for (final alt in e.value) {
          expect(dogrudanEslesir(alt, e.key), isTrue, reason: '$alt ← ${e.key}');
          sayac++;
        }
      }
      // ⚠ 255 → 459 → 439 → 517: önce öneri listesindeki ayrı işler hizmet oldu,
      // sonra tekrar eden ve dağıtım şirketine ait olanlar kaldırıldı
      // (eski not: ayrı işler gerçek
      // hizmet kaydına çevrildi.
      expect(sayac, 640);
    });

    test('İKİ FARKLI ALT HİZMET birbirine AÇILMAZ', () {
      expect(dogrudanEslesir('Buzdolabı Tamiri', 'Fırın Tamiri'), isFalse);
      expect(dogrudanEslesir('Kombi Bakımı', 'Kombi Tamiri'), isFalse);
    });

    test('farklı ana kategoriler eşleşmez', () {
      expect(dogrudanEslesir('Su Tesisatı', 'Elektrik Tesisatı'), isFalse);
      expect(
          dogrudanEslesir('Tadilat ve Yenileme', 'İnşaat ve Kaba Yapı'),
          isFalse,
          reason: 'bu bağ AİLE kademesinde kurulur');
    });

    test('boş ad eşleşmez', () {
      expect(dogrudanEslesir('', 'Su Tesisatı'), isFalse);
      expect(dogrudanEslesir('Su Tesisatı', ''), isFalse);
    });
  });

  group('KADEME 1 — AİLE', () {
    test('ürün sahibinin örneği: Tadilat ustası İnşaat ilanını alır', () {
      expect(aileEslesir('Tadilat ve Yenileme', 'İnşaat ve Kaba Yapı'), isTrue);
      expect(aileEslesir('Tadilat ve Yenileme', 'Kaba İnşaat'), isTrue);
      expect(aileEslesir('Tadilat ve Yenileme', 'Duvar Örme'), isTrue);
    });

    test('Isıtma ailesi karşılıklı çalışır', () {
      expect(
          aileEslesir('Doğalgaz', 'Isıtma Sistemleri'), isTrue);
      expect(aileEslesir('Kombi Servis', 'Doğalgaz Tesisatı'), isTrue);
    });

    test('YALNIZ ana kategori seçene uygulanır', () {
      // ⚠ Ölçüm: her seçimde açılsaydı ortalama erişim 1,8 → 19,4
      // oluyordu; `Buzdolabı Tamiri` ustasına 30 başlık düşüyordu.
      expect(aileEslesir('Buzdolabı Tamiri', 'Televizyon Tamiri'), isFalse);
      expect(aileEslesir('Kaba İnşaat', 'Tadilat ve Yenileme'), isFalse);
    });

    test('DAR AİLELER: uzak işler düşmez', () {
      // Çilingir ile PVC doğrama aynı ailede DEĞİLDİR.
      expect(aileEslesir('Çilingir ve Kilit', 'PVC Pencere Montajı'), isFalse);
      expect(aileEslesir('Boya ve Badana', 'Parke Döşeme'), isFalse);
    });

    test('kapı ve kilit aynı ailede', () {
      expect(aileEslesir('Kapı Montaj ve Tamir', 'Kapı Açma'), isTrue);
    });
  });

  group('ÖNCELİK', () {
    test('doğrudan 0 · aile 1 · yok -1', () {
      expect(eslesmeOnceligi(['Tadilat ve Yenileme'], 'Ev Tadilatı'),
          kEslesmeDogrudan);
      expect(eslesmeOnceligi(['Tadilat ve Yenileme'], 'Kaba İnşaat'),
          kEslesmeAile);
      expect(eslesmeOnceligi(['Tadilat ve Yenileme'], 'Gitar Dersi'),
          kEslesmeYok);
    });

    test('DOĞRUDAN, aileyi EZER', () {
      // İki kategori de seçiliyse ilan doğrudan sayılır ve öne geçer.
      final o = eslesmeOnceligi(
          ['Tadilat ve Yenileme', 'İnşaat ve Kaba Yapı'], 'Kaba İnşaat');
      expect(o, kEslesmeDogrudan);
    });

    test('seçim YOKSA kısıt uygulanmaz', () {
      expect(eslesmeOnceligi(const [], 'Herhangi Bir Başlık'),
          kEslesmeDogrudan);
    });

    test('ilanUygun, -1 dışındaki her kademede true', () {
      expect(ilanUygun(['Tadilat ve Yenileme'], 'Kaba İnşaat'), isTrue);
      expect(ilanUygun(['Tadilat ve Yenileme'], 'Gitar Dersi'), isFalse);
    });
  });

  group('EKRAN — SIRALAMA VE SESSİZLİK', () {
    final j = _kod('lib/screens/jobs_screen.dart');

    test('ekran kendi kuralını yazmaz, merkezî kuralı çağırır', () {
      expect(j.contains("import '../domain/eslestirme.dart';"), isTrue);
      expect(j.contains('eslesmeOnceligi(me.categories'), isTrue);
      // Eski yerel kural kalıntısı olmamalı.
      expect(j.contains('for (final secim in me.categories)'), isFalse);
      expect(j.contains('final altAd = turkceNormalize(l.title);'), isFalse);
    });

    test('öncelik BİRİNCİL sıralama anahtarı', () {
      expect(j.contains('return oa != ob ? oa.compareTo(ob) : olcuteGore(a, b);'),
          isTrue);
    });

    test('kullanıcının seçtiği sıralama ölçütü KORUNDU', () {
      for (final o in ["'yeni'", "'teklifsiz'", "'old'", "'offasc'", "'offdesc'"]) {
        expect(j.contains(o), isTrue, reason: o);
      }
    });

    test('⚠ KULLANICIYA "yakın kategori" DENMEZ', () {
      // Ne etiket, ne başlık, ne ayar, ne soru.
      for (final metin in [
        'Yakın kategori',
        'yakın kategori',
        'Yakın Kategori',
        'Yakın kategorilerden',
      ]) {
        expect(j.contains(metin), isFalse, reason: metin);
      }
    });

    test('hiçbir ekranda bu kavram GÖRÜNMEZ', () {
      final gorunen = <String>[];
      for (final e in Directory('lib/screens').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) {
          continue;
        }
        final s = _kod(e.path);
        if (s.contains('akın kategori')) {
          gorunen.add(e.path);
        }
      }
      expect(gorunen, isEmpty, reason: 'kavram ekrana sızmış: $gorunen');
    });
  });
}
