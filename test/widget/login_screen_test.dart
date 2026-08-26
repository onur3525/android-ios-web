import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/route_guard.dart';
import 'package:hizmetcep/core/theme.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/screens/login_screen.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';
import 'package:provider/provider.dart';
import '../support/test_config.dart';

/// YALNIZ BU DOSYAYA ÖZEL — gecikmeli giriş portu.
///
/// `MockAuthPort.login()` anında tamamlanır; widget testi 100 ms sonra
/// baktığında yükleniyor göstergesi çoktan kaybolmuş olur. Gerçek
/// kullanımda giriş bir ağ turu sürer.
///
/// Bu sarmalayıcı YALNIZCA gecikme ekler — kimlik doğrulama, hata
/// üretimi ve oturum davranışı `MockAuthPort`'un kendisine aittir.
/// Global mock DEĞİŞTİRİLMEZ; diğer testler etkilenmez.
class _GecikmeliAuthPort extends MockAuthPort {
  _GecikmeliAuthPort(super.repo);

  /// Bir ağ turu kadar. Testler 100 ms'de yükleniyor durumunu görebilir,
  /// 700 ms'de sonuç oluşmuş olur.
  static const gecikme = Duration(milliseconds: 300);

  /// Kaç kez giriş denendi — çift tıklamanın tek giriş ürettiğini
  /// doğrulamak için.
  int loginCagriSayisi = 0;

  @override
  Future<DomainError?> girisEposta(String email, String pass) async {
    loginCagriSayisi++;
    await Future<void>.delayed(gecikme);
    return super.girisEposta(email, pass);
  }
}

void main() {

  late AuthRepository authRepo;
  late _GecikmeliAuthPort authPort;

  /// GERÇEK ROUTE HARİTASI + GERÇEK RoleGuard
  ///
  /// Başarılı giriş `/customer/listings` veya `/provider/jobs`
  /// route'una yönlenir.
  ///
  /// ⚠ Hedefler `RoleGuard` ile SARILIDIR — üretimdeki zincirin
  /// aynısı. Telefonda görülen "giriş başarılı ama ekran değişmiyor"
  /// sorununun bir olasılığı guard'ın kullanıcıyı sessizce `/login`'e
  /// geri göndermesiydi; bu test onu kapatır.
  ///
  /// `MyListingsScreen`/`JobsScreen` çok sayıda controller'a bağlı
  /// olduğundan guard'ın `builder`'ında kimliklenebilir yalın bir
  /// widget çizilir. Guard'ın KENDİSİ zincirdedir.
  Widget app() {
    authRepo = AuthRepository();
    authPort = _GecikmeliAuthPort(authRepo);
    // Controller port üzerinden bağlanır (uygulamadaki DI ile aynı).
    return ChangeNotifierProvider(
      create: (_) => AuthController(authPort),
      child: MaterialApp(
        theme: HC.theme(),
        home: const LoginScreen(),
        routes: {
          // Üretimdeki kayıtla AYNI guard sarmalayıcısı.
          '/customer/listings': (_) => RoleGuard.customer(
                builder: (_) => const Scaffold(
                    body: Center(child: Text('MUSTERI_PANELI'))),
              ),
          '/provider/jobs': (_) => RoleGuard.provider(
                builder: (_) => const Scaffold(
                    body: Center(child: Text('SAGLAYICI_PANELI'))),
              ),
          '/login': (_) => const LoginScreen(),
          '/role': (_) =>
              const Scaffold(body: Center(child: Text('ROL_SECIMI'))),
        },
      ),
    );
  }

  /// Provider rolünde demo hesap üretir.
  ///
  /// `AuthRepository` yalnız CUSTOMER rollü tek test hesabı tohumlar
  /// (`5321112233`). Provider yolu için üretim kodundaki gerçek kayıt
  /// akışı kullanılır — fixture'a yeni ürün verisi EKLENMEZ.
  /// ⚠ FIXTURE E-POSTA VERİR.
  ///
  /// Şifreli giriş artık E-POSTA iledir; hesap e-postasız kurulursa
  /// `findByEmail` onu bulamaz ve giriş "kimlik hatalı" ile düşer.
  /// Bu bir yönlendirme hatası DEĞİL, eksik fixture'dı.
  ///
  /// Hesap PROVIDER-ONLY kurulur: tek rol, aktif rol provider.
  ({String email, String pass, Account account}) providerHesabiOlustur() {
    const phone = '5335556677';
    const email = 'saglayici@example.com';
    const pass = '123456';
    final r = authRepo.register(
      phone: phone, pass: pass, email: email,
      role: Role.provider, otpVerified: true, termsAccepted: true,
      name: 'Test Saglayici',
    );
    expect(r.error, isNull, reason: 'provider hesabı oluşturulamadı');
    final a = r.account!;
    // ⚠ TEŞHİS: hesabın rol sözleşmesi burada kilitlenir.
    expect(a.roles, {Role.provider}, reason: 'fixture çift rollü kurulmuş');
    expect(a.activeRole, Role.provider, reason: 'aktif rol provider değil');
    // Kayıt oturum açar; giriş testinden önce oturum kapatılır.
    authRepo.logout();
    expect(authRepo.currentAccount, isNull);
    return (email: email, pass: pass, account: a);
  }

  /// ⚠ EKRAN İKİ GİRİŞ YOLUNA AYRILDI.
  ///
  /// Varsayılan mod E-POSTA'dır: alanlar e-posta + şifre. Telefon
  /// artık şifreyle DEĞİL, SMS ile giriş yapar; o akış ayrı
  /// dosyalarda (challenge davranış testleri) kanıtlanıyor.
  ///
  /// Bu yüzden yardımcı telefon değil E-POSTA doldurur.
  /// ⚠ VARSAYILAN AÇILIŞ TELEFON FORMU.
  ///
  /// İki sekme tek geçiş düğmesine indirildi ve ekran telefon
  /// formuyla açılıyor. E-postayla ilgili testler önce buradan
  /// geçmek zorunda.
  Future<void> epostaModunaGec(WidgetTester t) async {
    final gecis = find.text('E-posta ile Giriş');
    expect(gecis, findsOneWidget, reason: 'geçiş düğmesi bulunamadı');
    await t.ensureVisible(gecis);
    await t.pump();
    await t.tap(gecis);
    await t.pump();
  }

  Future<void> doldur(WidgetTester t, String email, String pass) async {
    await epostaModunaGec(t);
    await t.enterText(find.byType(TextFormField).at(0), email);
    await t.enterText(find.byType(TextFormField).at(1), pass);
  }

  /// GİRİŞ DÜĞMESİNE GERÇEKTEN DOKUNUR.
  ///
  /// ⚠ TEST YÜZEYİ 800×600, LOGIN İÇERİĞİ DAHA UZUN.
  ///
  /// "Giriş Yap" düğmesinin merkezi Offset(400, 633.5)'e düşüyor ve
  /// kök render ağacının DIŞINDA kalıyor; `tap` hiç işlenmiyordu.
  /// Ardından loading, doğrulama ve yönlendirme iddiaları ZİNCİRLEME
  /// düşüyordu — hiçbiri gerçek bir davranış hatası değildi.
  ///
  /// ⚠ `warnIfMissed: false` ÇÖZÜM DEĞİLDİR: uyarıyı susturur ama
  /// dokunuş yine işlenmez. Düğme gerçek kullanıcı gibi görünür
  /// alana kaydırılır.
  ///
  /// ⚠ PRODUCTION UI DEĞİŞTİRİLMEDİ. Sorun testin yüzeyinde.
  Future<void> dugmeyeBas(WidgetTester t, String etiket) async {
    final dugme = find.widgetWithText(RefPrimaryButton, etiket);
    expect(dugme, findsOneWidget, reason: '$etiket düğmesi bulunamadı');
    await t.ensureVisible(dugme);
    // ⚠ `pumpAndSettle` DEĞİL, tek `pump`.
    //
    // `ensureVisible` kaydırmayı ANINDA yapar (süre sıfır), tek kare
    // yeter. `pumpAndSettle` ise sürmekte olan bir istek varken
    // yükleniyor çemberi durmadığı için ZAMAN AŞIMINA düşer —
    // çift tıklama testinde ikinci dokunuş bu yüzden atılamazdı.
    await t.pump();
    // ⚠ Görünür alana girdi mi? Girmediyse dokunuş yine kaybolur.
    final merkez = t.getCenter(dugme);
    expect(merkez.dy, lessThan(600),
        reason: '$etiket hâlâ yüzey dışında: $merkez');
    await t.tap(dugme);
  }

  /// Giriş düğmesi (e-posta modu).
  Future<void> girisYap(WidgetTester t) => dugmeyeBas(t, 'Giriş Yap');

  /// Google sheet'ini açar.
  ///
  /// ⚠ DOĞRUDAN `tap` YAPILMAZ.
  ///
  /// Widget testinin kök yüzeyi 800×600'dür. Login içeriği bundan
  /// uzundur; "Google ile Devam Et" düğmesinin merkezi Y≈619'a düşer
  /// ve hit-test kök ağacın DIŞINDA kalır:
  ///
  ///   Warning: Offset(400.0, 619.0) is outside the bounds of the
  ///   root of the render tree, Size(800.0, 600.0).
  ///
  /// Bu durumda dokunuş hiç işlenmez, sheet açılmaz ve ardındaki
  /// içerik/animasyon doğrulamaları ikincil olarak başarısız olur.
  ///
  /// `ensureVisible` düğmeyi gerçek kullanıcı gibi görünür alana
  /// kaydırır; ardından dokunuş güvenle işlenir.
  ///
  /// Tap sonrası YALNIZ tek `pump` yapılır — animasyon başlar ama
  /// tamamlanmaz; açılış testi ara kareleri ölçebilsin diye.
  Future<void> sheetAc(WidgetTester t) async {
    final dugme =
        find.widgetWithText(RefSecondaryButton, 'Google ile Devam Et');
    await t.ensureVisible(dugme);
    await t.pumpAndSettle();      // kaydırma otursun
    await t.tap(dugme);
    await t.pump();               // rota başlasın (animasyon SÜRÜYOR)
  }

  /// Ana giriş düğmesi — referans `.rg-primary` karşılığı.
  ///
  /// Ekran Material `ElevatedButton` yerine `RefPrimaryButton`
  /// kullanır (nihai HTML'de özel gradyanlı düğme vardır).
  RefPrimaryButton buton(WidgetTester t) =>
      t.widget<RefPrimaryButton>(find.byType(RefPrimaryButton));

  testWidgets('yanlış kimlik: loading sonrası alan-altı genel hata, giriş yok',
      (t) async {
    await t.pumpWidget(app());
    await doldur(t, kTestEmail, 'yanlis99');
    await girisYap(t);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget); // loading
    await t.pump(const Duration(milliseconds: 700));
    // ⚠ HATA ARTIK FORM DÜZEYİNDE, alan altında DEĞİL: iş kuralı
    // hatası hangi alanın yanlış olduğunu söylemez ve validator'a
    // enjekte edilmez. Metin aynı, yeri değişti.
    expect(find.text('Telefon numarası veya şifre hatalı'), findsOneWidget);
    expect(authRepo.loggedIn, isFalse);
    expect(buton(t).onPressed, isNotNull); // buton serbest kaldı
  });

  testWidgets('TELEFON MODU: telefon + ŞİFRE ile giriş', (t) async {
    // ⚠ KARAR GÜNCELLENDİ: kayıtlı kullanıcı her iki kimlikle de
    // ŞİFRESİYLE girer. SMS OTP giriş anahtarı değildir.
    await t.pumpWidget(app());
    await t.pump();

    // ⚠ VARSAYILAN AÇILIŞ TELEFON FORMU — geçiş gerekmez.
    // Geçiş düğmesi ÖTEKİ yolu gösterir.
    expect(find.text('E-posta ile Giriş'), findsOneWidget);
    expect(find.text('Telefon ile Giriş'), findsNothing,
        reason: 'bulunulan yol düğmede yazmamalı');

    // İki alan: telefon + şifre. Düğme metni yine "Giriş Yap".
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(RefPrimaryButton, 'Giriş Yap'), findsOneWidget);
    expect(find.text('Doğrulama Kodu Gönder'), findsNothing);

    // Zorunlu alanlar boşken düğme PASİF, uyarı da YOK.
    expect(buton(t).onPressed, isNull);
    expect(find.text('Bu alan zorunludur'), findsNothing);

    // Doldurunca giriş yapılır.
    await t.enterText(find.byType(TextFormField).at(0), '05321112233');
    await t.enterText(find.byType(TextFormField).at(1), kTestPass);
    await t.pump();
    await girisYap(t);
    await t.pump(const Duration(milliseconds: 700));
    expect(authRepo.loggedIn, isTrue);
  });

  testWidgets('boş alanlar: UYARI YOK, düğme PASİF, istek atılmaz', (t) async {
    // ⚠ SÖZLEŞME DEĞİŞTİ — DAHA SIKI HÂLE GELDİ.
    //
    // Eskiden boş formla düğmeye basılabiliyor ve alan altında
    // "Bu alan zorunludur" çıkıyordu. Yeni kural: boş alanda
    // KATİYEN uyarı gösterilmez; bunun yerine düğme zaten PASİFTİR,
    // dolayısıyla gönderim hiç denenemez.
    await t.pumpWidget(app());
    await t.pump();

    // 1) Hiçbir uyarı yok.
    expect(find.text('Bu alan zorunludur'), findsNothing);

    // 2) Düğme pasif — basılamaz.
    expect(buton(t).onPressed, isNull, reason: 'boş formda düğme aktif');

    // 3) Dokunuş bir istek üretmez.
    await t.tap(find.byType(RefPrimaryButton));
    await t.pump();
    expect(authPort.loginCagriSayisi, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Bu alan zorunludur'), findsNothing);
  });

  testWidgets('loading sırasında ikinci giriş isteği OLUŞMAZ', (t) async {
    // ⚠ ASIL KABUL KRİTERİ: ikinci auth çağrısının oluşmaması.
    // "Butonda hâlâ 'Giriş Yap' yazıyor mu" DEĞİL.
    //
    // `RefPrimaryButton` yükleniyorken metni SPINNER ile değiştirir;
    // bu yüzden metne bağlı finder loading sırasında 0 widget bulur.
    // İkinci etkileşim TÜRE bağlı finder ile yapılır.
    await t.pumpWidget(app());
    await doldur(t, kTestEmail, kTestPass);

    // Tekil submit kontrolü — loading'den ÖNCE yakalanır.
    final submit = find.byType(RefPrimaryButton);
    expect(submit, findsOneWidget, reason: 'submit kontrolü tekil değil');

    await girisYap(t);
    await t.pump(const Duration(milliseconds: 100));

    // 1) Yükleniyor durumu ve düğme KİLİTLİ.
    expect(buton(t).busy, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Metin yerine spinner çizildiği için metinli finder boş döner —
    // beklenen davranış budur.
    expect(find.widgetWithText(RefPrimaryButton, 'Giriş Yap'), findsNothing);

    // 2) İkinci kullanıcı etkileşimi — GERÇEK dokunuş, türe bağlı.
    await t.ensureVisible(submit);
    await t.pump();
    expect(t.getCenter(submit).dy, lessThan(600));
    await t.tap(submit);
    await t.pump();

    // 3) İkinci auth çağrısı OLUŞMADI.
    expect(authPort.loginCagriSayisi, 1,
        reason: 'loading sırasında ikinci istek gitti');

    await t.pump(const Duration(milliseconds: 700));
    expect(authRepo.loggedIn, isTrue);
    expect(authPort.loginCagriSayisi, 1);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Hoş geldiniz'), findsOneWidget);
  });

  // ═════════════════════════════════════════════════════════════
  // NAVİGASYON — kullanıcıya görünen SONUÇ doğrulanır.
  //
  // `loggedIn` gibi state kontrolü tek başına yeterli değildir:
  // önceki APK'da state doğruydu ama ekran değişmiyordu
  // (`Navigator.maybePop()` yığın boşken hiçbir şey yapmıyordu).
  // ═════════════════════════════════════════════════════════════

  testWidgets('CUSTOMER başarılı giriş → /customer/listings açılır', (t) async {
    await t.pumpWidget(app());
    await doldur(t, kTestEmail, kTestPass);
    await girisYap(t);
    await t.pumpAndSettle();

    // 1) Oturum açıldı, aktif rol customer.
    expect(authRepo.loggedIn, isTrue);
    expect(authRepo.activeRole, Role.customer);
    expect(authPort.loginCagriSayisi, 1);

    // 2) RoleGuard zincirdedir ve kullanıcıyı GEÇİRDİ.
    expect(find.byType(RoleGuard), findsOneWidget,
        reason: 'RoleGuard zincirde değil');
    expect(find.text('MUSTERI_PANELI'), findsOneWidget,
        reason: 'guard ekranı çizmedi / müşteri paneline geçilmedi');

    // 3) Guard kullanıcıyı sessizce /login'e geri GÖNDERMEDİ.
    expect(find.byType(LoginScreen), findsNothing,
        reason: 'LoginScreen ekranda kaldı (guard geri göndermiş olabilir)');
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'guard oturumsuz sanıp bekleme göstergesi çizdi');
  });

  testWidgets('CUSTOMER giriş sonrası GERİ tuşu Login\'e döndürmez', (t) async {
    await t.pumpWidget(app());
    await doldur(t, kTestEmail, kTestPass);
    await girisYap(t);
    await t.pumpAndSettle();
    expect(find.text('MUSTERI_PANELI'), findsOneWidget);

    // Yığın kökünde olunmalı: geri dönülecek sayfa KALMAMALI.
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    expect(nav.canPop(), isFalse,
        reason: 'yığında geri dönülecek sayfa kalmış');

    // Geri denemesi Login'i geri getirmemeli.
    await nav.maybePop();
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing,
        reason: 'geri tuşuyla Login ekranına dönüldü');
    expect(find.text('MUSTERI_PANELI'), findsOneWidget);
  });

  testWidgets('PROVIDER başarılı giriş → /provider/jobs açılır', (t) async {
    await t.pumpWidget(app());
    final p = providerHesabiOlustur();
    await doldur(t, p.email, p.pass);
    await girisYap(t);
    await t.pumpAndSettle();

    // 1) Oturum açıldı, AYNI hesap, aktif rol provider.
    expect(authRepo.loggedIn, isTrue);
    expect(authRepo.currentAccount!.id, p.account.id,
        reason: 'başka hesapla giriş yapıldı');
    expect(authRepo.currentAccount!.roles, {Role.provider});
    expect(authRepo.activeRole, Role.provider);
    expect(authPort.loginCagriSayisi, 1);

    // ⚠ YÖNLENDİRME KURALI: `_girisSonrasiYonlendir` aktif role
    // bakar — provider ise `/provider/jobs`, değilse
    // `/customer/listings`. Hesap provider-only ve aktif rolü
    // provider olduğu için beklenen hedef `/provider/jobs`.

    // 2) RoleGuard.provider zincirdedir ve kullanıcıyı GEÇİRDİ.
    expect(find.byType(RoleGuard), findsOneWidget,
        reason: 'RoleGuard zincirde değil');
    expect(find.text('SAGLAYICI_PANELI'), findsOneWidget,
        reason: 'guard ekranı çizmedi / hizmet veren paneline geçilmedi');

    // 3) Yanlış panele düşmedi, Login'de kalmadı.
    expect(find.text('MUSTERI_PANELI'), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Bu ekrana erişiminiz yok'), findsNothing,
        reason: 'guard rolü yanlış değerlendirdi');
  });

  testWidgets('YANLIŞ kimlik: route DEĞİŞMEZ, Login ekranda kalır', (t) async {
    await t.pumpWidget(app());
    await doldur(t, kTestEmail, 'yanlis99');
    await girisYap(t);
    await t.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('MUSTERI_PANELI'), findsNothing);
    expect(find.text('SAGLAYICI_PANELI'), findsNothing);
  });

  // ═════════════════════════════════════════════════════════════
  // GOOGLE SHEET — referans `googleSheet()` içeriği
  // ═════════════════════════════════════════════════════════════

  testWidgets('Google sheet referans içeriğini gösterir', (t) async {
    await t.pumpWidget(app());
    await sheetAc(t);
    await t.pumpAndSettle(); // içerik testi: animasyon tamamlansın

    // 1) ÖNCE sheet'in gerçekten açıldığı kanıtlanır.
    //    Aynı metnin ana düğmede de bulunması tek başına kanıt DEĞİLDİR.
    expect(find.byType(RefBottomSheet), findsOneWidget,
        reason: 'sheet açılmadı');

    // 2) Başlık, RefBottomSheet BAĞLAMINDA doğrulanır.
    expect(
      find.descendant(
        of: find.byType(RefBottomSheet),
        matching: find.text('Google ile Devam Et'),
      ),
      findsOneWidget,
      reason: 'sheet başlığı yok',
    );

    // 3) Referans içeriği.
    expect(find.text('Devam etmek için bir hesap seçin'), findsOneWidget);
    expect(find.text('Onur Bütün'), findsOneWidget);
    expect(find.text('onur@butunmuhendislik.com.tr'), findsOneWidget);
    expect(find.text('Başka bir hesap kullan'), findsOneWidget);
  });

  // ═════════════════════════════════════════════════════════════
  // ASSET — Login'in kullandığı her SVG gerçek dosyaya çözülmeli
  // ═════════════════════════════════════════════════════════════

  test('Login SVG yolları gerçek dosyaya çözülür', () {
    final src = File('lib/screens/login_screen.dart').readAsStringSync();
    final yollar = RegExp(r"'(assets/[^']+\.svg)'")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toSet();
    expect(yollar, isNotEmpty, reason: 'login hiç SVG kullanmıyor?');
    for (final y in yollar) {
      expect(File(y).existsSync(), isTrue, reason: 'eksik asset: $y');
    }
  });

  // ═════════════════════════════════════════════════════════════
  // SHEET ANİMASYON ZAMANLAMASI
  //
  // Referans:
  //   .rg-ov    opacity   .22s
  //   .rg-sheet transform .26s cubic-bezier(.2,.8,.2,1)
  // ═════════════════════════════════════════════════════════════

  /// Perdenin (`.rg-ov`) o anki opaklığı.
  ///
  /// ⚠ `find.byType(FadeTransition).first` KULLANILMAZ: ağaçta
  /// MaterialApp'in sayfa geçişinden gelen başka `FadeTransition`'lar
  /// da bulunur ve sıralama garanti değildir — bu yüzden perde
  /// `RefBottomSheet.perdeKey` anahtarıyla aranır.
  double perdeOpakligi(WidgetTester t) => t
      .widget<FadeTransition>(find.byKey(RefBottomSheet.perdeKey))
      .opacity
      .value;

  testWidgets('sheet AÇILIŞI: perde 220 ms, panel 260 ms', (t) async {
    await t.pumpWidget(app());
    await sheetAc(t); // tap + tek pump → animasyon BAŞLADI

    await t.pump(const Duration(milliseconds: 110)); // ~yarı yol
    final yari = perdeOpakligi(t);
    expect(yari, greaterThan(0.30), reason: 'perde açılışta ilerlemedi');
    expect(yari, lessThan(0.90), reason: 'perde çok erken doldu');

    // 220 ms → perde tamamlanmış olmalı (panel henüz sürüyor).
    await t.pump(const Duration(milliseconds: 115));
    expect(perdeOpakligi(t), closeTo(1.0, 0.05),
        reason: 'perde 220 ms icinde tamamlanmadi');

    await t.pumpAndSettle();
    expect(find.byType(RefBottomSheet), findsOneWidget);
  });

  testWidgets('sheet KAPANIŞI: perde GECİKMESİZ sönmeye başlar', (t) async {
    await t.pumpWidget(app());
    await sheetAc(t);
    await t.pumpAndSettle();
    expect(perdeOpakligi(t), closeTo(1.0, 0.02));

    // ── KAPANIŞI BAŞLAT ──
    //
    // ⚠ `maybePop()` KULLANILMAZ: ASENKRONDUR.
    //   Future<bool> maybePop() async {
    //     final disposition = await route.willPop();   ← microtask turu
    //     ...
    //     pop(result);
    //   }
    // Çağrı döndüğünde pop henüz gerçekleşmemiştir; reverse animasyonu
    // bir sonraki pump içinde başlar ve ölçüm karesi kayar
    // (elapsed 0 → opacity 1.0 okunur).
    //
    // `pop()` SENKRONDUR: entry.pop() → route.didPop() →
    // `_controller.reverse()`. Çağrı döndüğünde status == reverse,
    // value == 1.0 olur; başlangıç karesi kesinleşir.
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();

    // Reverse'ün BAŞLANGIÇ karesi (elapsed 0) — perde hâlâ tam opak.
    await t.pump();
    expect(perdeOpakligi(t), closeTo(1.0, 0.02),
        reason: 'reverse başlangıç karesi beklenen durumda değil');

    // İlk 40 ms — eski `Interval` kullanımında perde SABİT kalıyordu.
    // `flipped` ile ilk andan itibaren azalmalı.
    await t.pump(const Duration(milliseconds: 40));
    expect(perdeOpakligi(t), lessThan(0.95),
        reason: 'perde kapanista ilk 40 ms sabit kaldi (flipped yok)');

    // 220 ms → perde sönmüş olmalı.
    await t.pump(const Duration(milliseconds: 185));
    expect(perdeOpakligi(t), closeTo(0.0, 0.05),
        reason: 'perde 220 ms icinde sonmedi');

    await t.pumpAndSettle();
    expect(find.byType(RefBottomSheet), findsNothing);
  });
}
