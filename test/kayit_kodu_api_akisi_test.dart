// 15 Eki — GERÇEK API MODUNDA KAYIT KODU
//
//   · "Geliştirme sürümü test kodu: 123456" yalnız TEST MODU + MOCK'ta görünür.
//   · API modunda kod Firebase ile gönderilir/doğrulanır; sunucu kanıtı
//     ayrıca doğrular. Sabit kod bu yolda HİÇ kullanılmaz.
//   · Kod gönderilemezse doğrulama adımına geçilmez; "Kodu Tekrar Gönder"
//     sahte başarı üretmez.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  test('test kodu ipucu yalnız test modu + mock', () {
    final o = _kod('lib/screens/otp_screen.dart');
    expect(
        RegExp(r'if \(TestModu\.etkin && !ApiConfig\.useRealApi\)')
            .allMatches(o)
            .length,
        2);
    final s = _kod('lib/data/services/otp_service.dart');
    expect(s.contains('return TestModu.etkin && code == _debugCode;'), isTrue);
    expect(
        _kod('lib/core/test_modu.dart')
            .contains('static const bool etkin = !kReleaseMode'),
        isTrue);
  });

  test('kayıt ekranı: kod gönderilemezse doğrulama ekranı açılmaz', () {
    final r = _kod('lib/screens/register_screen.dart');
    expect(r.contains('if (ch.challengeId.isEmpty) {'), isTrue);
    expect(r.contains('if (yeni.challengeId.isEmpty) {'), isTrue);
    expect(r.contains('return FormMesaj.otpGonderilemedi;'), isTrue);
  });

  test('oturumsuz ilan akışı: API modunda gerçek gönderim ve doğrulama', () {
    final c = _kod('lib/screens/create_listing_screen.dart');
    expect(c.contains('.kayitKodGonder('), isTrue);
    expect(c.contains('.kayitDogrula(challenge, _otp.kod)'), isTrue);
    expect(c.contains('kayitYetkisi: _kayitYetkisi,'), isTrue);
    // Mock yolu DEĞİŞMEDİ.
    expect(c.contains('await MockOtpService().verify(telefon, _otp.kod)'),
        isTrue);
    // API modunda yalnız uzunluğa bakılıp geçilmez.
    expect(c.contains('? _otp.kod.length == 6'), isFalse);
    final a = _kod('lib/screens/widgets/ilan_otp_adimi.dart');
    expect(a.contains('final Future<String?> Function()? yenidenGonder;'),
        isTrue);
    expect(a.contains('onTap: _tekrarGonder,'), isTrue);
    expect(a.contains('onTap: _sayacBaslat,'), isFalse);
  });
}
