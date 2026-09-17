import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/izmir.dart';
import 'package:hizmetcep/data/services/search_service.dart';
import 'support/kaynak_okuma.dart';

/// ANA SAYFA ARAMA — AYRI SAYFAYA YÖNLENDİRME YOK
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Öneri kaynağı — admin eklemelerine açık', () {
    test('kısmi yazımda ana kategori gelir', () {
      final r = SearchService.services('do');
      expect(r.map((h) => h.label), contains('Doğalgaz'));
    });

    test('kısmi yazımda ALT hizmetler de gelir', () {
      final r = SearchService.services('Kombi');
      final etiketler = r.map((h) => h.label).toList();
      expect(etiketler, contains('Kombi Bakımı'));
      expect(etiketler, contains('Kombi Montajı'));
      // Alt hizmetin ana kategorisi taşınır.
      final bakim = r.firstWhere((h) => h.label == 'Kombi Bakımı');
      expect(bakim.category, 'Kombi Servis');
      expect(bakim.subService, 'Kombi Bakımı');
    });

    test('ANA KATEGORİ eşleşince o kategorinin TÜM alt hizmetleri gelir', () {
      // "doğalgaz" yazan kullanıcı yalnız adında "doğalgaz" geçenleri
      // değil, kategorinin HİZMETLERİNİN TAMAMINI görmelidir.
      final etiketler =
          SearchService.services('doğalgaz').map((h) => h.label).toList();
      expect(etiketler, contains('Doğalgaz'), reason: 'ana kategori');
      for (final s in kSubServices['Doğalgaz']!) {
        expect(etiketler, contains(s), reason: '$s listelenmeli');
      }
      // ⚠ `Kombi Montajı` ve `Petek Temizliği` ARTIK BAŞKA
      // KATEGORİLERDE (`Kombi` / `Isıtma`); "doğalgaz" sorgusunda
      // gelmeleri BEKLENMEZ. Kural değişmedi — kategori eşleşince o
      // kategorinin tüm alt hizmetleri gelir; yukarıdaki döngü bunu
      // zaten `kSubServices['Doğalgaz']` üzerinden doğruluyor.
      expect(etiketler, isNot(contains('Kombi Montajı')),
          reason: 'Kombi ayrı kategoridir');
    });

    test('her kayıt AYRI bir öneridir — tekrar yok', () {
      final r = SearchService.services('doğalgaz');
      final anahtarlar =
          r.map((h) => '${h.category}|${h.subService}').toList();
      expect(anahtarlar.toSet().length, anahtarlar.length,
          reason: 'aynı kayıt iki kez listelenmemeli');
      // Ana kategori + alt hizmetleri: 1 + katalogdaki alt hizmet sayısı.
      expect(r.length, 1 + kSubServices['Doğalgaz']!.length);
    });

    test('eşleşmeyen kategorinin alt hizmetleri SIZMAZ', () {
      final r = SearchService.services('doğalgaz');
      // Başka kategorilerin hizmetleri, adları eşleşmedikçe gelmez.
      expect(r.every((h) => h.category == 'Doğalgaz'), isTrue);
    });

    test('"te" → Temizlik ve Tesisat zinciri', () {
      // ⚠ `Tesisat` ana kategorisi artık `Su Tesisatı` adıyla duruyor;
      // katalog 53 kategoriye çıkarken yeniden adlandırıldı.
      final etiketler =
          SearchService.services('te').map((h) => h.label).toList();
      expect(etiketler, contains('Temizlik Hizmetleri'));
      expect(etiketler, contains('Su Tesisatçısı'));
    });

    test('Türkçe büyük/küçük harf duyarsız', () {
      expect(SearchService.services('TESİSAT').map((h) => h.label),
          contains('Su Tesisatı'));
      expect(SearchService.services('tesisat').map((h) => h.label),
          contains('Su Tesisatı'));
    });

    test('boş sorgu öneri üretmez', () {
      expect(SearchService.services(''), isEmpty);
      expect(SearchService.services('   '), isEmpty);
    });

    test('eşleşmeyen sorgu boş döner (çökmez)', () {
      expect(SearchService.services('zzzz'), isEmpty);
    });

    test('öneri listesi SABİT DEĞİL — tek veri kaynağından üretilir', () {
      // Admin/backend yeni kategori eklerse öneriler kendiliğinden
      // genişler; bileşende gömülü liste OLMAMALI.
      final box = read('lib/screens/widgets/inline_search_box.dart');
      expect(box.contains('SearchService.services'), isTrue);
      for (final c in kHomeCategories) {
        expect(box.contains("'$c'"), isFalse,
            reason: '$c bileşene gömülmüş — sabit liste olmamalı');
      }
    });
  });

  group('Ana sayfa sözleşmesi', () {
    final home = read('lib/screens/home_screen.dart');

    test('arama kutusu AYRI SAYFAYA yönlendirmez', () {
      // Kutu artık InlineSearchBox; SearchScreen'e push YOK.
      expect(home.contains('InlineSearchBox('), isTrue);
      final i = home.indexOf('InlineSearchBox(');
      final blok = home.pencere(i, 500);
      expect(blok.contains('SearchScreen'), isFalse,
          reason: 'arama kutusu ayrı sayfa açmamalı');
    });

    test('öneri seçimi rol seçim ekranı AÇMAZ', () {
      final i = home.indexOf('void _hizmetSecildi');
      expect(i, greaterThan(0));
      final govde = home.pencere(i, 1200);
      expect(govde.contains('RoleSelectScreen'), isFalse);
      expect(govde.contains('PreLoginListingRoute.name'), isTrue);
    });

    test('seçilen kategori ve alt hizmet TAŞINIR', () {
      // ⚠ PENCERE GENİŞLETİLDİ (1200 → 2800).
      //
      // `_hizmetSecildi` gövdesine ÇIKAR ÇATIŞMASI denetimi eklendi
      // (hizmet veren kendi alanında ilan açamaz). Aranan satırlar
      // 1200 karakterlik pencerenin DIŞINA düştü. İDDİA AYNI, yalnız
      // bakılan alan büyütüldü.
      final i = home.indexOf('void _hizmetSecildi');
      final govde = home.pencere(i, 2800);
      expect(govde.contains('category: kategori'), isTrue);
      expect(govde.contains('subService: altHizmet'), isTrue);
      expect(govde.contains('initialCategory: kategori'), isTrue);
      expect(govde.contains('initialSubService: altHizmet'), isTrue);
    });

    test('rol sözleşmesi category_screen ile AYNI', () {
      // ⚠ PENCERE GENİŞLETİLDİ (1200 → 2800).
      //
      // `_hizmetSecildi` gövdesine ÇIKAR ÇATIŞMASI denetimi eklendi
      // (hizmet veren kendi alanında ilan açamaz). Aranan satırlar
      // 1200 karakterlik pencerenin DIŞINA düştü. İDDİA AYNI, yalnız
      // bakılan alan büyütüldü.
      final i = home.indexOf('void _hizmetSecildi');
      final govde = home.pencere(i, 2800);
      // Müşteri rolü varsa korumalı form, yoksa public taslak.
      expect(govde.contains('roles.contains(Role.customer)'), isTrue);
      expect(govde.contains('switchRole(Role.customer)'), isTrue);
    });
  });

  group('Bileşen davranışı', () {
    final box = read('lib/screens/widgets/inline_search_box.dart');

    test('kapalıyken referans görünümü korunur', () {
      expect(box.contains('return RefSearchBox('), isTrue);
    });

    test('açıkken yazılabilir alan ve aşağı açılan liste var', () {
      expect(box.contains('TextField('), isTrue);
      expect(box.contains('ListView.separated'), isTrue);
      // ⚠ PANEL ARTIK OVERLAY'DE. Kutunun altındaki `Column` çocuğu
      // olmaktan çıktı (sayfayı aşağı itiyordu), bu yüzden kaynakta
      // kutudan SONRA gelmiyor — ayrı bir metotta (`_panelYap`).
      // Kutuya `LayerLink` ile bağlı; görsel olarak yine altında.
      expect(box.contains('CompositedTransformTarget'), isTrue);
      expect(box.contains('followerAnchor: Alignment.topLeft'), isTrue);
    });

    test('sayfa değiştiren çağrı YOK', () {
      expect(box.contains('Navigator.push'), isFalse,
          reason: 'bileşen sayfa açmamalı; seçim callback ile bildirilir');
      expect(box.contains('onSecim'), isTrue);
    });
  });
}
