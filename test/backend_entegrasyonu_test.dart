import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/api/category_api.dart';
import 'package:hizmetcep/screens/category_ui.dart';
import 'package:hizmetcep/data/repositories/demo_hesap_ozetleri.dart';
import 'package:hizmetcep/domain/password_hasher.dart';

import 'support/test_config.dart';

/// BACKEND ENTEGRASYONU — Flutter tarafı (admin paneli + backend turu)
///
/// ⚠ Mock mod (web demosu, testler) DEĞİŞMEDİ: yeni parçaların hepsi
/// yalnız API modunda devreye girer.
String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('ASKI / BAN', () {
    test('sunucu kodları tanınır, mesaj olduğu gibi gösterilir', () {
      final m = _kod('lib/data/remote/api_error_mapper.dart');
      expect(m.contains("case 'ACCOUNT_SUSPENDED':"), isTrue);
      expect(m.contains("case 'ACCOUNT_BANNED':"), isTrue);
    });
    test('oturum MEVCUT oturum-düşme yoluyla kapanır (yeni ekran yok)', () {
      final c = _kod('lib/data/remote/api_client.dart');
      expect(c.contains("(kod == 'ACCOUNT_SUSPENDED' || kod == 'ACCOUNT_BANNED')"), isTrue);
      expect(c.contains('await _forceLogout();'), isTrue);
    });
  });

  group('TEKLİF TALEBİ API PORTU', () {
    test('yalnız API modunda; mock mod aynen', () {
      final m = _kod('lib/main.dart');
      expect(m.contains('final TeklifTalebiPort teklifTalebiPort = ApiConfig.useRealApi'), isTrue);
      expect(m.contains('? ApiTeklifTalebiPort(ports.apiClient)'), isTrue);
      expect(m.contains(': MockTeklifTalebiPort('), isTrue);
    });
    test('durum eşlemesi sunucunun altı durumunu kapsar', () {
      final p = _kod('lib/data/remote/api_teklif_talebi_port.dart');
      for (final d in ['TEKLIF_GELDI', 'SECILDI', 'REDDEDILDI', 'SURESI_DOLDU', 'TAMAMLANDI']) {
        expect(p.contains("'$d' =>"), isTrue, reason: d);
      }
      expect(p.contains('_ => TeklifTalebiDurumu.beklemede'), isTrue);
    });
  });

  group('YASAL KABUL KAPISI', () {
    test('yalnız API modunda çalışır; kökte bağlı', () {
      final k = _kod('lib/ui/yasal_kabul_kapisi.dart');
      expect(k.contains('if (!ApiConfig.useRealApi || _auth != null) {'), isTrue);
      expect(k.contains("'/legal/pending-acceptances'"), isTrue);
      expect(k.contains("'sha256': '\${b['sha256']}'"), isTrue);
      expect(_kod('lib/main.dart').contains('child: YasalKabulKapisi('), isTrue);
    });
  });

  group('ADMİN İKON ATAMASI', () {
    test('yalnız paketteki ikon kabul edilir; bilinmeyen yol yok sayılır', () {
      final bilinen = kKategoriIkonu.values.first;
      final j = {
        'items': [
          {'category': 'Admin Yeni Kategori', 'active': true, 'icon': bilinen, 'services': ['A']},
          {'category': 'Kötü İkon', 'active': true, 'icon': 'https://kotu.com/x.svg', 'services': ['B']},
        ],
      };
      sunucuIkonlariniAyarla(CategoryApi.ikonlar(j));
      expect(categoryIcon('Admin Yeni Kategori'), bilinen);
      expect(categoryIcon('Kötü İkon'), 'assets/svg/ic_build.svg');
      sunucuIkonlariniAyarla(const {});
      expect(categoryIcon('Admin Yeni Kategori'), 'assets/svg/ic_build.svg');
    });
  });

  group('GİRİŞ EKRANI', () {
    test('demo hesap bilgisi GÖSTERİLMEZ; lib/ altında düz demo şifresi yok', () {
      final l = _kod('lib/screens/login_screen.dart');
      expect(l.contains('Demo hesap'), isFalse);
      expect(l.contains('kTestPass'), isFalse);
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        expect(f.readAsStringSync().contains(kTestPass), isFalse, reason: f.path);
      }
    });
    test('demo hesabın özeti test şifresiyle eşleşir (OTP/kayıt akışı için)', () {
      expect(PasswordHasher.verify(kTestPass, kDemoMusteriTuz, kDemoMusteriOzet), isTrue);
    });
  });
}
