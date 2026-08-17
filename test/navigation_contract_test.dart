import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// NAVİGASYON SÖZLEŞMESİ — nihai HTML ile kaynak düzeyi doğrulama.
///
/// Referans: `hizmetcep-v66-final__1_.html`
///
/// Widget testi koşulamayan geçişler için sözleşme, kaynak metin
/// üzerinden sabitlenir. Amaç: HTML'de bulunmayan koşullu davranışların
/// sessizce geri gelmesini engellemek.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('HOME — HTML davranış sözleşmesi', () {
    final home = read('lib/screens/home_screen.dart');

    // HTML: <button class="hd-r tap" onclick="openLogin()">
    // Koşulsuz; oturum durumuna göre ikon veya hedef DEĞİŞMEZ.
    test('profil ikonu KOŞULSUZ /login açar', () {
      expect(home.contains("pushNamed(context, '/login')"), isTrue);
    });

    // ── HOME GÖRÜNÜR DÜZENİ OTURUMA GÖRE DALLANMAZ ──
    //
    // ESKİ beklenti: `home_screen.dart` DOSYASININ TAMAMINDA
    // `loggedIn` / `auth.` geçmemesi.
    //
    // Bu beklenti yeni ürün akışıyla ÇELİŞİYOR: ana sayfadaki inline
    // arama, öneriye dokunulduğunda kullanıcıyı ilan formuna
    // yönlendirir ve bu yönlendirme rol sözleşmesine UYMAK ZORUNDADIR
    // (müşteri rolü varsa korumalı form, yoksa public taslak formu).
    // Yani Home artık bir EYLEM başlatıyor; eylem hedefi role bağlı.
    //
    // Korunan asıl kural DEĞİŞMEDİ: Home'un GÖRÜNÜR DÜZENİ (başlık,
    // ikon, kartlar, metinler) oturum durumuna göre değişmez.
    // Bu yüzden kontrol, eylem yönlendiricisi `_hizmetSecildi`
    // gövdesi HARİÇ tutularak yapılır.
    test('Home GÖRÜNÜR DÜZENİ oturum durumuna göre dallanmaz', () {
      // Yorumlar çıkarılır.
      var kod = home
          .split('\n')
          .where((l) =>
              !l.trimLeft().startsWith('//') &&
              !l.trimLeft().startsWith('///'))
          .join('\n');

      // Eylem yönlendiricisi gövdesi çıkarılır (süslü parantez dengesi).
      final i = kod.indexOf('void _hizmetSecildi');
      expect(i, greaterThan(0),
          reason: 'arama önerisi yönlendiricisi bulunamadı');
      final acilis = kod.indexOf('{', i);
      var derinlik = 0;
      var kapanis = acilis;
      for (var k = acilis; k < kod.length; k++) {
        if (kod[k] == '{') {
          derinlik++;
        } else if (kod[k] == '}') {
          derinlik--;
          if (derinlik == 0) {
            kapanis = k;
            break;
          }
        }
      }
      expect(kapanis, greaterThan(acilis), reason: 'gövde çıkarılamadı');
      kod = kod.replaceRange(i, kapanis + 1, '');

      // Görünür düzende oturum kontrolü OLMAMALI.
      expect(kod.contains('loggedIn'), isFalse,
          reason: 'Home görünür düzeni oturum kontrolü içeremez');
      expect(kod.contains('auth.'), isFalse,
          reason: 'Home görünür düzeni AuthController\'a bağlanamaz');
    });

    // Yönlendirici, rol sözleşmesine UYMAK ZORUNDADIR.
    test('arama önerisi yönlendiricisi rol sözleşmesine uyar', () {
      final i = home.indexOf('void _hizmetSecildi');
      expect(i, greaterThan(0));
      final govde = home.substring(i, i + 1200);
      // Müşteri rolü varsa korumalı form; yoksa public taslak formu.
      expect(govde.contains('roles.contains(Role.customer)'), isTrue);
      expect(govde.contains('PreLoginListingRoute.name'), isTrue);
      // Rol seçim ekranı bu akışta AÇILMAZ.
      expect(govde.contains('RoleSelectScreen'), isFalse);
    });

    test('Home bildirim düğmesi İÇERMEZ', () {
      // HTML vHome() içinde bildirim ikonu yoktur; bildirimlere
      // alt navigasyondan gidilir.
      expect(home.contains('NotificationButton'), isFalse);
      expect(home.contains('NotificationController'), isFalse);
    });

    // HTML: data-act="register" data-arg="customer" | "provider"
    test('rol kartları KOŞULSUZ kayıt akışına gider', () {
      expect(home.contains('startRegister(context, Role.customer)'), isTrue);
      expect(home.contains('startRegister(context, Role.provider)'), isTrue);
      // Panel ekranlarına doğrudan yönlendirme YOK.
      expect(home.contains('MyListingsScreen'), isFalse);
      expect(home.contains('JobsScreen'), isFalse);
    });
  });

  group('SPLASH — boot sözleşmesi (BOOT-01)', () {
    final splash = read('lib/screens/splash_screen.dart');

    // ── TEK GÖRÜNÜR SPLASH (nihai mimari) ──
    //
    // ESKİ: Flutter splash 1400 ms görünürdü; native açılış ekranı
    // ondan ÖNCE ayrı bir yüzey olarak çiziliyordu (iki splash).
    //
    // YENİ: kullanıcıya gösterilen TEK splash ANDROID NATIVE
    // splash'tır. En kısa süre (2000 ms) native tarafta yönetilir;
    // Flutter ikinci bir splash ÇİZMEZ.
    test('Flutter ikinci splash ÇİZMEZ (marka öğesi yok)', () {
      // Logo/animasyon çizilirse kullanıcı ikinci splash görür.
      expect(splash.contains('AssetImage'), isFalse,
          reason: 'Flutter splash yüzeyinde logo olmamalı');
      expect(splash.contains('ScaleTransition'), isFalse,
          reason: 'logo sıçraması olmamalı');
      expect(splash.contains('milliseconds: 1400'), isFalse,
          reason: 'süre artık native tarafta');
    });

    test('en kısa splash süresi NATIVE tarafta (2000 ms)', () {
      final main = File(
              'android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt')
          .readAsStringSync();
      // ⚠ Süre KISALTILDI: Android 12+ splash API'si uzun tutulan
      // splash'ta ikonu gizler ve beyaz ekran bırakır.
      // ⚠ Marka süresini NATIVE katman yönetir (tek splash).
      expect(main.contains('SPLASH_MIN_MS = 2000L'), isTrue);
      expect(main.contains('setKeepOnScreenCondition'), isTrue);
      // UI thread bloklanmamalı.
      expect(main.contains('Thread.sleep('), isFalse);
    });

    test('Dart açılış kararını native\'e bildirir', () {
      expect(splash.contains('NativeSplash.bootReady()'), isTrue);
    });

    test('splash yığından silinir (geri dönülemez)', () {
      expect(splash.contains('pushReplacementNamed'), isTrue);
    });

    test('oturum varken de Home hedefi korunur', () {
      expect(splash.contains("pushReplacementNamed('/home')"), isTrue);
    });
  });

  group('LOGIN — giriş sonrası yönlendirme', () {
    final login = read('lib/screens/login_screen.dart');

    test('maybePop KULLANILMAZ (yığın boşsa hiçbir şey yapmaz)', () {
      expect(login.contains('maybePop(); // ana sayfa'), isFalse);
    });

    test('rol duyarlı panel hedefi', () {
      expect(login.contains("'/provider/jobs'"), isTrue);
      expect(login.contains("'/customer/listings'"), isTrue);
      expect(login.contains('pushNamedAndRemoveUntil'), isTrue);
    });
  });

  group('ROUTE tablosu — HTML hedeflerinin karşılığı', () {
    final main = read('lib/main.dart');

    test('temel route\'lar tanımlı', () {
      for (final r in [
        '/home', '/login', '/role',
        '/customer/listings', '/provider/jobs',
        '/provider/status', '/provider/wallet',
      ]) {
        expect(main.contains("'$r'"), isTrue, reason: r);
      }
    });
  });
}
