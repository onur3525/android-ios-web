import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/validators.dart';
import 'package:hizmetcep/core/telefon_bicimi.dart';
import '../support/kaynak_okuma.dart';

/// HİZMET ALAN TARAFI — 15 MADDE REGRESYON KONTROLLERİ
///
/// Talimat: `HizmetCep_Hizmet_Alan_Duzeltme_Talimati_2026-08-09`
void main() {
  String read(String p) => File(p).readAsStringSync();

  test('01 — ApiClient provider ağacında sunulur', () {
    final m = read('lib/main.dart');
    expect(m.contains('Provider<ApiClient>.value(value: ports.apiClient)'),
        isTrue,
        reason: 'ProviderNotFoundError kaynağı');
    // İki veri kaynağı dalı da istemci vermeli.
    expect('apiClient:'.allMatches(m).length, greaterThanOrEqualTo(2));
  });

  test('02 — kayıt adresi Account.address\'e yazılır', () {
    final r = read('lib/screens/register_screen.dart');
    expect(r.contains('saveAddress('), isTrue);
    // Adreslerim kayıtlı değerleri preload eder.
    final a = read('lib/screens/addresses_screen.dart');
    expect(a.contains('ProfileController>().address'), isTrue);
  });

  test('03 — şifre değiştir ekranında sıfırlama yolu var', () {
    final c = read('lib/screens/change_password_screen.dart');
    expect(c.contains('Şifremi Unuttum'), isTrue);
    expect(c.contains('forgotStart('), isTrue);
  });

  // ══════════════════════════════════════════════════════════════
  // 04 — TEK GÖRÜNÜR SPLASH (nihai mimari)
  //
  // ESKİ mimari: `drawable/launch_background.xml` (native launch
  // yüzeyi) + ayrıca Flutter'ın kendi splash route'u → kullanıcı İKİ
  // splash görüyordu.
  //
  // YENİ mimari: kullanıcıya gösterilen TEK splash ANDROID NATIVE
  // splash'tır (`Theme.SplashScreen` + `setKeepOnScreenCondition`).
  // `launch_background.xml` BİLİNÇLİ OLARAK kaldırıldı; bu yüzden
  // varlığı ARTIK ZORUNLU DEĞİLDİR.
  // ══════════════════════════════════════════════════════════════
  group('04 — tek native splash', () {
    const resDizin = 'android/app/src/main/res';

    test('eski launch_background yapısı geri GELMEMELİ', () {
      // Geri gelirse ikinci bir splash yüzeyi oluşur.
      expect(File('$resDizin/drawable/launch_background.xml').existsSync(),
          isFalse,
          reason: 'eski native launch yüzeyi kaldırıldı');
      expect(File('$resDizin/drawable-v21/launch_background.xml').existsSync(),
          isFalse);
    });

    test('splash teması dört varyantta da tanımlı', () {
      for (final d in const [
        'values',
        'values-night',
        'values-v31',
        'values-night-v31',
      ]) {
        final f = File('$resDizin/$d/styles.xml');
        expect(f.existsSync(), isTrue, reason: '$d/styles.xml yok');
        final s = f.readAsStringSync();
        expect(s.contains('name="LaunchTheme"'), isTrue, reason: d);
        expect(s.contains('Theme.SplashScreen'), isTrue,
            reason: '$d: Android 12+ uyumlu splash teması gerekli');
      }
    });

    // TEMA VE API BAĞIMSIZLIĞI
    //
    // Marka görseli TEK kompozisyondur (`splash_brand.png`) ve sistem
    // onu ikon kutusuna ölçekler. Bu yüzden API seviyesine göre ayrı
    // yapı GEREKMEZ; dört varyant birebir aynıdır.
    test('dört varyant BİREBİR aynı splash üretir', () {
      final acik = read('$resDizin/values/styles.xml');
      for (final d in const [
        'values-night',
        'values-v31',
        'values-night-v31',
      ]) {
        expect(read('$resDizin/$d/styles.xml'), acik,
            reason: '$d farklı splash üretiyor');
      }
    });

    test('marka görseli TEK kompozisyon ve ölçeklenebilir', () {
      final s = read('$resDizin/values/styles.xml');
      // Logo + wordmark tek görselde.
      expect(s.contains('@drawable/splash_brand'), isTrue);
      // drawable-nodpi: sistem ikon kutusuna ölçekler → her ekran
      // boyutunda aynı oran. Sabit dp konumlandırma OLMAMALI.
      expect(File('$resDizin/drawable-nodpi/splash_brand.png').existsSync(),
          isTrue);
      // Eski sabit-dp layer-list yapıları geri gelmemeli.
      expect(File('$resDizin/drawable/splash_brand_full.xml').existsSync(),
          isFalse);
      expect(File('$resDizin/drawable/splash_logo_layer.xml').existsSync(),
          isFalse);
      // brandingImage'a artık gerek yok (wordmark kompozisyonun içinde).
      expect(s.contains('windowSplashScreenBrandingImage'), isFalse);
    });

    test('zemin tüm varyantlarda aynı resource', () {
      for (final d in const [
        'values',
        'values-night',
        'values-v31',
        'values-night-v31',
      ]) {
        expect(
            read('$resDizin/$d/styles.xml')
                .contains('windowSplashScreenBackground">@color/launch_background'),
            isTrue,
            reason: d);
      }
    });

    test('Android 12+ splash öznitelikleri doğru', () {
      final s = read('$resDizin/values-v31/styles.xml');
      expect(s.contains('windowSplashScreenBackground'), isTrue);
      expect(s.contains('windowSplashScreenAnimatedIcon'), isTrue);
      expect(s.contains('postSplashScreenTheme'), isTrue);
      // ⚠ ÖZNİTELİK ZORUNLU AMA SAYDAM OLAMAZ: saydam verilirse
      // Android "arka planı yok" dalını seçer ve ikon kutusu 288dp
      // olur; `SplashView` 240dp çizdiği için native yüzey
      // bırakıldığında logo küçülür. Değer splash zeminiyle AYNI
      // renktir, bu yüzden görünür bir daire oluşmaz.
      // Değerin kendisi `splash_cikis_animasyonu_test` ile kilitli.
      expect(s.contains('windowSplashScreenIconBackgroundColor'), isTrue);
    });

    test('splash zemini #FEFEFE (Flutter splash ile aynı)', () {
      final s = read('$resDizin/values/styles.xml');
      // Zemin resource üzerinden verilir.
      expect(s.contains('windowSplashScreenBackground">@color/launch_background'),
          isTrue);
      // Resource değeri hem açık hem koyu temada beyaz.
      for (final d in const ['values', 'values-night']) {
        expect(read('$resDizin/$d/colors.xml').contains('#FFFEFEFE'), isTrue,
            reason: '$d/colors.xml zemini beyaz olmalı');
      }
    });

    test('koyu tema lacivert / Theme.Black ÜRETMEZ', () {
      for (final d in const ['values-night', 'values-night-v31']) {
        final s = read('$resDizin/$d/styles.xml');
        expect(s.contains('Theme.Black'), isFalse, reason: d);
      }
      expect(read('$resDizin/values-night/colors.xml').contains('#FF16233D'),
          isFalse,
          reason: 'lacivert açılış zemini geri gelmemeli');
    });

    test('splash zemini #FEFEFE (tam ekran, bant yok)', () {
      final s = read('$resDizin/values/styles.xml');
      expect(
          s.contains('windowSplashScreenBackground">@color/launch_background'),
          isTrue);
      // Zemin resource'u açık ve koyu temada AYNI beyaz.
      for (final d in const ['values', 'values-night']) {
        expect(read('$resDizin/$d/colors.xml').contains('#FFFEFEFE'), isTrue,
            reason: d);
      }
    });


    test('FAIL-SAFE: bootReady gelmese bile splash BIRAKILIR', () {
      final m = read(
          'android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt');
      // Üst sınır tanımlı olmalı.
      expect(m.contains('SPLASH_MAX_MS'), isTrue,
          reason: 'splash sonsuza kadar tutulamaz');
      // Üst sınırda koşul KOŞULSUZ false dönmeli.
      expect(m.contains('gecen >= SPLASH_MAX_MS'), isTrue);
      // Üst sınır, en kısa süreden büyük olmalı.
      final min = RegExp(r'SPLASH_MIN_MS = (\d+)L').firstMatch(m);
      final max = RegExp(r'SPLASH_MAX_MS = (\d+)L').firstMatch(m);
      expect(min, isNotNull);
      expect(max, isNotNull);
      final minMs = int.parse(min!.group(1)!);
      final maxMs = int.parse(max!.group(1)!);
      // ⚠ TEK SPLASH KATMANI: marka süresini native katman yönetir.
      // İkon gizlenmesi `windowSplashScreenAnimationDuration` ile
      // engellenir (bkz. res/values*/styles.xml).
      expect(minMs, greaterThanOrEqualTo(1500),
          reason: 'marka splash yeterince görünmeli');
      expect(minMs, lessThanOrEqualTo(3000));
      expect(maxMs, greaterThan(minMs));
      // Kilitlenmeyi önlemek için üst sınır KISA tutulmalı.
      expect(maxMs, lessThanOrEqualTo(6000));
    });

    test('Dart: bootReady HER YOLDA gönderilir (finally)', () {
      final sp = read('lib/screens/splash_screen.dart');
      // Hata/erken dönüş durumunda da sinyal gitmeli.
      expect(sp.contains('finally {'), isTrue,
          reason: 'bootReady garanti altında olmalı');
      expect(sp.contains('_bootGuvenli'), isTrue);
      // Açılış hatasında sonsuz splash yerine kontrollü akış.
      expect(sp.contains('BootDecision.offline'), isTrue);
    });

    test('MainActivity: 2000 ms sözleşmesi, UI thread bloklanmaz', () {
      final m = read(
          'android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt');
      // ⚠ TEK SPLASH KATMANI: marka süresini native katman yönetir.
      // Flutter yüzeyi ikinci splash olarak çizilmediği için native
      // splash yeterince görünür kalmalıdır.
      expect(m.contains('SPLASH_MIN_MS = 2000L'), isTrue);
      expect(m.contains('installSplashScreen()'), isTrue);
      expect(m.contains('setKeepOnScreenCondition'), isTrue);
      expect(m.contains('Thread.sleep('), isFalse,
          reason: 'bekleme UI thread\'ini bloklamamalı');
      // Geriye uyumluluk kütüphanesi bağlı olmalı.
      expect(read('android/app/build.gradle').contains('core-splashscreen'),
          isTrue);
    });

    test('Flutter ikinci splash UI\'sı geri GELMEMELİ', () {
      final sp = read('lib/screens/splash_screen.dart');
      expect(sp.contains('AssetImage'), isFalse,
          reason: 'Flutter yüzeyinde logo olmamalı');
      expect(sp.contains('ScaleTransition'), isFalse,
          reason: 'logo sıçraması olmamalı');
      expect(sp.contains('FadeTransition'), isFalse);
      // Süre native tarafta yönetilir.
      expect(sp.contains('milliseconds: 1400'), isFalse);
      // Dart kararı native'e bildirir.
      expect(sp.contains('NativeSplash.bootReady()'), isTrue);
      expect(File('lib/core/native_splash.dart').existsSync(), isTrue);
    });
  });

  test('05 — arama sonucunda görsel/badge yok', () {
    final s = read('lib/screens/search_screen.dart');
    expect(s.contains('CategoryBadge'), isFalse,
        reason: 'HTML .srow satırında görsel yoktur');
  });

  test('06 — telefon yerel biçim ve uzunluk sınırı', () {
    // Kullanıcıya `0` ile gösterilir.
    expect(Validators.phoneLocal('5321112233'), '05321112233');
    expect(Validators.phoneLocal('05321112233'), '05321112233');
    // Sunucuya giden değer 10 hane, baştaki 0 yok.
    expect(Validators.phoneFmt('05321112233'), '5321112233');
    expect(kPhoneLocalMaxLength, 11);

    // ⚠ Test GEVŞETİLMEDİ, GÜÇLENDİRİLDİ.
    //
    // Önceki hâl yalnız uzunluk sınırının kodda geçtiğine bakıyordu.
    // Kural artık ortak `TelefonBicimlendirici` içindedir; test hem
    // ekranın bu bileşeni kullandığını hem de DAVRANIŞI doğrular.
    final r = read('lib/screens/register_screen.dart');
    expect(r.contains('TelefonBicimlendirici()'), isTrue,
        reason: 'telefon alanı ortak biçimlendiriciyi kullanmalı');

    const b = TelefonBicimlendirici();

    /// Boş alandan başlayarak yazma.
    TextEditingValue yaz(String yazilan) => b.formatEditUpdate(
        TextEditingValue.empty, TextEditingValue(text: yazilan));

    /// Var olan bir metni düzenleme (silme dâhil).
    TextEditingValue duzenle(String eski, String yeni, int imlec) =>
        b.formatEditUpdate(
            TextEditingValue(text: eski),
            TextEditingValue(
                text: yeni,
                selection: TextSelection.collapsed(offset: imlec)));

    // ── ALANDA HAM YEREL BİÇİM DURUR ──
    //
    // ⚠ Gruplama ALANDAN ÇIKARILDI. Boşluklu metin silmeyi ve imleç
    // konumunu bozuyordu: her tuşta metin yeniden diziliyor, imleç
    // sona atlıyordu. Boşluklu gösterim artık yalnız OKUMA
    // yerlerinde uygulanır (`TelefonBicimlendirici.gruplu`).
    //
    // ⚠ BAŞTAKİ `0` ARTIK YAZMA ANINDA EKLENMEZ.
    //
    // Otomatik `0`, basılan tuş sayısı ile alandaki karakter sayısını
    // eşitsiz hâle getiriyordu. Android IME metnin uzadığını bir
    // sonraki güncellemeyle öğrendiği için, hızlı ardışık yazımda
    // ESKİ metin üzerinden düzenleme gönderiyor ve RAKAM DÜŞÜYORDU.
    // Artık biçimlendirici uzunluğu değiştirmez.
    //
    // ⚠ Backend sözleşmesi etkilenmez: `phoneFmt` baştaki sıfırları
    // zaten atıyor, gösterimde gereken `0` `phoneLocal` ile üretiliyor.
    expect(yaz('5').text, '5');
    expect(yaz('5555631993').text, '5555631993');
    // Kullanıcı yerel biçimi elle yazar ya da sunucudan gelen numara
    // alana `phoneLocal` ile yazılırsa baştaki `0` KORUNUR.
    expect(yaz('05555631993').text, '05555631993');
    expect(yaz('005555631993').text, '05555631993');
    // Ülke kodu yapıştırıldığında atılır.
    expect(yaz('+90 555 563 19 93').text, '5555631993');
    // ⚠ SINIR BAŞTAKİ `0`A GÖRE: `5` ile başlayan biçim 10 hanedir.
    expect(yaz('5555631993999').text, '5555631993');
    expect(yaz('05555631993999').text, '05555631993');

    // ── İLK GİRİŞ KURALLARI (yalnız alan BOŞKEN) ──
    //
    // `5` ile başlamayan giriş alana HİÇ girmez.
    expect(yaz('3').text, '');
    expect(yaz('9').text, '');
    // Kullanıcı yerel biçimi elle yazıyorsa `0` ile başlayabilir.
    expect(yaz('0').text, '0');

    // ── SİLME SERBEST ──
    //
    expect(duzenle('05555631993', '5555631993', 0).text, '5555631993');
    // Ortadan silme çalışır ve imleç yerinde kalır.
    final orta = duzenle('05555631993', '0555631993', 4);
    expect(orta.text, '0555631993');
    expect(orta.selection.baseOffset, 4);
    // ⚠ DÜZENLEMEDE İLK GİRİŞ KURALLARI İŞLEMEZ.
    //
    // İşleseydi kullanıcı bir hane silince metin geçersiz sayılıp
    // TAMAMEN silinirdi. `05` içinden `5` silinince geriye `0` kalır;
    // kullanıcı bir kez daha silerek alanı boşaltır.
    expect(duzenle('05', '0', 1).text, '0');
    expect(duzenle('0', '', 0).text, '');
    expect(duzenle('05555631993', '0355631993', 2).text, '0355631993');

    // Gruplama yardımcısı OKUMA için hâlâ çalışır.
    expect(TelefonBicimlendirici.gruplu('05555631993'), '0555 563 19 93');
  });

  test('07 — şifre 8–64 karakter, içerik şartı YOK', () {
    // ⚠ ASGARİ 6 → 8 (16 Ağu). NIST SP 800-63B kullanıcı seçimli
    // şifrelerde asgari 8 istiyor ve 64+ desteklenmesini şart
    // koşuyor. App Store/Play bu konuda sayı BELİRTMEZ; değişiklik
    // mağaza zorunluluğu değil, standarda hizalanmadır.
    //
    // ⚠ Gerçek kullanıcı yokken yapıldı: canlıda olsaydı mevcut
    expect(kPasswordMinLength, 8);
    expect(kPasswordMaxLength, 64);

    // Alt sınır uygulanır.
    expect(Validators.password('1234567'), isNotNull, reason: '7 hane');
    expect(Validators.password('kdmrxz'), isNotNull, reason: '6 hane');
    expect(Validators.password(''), isNotNull);
    expect(Validators.password(null), isNotNull);

    // İÇERİK ZORUNLULUĞU YOK: rakam/harf/simge şart değildir.
    expect(Validators.password('a1b2c3d4'), isNull, reason: 'karışık');
    expect(Validators.password('kdmrxzpv'), isNull, reason: 'yalnız harf');
    expect(Validators.password('28407316'), isNull, reason: 'yalnız rakam');
    expect(Validators.password('çğüöşiab'), isNull, reason: 'Türkçe harf');

    // ⚠ ÜST SINIR 64: standart bunun ALTINA inilmemesini ister.
    expect(Validators.password('a' * 63 + 'b'), isNull, reason: '64 sınırda');
    expect(Validators.password('a' * 64 + 'b'), isNotNull, reason: '65 fazla');
    expect(Validators.password('cok-uzun-bir-parolam-2026!'), isNull);

    // ── ZAYIF ŞİFRE REDDİ (iş + güvenlik kuralı) ──
    //
    // ⚠ ÖRNEKLER 8 HANEYE ÇIKARILDI. Eskiden 6 haneliydi; asgari 8
    // olunca uzunluk denetimine takılıp ZAYIFLIK kuralını hiç
    // sınamıyorlardı. Test geçmeye devam ederdi ama YANLIŞ SEBEPLE.
    //
    // ARDIŞIK
    expect(Validators.password('12345678'), isNotNull, reason: 'artan rakam');
    expect(Validators.password('87654321'), isNotNull, reason: 'azalan rakam');
    expect(Validators.password('abcdefgh'), isNotNull, reason: 'artan harf');
    expect(Validators.password('hgfedcba'), isNotNull, reason: 'azalan harf');
    // TEKRAR EDEN
    expect(Validators.password('11111111'), isNotNull);
    expect(Validators.password('aaaaaaaa'), isNotNull);
    // YAYGIN SÖZCÜK — büyük harf ve sondaki rakam kuralı ATLATMAZ
    expect(Validators.password('qwerty'), isNotNull);
    expect(Validators.password('Sifre123'), isNotNull);
    expect(Validators.password('parola!'), isNotNull);
    expect(Validators.password('şifrem'), isNotNull, reason: 'Türkçe yazım');
    expect(Validators.password('01qwerty'), isNotNull, reason: 'baştaki rakam');

    // ⚠ ÜST SINIR ALANDA DEĞİL DOĞRULAYICIDA UYGULANIR.
    //
    // `maxLength` verilseydi kullanıcı 65. karakteri hiç yazamaz,
    // neden yazamadığını da anlamazdı; ayrıca şifre yöneticisinden
    // yapıştırılan uzun şifre SESSİZCE kırpılırdı. Doğrulayıcı ise
    // sebebi yazıyla söyler.
    final r = read('lib/screens/register_screen.dart');
    expect(r.contains('maxLength: kPasswordMaxLength'), isFalse,
        reason: 'şifre alanına maxLength konulmuş — sessiz kırpma riski');
  });

  test('08 — iki göz de ORTAK bileşeni kullanır (aynı renk, aynı davranış)',
      () {
    // ⚠ Test GEVŞETİLMEDİ, GÜÇLENDİRİLDİ.
    //
    // Önceki hâl yalnız rengin iki kez geçtiğine bakıyordu; renkler
    // aynı olsa bile davranışlar farklı olabilirdi. Artık iki alanın
    // da ORTAK `RefSifreGozu` bileşenini kullandığı doğrulanır —
    // renk de davranış da tek yerden gelir, ayrışamaz.
    final r = read('lib/screens/register_screen.dart');
    expect('RefSifreGozu('.allMatches(r).length, 2,
        reason: 'iki şifre alanı da ortak göz bileşenini kullanmalı');
    expect(r.contains('setState(() => _obscure = !_obscure)'), isFalse,
        reason: 'aç/kapa davranışı kalmamalı — basılı tutma kuralı');

    // Ortak bileşen BASILI TUTMA ile çalışır: bırakılınca maskelenir.
    final w = read('lib/ui/ref_widgets.dart');
    expect(w.contains('class RefSifreGozu'), isTrue);
    expect(w.contains('onPointerDown'), isTrue);
    expect(w.contains('onPointerUp'), isTrue);
    expect(w.contains('onPointerCancel'), isTrue,
        reason: 'parmak dışarı kayarsa da maskelenmeli');
  });

  test('09 — zorunlu yıldız tek kırmızı token', () {
    final t = read('lib/ui/ref_tokens.dart');
    expect(t.contains('requiredStar = Color(0xFFFF4D4F)'), isTrue);
    final w = read('lib/ui/ref_widgets.dart');
    expect(w.contains('RC.requiredStar'), isTrue);
  });

  test('10 — OTP backspace zinciri', () {
    final w = read('lib/ui/ref_widgets.dart');
    expect(w.contains('LogicalKeyboardKey.backspace'), isTrue);
    expect(w.contains('onKeyEvent:'), isTrue);
  });

  test('11 — profil fotoğrafı: kamera VE galeri', () {
    // ⚠ SÖZLEŞME DEĞİŞTİ — TEST GEVŞETİLMEDİ.
    //
    // Eskiden avatara dokunmak DOĞRUDAN galeriyi açıyordu ve bu test
    // "kamera olmasın" diye kilitliyordu. Ürün kararı değişti: artık
    // alt panel açılıyor ve kullanıcı seçiyor — Fotoğraf Çek ·
    // Galeriden Yükle · Fotoğrafı Kaldır. Kamera artık BEKLENEN
    // davranıştır.
    final p = read('lib/screens/profile_screen.dart');
    expect(p.contains('ic_cam.svg'), isTrue);
    expect(p.contains('ImageSource.gallery'), isTrue);
    expect(p.contains('ImageSource.camera'), isTrue,
        reason: 'kamera seçeneği kaldırılmış');
    // Seçim panelden gelir; doğrudan galeri açan kısa yol OLMAMALI.
    expect(p.contains('_fotoMenusu(context)'), isTrue);
  });

  test('12 — eksik rol çıkmaz sokak değil (tamamlama TEK SAYFADA)', () {
    // İŞ KURALI AYNI: ikinci rol tanımlı değilse hata verilmez,
    // eksik bilgiler toplanır ve rol aynı hesaba eklenir.
    final repo = read('lib/data/repositories/auth_repository.dart');
    expect(repo.contains('Hesabınızda bu rol tanımlı değil'), isFalse);
    expect(repo.contains('DomainError? addRole('), isTrue);

    // ⚠ AKIŞ TAŞINDI: eskiden profil ekranı panel açıp kullanıcıyı
    // iki ayrı ekrana gönderiyordu (`_eksikRolTamamla`). Artık tek
    // sayfa var: `RoleSwitchScreen`. Test o sayfayı doğrular.
    final p = read('lib/screens/profile_screen.dart');
    expect(p.contains('RoleSwitchScreen'), isTrue,
        reason: 'profil ekranı rol sayfasını açmalı');

    final r = read('lib/screens/role_switch_screen.dart');
    // Eksik bilgiler AYNI sayfada toplanır.
    expect(r.contains('RefMultiSelectSheet'), isTrue,
        reason: 'kategori ve bölge seçimi sayfadan yapılmalı');
    // Rol hesaba eklenir ve aktif role geçilir.
    expect(r.contains('addRole('), isTrue);
    expect(r.contains('switchRole('), isTrue);
    // Eksik bilgi varken geçiş düğmesi PASİFTİR.
    expect(r.contains('onPressed: _hazir ?'), isTrue,
        reason: 'zorunlu bilgiler tamamlanmadan geçilemez');
  });

  test('13 — destek içeriği admin kontrollü, e-posta tıklanabilir', () {
    expect(File('lib/data/models/support_info.dart').existsSync(), isTrue);
    final p = read('lib/screens/profile_screen.dart');
    // İçerik SUNUCUDAN gelir (admin yönetir), koda gömülü değildir.
    expect(p.contains('SupportInfo'), isTrue);
    // Adres gerçekten e-posta uygulamasını açar.
    expect(p.contains("scheme: 'mailto'"), isTrue);

    // ⚠ GÖRSEL KARAR DEĞİŞTİ: altı çizili düz bağlantı yerine
    // KENDİ KUTUSUNDA, ikonlu ve dokunulabilir bir alan kullanılır —
    // düz metinde tıklanabilir olduğu anlaşılmıyordu.
    //
    // Test tıklanabilirliği ARAR, biçimi dayatmaz.
    expect(p.contains('_mailAc(c, bilgi.email)'), isTrue,
        reason: 'adres dokunulabilir olmalı');
    expect(p.contains('RefTap('), isTrue);
  });

  test('14 — puanlama hata metni yok, mock çalışır', () {
    final a = read('lib/screens/app_rate_screen.dart');
    expect(a.contains('Değerlendirme bilgisi yüklenemedi'), isFalse);
    expect(a.contains('ApiConfig.useRealApi'), isTrue);
  });

  test('15 — Ad ve Soyad ayrı alanlar', () {
    final p = read('lib/screens/profile_info_screen.dart');
    expect(p.contains("hint: 'Ad'"), isTrue);
    expect(p.contains("hint: 'Soyad'"), isTrue);
    expect(p.contains("hint: 'Ad Soyad'"), isFalse,
        reason: 'ad ve soyad tek alana birleştirilmiş');
  });

  // ══════════════════════════════════════════════════════════════
  // SEÇİM KUTUCUKLARI VE ÇOK RENKLİ İKONLAR
  //
  // Gerçek cihazda görülen iki hata:
  //   1) Kategori/ilçe seçiminde kutucuk yerine 2×2 ızgara ikonu
  //      (`ic_grid.svg`) çiziliyordu.
  //   2) Kendi renklerini taşıyan ikonlara (`ic_x`, `ic_info`) renk
  //      filtresi uygulanınca tüm çizim tek renge boyanıp DOLU LEKE
  //      hâline geliyordu.
  // ══════════════════════════════════════════════════════════════
  group('Seçim kutucukları ve ikon renkleri', () {
    final w = read('lib/ui/ref_widgets.dart');

    test('gerçek onay kutusu çizilir (ızgara ikonu DEĞİL)', () {
      expect(w.contains('class RefCheckBox'), isTrue);
      // Referans `.rg-cb` ölçüleri.
      expect(w.contains('Color(0xFFC7CEDA)'), isTrue,
          reason: 'seçilmemiş kenarlık rengi');
      // Seçim satırında ızgara ikonu KULLANILMAZ.
      final satir = w.substring(w.indexOf('class RefCheckRow'));
      expect(satir.bastan(2200).contains('ic_grid'), isFalse);
    });

    test('kutucuk seçim satırının SAĞINDA', () {
      final satir = w.substring(w.indexOf('class RefCheckRow'));
      final govde = satir.bastan(2200);
      final iExpanded = govde.indexOf('Expanded(');
      final iKutu = govde.indexOf('RefCheckBox(');
      expect(iExpanded, greaterThan(0));
      expect(iKutu, greaterThan(iExpanded),
          reason: 'checkbox metinden SONRA gelmeli');
    });

    test('hiçbir ekranda ızgara ikonu kutucuk olarak kullanılmaz', () {
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final c = f.readAsStringSync();
        expect(
            RegExp(r"\? 'assets/svg/ic_checkc\.svg'[\s\S]{0,80}ic_grid")
                .hasMatch(c),
            isFalse,
            reason: '${f.path}: kutucuk yerine ızgara ikonu');
      }
    });

    test('kendi rengi olan ikonlara renk filtresi UYGULANMAZ', () {
      // Dolu daire + beyaz simge içeren ikonlar.
      const lekeRiski = ['ic_x.svg', 'ic_info.svg'];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final c = f.readAsStringSync();
        for (final ikon in lekeRiski) {
          final re = RegExp("RefSvg\\(\\s*'assets/svg/$ikon'[^)]{0,120}?color:");
          expect(re.hasMatch(c), isFalse,
              reason: '${f.path}: $ikon renk filtresiyle leke olur');
        }
      }
    });

    test('beyaz şekilli hediye ikonu MAVİ zemin üzerinde', () {
      final i = wl.indexOf('ic_gift.svg');
      expect(i, greaterThan(0));
      // Zemin mavi, ikon beyaz olmalı.
      expect(wl.substring(i - 400, i).contains('color: RC.blue'), isTrue,
          reason: 'hediye ikonu zemini mavi olmalı');
      expect(wl.pencere(i, 120).contains('RC.white'), isTrue);
    });
  });
}
