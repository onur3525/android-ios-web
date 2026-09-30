// GÜVENLİK VE SAĞLIK DENETİMİ — SÖZLEŞME TESTLERİ
//
// Bu dosya bir denetim turunda bulunan kusurların GERİ GELMESİNİ
// engeller. Her grup, düzeltilen tek bir bulguya karşılık gelir.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

List<String> _libDosyalari() {
  final out = <String>[];
  for (final e in Directory('lib').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) {
      out.add(e.path);
    }
  }
  out.sort();
  return out;
}

void main() {
  // ── SEC-01 ────────────────────────────────────────────────────
  group('SEC-01 · Kayıtsız akışta SMS kodu DOĞRULANIR', () {
    final c = _kod('lib/screens/create_listing_screen.dart');

    test('kod, kayıt isteğinden ÖNCE denetlenir', () {
      // Eski hâl: altı hane dolunca doğrudan `_kaydolVeYayinla`.
      expect(c.contains('unawaited(_otpDogrulaVeKaydol());'), isTrue);
      expect(c.contains('Future<void> _otpDogrulaVeKaydol() async {'), isTrue);
      expect(c.contains('unawaited(_kaydolVeYayinla());'), isFalse,
          reason: 'doğrulama atlanıyor');
    });

    test('mock modda yerel doğrulama, API modunda sunucu', () {
      expect(c.contains('MockOtpService().verify(telefon, _otp.kod)'), isTrue);
      expect(c.contains('ApiConfig.useRealApi'), isTrue);
    });

    test('yanlış kod kutuların ALTINDA bildirilir', () {
      expect(c.contains("_otp.hata = 'Doğrulama kodu hatalı'"), isTrue);
      final o = _kod('lib/screens/widgets/ilan_otp_adimi.dart');
      expect(o.contains('String? hata;'), isTrue);
      expect(o.contains('widget.veri.hata!'), isTrue);
    });

    test('sunucunun kod hatası genel mesaja gömülmez', () {
      expect(c.contains('_step = 4;'), isTrue);
      expect(c.contains('_otp.hata = mesaj;'), isTrue);
    });
  });

  // ── BUG-01 ────────────────────────────────────────────────────
  group('BUG-01 · İş detayı kategori ikonu', () {
    final j = _kod('lib/screens/job_detail_screen.dart');

    test('ikon FOTOĞRAF haritasından okunmaz', () {
      // Fotoğraf haritasındaki değerler `.jpg`; `.svg` koşulu asla
      // sağlanmıyor ve her ilanda `ic_grid.svg` çıkıyordu.
      expect(j.contains('kCategoryImage[baslik]'), isFalse);
      expect(j.contains("endsWith('.svg')"), isFalse);
    });

    test('⚠ TEK İKON ÇÖZÜCÜSÜ — EKRANDA DEĞİL, BİLEŞENDE', () {
      // ── ⚠ SÖZLEŞME DEĞİŞTİ (12 Eyl) ──
      //
      // Önceki kilit `kategoriIkonu(baslik) => categoryIcon(baslik)`
      // satırını zorunlu kılıyordu ve o satır HÂLÂ YANLIŞ İKON
      // çiziyordu: `categoryIcon` KATEGORİ ADIYLA anahtarlı bir
      // harita okur, ona hizmet adı verilince eşleşme olmaz ve genel
      // yedek ikon döner. Yani arıza "düzeltildi" sayılmıştı ama
      // yalnız yedek ikonun adı değişmişti.
      //
      // Doğru çözüm başlıktan KATEGORİYE geçmektir; tek çözücü
      // `ilanIkonu`, tek çağıran `IlanBaslikSatiri`.
      expect(j.contains('kategoriIkonu'), isFalse,
          reason: 'ekran kendi ikon çözücüsünü geri almış');
      expect(j.contains('IlanBaslikSatiri('), isTrue,
          reason: 'iş detayı ortak başlık bileşenini kullanmalı');

      final w = _kod('lib/screens/widgets/ilan_baslik_satiri.dart');
      expect(w.contains('String ilanIkonu(String baslik)'), isTrue);
      expect(w.contains('SearchService.services(baslik)'), isTrue,
          reason: 'başlıktan kategoriye geçiş kalkmış');
    });

    test('⚠ İKON ÇÖZÜCÜSÜ TEK YERDE', () {
      // İkinci bir çözücü doğarsa iki ekran yine ayrışır.
      final yerler = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (f.readAsStringSync().contains('String ilanIkonu(')) {
          yerler.add(f.path);
        }
      }
      expect(yerler, ['lib/screens/widgets/ilan_baslik_satiri.dart']);
    });
  });

  // ── CRASH-01..04 ──────────────────────────────────────────────
  group('CRASH · Oturum düşünce ekranlar ÇÖKMEZ', () {
    const korumasizEkranlar = [
      'lib/screens/job_detail_screen.dart',
      'lib/screens/offer_detail_screen.dart',
      'lib/screens/listing_detail_screen.dart',
      'lib/screens/chat_screen.dart',
    ];

    for (final yol in korumasizEkranlar) {
      test('${yol.split('/').last} build içinde `currentAccount!` yok', () {
        // Bu ekranlar `RoleGuard` ile sarılmaz; `MaterialPageRoute` ile
        // açılır. Oturum düşünce `build` yeniden koşar ve null denetimi
        // patlıyordu.
        final s = _kod(yol);
        final i = s.indexOf('Widget build(BuildContext context)');
        expect(i, greaterThan(-1), reason: yol);
        final govde = s.substring(i);
        expect(govde.contains('currentAccount!'), isFalse, reason: yol);
      });

      test('${yol.split('/').last} kontrollü oturum durumu gösterir', () {
        expect(_kod(yol).contains('SysKind.sessionExpired'), isTrue,
            reason: yol);
      });
    }

    test('sohbet gönderiminde oturum kontrolü var', () {
      final s = _kod('lib/screens/chat_screen.dart');
      expect(s.contains('if (me == null) {'), isTrue);
      // Metin, oturum düşmüşse temizlenmez.
      final i = s.indexOf('Future<void> _send(');
      final govde = s.substring(i, i + 700);
      expect(govde.indexOf('me == null') < govde.indexOf('_input.clear()'),
          isTrue, reason: 'metin kaybolmadan önce kontrol edilmeli');
    });
  });

  // ── ÖLÜ KOD ───────────────────────────────────────────────────
  group('ÖLÜ KOD temizlendi', () {
    test('bağlantısız `backend.dart` silindi', () {
      expect(File('lib/data/remote/backend.dart').existsSync(), isFalse);
      for (final f in _libDosyalari()) {
        expect(_kod(f).contains('remote/backend.dart'), isFalse, reason: f);
      }
    });

    test('çağrılmayan `kapatTumKategoriler` silindi', () {
      final hepsi = _libDosyalari().map(_kod).join('\n');
      expect(hepsi.contains('kapatTumKategoriler'), isFalse);
    });

    test('silinen dosyaya kalan atıf yok', () {
      // Yetim dosya taraması denetim turunda elle yapıldı; burada
      // kilitlenen şey, silinen dosyaya kalan bir atıf olmamasıdır.
      for (final f in _libDosyalari()) {
        expect(_kod(f).contains('backend.dart'), isFalse, reason: f);
      }
    });
  });

  // ── GÜVENLİK SÖZLEŞMELERİ ─────────────────────────────────────
  group('GÜVENLİK · geri gelmemesi gerekenler', () {
    final hepsi = _libDosyalari().map(_kod).join('\n');

    test('TLS doğrulaması gevşetilmemiş', () {
      expect(hepsi.contains('allowSelfSigned'), isFalse);

      // ── ⚠ `HttpOverrides` TEK İSTİSNA: WEBSOCKET SABİTLEMESİ ──
      //
      // Güvenlik turu 2: `socket_io_client` dışarıdan `HttpClient`
      // almadığı için WebSocket, sabitlemeli istemci üreten bir
      // `HttpOverrides.runZoned` bölgesinde kurulur — TLS SIKILAŞIR.
      // Yasak olan: `HttpOverrides.global` (bütün bağlantıları etkiler)
      // ve sabitlemeli istemci dışında bir şey üretmek.
      expect(hepsi.contains('HttpOverrides.global'), isFalse);
      final overrideKullanan = _libDosyalari()
          .where((y) => _kod(y).contains('HttpOverrides'))
          .toList();
      expect(overrideKullanan, ['lib/data/remote/sabitlemeli_istemci_io.dart'],
          reason: 'beklenmeyen HttpOverrides: $overrideKullanan');
      expect(
          _kod('lib/data/remote/sabitlemeli_istemci_io.dart').contains(
              'createHttpClient: (_) => SertifikaSabitleme.istemci(),'),
          isTrue);

      // ── ⚠ `badCertificateCallback` TEK İSTİSNA: SABİTLEME ──
      //
      // Geri çağrı kendi başına TLS'i GEVŞETMEZ; ne döndürdüğüne
      // bakılır. Sertifika sabitlemesinde pin tutmayan bağlantı
      // REDDEDİLİR — yani doğrulama SIKILAŞIR.
      //
      // ⚠ Tehlikeli olan koşulsuz `true` dönmektir; onu ayrıca ararız.
      final kullanan = _libDosyalari()
          .where((y) => _kod(y).contains('badCertificateCallback'))
          .toList();
      expect(kullanan, ['lib/data/remote/sertifika_sabitleme.dart'],
          reason: 'sabitleme dışında TLS geri çağrısı: \$kullanan');

      final sab = _kod('lib/data/remote/sertifika_sabitleme.dart');
      // Pin denetimi yapılıyor ve sonucu döndürülüyor.
      expect(sab.contains('kabulEdilir(sertifika)'), isTrue);
      // Koşulsuz kabul YOK.
      expect(sab.contains('=> true;'), isFalse,
          reason: 'geri çağrı her sertifikayı kabul ediyor');
    });

    test('düz `SharedPreferences` ile hassas veri saklanmaz', () {
      // ⚠ `encryptedSharedPreferences: true` AYRI ŞEYDİR: bu,
      // `flutter_secure_storage`'ın Android arka ucudur ve şifrelidir.
      // Yasak olan `shared_preferences` PAKETİDİR.
      expect(hepsi.contains('package:shared_preferences'), isFalse);
      final pub = File('pubspec.yaml').readAsStringSync();
      expect(pub.contains('shared_preferences:'), isFalse);
      // Token deposu güvenli olmalı.
      final t = _kod('lib/data/remote/token_store.dart');
      expect(t.contains('FlutterSecureStorage'), isTrue);
      expect(t.contains('encryptedSharedPreferences: true'), isTrue);
    });

    // ⚠ 30 Eyl (H-01): kapı `kDebugMode` DEĞİL `TestModu.etkin`.
    // `TestModu` release'te hiçbir koşulda açılmaz VE web'de varsayılan
    // kapalıdır (debug web yayını da sabit OTP/demo hesap taşımaz).
    // Kural GÜÇLENDİ: eski kapı debug web yayınında açıktı.
    test('test OTP kodu YALNIZ test modunda geçerli', () {
      final o = _kod('lib/data/services/otp_service.dart');
      expect(o.contains('return TestModu.etkin && code == _debugCode;'),
          isTrue);
    });

    test('test hesabı YALNIZ test modunda seed edilir', () {
      final a = _kod('lib/data/repositories/auth_repository.dart');
      expect(a.contains('bool seedTestAccount = TestModu.etkin'), isTrue);
    });

    test('test modu: release\'te imkânsız, web\'de varsayılan kapalı', () {
      final k = _kod('lib/core/test_modu.dart');
      expect(
          k.contains(
              'static const bool etkin = !kReleaseMode && (!kIsWeb || _webIstegi);'),
          isTrue);
      expect(k.contains("bool.fromEnvironment('HC_TEST_MODU')"), isTrue);
    });

    test('release derlemede mock veri kaynağı İMKÂNSIZ', () {
      final c = _kod('lib/data/remote/api_config.dart');
      expect(c.contains('if (kReleaseMode) {\n      return DataSourceMode.api;'),
          isTrue);
    });

    test('release derlemede düz HTTP reddedilir', () {
      final c = _kod('lib/data/remote/api_config.dart');
      expect(c.contains("!_envBaseUrl.startsWith('https://')"), isTrue);
      final m = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(m.contains('android:usesCleartextTraffic="false"'), isTrue);
      expect(m.contains('android:allowBackup="false"'), isTrue);
    });

    test('release imzası eksikse build KIRILIR', () {
      final g = File('android/app/build.gradle').readAsStringSync();
      expect(g.contains('RELEASE İMZALAMA ANAHTARI BULUNAMADI'), isTrue);
      expect(g.contains('throw new GradleException'), isTrue);
    });

    test('yığın izi release logcat\'e yazılmaz', () {
      final s = _kod('lib/screens/splash_screen.dart');
      expect(s.contains('if (kDebugMode) {\n        debugPrint('), isTrue);
    });
  });
}
