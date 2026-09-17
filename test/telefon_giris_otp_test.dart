// TELEFONLA GİRİŞ — OTP AKIŞI KANITI
//
// İDDİA: `OtpPurpose.login` akışı YALNIZ "6 hane girildi mi" diye
// bakıp giriş yapmaz; sonucu `girisTelefonDogrula` belirler.
//
// Bu, kayıtsız ilan akışında bir kez gerçekten yaşanmış bir hataydı
// (SEC-01): kod hiç doğrulanmadan hesap açılıyordu. Aynı hatanın
// giriş yolunda tekrarlanmadığını kanıtlarız.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/domain/otp_challenge.dart';

String _kod(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) =>
          !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

AuthRepository _depo() {
  final auth = AuthRepository(seedTestAccount: false);
  final r = auth.register(
    phone: '5321110001',
    pass: 'abc123',
    email: 'onur@gmail.com',
    role: Role.customer,
    otpVerified: true,
    termsAccepted: true,
  );
  expect(r.error, isNull);
  // ⚠ Kayıt oturum açar; negatif kanıtlar temiz durumdan başlamalı.
  auth.logout();
  expect(auth.currentAccount, isNull);
  return auth;
}

void main() {
  group('UI BYPASS EDİLSE BİLE OTURUM AÇILAMAZ', () {
    // ⚠ Bu grup EKRANI HİÇ KULLANMAZ: depo doğrudan çağrılır.
    // Doğrulamanın authoritative noktası burasıdır.

    test('YANLIŞ 6 haneli kod oturum AÇMAZ', () async {
      final auth = _depo();
      for (final kod in const ['000000', '111111', '654321']) {
        // Her deneme için yeni challenge: deneme hakkı tükenmesin,
        // kanıt kodun kendisine ait olsun.
        final r = auth.girisTelefonKodGonder('05321110001');
        expect(r.challengeId, isNotNull);
        expect(await auth.girisTelefonDogrula(r.challengeId!, kod), isNotNull,
            reason: kod);
        expect(auth.currentAccount, isNull, reason: kod);
      }
    });

    test('yanlış kod denendikten sonra bile oturum YOK', () async {
      final auth = _depo();
      final r = auth.girisTelefonKodGonder('05321110001');
      final err = await auth.girisTelefonDogrula(r.challengeId!, '000000');
      expect(err, isNotNull);
      expect(auth.currentAccount, isNull);
    });

    test('DOĞRU kod oturum açar', () async {
      final auth = _depo();
      final r = auth.girisTelefonKodGonder('05321110001');
      expect(await auth.girisTelefonDogrula(r.challengeId!, '123456'), isNull);
      expect(auth.currentAccount, isNotNull);
    });

    test('CHALLENGE TEK KULLANIMLIK', () async {
      final auth = _depo();
      final r = auth.girisTelefonKodGonder('05321110001');
      expect(await auth.girisTelefonDogrula(r.challengeId!, '123456'), isNull);
      auth.logout();
      // Aynı challenge ikinci kez KULLANILAMAZ.
      expect(await auth.girisTelefonDogrula(r.challengeId!, '123456'),
          isNotNull);
      expect(auth.currentAccount, isNull);
    });

    test('OLMAYAN challenge ile oturum açılmaz', () async {
      final auth = _depo();
      expect(await auth.girisTelefonDogrula('uydurma-id', '123456'), isNotNull);
      expect(auth.currentAccount, isNull);
    });

    test('DENEME HAKKI bitince doğru kod da kabul edilmez', () async {
      final auth = _depo();
      final r = auth.girisTelefonKodGonder('05321110001');
      for (var i = 0; i < 5; i++) {
        await auth.girisTelefonDogrula(r.challengeId!, '000000');
      }
      expect(await auth.girisTelefonDogrula(r.challengeId!, '123456'),
          isNotNull);
      expect(auth.currentAccount, isNull);
    });

    test('SÜRESİ DOLMUŞ challenge reddedilir', () async {
      final auth = _depo();
      final ch = OtpChallenge(
        id: 'sure-doldu',
        phone: '5321110001',
        amac: OtpAmac.giris,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      // ⚠ SAAT DIŞARIDAN VERİLİR (Y7). Getter'lar metoda dönüştü:
      // `expiresAt` deponun ENJEKTE EDİLEN saatiyle hesaplanırken
      // denetim gerçek saati okuyordu; testler duvar saatine bağlı
      // hale geliyordu (sahte saati geçmişe kuran testler, gerçek
      // saat o ana yetişene kadar geçip sonra düşüyordu).
      final simdi = DateTime.now();
      expect(ch.suresiDolduMu(simdi), isTrue);
      expect(ch.kullanilabilirMi(simdi), isFalse);
      expect(
          await auth.challengeDogrula('sure-doldu', '123456', OtpAmac.giris),
          OtpSonuc.gecersizChallenge);
    });

    test('AMACI FARKLI challenge giriş için kullanılamaz', () async {
      final auth = _depo();
      final r = auth.girisTelefonKodGonder('05321110001');
      expect(
          await auth.challengeDogrula(
              r.challengeId!, '123456', OtpAmac.telefonDegisimi),
          OtpSonuc.gecersizChallenge);
    });

    test('doğru kod ama KAYITSIZ numara — hesap AÇILMAZ (K2)', () async {
      final auth = _depo();
      final once = auth.accounts.length;
      final r = auth.girisTelefonKodGonder('05559998877');
      expect(await auth.girisTelefonDogrula(r.challengeId!, '123456'),
          isNotNull);
      expect(auth.accounts.length, once);
      expect(auth.currentAccount, isNull);
    });

    test('kayıtsız numaraya gerçek SMS GÖNDERİLMEZ ama cevap AYNI', () {
      // Challenge her hâlde üretilir (K5); gönderim kararı ayrıdır.
      final auth = _depo();
      expect(auth.girisTelefonKodGonder('05559998877').challengeId, isNotNull);
      expect(auth.girisTelefonKodGonder('05321110001').challengeId, isNotNull);
      final k = _kod('lib/data/repositories/auth_repository.dart');
      expect(k.contains('if (findByPhone(p) != null) {'), isTrue);
      expect(k.contains('unawaited(_otp.sendCode(p));'), isTrue);
    });
  });

  group('EKRAN AKIŞI — SONUÇ DOĞRULAMADAN GELİR', () {
    final l = _kod('lib/screens/login_screen.dart');
    final o = _kod('lib/screens/otp_screen.dart');

    test('OtpPurpose.login TANIMLI ama giriş ekranında KULLANILMIYOR', () {
      // ⚠ Enum değeri duruyor (challenge amacı olarak depoda
      // kullanılıyor); giriş EKRANI artık OTP açmıyor.
      expect(o.contains("login('LOGIN')"), isTrue);
      expect(l.contains('purpose: OtpPurpose.login'), isFalse);
    });

    test('GİRİŞ EKRANINDA OTP AKIŞI YOK — telefon da ŞİFREYLE girer', () {
      // ⚠ ÜRÜN KARARI GÜNCELLENDİ: kayıtlı kullanıcı her iki
      // kimlikle de şifresiyle girer. SMS OTP giriş anahtarı
      // değildir; yalnız kayıt, numara değişikliği ve hesap
      // kurtarmada sahiplik doğrular.
      expect(l.contains('OtpScreen('), isFalse,
          reason: 'giriş ekranında OTP akışı geri gelmiş');
      expect(l.contains('.girisTelefonSifre('), isTrue);
      expect(l.contains("'Doğrulama Kodu Gönder'"), isFalse);
    });

    test('şifre alanı HER İKİ modda da çizilir', () {
      // Telefon modunda şifre alanı gizlenirse kullanıcı giriş
      // yapamaz.
      final i = l.indexOf("iconAsset: 'assets/svg/ic_lock.svg'");
      expect(i, greaterThan(0));
      final onceki = l.substring(i - 200, i);
      expect(onceki.contains('if (_epostaModu)'), isFalse,
          reason: 'şifre alanı yine koşullu');
    });

    test('MOD ALANLARI AYRI KİMLİKLİ — klavye türü karışmaz', () {
      // ⚠ İki alan Column'da AYNI konumda ve aynı tipte. Anahtar
      // olmadan Flutter Element'i yeniden kullanıyor; e-posta alanı
      // çizilse bile klavye TELEFON klavyesi olarak açık kalıyordu.
      expect(l.contains("key: const ValueKey('giris-eposta')"), isTrue);
      expect(l.contains("key: const ValueKey('giris-telefon')"), isTrue);
      // Klavye türleri de doğru kalmalı.
      expect(l.contains('keyboardType: TextInputType.emailAddress'), isTrue);
      expect(l.contains('keyboardType: TextInputType.phone'), isTrue);
    });

    test('depo telefon+şifre yolunu sunuyor', () {
      final r = _kod('lib/data/repositories/auth_repository.dart');
      expect(r.contains('DomainError? girisTelefonSifre(String phone, String pass)'),
          isTrue);
    });

    test('OtpScreen YEREL doğrulama YAPMAZ — fallback kaldırıldı', () {
      // ⚠ SÖZLEŞME SIKILAŞTI: `dogrula` artık isteğe bağlı değil
      expect(o.contains('final Future<String?> Function(String kod) dogrula;'),
          isTrue);
      expect(o.contains('required this.dogrula,'), isTrue);
      final i = o.indexOf('Future<void> _verify(String code)');
      final govde = o.substring(i, o.indexOf('\n  }', i));
      expect(govde.contains('code.length == 6'), isFalse,
          reason: 'yerel "6 hane" kararı geri gelmiş');
      expect(govde.contains('_mock.verify('), isFalse);
      expect(govde.contains('await widget.dogrula(code)'), isTrue);
      // Hata dönerse onVerified çağrılmaz.
      final iHata = govde.indexOf('if (hata != null) {');
      final iCagri = govde.indexOf('widget.onVerified(context, code)');
      expect(iHata, greaterThan(-1));
      expect(iCagri, greaterThan(iHata));
      expect(govde.substring(iHata, iCagri).contains('return;'), isTrue);
    });

    test('OTP giriş yardımcıları KALDIRILDI', () {
      // `_telefonKodIste` ve `_girisTamam` giriş akışına aitti;
      expect(l.contains('void _girisTamam('), isFalse);
      expect(l.contains('_telefonKodIste'), isFalse);
      expect(l.contains('girisTelefonDogrula'), isFalse,
          reason: 'giriş ekranı hâlâ OTP doğrulaması çağırıyor');
    });

    test('TEK GEÇİŞ DÜĞMESİ — iki sekme yok', () {
      expect(l.contains('class _GirisSekmesi'), isFalse);
      expect(l.contains('class _GirisYoluDegistir'), isTrue);
      expect(l.contains("_epostaModu\n                              ? 'Telefon ile Giriş'"),
          isTrue);
      expect(l.contains('onTap: () => _moduDegistir(!_epostaModu)'), isTrue);
    });

    test('VARSAYILAN AÇILIŞ telefon formu', () {
      expect(l.contains('bool _epostaModu = false;'), isTrue);
    });

    test('İKİ MODDA DA TEK EYLEM: Giriş Yap', () {
      // ⚠ Telefon modunda "kod gönder" düğmesi YOK; iki kimlik de
      // şifreyle girer.
      expect(l.contains("'Giriş Yap',"), isTrue);
      expect(l.contains('_epostaModu ?'), isTrue,
          reason: 'mod ayrımı korunmalı (e-posta / telefon alanı)');
    });

    test('iş kuralı hatası validator İÇİNE girmiyor', () {
      // Eski hâlde `_authError` şifre validator'ından dönüyordu.
      expect(l.contains('_authError'), isFalse);
      // ⚠ Şifre alanı da ORTAK KAPIDAN geçiyor (`_kural`), iş
      // kuralı hatası validator'a girmiyor.
      expect(
          l.contains(
              "_kural(\n                              'sifre', _fPass, v, "
              'Validators.loginPassword)'),
          isTrue);
      expect(l.contains('String? _isHatasi;'), isTrue);
      expect(l.contains('String? _sistemHatasi;'), isTrue);
    });

    test('stale-response koruması: snapshot + alan kilidi', () {
      expect(l.contains('final epostaAnlik = _email.text;'), isTrue);
      expect(l.contains('final sifreAnlik = _pass.text;'), isTrue);
      expect(l.contains('final telefonAnlik = Validators.phoneFmt('), isTrue);
      expect('enabled: !_busy'.allMatches(l).length, greaterThanOrEqualTo(3));
      // ⚠ "Beni Hatırla" istek SONRASI denetleyiciyi okumaz; moda
      // göre e-posta ya da numara ANLIK değerinden saklanır.
      expect(
          l.contains(
              'OturumTercihi().kaydet(_epostaModu ? epostaAnlik : telefonAnlik)'),
          isTrue);
    });
  });
}
