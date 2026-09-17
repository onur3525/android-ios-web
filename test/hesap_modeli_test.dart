// HESAP MODELİ — PAKET 1 (MODEL + DEPO)
//
// Karar: kimlik userId; iki giriş yolu (e-posta+şifre / telefon+OTP);
// beş ek sözleşme kuralı K1-K5.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
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

AuthRepository _bosDepo() => AuthRepository(seedTestAccount: false);

Account _hesapAc(
  AuthRepository auth, {
  required String phone,
  required String email,
  String pass = 'abc123',
}) {
  final r = auth.register(
    phone: phone,
    pass: pass,
    email: email,
    role: Role.customer,
    otpVerified: true,
    termsAccepted: true,
  );
  expect(r.error, isNull, reason: 'kurulum kaydı başarısız: ${r.error}');
  // ⚠ KAYIT OTURUM AÇAR — kurulumdan oturum bırakılmaz.
  //
  // Negatif testler "oturum açılmadı" derken kurulumdan kalan
  // oturumu görüyordu. Bu bir güvenlik açığı değil, test kurulum
  // hatasıydı.
  auth.logout();
  expect(auth.currentAccount, isNull, reason: 'kurulum oturum bıraktı');
  return r.account!;
}

void main() {
  group('K1 — E-POSTA CASE-INSENSITIVE VE BENZERSİZ', () {
    test('büyük/küçük harf farkı AYNI hesabı bulur', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'Onur@Gmail.com');
      for (final y in const [
        'onur@gmail.com',
        'ONUR@GMAIL.COM',
        '  Onur@Gmail.com  ',
      ]) {
        expect(auth.findByEmail(y)?.id, acc.id, reason: y);
      }
    });

    test('aynı e-posta İKİNCİ hesaba bağlanamaz', () {
      final auth = _bosDepo();
      _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      final r = auth.register(
        phone: '5321110002',
        pass: 'abc123',
        email: 'ONUR@gmail.com',
        role: Role.customer,
        otpVerified: true,
        termsAccepted: true,
      );
      expect(r.account, isNull);
      expect(r.error?.message, FormMesaj.epostaKullanimda);
    });

    test('boş e-posta eşleşme üretmez', () {
      final auth = _bosDepo();
      _hesapAc(auth, phone: '5321110001', email: '');
      expect(auth.findByEmail(''), isNull);
      expect(auth.findByEmail('   '), isNull);
    });

    test('kendi adresi çakışma sayılmaz', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      expect(
          auth.epostaBaskaHesaptaMi('Onur@Gmail.com', haricTutulanId: acc.id),
          isFalse);
      expect(auth.epostaBaskaHesaptaMi('Onur@Gmail.com'), isTrue);
    });
  });

  group('E-POSTA + ŞİFRE İLE GİRİŞ', () {
    test('doğru bilgiyle oturum açılır', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      expect(auth.girisEposta('ONUR@gmail.com', 'abc123'), isNull);
      expect(auth.currentAccount?.id, acc.id);
    });

    test('yanlış şifre ve OLMAYAN hesap AYNI mesajı verir', () {
      // Hesabın var olup olmadığı sızdırılmaz.
      final auth = _bosDepo();
      _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      final a = auth.girisEposta('onur@gmail.com', 'yanlis');
      final b = auth.girisEposta('yok@gmail.com', 'abc123');
      expect(a?.message, FormMesaj.kimlikHatali);
      expect(b?.message, a?.message);
      expect(auth.currentAccount, isNull);
    });

    test('e-posta kanalının kendi kilidi var', () {
      final auth = _bosDepo();
      _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      expect(auth.girisKilidiKalanEposta('onur@gmail.com'), 0);
      for (var i = 0; i < 5; i++) {
        auth.girisEposta('onur@gmail.com', 'yanlis');
      }
      expect(auth.girisKilidiKalanEposta('ONUR@GMAIL.COM'), greaterThan(0));
      // Telefon kanalı ETKİLENMEZ.
      expect(auth.girisKilidiKalan('5321110001'), 0);
    });
  });

  group('K2 — TELEFON OTP GİRİŞİ HESAP OLUŞTURMAZ', () {
    // ⚠ İMZA DEĞİŞTİ, SENARYO DEĞİŞMEDİ.
    //
    // Doğrulama artık telefon+kod değil CHALLENGE üzerinden yapılıyor
    // ve async. Testler aynı üç şeyi kanıtlamaya devam ediyor:
    // kayıtlı numara girer · kayıtsız numara HESAP AÇMAZ · mesaj
    // hesabın varlığını sızdırmaz.

    test('kayıtlı numara oturum açar', () async {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      final ch = auth.girisTelefonKodGonder('05321110001');
      expect(await auth.girisTelefonDogrula(ch.challengeId!, '123456'), isNull);
      expect(auth.currentAccount?.id, acc.id);
    });

    test('KAYITSIZ numara hesap AÇMAZ', () async {
      final auth = _bosDepo();
      final oncekiSayi = auth.accounts.length;
      final ch = auth.girisTelefonKodGonder('05559998877');
      final err = await auth.girisTelefonDogrula(ch.challengeId!, '123456');
      expect(err, isNotNull);
      expect(auth.accounts.length, oncekiSayi, reason: 'sessizce hesap açıldı');
      expect(auth.currentAccount, isNull);
    });

    test('kayıtsız numarada mesaj "kayıtlı değil" DEMEZ (K5)', () async {
      final auth = _bosDepo();
      final ch = auth.girisTelefonKodGonder('05559998877');
      final err = await auth.girisTelefonDogrula(ch.challengeId!, '123456');
      expect(err?.message, FormMesaj.otpHatali);
      expect(err?.message.contains('kayıtlı'), isFalse);
    });

    test('kod gönderme ucu kayıtsız numarada da challenge ÜRETİR (K5)', () {
      // ⚠ Cevap her iki numarada da AYNI görünür; fark yalnız
      // gerçekten SMS gönderilip gönderilmediğindedir.
      final auth = _bosDepo();
      _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      expect(auth.girisTelefonKodGonder('05559998877').challengeId, isNotNull);
      expect(auth.girisTelefonKodGonder('05321110001').challengeId, isNotNull);
    });
  });

  group('K3 — DOĞRULANMAMIŞ E-POSTA KURTARMA KANALI DEĞİL', () {
    test('doğrulanmamış adrese bağlantı gönderilmez', () {
      final auth = _bosDepo();
      _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      // Kayıt sonrası e-posta doğrulanmamıştır.
      expect(auth.findByEmail('onur@gmail.com')!.emailVerified, isFalse);
      expect(auth.sifirlamaBaglantisiGonderilir('onur@gmail.com'), isFalse);
    });

    test('doğrulanmış adrese gönderilir', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      acc.emailVerified = true;
      expect(auth.sifirlamaBaglantisiGonderilir('ONUR@gmail.com'), isTrue);
    });

    test('bilinmeyen adrese gönderilmez ama CEVAP AYNI (K5)', () {
      final auth = _bosDepo();
      _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      expect(auth.sifirlamaBaglantisiGonderilir('yok@gmail.com'), isFalse);
      // Kullanıcıya dönen sonuç her hâlde aynıdır.
      expect(auth.sifreSifirlamaIste('yok@gmail.com'), isNull);
      expect(auth.sifreSifirlamaIste('onur@gmail.com'), isNull);
    });
  });

  group('K4 — YENİ DEĞER DOĞRULANANA KADAR ESKİSİ KORUNUR', () {
    test('e-posta değişince ESKİSİ hâlâ geçerli', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'eski@gmail.com');
      acc.emailVerified = true;
      auth.girisEposta('eski@gmail.com', 'abc123');

      auth.updateProfile(email: 'yeni@gmail.com');
      // Eski adres DEĞİŞMEDİ ve doğrulanmış kaldı.
      expect(acc.email, 'eski@gmail.com');
      expect(acc.emailVerified, isTrue);
      expect(acc.bekleyenEposta, 'yeni@gmail.com');
      // Kurtarma kanalı hâlâ çalışıyor.
      expect(auth.sifirlamaBaglantisiGonderilir('eski@gmail.com'), isTrue);
    });

    test('doğrulama geçişi TEK ADIMDA yapılır', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'eski@gmail.com');
      acc.emailVerified = true;
      auth.girisEposta('eski@gmail.com', 'abc123');
      auth.updateProfile(email: 'Yeni@Gmail.com');

      expect(auth.epostaDogrula(), isNull);
      expect(acc.email, 'yeni@gmail.com');
      expect(acc.emailVerified, isTrue);
      expect(acc.bekleyenEposta, isNull);
      // Eski adres artık hesabı bulmaz.
      expect(auth.findByEmail('eski@gmail.com'), isNull);
      expect(auth.findByEmail('yeni@gmail.com')?.id, acc.id);
    });

    test('bekleme sırasında adres kapılırsa geçiş REDDEDİLİR (K1)', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'eski@gmail.com');
      auth.girisEposta('eski@gmail.com', 'abc123');
      auth.updateProfile(email: 'ortak@gmail.com');
      // Başka biri aynı adresi aldı.
      _hesapAc(auth, phone: '5321110002', email: 'ortak@gmail.com');
      // ⚠ RAKİP HESAP OTURUMU DEĞİŞTİRİR.
      //
      // `register` başarıda oturum açar; yardımcı onu kapatır.
      // Dolayısıyla rakip kurulduktan SONRA kendi hesabımıza yeniden
      // girmek gerekir — yoksa doğrulama "oturum yok" der ve test
      // yanlış nedenle düşer.
      auth.girisEposta('eski@gmail.com', 'abc123');

      expect(auth.epostaDogrula()?.message, FormMesaj.epostaKullanimda);
      expect(acc.email, 'eski@gmail.com', reason: 'eski değer bozuldu');
    });

    test('iptal edilince eski adres kalır', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'eski@gmail.com');
      auth.girisEposta('eski@gmail.com', 'abc123');
      auth.updateProfile(email: 'yeni@gmail.com');
      auth.epostaDegisikligiIptal();
      expect(acc.bekleyenEposta, isNull);
      expect(acc.email, 'eski@gmail.com');
    });
  });

  group('K5 — KURTARMA BAŞLANGICINDA ENUMERATION YOK', () {
    test('kayıtsız numara da BAŞARI döner', () {
      final auth = _bosDepo();
      _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      expect(auth.forgotStart('05559998877'), isNull);
      expect(auth.forgotStart('05321110001'), isNull);
    });

    test('K5 DEPO KATMANINDA GEÇERLİ — başlangıç ucu nötr', () {
      // ⚠ 14 AĞUSTOS ÜRÜN KARARI GERİ ALINDI (16 Ağu).
      //
      // Telefon yolunda "numaranız tanınmadı" demek, hesap sayımına
      // (enumeration) kapı bırakıyordu. K5 artık HER İKİ YOLDA da
      // tam olarak geçerlidir: ekran kayıt durumunu sormaz, cevap
      // kayıtlı ve kayıtsız numarada AYNIDIR.
      final k = _kod('lib/screens/forgot_password_screen.dart');
      expect(k.contains('FormMesaj.numaraKayitsiz'), isFalse,
          reason: 'kayıtsızlık uyarısı geri gelmiş');
      expect(k.contains('telefonKayitliMi('), isFalse,
          reason: 'ekran kayıt durumunu sorguluyor');
      // ⚠ Telefon yolunda nötr KUTU kaldırıldı (16 Ağu): doğrulama
      // ekranı zaten açılıyor. Nötrlük artık akışın kendisinde:
      // kayıtlı ve kayıtsız numara AYNI adıma geçiyor.
      expect(k.contains('Navigator.push('), isTrue,
          reason: 'kayıtsız numarada da doğrulama adımına geçilmeli');
      // ⚠ DEPO UCU HÂLÂ NÖTR — davranışla doğrulanır.
      //
      // Kaynak metninde yorum aramak işe yaramaz: `_kod` yorum
      // satırlarını eler. Kayıtsız numarada da challenge üretilmeli
      // ki cevap ve akış kayıtlı numarayla AYNI görünsün.
      final auth = _bosDepo();
      final ch = auth.hesapKurtarmaKodGonder('05559998877');
      expect(ch.challengeId, isNotEmpty,
          reason: 'kayıtsız numarada challenge üretilmedi');
    });
  });

  group('KİMLİK userId — VERİLER TELEFONA BAĞLI DEĞİL', () {
    test('telefon değişse de hesap kimliği AYNI', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      final id = acc.id;
      acc.phone = '5559998877';
      expect(acc.id, id);
      expect(auth.byId(id)?.id, id);
    });

    test('hesap kimliği UUID biçiminde ve telefon DEĞİL', () {
      final auth = _bosDepo();
      final acc = _hesapAc(auth, phone: '5321110001', email: 'onur@gmail.com');
      expect(acc.id.length, greaterThan(20));
      expect(acc.id.contains('532'), isFalse);
    });
  });
}
