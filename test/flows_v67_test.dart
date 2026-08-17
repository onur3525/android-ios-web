import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/boot.dart';
import 'package:hizmetcep/core/deep_links.dart';
import 'package:hizmetcep/data/izmir.dart';
import 'package:hizmetcep/data/izmir_neighborhoods.dart';
import 'package:hizmetcep/data/legal_cache.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/models/payment.dart';
import 'package:hizmetcep/data/store_links.dart';
import 'package:hizmetcep/screens/category_ui.dart';
import 'package:hizmetcep/screens/widgets/photo_picker.dart';

/// v67 paketi — yeni akışların saf mantık testleri.
/// Widget testleri ayrı dosyada; burada ağ/IO gerektirmeyen sözleşmeler
/// doğrulanır. ÇALIŞTIRILMADI (ortamda Flutter SDK yok).
void main() {
  // ── ÖDEME DURUM MAKİNESİ ────────────────────────────────────────────
  group('Ödeme durumu', () {
    test('sunucu sözlüğü doğru eşlenir', () {
      expect(PaymentStatus.parse('SUCCEEDED'), PaymentStatus.succeeded);
      expect(PaymentStatus.parse('FAILED'), PaymentStatus.failed);
      expect(PaymentStatus.parse('CANCELLED'), PaymentStatus.cancelled);
      expect(PaymentStatus.parse('EXPIRED'), PaymentStatus.expired);
      expect(PaymentStatus.parse('PENDING'), PaymentStatus.pending);
    });

    test('bilinmeyen/boş durum PENDING sayılır (sahte başarı YOK)', () {
      expect(PaymentStatus.parse(null), PaymentStatus.pending);
      expect(PaymentStatus.parse(''), PaymentStatus.pending);
      expect(PaymentStatus.parse('OK'), PaymentStatus.pending);
      expect(PaymentStatus.parse('TRUE'), PaymentStatus.pending);
    });

    test('yalnız succeeded/failed/cancelled/expired nihaidir', () {
      expect(PaymentStatus.pending.isFinal, isFalse);
      expect(PaymentStatus.succeeded.isFinal, isTrue);
      expect(PaymentStatus.failed.isFinal, isTrue);
      expect(PaymentStatus.cancelled.isFinal, isTrue);
      expect(PaymentStatus.expired.isFinal, isTrue);
    });

    test('sağlayıcı ekranı yoksa canOpenProvider false', () {
      const s = PaymentSession(
        sessionId: 's1', providerRef: 'r1', amountTl: 500,
        status: PaymentStatus.pending,
      );
      expect(s.canOpenProvider, isFalse);
    });

    test('fromJson sözleşmesi', () {
      final s = PaymentSession.fromJson(const {
        'sessionId': 's1', 'providerRef': 'r1', 'amountTl': 500,
        'status': 'PENDING', 'redirectUrl': 'https://pay.example/checkout',
      });
      expect(s.sessionId, 's1');
      expect(s.amountTl, 500);
      expect(s.canOpenProvider, isTrue);
    });
  });

  // ── DERİN BAĞLANTI ──────────────────────────────────────────────────
  group('Ödeme derin bağlantısı', () {
    test('geçerli dönüş adresinden session okunur', () {
      final u = Uri.parse('hizmetcep://payment/return?session=abc-123');
      expect(isPaymentReturn(u), isTrue);
      expect(paymentSessionIdFrom(u), 'abc-123');
    });

    test('sessionId anahtarı da kabul edilir', () {
      final u = Uri.parse('hizmetcep://payment/return?sessionId=xyz');
      expect(paymentSessionIdFrom(u), 'xyz');
    });

    test('BAŞARI BİLGİSİNE GÜVENİLMEZ — yalnız session taşınır', () {
      final u = Uri.parse(
          'hizmetcep://payment/return?session=s1&status=SUCCEEDED&success=true');
      // Yardımcı yalnız session döndürür; durum bilgisi taşınmaz.
      expect(paymentSessionIdFrom(u), 's1');
    });

    test('yabancı şema ve yol reddedilir', () {
      expect(isPaymentReturn(Uri.parse('https://evil.test/payment/return')),
          isFalse);
      expect(isPaymentReturn(Uri.parse('hizmetcep://profile')), isFalse);
      expect(paymentSessionIdFrom(Uri.parse('hizmetcep://payment/return')),
          isNull);
    });

    test('DUPLICATE CALLBACK ikinci kez işlenmez', () {
      DeepLinks.instance.resetHandled();
      final u = Uri.parse('hizmetcep://payment/return?session=dup');
      expect(DeepLinks.instance.markHandled(u), isFalse); // ilk
      expect(DeepLinks.instance.markHandled(u), isTrue);  // ikinci
      DeepLinks.instance.resetHandled();
    });
  });

  // ── SPLASH KARAR MATRİSİ ────────────────────────────────────────────
  group('Splash açılış kararı', () {
    BootResult run({
      bool configOk = true,
      bool maintenance = false,
      String app = '1.0.0',
      String? minVer,
      bool session = false,
      bool provider = false,
      // ⚠ ÜÇ DURUMLU AĞ MODELİ: `configOk` (sunucu meta bilgisi) ile
      // cihazın ağ durumu AYRI kavramlardır. Çevrimdışı ekranı yalnız
      // ağ KESİN olarak yokken gösterilir.
      AgDurumu ag = AgDurumu.bilinmiyor,
    }) =>
        decideBoot(
          configOk: configOk,
          maintenanceActive: maintenance,
          appVersion: app,
          minSupportedVersion: minVer,
          hasSession: session,
          isProvider: provider,
          ag: ag,
        );

    test('bakım OTURUMDAN ÖNCE gelir', () {
      expect(run(maintenance: true, session: true).decision,
          BootDecision.maintenance);
    });

    test('zorunlu güncelleme oturumdan önce gelir', () {
      expect(run(app: '1.0.0', minVer: '2.0.0', session: true).decision,
          BootDecision.forceUpdate);
    });

    test('sürüm yeterliyse güncelleme istenmez', () {
      expect(run(app: '2.1.0', minVer: '2.0.0', session: true).decision,
          BootDecision.home);
    });

    // HTML SÖZLEŞMESİ: `vSplash()` 1400 ms sonra KOŞULSUZ home'a gider.
    // Oturumsuz kullanıcı karşılama ekranını görür; giriş ekranı ancak
    // profil ikonuna dokununca açılır.
    test('oturum yoksa da ANA EKRAN (otomatik giriş YOK)', () {
      final r = run(session: false);
      expect(r.decision, BootDecision.home);
      // Oturumsuzda panel seçimi yapılmaz.
      expect(r.isProvider, isFalse);
    });

    test('oturum varsa ana ekran ve rol taşınır', () {
      final r = run(session: true, provider: true);
      expect(r.decision, BootDecision.home);
      expect(r.isProvider, isTrue);
    });

    // Talimat BOOT-01: temiz kurulumda otomatik giriş ekranı AÇILMAZ.
    test('BOOT-01: hiçbir koşulda login kararı üretilmez', () {
      final durumlar = [
        run(session: false),
        run(session: true),
        run(session: true, provider: true),
        run(app: '2.1.0', minVer: '2.0.0', session: false),
      ];
      for (final r in durumlar) {
        expect(r.decision, isNot(BootDecision.offline),
            reason: 'bu senaryoda çevrimdışı beklenmiyor');
        expect(r.decision, BootDecision.home,
            reason: 'oturum durumundan bağımsız olarak Home beklenir');
      }
    });

    test('ağ KESİN yok + oturum yok → çevrimdışı', () {
      expect(
          run(configOk: false, session: false, ag: AgDurumu.offline).decision,
          BootDecision.offline);
    });

    // ⚠ Ağ durumu BİLİNMİYORSA kullanıcı sahte çevrimdışına
    // KİLİTLENMEZ: sunucuya ulaşılamaması tek başına yeterli değildir.
    test('ağ durumu BİLİNMİYOR + oturum yok → çevrimdışı DEĞİL', () {
      expect(
          run(configOk: false, session: false, ag: AgDurumu.bilinmiyor)
              .decision,
          isNot(BootDecision.offline));
    });

    test('ağ KESİN yok + oturum var → içeri alınır (kilitlenmez)', () {
      expect(run(configOk: false, session: true, ag: AgDurumu.offline).decision,
          BootDecision.home);
    });

    test('minVer bilinmiyorsa kullanıcı güncellemeye ZORLANMAZ', () {
      expect(run(app: '0.1.0', minVer: null, session: true).decision,
          BootDecision.home);
      expect(compareVersions('1.0.0', null), 0);
      expect(compareVersions(null, '1.0.0'), 0);
    });

    test('sürüm karşılaştırma', () {
      expect(compareVersions('1.2.3', '1.2.4'), -1);
      expect(compareVersions('1.10.0', '1.9.9'), 1);
      expect(compareVersions('2.0.0', '2.0.0'), 0);
      expect(compareVersions('1.0.0-beta', '1.0.0'), 0);
      expect(compareVersions('bozuk', '1.0.0'), 0); // biçimsizde zorlama yok
    });
  });

  // ── KATEGORİ GÖRSELİ ────────────────────────────────────────────────
  group('Kategori görselleri', () {
    test('Türkçe adlar güvenli slug üretir', () {
      expect(categorySlug('Doğalgaz'), 'dogalgaz');
      expect(categorySlug('Mühendislik'), 'muhendislik');
      expect(categorySlug('Su Tesisatı'), 'sutesisati');
      expect(categorySlug('Boya'), 'boya');
    });

    test('GÖRSELİ OLAN kategorilerde asset çözülür', () {
      // ⚠ 53 KATEGORİNİN HEPSİNİN GÖRSELİ YOKTUR.
      //
      // Katalog 34 → 53'e çıkarken otomotiv · eğitim · dijital ·
      // kişisel alanlar eklendi; onların fotoğrafı üretilmedi.
      // `categoryAsset` null döner ve çağıran taraf `categoryIcon`
      // SVG çizimine düşer — bu BEKLENEN davranıştır, hata değil.
      //
      // Burada denetlenen: görseli TANIMLI olanların dosyası GERÇEKTEN
      // var mı. Tanımlı ama diskte olmayan yol sessiz kırık görseldir.
      var sayac = 0;
      for (final c in kHomeCategories) {
        final a = categoryAsset(c);
        if (a == null) {
          continue;
        }
        sayac++;
        expect(File(a).existsSync(), isTrue, reason: '$c → $a yok');
      }
      expect(sayac, greaterThan(0), reason: 'hiç görsel tanımlı değil');
    });

    test('GÖRSELİ OLMAYAN kategori SVG ikona düşer', () {
      final gorselsiz =
          kHomeCategories.where((c) => categoryAsset(c) == null).toList();
      for (final c in gorselsiz) {
        expect(categoryIcon(c), isNotNull, reason: c);
        expect(File(categoryIcon(c)).existsSync(), isTrue, reason: c);
      }
    });

    test('BİLİNMEYEN kategoride asset null → fallback ikon', () {
      expect(categoryAsset('Uzay Mühendisliği'), isNull);
      // İkon fallback her zaman bir değer döndürür (çökme yok).
      expect(categoryIcon('Uzay Mühendisliği'), isNotNull);
      expect(categoryIcon(''), isNotNull);
    });

    test('slug listesi asset dosyalarıyla birebir', () {
      // ⚠ SLUG KÜMESİ KATALOGDAN KÜÇÜKTÜR.
      //
      // `kCategoryAssetSlugs` yalnız GÖRSELİ TANIMLI kategorileri
      // içerir (34); katalog 53 kategoridir. Eşitlik beklemek yanlıştı.
      //
      // Denetlenen kural: kümedeki her slug GERÇEK bir kategoriye ait
      // olmalı — ölü anahtar kalmamalı.
      expect(kCategoryAssetSlugs.length,
          lessThanOrEqualTo(kHomeCategories.length));
      final katalogSluglari = kHomeCategories.map(categorySlug).toSet();
      for (final s in kCategoryAssetSlugs) {
        expect(katalogSluglari.contains(s), isTrue,
            reason: '$s hiçbir kategoriye ait değil (ölü anahtar)');
      }
      for (final c in kHomeCategories.where((c) => categoryAsset(c) != null)) {
        expect(kCategoryAssetSlugs.contains(categorySlug(c)), isTrue,
            reason: c);
      }
      // ⚠ ÇAKIŞMA DENETİMİ — KATALOG SAYISIYLA DEĞİL.
      //
      // Eskiden `kHomeCategories.length` ile eşitlik bekleniyordu; ama
      // küme yalnız GÖRSELİ TANIMLI kategorileri içerir (34), katalog
      // 53'tür. Doğru denetim: görseli olan kategorilerin slug'ları
      // BİRBİRİNE ÇAKIŞMAMALI — iki kategori aynı dosyaya düşmesin.
      final gorselli =
          kHomeCategories.where((c) => categoryAsset(c) != null).toList();
      expect(kCategoryAssetSlugs.length, gorselli.map(categorySlug).toSet().length);
    });
  });

  // ── İLAN FOTOĞRAFI ──────────────────────────────────────────────────
  group('İlan fotoğrafı politikası', () {
    test('izinli türler kabul edilir', () {
      expect(contentTypeOf('a.jpg'), 'image/jpeg');
      expect(contentTypeOf('a.JPEG'), 'image/jpeg');
      expect(contentTypeOf('a.png'), 'image/png');
      expect(contentTypeOf('a.webp'), 'image/webp');
    });

    test('izinsiz tür reddedilir', () {
      expect(contentTypeOf('a.gif'), isNull);
      expect(contentTypeOf('a.pdf'), isNull);
      expect(contentTypeOf('a.exe'), isNull);
      expect(validatePhoto(path: 'a.gif', sizeBytes: 100), isNotNull);
    });

    test('boyut sınırı uygulanır', () {
      expect(validatePhoto(path: 'a.jpg', sizeBytes: 1024), isNull);
      expect(validatePhoto(path: 'a.jpg', sizeBytes: kMaxPhotoBytes), isNull);
      expect(validatePhoto(path: 'a.jpg', sizeBytes: kMaxPhotoBytes + 1),
          isNotNull);
      expect(validatePhoto(path: 'a.jpg', sizeBytes: 0), isNotNull);
    });

    test('yüklenmemiş fotoğraf isUploaded=false', () {
      final p = PhotoItem(
          localPath: '/tmp/a.jpg', sizeBytes: 10, contentType: 'image/jpeg');
      expect(p.isUploaded, isFalse);
      p.storageRef = 'mock://listing-photo/u1/a.jpg';
      expect(p.isUploaded, isTrue);
    });

    test('maksimum fotoğraf sayısı 5', () {
      expect(kMaxListingPhotos, 5);
    });
  });

  // ── BÖLGE VERİSİ ────────────────────────────────────────────────────
  group('İzmir bölge verisi', () {
    test('30 ilçe / 1300 mahalle', () {
      expect(kIzmirDistricts.length, 30);
      final total = kIzmirNeighborhoods.values
          .fold<int>(0, (a, n) => a + n.length);
      expect(total, 1300);
    });

    test('her ilçenin mahallesi var, duplicate yok', () {
      for (final d in kIzmirDistricts) {
        final ns = neighborhoodsOf(d);
        expect(ns, isNotEmpty, reason: d);
        expect(ns.toSet().length, ns.length, reason: '$d duplicate');
      }
    });

    test('yazım bozukluğu yok', () {
      for (final e in kIzmirNeighborhoods.entries) {
        for (final n in e.value) {
          expect(n.trim(), n, reason: '${e.key}: "$n"');
          expect(n.contains('  '), isFalse, reason: '${e.key}: "$n"');
        }
      }
    });

    test('bilinmeyen ilçede boş liste (çökme yok)', () {
      expect(neighborhoodsOf('Ankara'), isEmpty);
      expect(neighborhoodsOf(''), isEmpty);
    });

    test('sürüm damgası vardır (backend ile eşleşmeli)', () {
      expect(kIzmirRegionsVersion, isNotEmpty);
    });
  });

  // ── TEK ADRES ───────────────────────────────────────────────────────
  group('Tek adres modeli', () {
    test('Account.address TEK kayıttır (liste değil)', () {
      final a = Account(id: 'u1', phone: '5551112233',
          passwordHash: 'h', salt: 's');
      expect(a.address, isNull);
      a.address = Address(
          id: 'a1', district: 'Konak', neighborhood: 'Alsancak');
      expect(a.address, isNotNull);
      expect(a.address!.display, 'Alsancak, Konak / İzmir');
    });

    test('eksik alan isComplete=false', () {
      final a = Address(id: 'a1', district: 'Konak', neighborhood: '');
      expect(a.isComplete, isFalse);
      a.neighborhood = 'Alsancak';
      expect(a.isComplete, isTrue);
    });
  });

  // ── YASAL METİN ÖNBELLEĞİ ───────────────────────────────────────────
  group('Yasal metin önbelleği (çevrimdışı)', () {
    test('yazılan belge okunur', () {
      LegalCache.instance.clear();
      expect(LegalCache.instance.read('terms'), isNull);
      LegalCache.instance.write(const LegalDoc(
        slug: 'terms', title: 'Kullanım Koşulları',
        version: '1.0.0', effectiveDate: '2026-07-01', body: '# Başlık',
      ));
      final d = LegalCache.instance.read('terms');
      expect(d, isNotNull);
      expect(d!.version, '1.0.0');
      LegalCache.instance.clear();
    });

    test('profil menüsündeki tüm bağlantılar slug taşır', () {
      expect(kLegalLinks, isNotEmpty);
      for (final l in kLegalLinks) {
        expect(l.slug.trim(), isNotEmpty);
        expect(l.title.trim(), isNotEmpty);
      }
      // Destek Merkezi menüde bulunmalı.
      expect(kLegalLinks.any((l) => l.slug == 'support'), isTrue);
    });
  });

  // ── MAĞAZA BAĞLANTISI ───────────────────────────────────────────────
  group('Mağaza bağlantısı (yalnız zorunlu güncelleme)', () {
    test('mock kimlik KULLANILMAZ', () {
      expect(kIosAppStoreId, isNot('0000000000'));
      expect(storeUrlForPlatform(), isNot(contains('id0000000000')));
      expect(storeUrlForPlatform(), isNot(contains('example.com')));
    });

    test('paket adı gerçek değer taşır', () {
      expect(kAndroidPackage, 'com.hizmetcep.app');
      expect(storeFallbackUrl(), isNotEmpty);
    });
  });
}
