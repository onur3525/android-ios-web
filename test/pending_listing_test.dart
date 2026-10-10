import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/pending_listing_controller.dart';
import 'package:hizmetcep/data/models/pending_listing.dart';
import 'package:hizmetcep/data/repositories/pending_listing_store.dart';
import 'support/kaynak_okuma.dart';

/// Bellek içi sahte saklama — güvenli depoya (platform kanalı)
/// ihtiyaç duymadan davranışı doğrular.
class _FakeStore implements PendingListingStore {
  String? raw;
  int yazma = 0;
  int silme = 0;

  @override
  Future<PendingListing?> read() async => PendingListing.decode(raw);

  @override
  Future<void> save(PendingListing p) async {
    raw = p.encode();
    yazma++;
  }

  @override
  Future<void> clear() async {
    raw = null;
    silme++;
  }
}

void main() {
  String read(String p) => File(p).readAsStringSync();

  PendingListing taslak({
    String category = 'Tesisat',
    String? subService = 'Kombi Bakımı',
    List<String> fotograflar = const [],
  }) =>
      PendingListing(
        category: category,
        subService: subService,
        description: 'Kombim ısıtmıyor, bakım gerekiyor.',
        city: 'İzmir',
        district: 'Bornova',
        neighborhood: 'Erzene',
        localPhotoPaths: fotograflar,
        createdAt: DateTime(2026, 1, 1),
      );

  group('B — Taslak içeriği ve kalıcılık', () {
    test('9. 0 fotoğrafla taslak oluşturulabilir', () {
      final p = taslak();
      expect(p.localPhotoPaths, isEmpty);
      expect(p.isComplete, isTrue,
          reason: 'fotoğraf ZORUNLU değildir');
    });

    test('10-14. tüm kullanıcı girdileri korunur', () {
      final p = taslak(fotograflar: ['/a/1.jpg', '/a/2.png']);
      final geri = PendingListing.decode(p.encode())!;
      expect(geri.category, 'Tesisat');
      expect(geri.subService, 'Kombi Bakımı');
      expect(geri.description, p.description);
      expect(geri.city, 'İzmir');
      expect(geri.district, 'Bornova');
      expect(geri.neighborhood, 'Erzene');
      expect(geri.localPhotoPaths, ['/a/1.jpg', '/a/2.png']);
      expect(geri.createdAt, p.createdAt);
    });

    test('ilan başlığı alt hizmeti tercih eder', () {
      expect(taslak().title, 'Kombi Bakımı');
      expect(taslak(subService: null).title, 'Tesisat');
    });

    test('konum İl/İlçe/Mahalle zincirinden üretilir', () {
      expect(taslak().location, 'Erzene, Bornova / İzmir');
    });

    test('15-16. taslak saklanır ve yeniden okunur', () async {
      final store = _FakeStore();
      final c = PendingListingController(store);
      await c.saveDraft(taslak());
      expect(store.raw, isNotNull);

      // Uygulama state'i yeniden kuruldu.
      final c2 = PendingListingController(store);
      await c2.load();
      expect(c2.hasDraft, isTrue);
      expect(c2.draft!.category, 'Tesisat');
    });

    test('17. bozuk JSON crash oluşturmaz', () async {
      final store = _FakeStore()..raw = '{bozuk';
      final c = PendingListingController(store);
      await c.load();
      expect(c.hasDraft, isFalse);
      expect(PendingListing.decode('['), isNull);
      expect(PendingListing.decode(null), isNull);
      expect(PendingListing.decode(''), isNull);
    });
  });

  group('C/D — Yayın ve double-publish koruması', () {
    late _FakeStore store;
    late PendingListingController c;
    setUp(() {
      store = _FakeStore();
      c = PendingListingController(store);
    });

    test('18. taslak yoksa yayın çağrısı YAPILMAZ', () async {
      var cagri = 0;
      final r = await c.publishIfAny(yayinla: (_, __) async {
        cagri++;
        return true;
      });
      expect(r, PendingPublishOutcome.yok);
      expect(cagri, 0);
    });

    test('22/28. başarılı yayın → tek çağrı, taslak temizlenir', () async {
      await c.saveDraft(taslak());
      var cagri = 0;
      final r = await c.publishIfAny(yayinla: (_, __) async {
        cagri++;
        return true;
      });
      expect(r, PendingPublishOutcome.yayinlandi);
      expect(cagri, 1);
      expect(c.hasDraft, isFalse);
      expect(store.raw, isNull);
      expect(store.silme, 1);
    });

    test('26. EŞZAMANLI iki çağrı → tek create', () async {
      await c.saveDraft(taslak());
      var cagri = 0;
      Future<bool> yayin(PendingListing p, List<String> f) async {
        cagri++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return true;
      }

      final sonuclar = await Future.wait([
        c.publishIfAny(yayinla: yayin),
        c.publishIfAny(yayinla: yayin),
      ]);
      expect(cagri, 1, reason: 'backend create YALNIZ bir kez çağrılmalı');
      expect(sonuclar.where((x) => x == PendingPublishOutcome.yayinlandi).length,
          1);
    });

    test('27. ART ARDA iki çağrı → tek create', () async {
      await c.saveDraft(taslak());
      var cagri = 0;
      Future<bool> yayin(PendingListing p, List<String> f) async {
        cagri++;
        return true;
      }

      final a = await c.publishIfAny(yayinla: yayin);
      final b = await c.publishIfAny(yayinla: yayin);
      expect(a, PendingPublishOutcome.yayinlandi);
      expect(b, PendingPublishOutcome.yok);
      expect(cagri, 1);
    });

    test('29-30. başarısız yayın → taslak KORUNUR, retry mümkün', () async {
      await c.saveDraft(taslak());
      var cagri = 0;
      final ilk = await c.publishIfAny(yayinla: (_, __) async {
        cagri++;
        return false; // sunucu hatası
      });
      expect(ilk, PendingPublishOutcome.hata);
      expect(c.hasDraft, isTrue, reason: 'taslak silinmemeli');
      expect(store.raw, isNotNull);

      // Retry
      final ikinci = await c.publishIfAny(yayinla: (_, __) async {
        cagri++;
        return true;
      });
      expect(ikinci, PendingPublishOutcome.yayinlandi);
      expect(cagri, 2);
      expect(c.hasDraft, isFalse);
    });
  });

  group('E — Fotoğraf kuralları (fotoğraf OPSİYONEL)', () {
    late PendingListingController c;
    setUp(() => c = PendingListingController(_FakeStore()));

    test('31. 0 fotoğraf → yayın mümkün, bloke YOK', () async {
      await c.saveDraft(taslak());
      List<String>? gelen;
      final r = await c.publishIfAny(yayinla: (_, f) async {
        gelen = f;
        return true;
      });
      expect(r, PendingPublishOutcome.yayinlandi);
      expect(gelen, isEmpty);
    });

    test('32. mevcut fotoğraf yayına taşınır', () async {
      final dosya = File('${Directory.systemTemp.path}/hc_test_foto.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      await c.saveDraft(taslak(fotograflar: [dosya.path]));
      List<String>? gelen;
      final r = await c.publishIfAny(yayinla: (_, f) async {
        gelen = f;
        return true;
      });
      expect(r, PendingPublishOutcome.yayinlandi);
      expect(gelen, [dosya.path]);
      dosya.deleteSync();
    });

    test('33. kayıp fotoğraf → SESSİZ yayın YOK', () async {
      await c.saveDraft(taslak(fotograflar: ['/yok/olmayan.jpg']));
      var cagri = 0;
      final r = await c.publishIfAny(yayinla: (_, __) async {
        cagri++;
        return true;
      });
      expect(r, PendingPublishOutcome.eksikFotograf);
      expect(cagri, 0, reason: 'kullanıcı karar vermeden yayın YAPILMAZ');
      expect(c.hasDraft, isTrue);
      expect(c.kayipFotograflar, ['/yok/olmayan.jpg']);
    });

    test('34-35. kullanıcı onaylarsa kalanlarla/fotoğrafsız yayın', () async {
      final dosya = File('${Directory.systemTemp.path}/hc_test_foto2.jpg')
        ..writeAsBytesSync([1]);
      await c.saveDraft(
          taslak(fotograflar: [dosya.path, '/yok/olmayan.jpg']));
      List<String>? gelen;
      final r = await c.publishIfAny(
        yayinla: (_, f) async {
          gelen = f;
          return true;
        },
        eksikFotografaIzinVer: true,
      );
      expect(r, PendingPublishOutcome.yayinlandi);
      expect(gelen, [dosya.path], reason: 'yalnız MEVCUT dosyalar');
      dosya.deleteSync();
    });

    test('36. yükleme başarısız → ilan başarılı gösterilmez', () async {
      await c.saveDraft(taslak());
      final r = await c.publishIfAny(yayinla: (_, __) async => false);
      expect(r, isNot(PendingPublishOutcome.yayinlandi));
      expect(c.hasDraft, isTrue);
    });
  });

  group('A/C — Ekran ve güvenlik sözleşmesi', () {
    final cat = read('lib/screens/category_screen.dart');
    final mn = read('lib/main.dart');
    final reg = read('lib/screens/register_screen.dart');
    final cre = read('lib/screens/create_listing_screen.dart');
    final rot = read('lib/screens/prelogin_listing_route.dart');

    test('1-2. kategori yolunda RoleSelectScreen AÇILMAZ', () {
      for (final s in [cat]) {
        expect(s.contains('RoleSelectScreen()'), isFalse,
            reason: 'rol seçim ekranı bu akıştan çıkarılmalı');
      }
    });

    test('3. kategori yolu public pre-login route\'a gider', () {
      for (final s in [cat]) {
        expect(s.contains('PreLoginListingRoute.name'), isTrue);
      }
    });

    test('4-5. kategori ve ALT HİZMET taşınır', () {
      for (final s in [cat]) {
        expect(s.contains('PreLoginListingArgs('), isTrue);
        expect(s.contains('subService:'), isTrue);
      }
      // Oturumlu akışta da alt hizmet taşınır.
      expect(cat.contains('initialSubService: sub'), isTrue);
    });

    test('6. bağımsız kayıt akışında RoleSelectScreen KORUNUR', () {
      expect(File('lib/screens/role_select_screen.dart').existsSync(), isTrue);
      expect(read('lib/screens/role_select_screen.dart')
          .contains('Nasıl Başlamak İstersiniz?'), isTrue);
    });

    test('24. RoleGuard.customer GEVŞETİLMEMİŞ', () {
      expect(
          mn.contains(
              "'/customer/new-listing': (_) =>\n              RoleGuard.customer"),
          isTrue,
          reason: 'korumalı route aynen kalmalı');
    });

    test('25. public route customer-only yetki VERMEZ', () {
      // Yalnız taslak üretir; yayın kayıt sonrasındadır.
      expect(rot.contains('preLogin: true'), isTrue);
      expect(rot.contains('RoleGuard'), isFalse);
    });

    test('18. kayıt öncesi ListingController.publish ÇAĞRILMAZ', () {
      // preLogin dalı taslak kaydedip kayıt akışına geçer.
      final i = cre.indexOf('if (widget.preLogin)');
      expect(i, greaterThan(0));
      final govde = cre.pencere(i, 260);
      expect(govde.contains('_taslakKaydetVeKayitaGec'), isTrue);
      expect(govde.contains('ListingController'), isFalse);
    });

    test('19-21. onboarding tamamlanmadan publish YOK', () {
      expect(reg.contains('customerOnboardingComplete'), isTrue,
          reason: 'SMS OTP + e-posta + adres + sözleşme zorunlu');
      final i = reg.indexOf('Future<void> _bekleyenIlaniYayinla');
      expect(i, greaterThan(0));
      final govde = reg.pencere(i, 900);
      expect(govde.contains('!acc.customerOnboardingComplete'), isTrue);
      expect(govde.contains('return;'), isTrue);
    });

    test('kayıtsızken fotoğraf backend\'e YÜKLENMEZ', () {
      expect(cre.contains('uploadEnabled: !widget.preLogin'), isTrue);
      final pp = read('lib/screens/widgets/photo_picker.dart');
      expect(pp.contains('if (!widget.uploadEnabled)'), isTrue);
    });
  });

  group('11 — photo_picker bütünlüğü', () {
    final pp = read('lib/screens/widgets/photo_picker.dart');

    test('tek sınıf tanımı, duplicate YOK', () {
      expect(RegExp(r'^class PhotoItem', multiLine: true)
          .allMatches(pp)
          .length, 1);
      expect(RegExp(r'^class ListingPhotoPicker', multiLine: true)
          .allMatches(pp)
          .length, 1);
    });

    test('import satırları dosya başında', () {
      final satirlar = pp.split('\n');
      final sonImport =
          satirlar.lastIndexWhere((l) => l.startsWith('import '));
      final ilkClass =
          satirlar.indexWhere((l) => l.startsWith('class '));
      expect(sonImport, lessThan(ilkClass));
    });

    test('mevcut fotoğraf kuralları BOZULMADI', () {
      expect(pp.contains('kMaxListingPhotos = 5'), isTrue);
      expect(pp.contains('kMaxPhotoBytes = 10 * 1024 * 1024'), isTrue);
      expect(pp.contains("'image/jpeg', 'image/png', 'image/webp'"), isTrue);
    });

    test('authenticated akışta upload eskisi gibi (varsayılan açık)', () {
      expect(pp.contains('this.uploadEnabled = true'), isTrue);
    });
  });
}
