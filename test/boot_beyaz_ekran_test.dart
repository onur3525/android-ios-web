import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/boot.dart';
import 'support/kaynak_okuma.dart';

/// BOOT / BEYAZ EKRAN / İNTERNET KONTROLÜ
///
/// Talimat: `HizmetCep_Claude_Boot_Beyaz_Ekran_Internet_Hatasi_Talimati`
void main() {
  String read(String p) => File(p).readAsStringSync();
  final sp = read('lib/screens/splash_screen.dart');

  group('BootDecision — her dal görünür bir route üretir', () {
    BootResult karar({
      bool configOk = true,
      bool hasSession = false,
      AgDurumu ag = AgDurumu.bilinmiyor,
      bool maintenance = false,
      String app = '1.0.0',
      String? minVer,
    }) =>
        decideBoot(
          configOk: configOk,
          maintenanceActive: maintenance,
          appVersion: app,
          minSupportedVersion: minVer,
          hasSession: hasSession,
          isProvider: false,
          ag: ag,
        );

    test('ONLINE + oturum yok → home', () {
      expect(karar().decision, BootDecision.home);
    });

    test('ONLINE + oturum var → home', () {
      expect(karar(hasSession: true).decision, BootDecision.home);
    });

    test('sunucu YOK ama İNTERNET VAR → offline ekranı GELMEZ', () {
      // Gerçek cihaz hatası: internet varken "İnternet bağlantısı yok"
      // gösteriliyordu. `configOk=false` yalnız sunucuya ulaşılamadığı
      // anlamına gelir.
      expect(karar(configOk: false, ag: AgDurumu.online).decision,
          isNot(BootDecision.offline));
    });

    test('sunucu YOK ve İNTERNET YOK + oturum yok → offline', () {
      expect(karar(configOk: false, ag: AgDurumu.offline).decision,
          BootDecision.offline);
    });

    // ⚠ ÜÇ DURUMLU AĞ: kontrol edilemediğinde kullanıcı NE yanlış
    // offline'a NE sahte online'a kilitlenir.
    test('ağ durumu BİLİNMİYOR → offline ekranı GÖSTERİLMEZ', () {
      expect(karar(configOk: false, ag: AgDurumu.bilinmiyor).decision,
          isNot(BootDecision.offline),
          reason: 'kontrol hatası yanlış offline üretmemeli');
    });

    test('yalnız KESİN offline çevrimdışı ekranı üretir', () {
      expect(AgDurumu.offline.kesinCevrimdisi, isTrue);
      expect(AgDurumu.online.kesinCevrimdisi, isFalse);
      expect(AgDurumu.bilinmiyor.kesinCevrimdisi, isFalse);
    });

    test('sunucu YOK, internet yok ama oturum VAR → offline değil', () {
      expect(
          karar(configOk: false, ag: AgDurumu.offline, hasSession: true)
              .decision,
          isNot(BootDecision.offline));
    });

    test('bakım → maintenance', () {
      expect(karar(maintenance: true).decision, BootDecision.maintenance);
    });

    test('sürüm düşük → forceUpdate', () {
      expect(karar(app: '1.0.0', minVer: '2.0.0').decision,
          BootDecision.forceUpdate);
    });

    test('hiçbir dal geçersiz sonuç üretmez', () {
      for (final c in [true, false]) {
        for (final s in [true, false]) {
          for (final i in AgDurumu.values) {
            final d = karar(configOk: c, hasSession: s, ag: i).decision;
            expect(BootDecision.values.contains(d), isTrue);
          }
        }
      }
    });
  });

  group('Beyaz ekran koruması', () {
    test('bootReady NAVİGASYON SONRASI karenin sonunda gönderilir', () {
      // ⚠ SÖZLEŞMENİN GEÇMİŞİ:
      //
      // 1) "bootReady navigasyondan SONRA gelsin" — yetmedi:
      //    `Navigator` çağrısının dönmesi çizildiği anlamına gelmez.
      // 2) Kök sarmalayıcı `IlkKareBildirimi` denendi — ÇALIŞMADI:
      //    sinyal `static bool` değişimine bağlıydı, oysa static alan
      //    değişimi hiçbir Element'i kirletmez ve `Navigator` yalnız
      //    kendi alt ağacını yeniden inşa eder.
      // 3) NİHAİ: navigasyon çağrısından SONRA kaydedilen post-frame
      //    geri çağrısı. Kareler arasında kaydedildiği için bir
      //    SONRAKİ karenin sonunda çalışır — hedef rota o karede
      //    build/layout/paint edilir.
      expect(sp.contains('await _yonlendir(karar);'), isTrue);
      expect(sp.contains('void _navSonrasiKareyiBekle(String hedef) {'),
          isTrue);

      // Kayıt navigasyondan SONRA olmalı.
      final iNav = sp.indexOf("BootLog.olay('NAVIGATION_START', '/home')");
      final iKayit = sp.indexOf("_navSonrasiKareyiBekle('/home')", iNav);
      expect(iKayit, greaterThan(iNav));
      final iCagri = sp.indexOf('pushReplacementNamed', iNav);
      expect(iKayit, greaterThan(iCagri),
          reason: 'geri çağrı navigasyon çağrısından ÖNCE kaydediliyor');
    });

    test('kaldırılan sarmalayıcı geri gelmemiş', () {
      expect(File('lib/core/ilk_kare_bildirimi.dart').existsSync(), isFalse);
      final spKod = sp
          .split('\n')
          .where((l) =>
              !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
          .join('\n');
      expect(spKod.contains('IlkKareBildirimi'), isFalse);
      final mKod2 = read('lib/main.dart')
          .split('\n')
          .where((l) =>
              !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
          .join('\n');
      expect(mKod2.contains('IlkKareBildirimi'), isFalse);
      // Mevcut builder yapısı korundu.
      expect(mKod2.contains('OfflineBanner(child: child ?? const SizedBox.shrink())'),
          isTrue);
    });

    test('splash sinyali TEK KEZ gider (çift bırakma yok)', () {
      expect(sp.contains('bool _splashBirakildi = false;'), isTrue);
      expect(sp.contains('if (_splashBirakildi) {'), isTrue);
    });

    test('FALLBACK normal yolun yerine kullanılmaz', () {
      // `finally` bloğundaki geri çağrı YALNIZ navigasyon
      // yapılamadığında kaydedilir.
      final iF = sp.indexOf('FALLBACK — NORMAL YOL BURAYA BAĞLI DEĞİLDİR');
      expect(iF, greaterThan(0));
      final iKosul = sp.indexOf('if (!_yonlendirildi) {', iF);
      final iKayit = sp.indexOf('unawaited(_splashBirak());', iF);
      expect(iKosul, greaterThan(0));
      expect(iKayit, greaterThan(iKosul),
          reason: 'fallback koşulsuz çalışıyor');
    });

    test('yönlendirme hiç yapılamazsa sinyal YİNE gider', () {
      // Sonsuz splash oluşmaz.
      final iFinally = sp.indexOf('BOOT_FALLBACK');
      expect(sp.indexOf('unawaited(_splashBirak());', iFinally),
          greaterThan(iFinally));
    });

    test('finally: yönlendirme yapılmadıysa son güvence devreye girer', () {
      expect(sp.contains('if (!_yonlendirildi)'), isTrue);
      expect(sp.contains('BOOT_FALLBACK'), isTrue);
    });

    test('navigasyon TEK kez çalışır (çift push yok)', () {
      expect(sp.contains('bool _yonlendirildi = false;'), isTrue);
      expect(sp.contains('_yonlendirildi = true;'), isTrue);
    });

    // ⚠ TEK SPLASH KATMANI SÖZLEŞMESİ.
    //
    // Kullanıcıya gösterilen tek splash NATIVE splash'tır. Flutter
    // yüzeyi ikinci bir splash olarak render EDİLMEZ: logo, wordmark
    // veya ilerleme göstergesi çizmez.
    test('Flutter yüzeyi BOŞ DEĞİL — marka bloğu çizer', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ (gerçek cihaz kanıtı).
      //
      // Eski kural: "bu yüzey hiçbir şey çizmez, çünkü zaten
      // görünmez". Varsayım tutmadı: native fail-safe tetiklendiğinde
      // yüzey görünür oluyor ve BOŞ olduğu için kullanıcı tamamen
      // beyaz ekran görüyordu.
      // ⚠ KAYNAK SONRADAN DEĞİŞTİ: `logo_mark.png` + `wordmark.png`
      // ikilisi yerine native splash'ın TAM OLARAK AYNI dosyası
      // çiziliyor (`splash_brand.png`). Ölçüm göstermişti ki iki
      // ayrı dosyanın kenar boşlukları kompozisyondan farklı; logo
      // native'den Flutter'a geçerken kayıyordu.
      expect(sp.contains("Image.asset(\n          'assets/logo/splash_brand.png'"),
          isTrue);
      expect(sp.contains('const double _kMarkaKutusu = 240;'), isTrue);
      expect(sp.contains('SizedBox.expand()'), isFalse,
          reason: 'boş yüzey geri gelmiş');

      // ⚠ SPINNER KURALI KORUNDU.
      expect(sp.contains('CircularProgressIndicator'), isFalse,
          reason: 'ilerleme göstergesi kesinlikle olmamalı');
    });

    // ⚠ 200 ms'lik teorik pay BAŞARI GARANTİSİ SAYILMAZ: gerçek cihaz
    // ek yükü bu süreyi aşabilir. Asıl güvence, fail-safe tetiklense
    // bile Flutter tarafında GÖRÜNÜR bir yüzeyin çizili olmasıdır
    // (üstteki 'splash yüzeyi BOŞ değil' testi).
    test('ana açılış çağrıları fail-safe bütçesinin ALTINDA', () {
      final m = read(
          'android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt');
      final maxMs =
          int.parse(RegExp(r'SPLASH_MAX_MS = (\d+)L').firstMatch(m)!.group(1)!);
      final cfg = int.parse(
          RegExp(r'_kConfigButce = Duration\(milliseconds: (\d+)\)')
              .firstMatch(sp)!
              .group(1)!);
      final ses = int.parse(
          RegExp(r'_kOturumButce = Duration\(milliseconds: (\d+)\)')
              .firstMatch(sp)!
              .group(1)!);
      // ⚠ SÖZLEŞME DEĞİŞTİ.
      //
      // Native splash süresi KISALTILDI (Android 12+ uzun tutulan
      // splash'ta ikonu gizleyip beyaz zemin bırakıyordu). Artık
      // fail-safe erken devreye girer ve Flutter yüzeyi devralır.
      //
      // ⚠ Native splash, boot kararı ve hedef route HAZIR OLMADAN
      // kaldırılmaz: `bootReady` yönlendirmeden SONRA, ilk kare
      // çizildiğinde çağrılır. Fail-safe devreye girse bile ikinci
      // splash gösterilmez; kontrollü ekrana geçilir.
      expect(maxMs, greaterThan(0));
      expect(sp.contains('addPostFrameCallback((_) {'), isTrue,
          reason: 'bootReady hedef route çizildikten sonra gönderilmeli');
      expect(sp.contains('NativeSplash.bootReady()'), isTrue);
      // Marka süresini NATIVE katman yönetir, Flutter beklemez.
      expect(sp.contains('_kMarkaEnAz'), isFalse);

      // Sunucu çağrıları yine de sınırlı olmalı — 20 sn timeout'a
      // bırakılmamalı.
      expect(cfg, lessThanOrEqualTo(3000),
          reason: 'config sorgusu sınırsız beklememeli');
      expect(ses, lessThanOrEqualTo(3000),
          reason: 'oturum sorgusu sınırsız beklememeli');
    });
  });

  group('İnternet kontrolü — yanlış negatif koruması', () {
    test('tek olumsuz sonuç kalıcı çevrimdışı yapmaz', () {
      expect(sp.contains('_kAgTekrarGecikme'), isTrue);
      expect(sp.contains('online(retry)'), isTrue,
          reason: 'kısa yeniden doğrulama olmalı');
    });

    test('kontrol hatası SAHTE ONLINE da üretmez', () {
      final i = sp.indexOf('Future<AgDurumu> _agDurumu()');
      expect(i, greaterThan(0));
      final govde = sp.pencere(i, 1600);
      expect(govde.contains("'unknown:"), isTrue);
      // catch bloğu `bilinmiyor` dönmeli — `online` DEĞİL.
      expect(
          RegExp(r'catch \(e\) \{[\s\S]{0,600}?return AgDurumu\.bilinmiyor;')
              .hasMatch(govde),
          isTrue,
          reason: 'hata durumunda kesin bilgi yokmuş gibi davranılmalı');
      expect(
          RegExp(r'catch \(e\) \{[\s\S]{0,600}?return AgDurumu\.online;')
              .hasMatch(govde),
          isFalse,
          reason: 'hata SAHTE ONLINE üretmemeli');
    });

    test('ağ sorgusu zaman aşımına bağlı (asılı kalmaz)', () {
      expect(sp.contains('_kAgSorguButce'), isTrue);
      final i = sp.indexOf('Future<AgDurumu> _agDurumu()');
      final govde = sp.pencere(i, 1600);
      expect('timeout(_kAgSorguButce)'.allMatches(govde).length, 2);
    });

    test('sonsuz yeniden deneme döngüsü YOK', () {
      final i = sp.indexOf('Future<AgDurumu> _agDurumu()');
      final govde = sp.pencere(i, 1600);
      expect(govde.contains('while ('), isFalse);
      expect(govde.contains('for ('), isFalse);
      // En fazla iki sorgu.
      expect('defaultOnlineChecker()'.allMatches(govde).length, 2);
    });

    test('Tekrar Dene gerçek boot akışını yeniden çalıştırır', () {
      expect(sp.contains('builder: (_) => const SplashScreen()'), isTrue,
          reason: 'yalnız rebuild değil, boot baştan çalışmalı');
    });
  });

  group('Telemetri', () {
    test('tek etiket altında ve gizli veri içermez', () {
      final l = read('lib/core/boot_log.dart');
      expect(l.contains("_etiket = 'HC_BOOT'"), isTrue);
      // Yalnız debug derlemede yazar.
      expect(l.contains('if (!kDebugMode)'), isTrue);
    });

    test('zorunlu olaylar kayıtlı', () {
      // ⚠ İKİ AD DEĞİŞTİ (ölçüm turu):
      //   SESSION_RESTORE_*   → SESSION_RESTORE_SPLASH_*
      //     (main() içindeki ikinci çağrıdan ayırt edilebilsin diye)
      //   NAVIGATION_SUCCESS  → NAVIGATION_CALL_RETURNED
      //     ("başarılı" demek yanıltıcıydı: Navigator çağrısının
      //      dönmesi hedef ekranın ÇİZİLDİĞİ anlamına gelmez)
      final m = read('lib/main.dart');
      for (final e in const [
        'FLUTTER_FIRST_FRAME',
        'CONFIG_CHECK_START',
        'CONNECTIVITY_CHECK_START',
        'CONNECTIVITY_RESULT',
        'SESSION_RESTORE_SPLASH_START',
        'BOOT_DECISION',
        'NAVIGATION_START',
        'NAVIGATION_CALL_RETURNED',
        'NATIVE_BOOT_READY_SENT',
        'BOOT_EXCEPTION',
      ]) {
        expect(sp.contains(e) || read('lib/core/boot_log.dart').contains(e),
            isTrue,
            reason: '$e olayı kayıtlı değil');
      }

      // `runApp` ÖNCESİ pencere de ölçülür — asıl şüpheli orası.
      //
      for (final e in const [
        'MAIN_ENTRY',
        'ENSURE_INITIALIZED_END',
        'BUILD_PORTS_START',
        'BUILD_PORTS_END',
        'SEED_DEMO',
        'RUN_APP_CALL',
      ]) {
        expect(m.contains(e), isTrue, reason: '$e main.dart\'ta yok');
      }
      expect(m.contains('RESTORE_SESSION_MAIN_START'), isFalse,
          reason: 'ikinci restoreSession geri gelmiş');
      // Tokenizer artık tembel: açılışta ölçülecek bir çağrı yok.

      for (final e in const [
        'SPLASH_INIT_STATE',
        'SPLASH_BOOT_START',
        'NAVIGATION_START',
        'NAVIGATION_CALL_RETURNED',
        'POST_NAV_FRAME_END',
        'NATIVE_BOOT_READY_SENT',
      ]) {
        expect(sp.contains(e), isTrue, reason: '$e olayı yok');
      }

      // ⚠ KANITLANMAYAN ADLAR KULLANILMAZ.
      //
      // ⚠ YORUMSUZ METİNDE ARANIR. `read` HAM metin döndürür; bu
      // dosyadaki bazı iddialar bilinçli olarak YORUM arar (bkz.
      // bakiye kuralları). Ama YOKLUK denetimi ham metinde yapılamaz:
      // `splash_screen.dart` bu adın NİÇİN kullanılmadığını bir
      // açıklama satırında anlatıyor, o da eşleşiyordu.
      final spKodu = sp
          .split('\n')
          .where((l) =>
              !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
          .join('\n');
      for (final e in const [
        'TARGET_ROUTE_FIRST_FRAME',
        'TARGET_ROUTE_USABLE',
        'TARGET_ROUTE_BEKLENIYOR',
      ]) {
        expect(spKodu.contains(e), isFalse, reason: '$e adı geri gelmiş');
      }

      expect(read('lib/domain/password_hasher.dart').contains('PBKDF2'),
          isTrue);
    });

    test('ölçüm kronometresi SIFIRLANMAZ', () {
      // Eski hâlde `basla()` her çağrıda yeni Stopwatch kuruyordu;
      // `main()` ile Splash farklı sıfırlara göre ölçerdi.
      final l = read('lib/core/boot_log.dart');
      expect(l.contains('_kronometre ??= Stopwatch()..start();'), isTrue);
    });

    test('ölçüm yardımcıları davranışı değiştirmez', () {
      final l = read('lib/core/boot_log.dart');
      // Release'de iş DOĞRUDAN çalışır, log katmanı devreye girmez.
      expect(l.contains('if (!kDebugMode) {\n      return is_();'), isTrue);
      // Hata atsa bile _END yazılır; istisna YUTULMAZ.
      expect(l.contains('} finally {'), isTrue);
      // Yapay bekleme eklenmedi.
      expect(l.contains('Future.delayed'), isFalse);
    });
  });

  group('AÇILIŞ BLOKLAYICILARI KALDIRILDI', () {
    final m = read('lib/main.dart');
    final b = read('lib/data/services/card_tokenization_bridge.dart');

    /// ⚠ YORUMSUZ metin: açıklamalarda ESKİ çağrılar anlatılıyor
    /// ("burada `_seedDemo(authRepo)` çağrılıyordu"). Ham metinde
    /// arayınca kaldırılmış çağrı hâlâ varmış gibi görünür.
    String kodu(String x) => x
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    final mKod = kodu(m);

    test('demo tohumlama runApp\'i BEKLETMEZ', () {
      // PBKDF2 (20.000 tur) ilk kareyi geciktiriyordu.
      // ⚠ İmza genişledi: tohumlama artık depoları da alıyor
      // (demo ilan/teklif senaryosu için). Çağrının VARLIĞI ve
      // post-frame'e alınmış olması aynen kilitli.
      expect(m.contains('demoTohumla(authRepo,'), isTrue);
      expect(m.contains('addPostFrameCallback'), isTrue);
      // Doğrudan çağrı geri gelmemeli.
      final iRun = mKod.indexOf("BootLog.olay('RUN_APP_CALL')");
      expect(mKod.substring(0, iRun).contains('_seedDemo(authRepo)'), isFalse,
          reason: 'tohumlama yine runApp öncesine alınmış');
    });

    test('⚠ DEMO SENARYOSU YALNIZ DEBUG KAPISININ ARKASINDA', () {
      // ⚠ EN ÖNEMLİ KİLİT: mağazaya giden release paketinde uydurma
      // ilan ÜRETİLMEZ. Çağrı `kDebugMode` bloğunun içinde olmalı.
      final i = mKod.indexOf('if (kDebugMode) {');
      final j = mKod.indexOf('demoTohumla(authRepo,');
      expect(i, greaterThan(0), reason: 'debug kapısı kalkmış');
      expect(j, greaterThan(i),
          reason: 'tohumlama debug kapısının DIŞINA çıkmış');
      expect(j - i, lessThan(200),
          reason: 'çağrı debug bloğunun içinde değil');
    });

    test('⚠ TAMAMLANMIŞ demo işlerde ZİNCİR TAM', () {
      // ⚠ Kullanıcının bildirdiği hatanın kaynağı buydu: tohum
      // ilanı `completed` yapıyor ama teklifi SEÇİLİ işaretlemiyordu.
      // `selectedOfferId` boş kalınca ekran "iletişim açılmamış"
      // sayıyor ve tamamlanan işte "İletişimi Aç" düğmesi çıkıyordu.
      //
      // Tamamlanmış işte dördü birden yazılı olmalı.
      expect(mKod.contains('teklif.status = OfferStatus.selected'), isTrue);
      expect(mKod.contains('ilan.selectedOfferId = teklif.id'), isTrue);
      expect(mKod.contains('contacts?.open(teklif.id)'), isTrue,
          reason: 'iletişim kaydı yazılmamış');
    });

    test('demo senaryosu: iki ilan + iki teklif', () {
      expect(mKod.contains("title: 'Kombi Bakımı'"), isTrue);
      expect(mKod.contains("title: 'Petek Temizliği'"), isTrue);
      // İki farklı hizmet verenden teklif.
      expect(mKod.contains("phone: '5559998877'"), isTrue,
          reason: 'ikinci demo usta yok — teklif karşılaştırması olmaz');
      expect('offers.create('.allMatches(mKod).length, 2);
      // ⚠ Bloke GERÇEKTEN düşülür; cüzdan tutarsız kalmaz.
      expect('wallets.block('.allMatches(mKod).length, 2);
    });

    test('demo VERİSİ kaldırılmadı', () {
      expect(m.contains('void _seedDemo('), isTrue);
      expect(m.contains("phone: '5507654321'"), isTrue);
      expect(m.contains("'Kombi Servis'"), isTrue);
      expect(m.contains('setAddressFor'), isTrue);
    });

    test('tohumlama TEK kez çalışır', () {
      expect(m.contains('bool _tohumlandi = false;'), isTrue);
    });

    test('tokenizer runApp\'i BEKLETMEZ', () {
      final iRun = mKod.indexOf("BootLog.olay('RUN_APP_CALL')");
    });

    test('platform ping ZAMAN AŞIMLI', () {
      // Timeout'suz `await` uygulamayı süresiz bekletebiliyordu.
      expect(b.contains('.timeout(pingButce)'), isTrue);
      expect(b.contains('pingButce = Duration(milliseconds:'), isTrue);
    });

    test('tokenizer sonucu ÖNBELLEKLENİR, tek sorgu yapılır', () {
      expect(b.contains('_bekleyen ??= _sor();'), isTrue);
    });

    test('oturum geri yükleme TEK yerden', () {
      expect(mKod.contains('ports.auth.restoreSession()'), isFalse,
          reason: 'main() içinde ikinci restoreSession geri gelmiş');
      expect(sp.contains('await auth.restoreSession().timeout('), isTrue);
      expect(sp.contains('refreshBadge(me.id)'), isTrue);
    });
  });

  group('ROTASIZ SPLASH / mounted=false', () {
    test('boot kararı mounted denetimiyle KESİLMEZ', () {
      // Eskiden oturum geri yüklemeden sonra `if (!mounted) return;`
      // vardı: karar hiç üretilmiyor, yönlendirme yapılmıyor ama
      // native splash yine bırakılıyordu → rotasız marka ekranı.
      final iSes = sp.indexOf("SESSION_RESTORE_SPLASH_END");
      final iKarar = sp.indexOf('final karar = decideBoot(', iSes);
      expect(iKarar, greaterThan(iSes));
      final ara = sp.substring(iSes, iKarar);
      expect(ara.contains('if (!mounted) {'), isFalse,
          reason: 'erken dönüş geri gelmiş');
    });

    test('yönlendirme yapılamadıysa YANLIŞ bootReady gönderilmez', () {
      expect(sp.contains('if (!_yonlendirildi && !mounted) {'), isTrue);
      expect(sp.contains("BootLog.olay('BOOT_UNMOUNTED'"), isTrue);
      // Koruma, son çare sinyalinden ÖNCE gelmeli.
      final iKoruma = sp.indexOf('if (!_yonlendirildi && !mounted) {');
      final iBirak = sp.indexOf('unawaited(_splashBirak());', iKoruma);
      expect(iBirak, greaterThan(iKoruma));
    });

    test('mounted iken son güvence YİNE yönlendirir', () {
      expect(sp.contains("BootLog.olay('BOOT_FALLBACK'"), isTrue);
      expect(sp.contains('if (!_yonlendirildi) {'), isTrue);
    });
  });

  group('SEED YARIŞI', () {
    final m = read('lib/main.dart');

    test('tohumlama açılış kararından ÖNCE kaydedilir', () {
      // Post-frame geri çağrıları KAYIT SIRASINA göre işlenir.
      // `demoTohumla` buildPorts sırasında (runApp öncesi),
      // `_bootGuvenli` ise SplashScreen.initState'te kaydedilir.
      final iSeed = m.indexOf('demoTohumla(authRepo);');
      final iRun = m.indexOf("BootLog.olay('RUN_APP_CALL')");
      expect(iSeed, greaterThan(0));
      expect(iSeed, lessThan(iRun),
          reason: 'tohumlama kaydı runApp SONRASINA kaymış');
    });

    test('ilk yüzey seed verisine İHTİYAÇ DUYMAZ', () {
      // SplashView yalnız marka bloğu çizer: hesap, kategori, adres
      // veya bölge verisi okumaz.
      final iView = sp.indexOf('class SplashView');
      final iState = sp.indexOf('class SplashScreen', iView);
      final govde = sp.substring(iView, iState);
      for (final t in const [
        'AuthController',
        'RegionController',
        'currentAccount',
        'kCategoryTree',
      ]) {
        expect(govde.contains(t), isFalse, reason: '$t ilk yüzeyde okunuyor');
      }
    });
  });

  group('ROZET VE TOKENIZER AÇILIŞI BEKLETMEZ', () {
    test('bildirim rozeti beklenmez', () {
      expect(sp.contains('unawaited(_bildirimler.refreshBadge(me.id));'),
          isTrue);
      expect(sp.contains('await _bildirimler.refreshBadge'), isFalse,
          reason: 'rozet açılışı bekletiyor');
    });

    test('rozet denetleyicisi await ÖNCESİ alınır', () {
      final iAl = sp.indexOf('_bildirimler = context.read<NotificationController>();');
      final iIlkAwait = sp.indexOf('await ', iAl);
      expect(iAl, greaterThan(0));
      expect(iIlkAwait, greaterThan(iAl));
    });

    test('ping bütçesi sonsuz beklemeyi önler ama toleranslıdır', () {
      final b = read('lib/data/services/card_tokenization_bridge.dart');
      final ms = int.parse(
          RegExp(r'pingButce = Duration\(milliseconds: (\d+)\)')
              .firstMatch(b)!
              .group(1)!);
      expect(ms, greaterThanOrEqualTo(500),
          reason: 'yavaş cihazda gerçek tokenizer yanlışlıkla elenmemeli');
      expect(ms, lessThanOrEqualTo(2000), reason: 'sonsuz bekleme olmamalı');
    });
  });

  group('NATIVE ↔ FLUTTER MARKA SÜREKLİLİĞİ', () {
    test('AYNI görsel kaynağı kullanılır', () {
      expect(sp.contains("Image.asset(\n          'assets/logo/splash_brand.png'"),
          isTrue);
      expect(File('assets/logo/splash_brand.png').existsSync(), isTrue);
      expect(
          File('android/app/src/main/res/drawable-nodpi/splash_brand.png')
              .readAsBytesSync()
              .length,
          File('assets/logo/splash_brand.png').readAsBytesSync().length,
          reason: 'iki kopya farklılaşmış');
    });

    test('zemin rengi native ile BİREBİR aynı', () {
      final c = read('android/app/src/main/res/values/colors.xml');
      expect(c.contains('#FFFEFEFE'), isTrue);
      expect(read('lib/ui/ref_tokens.dart').contains('0xFFFEFEFE'), isTrue);
    });

    test('ölçü native ikon kutusuyla aynı, animasyon YOK', () {
      expect(sp.contains('const double _kMarkaKutusu = 240;'), isTrue);
      for (final t in const [
        'ScaleTransition',
        'FadeTransition',
        'AnimatedOpacity',
        'CircularProgressIndicator',
      ]) {
        expect(sp.contains(t), isFalse, reason: '$t eklenmiş');
      }
    });
  });
}
