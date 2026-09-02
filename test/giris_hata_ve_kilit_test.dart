// GİRİŞ EKRANI — HATA GÖRÜNÜRLÜĞÜ VE KİLİT GERİ SAYIMI
//
// İKİ KUSUR:
//   1. "Telefon veya şifre hatalı" uyarısı, alan tamamen silinse bile
//      ekranda ASILI KALIYORDU.
//   2. "Çok fazla hatalı deneme. N saniye sonra..." metni bir kez
//      üretilip DONUYORDU: sayı ilerlemiyor, ekran kapanıp açılınca
//      aynı saniyede kalıyor ya da kayboluyordu.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'support/test_config.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';

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

void main() {
  final l = _kod('lib/screens/login_screen.dart');

  group('KİMLİK HATASI YAPIŞIP KALMAZ', () {
    // ⚠ EKRAN İKİ GİRİŞ YOLUNA AYRILDI (hesap modeli kararı):
    // e-posta + şifre · telefon + SMS. Alan sayısı ÜÇ oldu
    // (e-posta, telefon, şifre) ve iş kuralı hatası validator'dan
    // çıkarılıp form düzeyine taşındı.

    test('değer değişince hata temizlenir — ÜÇ alanda da', () {
      // ⚠ SARMALAYICI EKLENDİ: `_degerDegisti` hem eski hatayı
      // temizler hem DÜĞME DURUMUNU tazeler. Yalnız temizleme
      // yetmiyordu: hata yokken `setState` çağrılmadığı için
      // zorunlu alanlar dolsa da düğme pasif kalıyordu.
      expect(l.contains('void _kimlikHatasiniTemizle() {'), isTrue);
      expect(l.contains('void _degerDegisti()'), isTrue);
      expect('onChanged: (_) => _degerDegisti()'.allMatches(l).length, 3);
      expect(l.contains('addListener(_kimlikHatasiniTemizle)'), isFalse,
          reason: 'dolaylı yol geri gelmiş');
    });

    test('istek sürerken alanlar KİLİTLİ (stale cevap koruması)', () {
      expect('enabled: !_busy'.allMatches(l).length, 3);
    });

    test('temizleme yalnız KİMLİK/SİSTEM hatasını siler', () {
      // ⚠ Kilit numaraya uygulanan bir yaptırımdır; yazı yazmakla
      // kalkmaz. `_authError` yerine artık ayrı hata sınıfları var.
      final i = l.indexOf('void _kimlikHatasiniTemizle() {');
      final govde = l.substring(i, l.indexOf('\n  }', i));
      expect(govde.contains('_isHatasi = null'), isTrue);
      expect(govde.contains('_sistemHatasi = null'), isTrue);
      expect(govde.contains('_kilitKalan'), isFalse,
          reason: 'kilit de siliniyor');
    });

    test('İŞ KURALI HATASI validator İÇİNE GİRMEZ', () {
      // Eski hâlde `_authError` şifre validator'ından dönüyordu ve
      // FormFieldState içinde takılı kalıyordu.
      expect(l.contains('_authError'), isFalse);
      expect(
          l.contains(
              "_kural(\n                              'sifre', _fPass, v, "
              'Validators.loginPassword)'),
          isTrue);
    });
  });

  group('KİLİT GERİ SAYIMI CANLI', () {
    test('kalan süre DEPODAN sorulur, metne gömülmez', () {
      expect(l.contains('girisKilidiKalan(Validators.phoneFmt(_phone.text))'),
          isTrue);
      expect(l.contains('String? get _kilitMesaji =>'), isTrue);
    });

    test('saniyede bir tazelenir ve bitince durur', () {
      expect(l.contains('Timer.periodic('), isTrue);
      expect(l.contains('const Duration(seconds: 1)'), isTrue);
      final i = l.indexOf('void _kilidiTazele() {');
      final govde = l.substring(i, l.indexOf('\n  }', i));
      expect(govde.contains('_kilitSayaci?.cancel();'), isTrue,
          reason: 'süre bitince sayaç durmuyor');
    });

    test('yerel azaltma YOK — her tıkta yeniden sorulur', () {
      // `_kilitKalan--` gibi yerel sayaç, ekran kapanıp açılınca
      // gerçekten sapardı.
      expect(l.contains('_kilitKalan--'), isFalse);
      expect(l.contains('_kilitKalan -= 1'), isFalse);
    });

    test('ekran açılışında kilit yeniden okunur', () {
      expect(l.contains('void initState() {'), isTrue);
      final i = l.indexOf('void initState() {');
      final govde = l.substring(i, l.indexOf('\n  }', i));
      expect(govde.contains('_kilidiTazele()'), isTrue);
    });

    test('sayaç dispose edilir', () {
      expect(l.contains('_kilitSayaci?.cancel();'), isTrue);
      final i = l.indexOf('void dispose() {');
      final govde = l.substring(i, l.indexOf('\n  }', i));
      expect(govde.contains('_kilitSayaci?.cancel();'), isTrue);
    });

    test('kilit mesajı FORM DÜZEYİNDE ve öncelikli gösterilir', () {
      // ⚠ Kilit artık validator'dan değil, alanların üstündeki tek
      // satırdan geliyor. Sıra: kilit > iş kuralı > sistem.
      final i = l.indexOf('_kilitMesaji ?? _isHatasi ?? _sistemHatasi!');
      expect(i, greaterThan(0), reason: 'öncelik sırası bozulmuş');
      expect(l.contains('String? get _kilitMesaji =>'), isTrue);
    });
  });

  group('DEPO SÖZLEŞMESİ', () {
    test('kalan süre dışarıya AÇIK', () {
      final r = _kod('lib/data/repositories/auth_repository.dart');
      expect(r.contains('int girisKilidiKalan(String phone) =>'), isTrue);
      final p = _kod('lib/data/ports/repository_ports.dart');
      expect(p.contains('int girisKilidiKalan(String phone);'), isTrue);
      final m = _kod('lib/data/ports/mock_ports.dart');
      expect(m.contains('int girisKilidiKalan(String phone) => repo.'), isTrue);
      final a = _kod('lib/data/ports/api_ports.dart');
      expect(a.contains('int girisKilidiKalan(String phone) => 0;'), isTrue,
          reason: 'API modunda kilit sunucudadır, uydurulmaz');
      final c = _kod('lib/data/controllers/auth_controller.dart');
      expect(c.contains('int girisKilidiKalan(String phone) =>'), isTrue);
    });

    test('kilit gerçekten oluşur ve kalan süre okunur', () {
      final auth = AuthRepository(seedTestAccount: false);
      auth.register(
        phone: '5321119988',
        pass: 'abc123',
        email: 'k1@example.com',
        role: Role.customer,
        otpVerified: true,
        termsAccepted: true,
      );
      // Kilitten önce kalan süre 0.
      expect(auth.girisKilidiKalanEposta('k1@example.com'), 0);

      // Beş hatalı deneme kilidi açar.
      for (var i = 0; i < 5; i++) {
        expect(auth.girisEposta('k1@example.com', 'yanlis$i'), isNotNull);
      }
      expect(auth.girisKilidiKalanEposta('k1@example.com'), greaterThan(0));

      // Kilitliyken DOĞRU şifre de reddedilir.
      expect(auth.girisEposta('k1@example.com', 'abc123'), isNotNull);
    });

    test('kilit NUMARAYA aittir, başka numarayı etkilemez', () {
      final auth = AuthRepository(seedTestAccount: false);
      for (final t in ['5321110001', '5321110002']) {
        auth.register(
          phone: t,
          pass: 'abc123',
          email: '$t@example.com',
          role: Role.customer,
          otpVerified: true,
          termsAccepted: true,
        );
      }
      for (var i = 0; i < 5; i++) {
        auth.girisEposta('5321110001@example.com', 'yanlis');
      }
      expect(auth.girisKilidiKalanEposta('5321110001@example.com'), greaterThan(0));
      expect(auth.girisKilidiKalanEposta('5321110002@example.com'), 0);
      expect(auth.girisEposta('5321110002@example.com', 'abc123'), isNull);
    });

    test('başarılı giriş sayacı sıfırlar', () {
      final auth = AuthRepository(seedTestAccount: false);
      auth.register(
        phone: '5321110003',
        pass: 'abc123',
        email: 'k3@example.com',
        role: Role.customer,
        otpVerified: true,
        termsAccepted: true,
      );
      // Dört hatalı deneme kilit açmaz.
      for (var i = 0; i < 4; i++) {
        auth.girisEposta('k3@example.com', 'yanlis');
      }
      expect(auth.girisKilidiKalanEposta('k3@example.com'), 0);
      expect(auth.girisEposta('k3@example.com', 'abc123'), isNull);
      // Sayaç sıfırlandığı için yeniden dört hatalı deneme yetmez.
      for (var i = 0; i < 4; i++) {
        auth.girisEposta('k3@example.com', 'yanlis');
      }
      expect(auth.girisKilidiKalanEposta('k3@example.com'), 0);
    });
  });

  group('TEST GİRİŞ BİLGİSİ GERÇEKTEN ÇALIŞIR', () {
    test('kutuda yazan e-posta ve şifre ile giriş yapılır', () {
      // ⚠ Kutu telefon numarası gösteriyordu; o değerle e-posta
      // alanı doldurulunca giriş imkânsızdı. Gösterilen bilgi
      // tohumlanan hesapla AYNI olmak zorunda.
      final auth = AuthRepository();
      expect(auth.girisEposta(kTestEmail, kTestPass), isNull);
      expect(auth.loggedIn, isTrue);
    });

    test('kutu MODA GÖRE doğru kimliği gösterir', () {
      // ⚠ Telefon modunda da e-posta gösteriliyordu; o değer telefon
      // alanına yazılamaz. Her mod kendi kimliğini gösterir ve ikisi
      // de TOHUMLANAN hesaba aittir.
      final l = _kod('lib/screens/login_screen.dart');
      final r = _kod('lib/data/repositories/auth_repository.dart');

      expect(l.contains("'Test girişi — E-posta: '"), isTrue);
      expect(l.contains("'Test girişi — Telefon: '"), isTrue);
      expect(l.contains("? 'test@hizmetcep.com'"), isTrue);
      expect(l.contains("'0532 111 22 33'"), isTrue);

      // Tohumlanan hesapla eşleşme.
      expect(r.contains("email: 'test@hizmetcep.com'"), isTrue);
      expect(r.contains("phone: '5321112233'"), isTrue);
    });

    test('kutuda yazan TELEFON + şifre ile de giriş yapılır', () {
      final auth = AuthRepository();
      expect(auth.girisTelefonSifre('0532 111 22 33', kTestPass), isNull);
      expect(auth.loggedIn, isTrue);
    });
  });
}
