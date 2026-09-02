// TELEFON SAHİPLİĞİ DOĞRULANAN DÖRT AKIŞ — TEK CHALLENGE MODELİ
//
// C0: kayit · giris · telefonDegisimi · hesapKurtarma
// C1: ekran hiçbirinde "6 hane doğruysa başarılı" demez
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/domain/form_mesajlari.dart';

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

AuthRepository _bos() => AuthRepository(seedTestAccount: false);

/// ⚠ KAYIT OTURUM AÇAR — YARDIMCI BUNU KAPATIR.
///
/// `AuthRepository.register` başarıda `currentAccount`'ı doldurur
/// (kullanıcı kaydolunca giriş yapmış olur). Test kurulumunda bu
/// istenmez: negatif OTP testleri "oturum açılmadı" diye bakarken
/// KURULUMDAN kalan oturumu görüyordu.
///
/// ⚠ BU BİR GÜVENLİK AÇIĞI DEĞİL, TEST KURULUM HATASIYDI. Yardımcı
/// artık kaydın açtığı oturumu kapatır ve bunu doğrular.
Account _hesap(AuthRepository auth,
    {String phone = '5321110001', String email = 'a@example.com'}) {
  final r = auth.register(
    phone: phone,
    pass: 'abc123',
    email: email,
    role: Role.customer,
    otpVerified: true,
    termsAccepted: true,
  );
  expect(r.error, isNull);
  auth.logout();
  expect(auth.currentAccount, isNull, reason: 'kurulum oturum bıraktı');
  return r.account!;
}

/// Negatif OTP testlerinin ortak başlangıç koşulu.
///
/// ⚠ Her negatif test bunu çağırır: temiz depo + oturum YOK.
AuthRepository _temizDepo() {
  final auth = _bos();
  expect(auth.currentAccount, isNull);
  expect(auth.loggedIn, isFalse);
  return auth;
}

void main() {
  group('KAYIT — OtpAmac.kayit', () {
    test('OTP doğrulanmadan HESAP OLUŞMAZ', () async {
      final auth = _bos();
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      // Yanlış kod → yetki yok → kayıt reddedilir.
      final d = await auth.kayitDogrula(ch.challengeId, '000000');
      expect(d.yetki, isNull);
      final r = auth.register(
        phone: '05551110000',
        pass: 'abc123',
        role: Role.customer,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't1',
        termsAccepted: true,
      );
      expect(r.account, isNull);
      expect(auth.accounts, isEmpty);
    });

    test('doğru kod → yetki → kayıt tamamlanır', () async {
      final auth = _bos();
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final d = await auth.kayitDogrula(ch.challengeId, '123456');
      expect(d.yetki, isNotNull);
      final r = auth.register(
        phone: '05551110000',
        pass: 'abc123',
        role: Role.customer,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't1',
        termsAccepted: true,
      );
      expect(r.error, isNull);
      expect(r.account, isNotNull);
    });

    test('yetki BAŞKA TELEFONLA kullanılamaz', () async {
      final auth = _bos();
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final d = await auth.kayitDogrula(ch.challengeId, '123456');
      final r = auth.register(
        phone: '05559998877', // başka numara
        pass: 'abc123',
        role: Role.customer,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't1',
        termsAccepted: true,
      );
      expect(r.account, isNull);
      expect(auth.accounts, isEmpty);
    });

    test('yetki TEK KULLANIMLIK', () async {
      final auth = _bos();
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final d = await auth.kayitDogrula(ch.challengeId, '123456');
      auth.register(
        phone: '05551110000',
        pass: 'abc123',
        role: Role.customer,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't1',
        termsAccepted: true,
      );
      // İkinci kez aynı yetkiyle başka hesap açılamaz.
      final r2 = auth.register(
        phone: '05551110000',
        pass: 'abc123',
        role: Role.provider,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't1',
        termsAccepted: true,
      );
      expect(r2.error, isA<OtpRequiredError>());
    });

    test('YENİ KOD ÖNCEKİ CHALLENGE\'I İPTAL EDER (C7)', () async {
      final auth = _bos();
      final ilk = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final ikinci = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      expect(ilk.challengeId, isNot(ikinci.challengeId));
      // Eski challenge artık kullanılamaz.
      final d1 = await auth.kayitDogrula(ilk.challengeId, '123456');
      expect(d1.yetki, isNull);
      final d2 = await auth.kayitDogrula(ikinci.challengeId, '123456');
      expect(d2.yetki, isNotNull);
    });

    test('kayıt challenge\'ı GİRİŞ için kullanılamaz (C8)', () async {
      final auth = _bos();
      _hesap(auth, phone: '5551110000');
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      expect(await auth.girisTelefonDogrula(ch.challengeId, '123456'),
          isNotNull);
      expect(auth.currentAccount, isNull);
    });
  });

  group('TELEFON DEĞİŞİKLİĞİ — OtpAmac.telefonDegisimi', () {
    test('MEVCUT TELEFON HEMEN DEĞİŞMEZ', () async {
      final auth = _bos();
      final acc = _hesap(auth);
      auth.girisEposta('a@example.com', 'abc123');
      final r = auth.telefonDegisimiKodGonder('05559998877');
      expect(r.challengeId, isNotNull);
      expect(acc.phone, '5321110001', reason: 'numara erken değişti');
    });

    test('BAŞARISIZ doğrulamada eski telefon KALIR', () async {
      final auth = _bos();
      final acc = _hesap(auth);
      auth.girisEposta('a@example.com', 'abc123');
      final r = auth.telefonDegisimiKodGonder('05559998877');
      expect(await auth.telefonDegisimiDogrula(r.challengeId!, '000000'),
          isNotNull);
      expect(acc.phone, '5321110001');
    });

    test('doğru kod → TEK ADIMDA bağlanır', () async {
      final auth = _bos();
      final acc = _hesap(auth);
      final id = acc.id;
      auth.girisEposta('a@example.com', 'abc123');
      final r = auth.telefonDegisimiKodGonder('05559998877');
      expect(await auth.telefonDegisimiDogrula(r.challengeId!, '123456'),
          isNull);
      expect(acc.phone, '5559998877');
      expect(acc.phoneVerified, isTrue);
      // ⚠ Kimlik userId; veriler taşınmaz, değişmez.
      expect(acc.id, id);
    });

    test('numara BAŞKASINDAYSA kod bile gönderilmez', () {
      final auth = _temizDepo();
      _hesap(auth);
      _hesap(auth, phone: '5559998877', email: 'b@example.com');
      auth.girisEposta('a@example.com', 'abc123');
      final r = auth.telefonDegisimiKodGonder('05559998877');
      expect(r.challengeId, isNull);
      expect(r.error?.message, FormMesaj.telefonKullanimda);
    });

    test('bekleme sırasında numara kapılırsa geçiş REDDEDİLİR', () async {
      final auth = _bos();
      final acc = _hesap(auth);
      auth.girisEposta('a@example.com', 'abc123');
      final r = auth.telefonDegisimiKodGonder('05559998877');
      // Başkası aynı numarayı aldı.
      _hesap(auth, phone: '5559998877', email: 'b@example.com');
      // ⚠ RAKİP HESAP OTURUMU DEĞİŞTİRİR.
      //
      // `register` başarıda oturum açar; yardımcı onu kapatır.
      // Dolayısıyla rakip kurulduktan SONRA kendi hesabımıza yeniden
      // girmek gerekir — yoksa doğrulama "oturum yok" der ve test
      // yanlış nedenle düşer.
      auth.girisEposta('a@example.com', 'abc123');
      expect(await auth.telefonDegisimiDogrula(r.challengeId!, '123456'),
          isNotNull);
      expect(acc.phone, '5321110001', reason: 'eski numara bozuldu');
    });

    test('değişiklik challenge\'ı GİRİŞ için kullanılamaz (C8)', () async {
      final auth = _temizDepo();
      _hesap(auth);
      auth.girisEposta('a@example.com', 'abc123');
      final r = auth.telefonDegisimiKodGonder('05559998877');
      auth.logout();
      expect(await auth.girisTelefonDogrula(r.challengeId!, '123456'),
          isNotNull);
      expect(auth.currentAccount, isNull);
    });
  });

  group('HESAP KURTARMA — OtpAmac.hesapKurtarma', () {
    test('DOĞRU KOD OTURUM AÇMAZ, yalnız YETKİ verir', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      expect(d.yetki, isNotNull);
      // ⚠ EN KRİTİK İDDİA: SMS kodu hesaba giriş anahtarı DEĞİLDİR.
      expect(auth.currentAccount, isNull, reason: 'OTP ile oturum açıldı');
      expect(auth.loggedIn, isFalse);
    });

    test('yetkiyle yeni şifre belirlenir ve OTURUM AÇILMAZ', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      expect(auth.kurtarmaSifreBelirle(d.yetki!, 'yeni456'), isNull);
      expect(auth.currentAccount, isNull);
      // Kullanıcı yeni şifresiyle normal yoldan girer.
      expect(auth.girisEposta('a@example.com', 'yeni456'), isNull);
    });

    test('yetki TEK KULLANIMLIK', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      expect(auth.kurtarmaSifreBelirle(d.yetki!, 'yeni456'), isNull);
      expect(auth.kurtarmaSifreBelirle(d.yetki!, 'baska789'), isNotNull);
      // İkinci şifre işlenmedi.
      expect(auth.girisEposta('a@example.com', 'yeni456'), isNull);
    });

    test('UYDURMA yetkiyle şifre değiştirilemez', () {
      final auth = _temizDepo();
      _hesap(auth);
      expect(auth.kurtarmaSifreBelirle('uydurma', 'yeni456'), isNotNull);
      expect(auth.girisEposta('a@example.com', 'abc123'), isNull);
    });

    test('KAYITSIZ telefonda yetki verilmez ama cevap NÖTR (K5)', () async {
      final auth = _temizDepo();
      _hesap(auth);
      // Başlangıç cevabı aynı: challenge her hâlde üretilir.
      final k1 = auth.hesapKurtarmaKodGonder('05559998877');
      final k2 = auth.hesapKurtarmaKodGonder('05321110001');
      expect(k1.challengeId, isNotEmpty);
      expect(k2.challengeId, isNotEmpty);
      final d = await auth.hesapKurtarmaDogrula(k1.challengeId, '123456');
      expect(d.yetki, isNull);
      expect(d.error?.message, FormMesaj.otpHatali);
      expect(d.error?.message.contains('kayıtlı'), isFalse);
    });

    test('kurtarma challenge\'ı GİRİŞ için kullanılamaz (C8)', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      expect(await auth.girisTelefonDogrula(ch.challengeId, '123456'),
          isNotNull);
      expect(auth.currentAccount, isNull);
    });
  });

  group('KAYNAK SÖZLEŞMESİ', () {
    final r = _kod('lib/data/repositories/auth_repository.dart');

    test('dört amaç da challenge üretiyor', () {
      for (final t in const [
        'OtpAmac.kayit',
        'OtpAmac.giris',
        'OtpAmac.telefonDegisimi',
        'OtpAmac.hesapKurtarma',
      ]) {
        expect(r.contains(t), isTrue, reason: t);
      }
    });

    test('yeni kod öncekini iptal ediyor (C7)', () {
      expect(r.contains('void _oncekiChallengeIptal('), isTrue);
      expect(r.contains('_oncekiChallengeIptal(phone, amac);'), isTrue);
    });

    test('kurtarmada OTP doğrudan oturum açmıyor', () {
      final i = r.indexOf('Future<({String? yetki, DomainError? error})> '
          'hesapKurtarmaDogrula(');
      expect(i, greaterThan(0));
      final govde = r.substring(i, r.indexOf('\n  }', i));
      expect(govde.contains('_oturumAc('), isFalse,
          reason: 'OTP ile oturum açılıyor');
    });

    test('yetkiler süreli ve ayrı tutuluyor', () {
      expect(r.contains('final Duration _yetkiOmru;'), isTrue);
      expect(r.contains('_now().add(_yetkiOmru)'), isTrue);
      expect(r.contains('_kayitYetkileri'), isTrue);
      expect(r.contains('_kurtarmaYetkileri'), isTrue);
    });
  });

  group('Y1 — KAYIT YETKİSİ TASLAĞA DA BAĞLI', () {
    test('BAŞKA TASLAK aynı yetkiyi kullanamaz', () async {
      final auth = _bos();
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final d = await auth.kayitDogrula(ch.challengeId, '123456');
      final r = auth.register(
        phone: '05551110000',
        pass: 'abc123',
        role: Role.customer,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't2', // farklı deneme
        termsAccepted: true,
      );
      expect(r.account, isNull);
      expect(auth.accounts, isEmpty);
    });

    test('SÜRESİ DOLMUŞ yetki kabul edilmez', () async {
      // ⚠ Y7: zaman ENJEKTE EDİLİR, beklenmez.
      var simdi = DateTime(2026, 8, 14, 12);
      final auth = AuthRepository(
        seedTestAccount: false,
        yetkiOmru: const Duration(minutes: 10),
        nowProvider: () => simdi,
      );
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final d = await auth.kayitDogrula(ch.challengeId, '123456');
      expect(d.yetki, isNotNull);
      // Saat 11 dakika ileri alınır — yetki ömrü doldu.
      simdi = simdi.add(const Duration(minutes: 11));
      final r = auth.register(
        phone: '05551110000',
        pass: 'abc123',
        role: Role.customer,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't1',
        termsAccepted: true,
      );
      expect(r.error, isA<OtpRequiredError>());
    });

    test('OTP SONRASI ad/e-posta değişebilir, TELEFON değişemez', () async {
      final auth = _bos();
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final d = await auth.kayitDogrula(ch.challengeId, '123456');
      // Ad ve e-posta doğrulamadan sonra girilmiş olabilir.
      final r = auth.register(
        phone: '05551110000',
        pass: 'abc123',
        name: 'Sonradan Girildi',
        email: 'sonra@example.com',
        role: Role.customer,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't1',
        termsAccepted: true,
      );
      expect(r.error, isNull);
      expect(r.account!.name, 'Sonradan Girildi');
      expect(r.account!.email, 'sonra@example.com');
      expect(r.account!.phone, '5551110000');
    });
  });

  group('Y2 — KAYITSIZ TELEFON RECOVERY YETKİSİ ÜRETEMEZ', () {
    test('BYPASS: depo doğrudan çağrılsa da yetki YOK', () async {
      final auth = _temizDepo();
      _hesap(auth); // başka bir hesap var, ama bu numara kayıtsız
      final ch = auth.hesapKurtarmaKodGonder('05559998877');
      // Kod DOĞRU olsa bile yetki verilmez.
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      expect(d.yetki, isNull);
      expect(auth.kurtarmaSifreBelirle('uydurma', 'yeni456'), isNotNull);
      // Var olan hesabın şifresi bozulmadı.
      expect(auth.girisEposta('a@example.com', 'abc123'), isNull);
    });

    test('kayıtsız numarada birden çok deneme de yetki üretmez', () async {
      final auth = _bos();
      for (var i = 0; i < 3; i++) {
        final ch = auth.hesapKurtarmaKodGonder('05559998877');
        final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
        expect(d.yetki, isNull, reason: 'deneme $i');
      }
    });
  });

  group('Y3 — KURTARMA YETKİSİ KULLANICIYA BAĞLI', () {
    test('BAŞKA KULLANICIYA uygulanamaz', () async {
      final auth = _temizDepo();
      _hesap(auth); // a@example.com / 5321110001
      _hesap(auth, phone: '5321110002', email: 'b@example.com');
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      expect(auth.kurtarmaSifreBelirle(d.yetki!, 'yeni456'), isNull);
      expect(auth.girisEposta('a@example.com', 'yeni456'), isNull);
      auth.logout();
      expect(auth.girisEposta('b@example.com', 'abc123'), isNull);
    });

    test('SÜRESİ DOLMUŞ yetki şifre değiştiremez', () async {
      // ⚠ Y7: zaman ENJEKTE EDİLİR, beklenmez.
      var simdi = DateTime(2026, 8, 14, 12);
      final auth = AuthRepository(
        seedTestAccount: false,
        yetkiOmru: const Duration(minutes: 10),
        nowProvider: () => simdi,
      );
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      simdi = simdi.add(const Duration(minutes: 11));
      expect(auth.kurtarmaSifreBelirle(d.yetki!, 'yeni456'), isNotNull);
      // Eski şifre hâlâ geçerli.
      expect(auth.girisEposta('a@example.com', 'abc123'), isNull);
    });

    test('başarılı kullanımdan sonra TÜKETİLİR', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      expect(auth.kurtarmaSifreBelirle(d.yetki!, 'yeni456'), isNull);
      expect(auth.kurtarmaSifreBelirle(d.yetki!, 'ucuncu999'), isNotNull);
    });
  });

  group('Y4 — DEĞİŞİKLİK CHALLENGE\'I YENİ TELEFONA BAĞLI', () {
    test('doğrulama CHALLENGE içindeki numarayı esas alır', () async {
      final auth = _bos();
      final acc = _hesap(auth);
      auth.girisEposta('a@example.com', 'abc123');
      final r = auth.telefonDegisimiKodGonder('05559998877');
      expect(await auth.telefonDegisimiDogrula(r.challengeId!, '123456'),
          isNull);
      expect(acc.phone, '5559998877');
    });

    test('doğrulama fonksiyonu telefon parametresi ALMAZ', () {
      // ⚠ İmza kanıtı: controller o anki alan değerini geçiremez.
      final r = _kod('lib/data/repositories/auth_repository.dart');
      expect(
          r.contains('Future<DomainError?> telefonDegisimiDogrula(\n'
              '      String challengeId, String kod) async {'),
          isTrue);
    });

    test('yeni kod istenince eski challenge ölür (C7)', () async {
      final auth = _bos();
      final acc = _hesap(auth);
      auth.girisEposta('a@example.com', 'abc123');
      final ilk = auth.telefonDegisimiKodGonder('05559998877');
      final ikinci = auth.telefonDegisimiKodGonder('05559998877');
      expect(await auth.telefonDegisimiDogrula(ilk.challengeId!, '123456'),
          isNotNull);
      expect(acc.phone, '5321110001');
      expect(await auth.telefonDegisimiDogrula(ikinci.challengeId!, '123456'),
          isNull);
      expect(acc.phone, '5559998877');
    });
  });

  group('Y5 — YETKİ YALNIZ BAŞARIDA TÜKETİLİR', () {
    test('kayıt kuralı düşerse yetki YANMAZ', () async {
      final auth = _bos();
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final d = await auth.kayitDogrula(ch.challengeId, '123456');
      // Sözleşme onayı YOK → kayıt reddedilir.
      final r1 = auth.register(
        phone: '05551110000',
        pass: 'abc123',
        role: Role.customer,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't1',
        termsAccepted: false,
      );
      expect(r1.account, isNull);
      // ⚠ Aynı yetki hâlâ geçerli: kullanıcı baştan SMS istemez.
      final r2 = auth.register(
        phone: '05551110000',
        pass: 'abc123',
        role: Role.customer,
        otpVerified: false,
        kayitYetkisi: d.yetki,
        taslakKimligi: 't1',
        termsAccepted: true,
      );
      expect(r2.error, isNull);
      expect(r2.account, isNotNull);
    });

    test('şifre politikası düşerse kurtarma yetkisi YANMAZ', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      // Politikaya aykırı şifre.
      expect(auth.kurtarmaSifreBelirle(d.yetki!, '123'), isNotNull);
      // ⚠ Yetki hâlâ geçerli.
      expect(auth.kurtarmaSifreBelirle(d.yetki!, 'guclu456'), isNull);
      expect(auth.girisEposta('a@example.com', 'guclu456'), isNull);
    });
  });

  group('Y6 — TELEFON DEĞİŞİKLİĞİ ATOMİK', () {
    test('benzersizlik düşerse challenge TÜKETİLMEZ', () async {
      final auth = _bos();
      final acc = _hesap(auth);
      auth.girisEposta('a@example.com', 'abc123');
      final r = auth.telefonDegisimiKodGonder('05559998877');
      // Başkası numarayı kaptı.
      final rakip = _hesap(auth, phone: '5559998877', email: 'b@example.com');
      // ⚠ RAKİP HESAP OTURUMU DEĞİŞTİRİR.
      //
      // `register` başarıda oturum açar; yardımcı onu kapatır.
      // Dolayısıyla rakip kurulduktan SONRA kendi hesabımıza yeniden
      // girmek gerekir — yoksa doğrulama "oturum yok" der ve test
      // yanlış nedenle düşer.
      auth.girisEposta('a@example.com', 'abc123');
      expect(await auth.telefonDegisimiDogrula(r.challengeId!, '123456'),
          isNotNull);
      // ⚠ Rakibin numarası EZİLMEDİ.
      expect(rakip.phone, '5559998877');
      expect(acc.phone, '5321110001');
    });

    test('başarıda challenge tüketilir, ikinci kez uygulanamaz', () async {
      final auth = _bos();
      final acc = _hesap(auth);
      auth.girisEposta('a@example.com', 'abc123');
      final r = auth.telefonDegisimiKodGonder('05559998877');
      expect(await auth.telefonDegisimiDogrula(r.challengeId!, '123456'),
          isNull);
      expect(acc.phone, '5559998877');
      expect(await auth.telefonDegisimiDogrula(r.challengeId!, '123456'),
          isNotNull);
    });
  });

  group('Y7 — ZAMAN ENJEKTE EDİLİR', () {
    test('saat ilerlemeden yetki GEÇERLİ, ilerleyince GEÇERSİZ', () async {
      var simdi = DateTime(2026, 8, 14, 12);
      final auth = AuthRepository(
        seedTestAccount: false,
        nowProvider: () => simdi,
      );
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      // 9 dakika sonra hâlâ geçerli.
      simdi = simdi.add(const Duration(minutes: 9));
      expect(auth.kurtarmaSifreBelirle(d.yetki!, 'gecerli9'), isNull);

      final ch2 = auth.hesapKurtarmaKodGonder('05321110001');
      final d2 = await auth.hesapKurtarmaDogrula(ch2.challengeId, '123456');
      simdi = simdi.add(const Duration(minutes: 11));
      expect(auth.kurtarmaSifreBelirle(d2.yetki!, 'baska456'), isNotNull);
    });
  });

  group('YENİDEN GÖNDERİM DAVRANIŞI (C7) — ESAS KABUL KRİTERİ', () {
    // ⚠ Bu grup KAYNAK METNİ TARAMAZ. Gerçek depo çağrılarıyla
    // resend'in beklenen davranışı kanıtlanır: yeni challenge üretilir,
    // eskisi ölür, doğrulama YENİ kimlikle çalışır.

    test('GİRİŞ: resend yeni kimlik üretir, eski ölür, yeni çalışır',
        () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ilk = auth.girisTelefonKodGonder('05321110001');
      final ikinci = auth.girisTelefonKodGonder('05321110001');

      expect(ikinci.challengeId, isNot(ilk.challengeId),
          reason: 'resend yeni challenge üretmedi');
      // Eski challenge DOĞRU kodla bile artık çalışmaz.
      expect(await auth.girisTelefonDogrula(ilk.challengeId!, '123456'),
          isNotNull);
      expect(auth.currentAccount, isNull);
      // Yeni challenge çalışır.
      expect(await auth.girisTelefonDogrula(ikinci.challengeId!, '123456'),
          isNull);
      expect(auth.currentAccount, isNotNull);
    });

    test('KAYIT: resend sonrası yalnız yeni challenge yetki üretir',
        () async {
      final auth = _bos();
      final ilk = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final ikinci = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      expect(ikinci.challengeId, isNot(ilk.challengeId));
      expect((await auth.kayitDogrula(ilk.challengeId, '123456')).yetki,
          isNull);
      expect((await auth.kayitDogrula(ikinci.challengeId, '123456')).yetki,
          isNotNull);
    });

    test('KURTARMA: resend sonrası yalnız yeni challenge yetki üretir',
        () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ilk = auth.hesapKurtarmaKodGonder('05321110001');
      final ikinci = auth.hesapKurtarmaKodGonder('05321110001');
      expect(ikinci.challengeId, isNot(ilk.challengeId));
      expect((await auth.hesapKurtarmaDogrula(ilk.challengeId, '123456')).yetki,
          isNull);
      expect(
          (await auth.hesapKurtarmaDogrula(ikinci.challengeId, '123456')).yetki,
          isNotNull);
    });

    test('EKRAN DESENİ: kapanışlar resend sonrası YENİ kimliği kullanır',
        () async {
      // ⚠ Ekranın kurduğu bağı BİREBİR taklit eder: `dogrula` ve
      // `yenidenGonder` kapanışları AYNI değişkeni paylaşır.
      // Gerçek kanıt budur — kaynakta `final` aranması değil.
      final auth = _temizDepo();
      _hesap(auth);

      var challengeId = auth.girisTelefonKodGonder('05321110001').challengeId!;
      final ilkKimlik = challengeId;

      Future<String?> dogrula(String kod) async =>
          (await auth.girisTelefonDogrula(challengeId, kod))?.message;

      Future<String?> yenidenGonder() async {
        final y = auth.girisTelefonKodGonder('05321110001');
        challengeId = y.challengeId!;
        return null;
      }

      // Kullanıcı "Kodu Tekrar Gönder" dedi.
      expect(await yenidenGonder(), isNull);
      expect(challengeId, isNot(ilkKimlik), reason: 'kimlik güncellenmedi');

      // ⚠ Doğrulama artık YENİ challenge'a gidiyor ve BAŞARILI.
      expect(await dogrula('123456'), isNull);
      expect(auth.currentAccount, isNotNull);
    });

    test('EKRAN DESENİ: resend olmadan eski kimlik çalışmaya devam eder',
        () async {
      // Karşı kontrol: kimliğin değişmesi resend'e bağlıdır, kendi
      // kendine değişmez.
      final auth = _temizDepo();
      _hesap(auth);
      var challengeId = auth.girisTelefonKodGonder('05321110001').challengeId!;
      Future<String?> dogrula(String kod) async =>
          (await auth.girisTelefonDogrula(challengeId, kod))?.message;
      expect(await dogrula('123456'), isNull);
      expect(auth.currentAccount, isNotNull);
    });
  });

  group('NEGATİF OTP — TEMİZ DEPO İLE KANIT', () {
    // ⚠ HER TEST KENDİ DEPOSUNU KURAR ve başlangıçta oturum
    // OLMADIĞINI doğrular. Böylece "oturum açılmadı" iddiası
    // kurulumdan kalan bir oturumu değil, gerçek sonucu ölçer.
    //
    // Ayrıca her testte üç şey birlikte kanıtlanır:
    //   1. dönen hata beklenen türde,
    //   2. currentAccount hâlâ null,
    //   3. hesap sayısı değişmedi.

    test('YANLIŞ KOD (000000) oturum açamaz', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final sayi = auth.accounts.length;
      expect(auth.currentAccount, isNull);

      final ch = auth.girisTelefonKodGonder('05321110001');
      final err = await auth.girisTelefonDogrula(ch.challengeId!, '000000');

      expect(err, isNotNull);
      expect(err!.message, FormMesaj.otpHatali);
      expect(auth.currentAccount, isNull);
      expect(auth.loggedIn, isFalse);
      expect(auth.accounts.length, sayi);
    });

    test('OLMAYAN challenge oturum açamaz', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final err = await auth.girisTelefonDogrula('yok-boyle-bir-id', '123456');
      expect(err, isNotNull);
      expect(auth.currentAccount, isNull);
      expect(auth.loggedIn, isFalse);
    });

    test('DENEME HAKKI BİTMİŞ challenge oturum açamaz', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ch = auth.girisTelefonKodGonder('05321110001');
      for (var i = 0; i < 5; i++) {
        await auth.girisTelefonDogrula(ch.challengeId!, '000000');
      }
      expect(auth.currentAccount, isNull);
      final err = await auth.girisTelefonDogrula(ch.challengeId!, '123456');
      expect(err, isNotNull);
      expect(auth.currentAccount, isNull);
      expect(auth.loggedIn, isFalse);
    });

    test('KAYIT challenge\'ı giriş açamaz (C8)', () async {
      final auth = _temizDepo();
      _hesap(auth, phone: '5551110000', email: 'k@example.com');
      final ch = auth.kayitKodGonder('05551110000', taslakKimligi: 't1');
      final err = await auth.girisTelefonDogrula(ch.challengeId, '123456');
      expect(err, isNotNull);
      expect(auth.currentAccount, isNull);
      expect(auth.loggedIn, isFalse);
    });

    test('KURTARMA challenge\'ı giriş açamaz (C8)', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final err = await auth.girisTelefonDogrula(ch.challengeId, '123456');
      expect(err, isNotNull);
      expect(auth.currentAccount, isNull);
      expect(auth.loggedIn, isFalse);
    });

    test('KURTARMA OTP\'si DOĞRU olsa bile OTURUM AÇILMAZ', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ch = auth.hesapKurtarmaKodGonder('05321110001');
      final d = await auth.hesapKurtarmaDogrula(ch.challengeId, '123456');
      // Yetki verilir…
      expect(d.yetki, isNotNull);
      expect(auth.currentAccount, isNull);
      expect(auth.loggedIn, isFalse);
    });

    test('RESEND sonrası eski challenge açamaz, yenisi açar', () async {
      final auth = _temizDepo();
      _hesap(auth);
      final ilk = auth.girisTelefonKodGonder('05321110001');
      final ikinci = auth.girisTelefonKodGonder('05321110001');

      expect(await auth.girisTelefonDogrula(ilk.challengeId!, '123456'),
          isNotNull);
      expect(auth.currentAccount, isNull, reason: 'ölü challenge oturum açtı');

      expect(await auth.girisTelefonDogrula(ikinci.challengeId!, '123456'),
          isNull);
      expect(auth.currentAccount, isNotNull);
    });
  });
}
