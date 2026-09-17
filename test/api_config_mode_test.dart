import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/api_config.dart';
import 'support/kaynak_okuma.dart';

/// VERİ KAYNAĞI SEÇİMİ + MOCK BUILD SÖZLEŞMESİ
///
/// Talimat: `HizmetCep_Claude_Mock_APK_Boot_Duzeltme_Talimati`
void main() {
  group('ApiConfig.mode — çalışma zamanı', () {
    // `String.fromEnvironment` DERLEME ZAMANI sabittir; test süreci
    // dart-define almadan koştuğu için `raw` boştur.
    //
    // Bu grup, testin koştuğu gerçek derleme modunda beklenen sonucu
    // doğrular. Diğer kombinasyonlar aşağıda KAYNAK düzeyinde
    // sözleşme olarak kontrol edilir.
    test('DEBUG + DATA_SOURCE boş → mock', () {
      if (kReleaseMode) {
        return; // bu dal aşağıdaki release testinde doğrulanır
      }
      expect(ApiConfig.mode, DataSourceMode.mock,
          reason: 'dart-define unutulduğunda sessizce API\'ye düşmemeli');
      expect(ApiConfig.useRealApi, isFalse);
    });

    test('RELEASE → her koşulda api', () {
      if (!kReleaseMode) {
        return;
      }
      expect(ApiConfig.mode, DataSourceMode.api);
      expect(ApiConfig.useRealApi, isTrue);
    });
  });

  group('ApiConfig.mode — sözleşme (kaynak düzeyi)', () {
    final src = File('lib/data/remote/api_config.dart').readAsStringSync();
    final govde = src.substring(
        src.indexOf('static DataSourceMode get mode'),
        src.indexOf('static bool get useRealApi'));

    test('1) release kontrolü EN BAŞTA ve koşulsuz api döner', () {
      final iRelease = govde.indexOf('if (kReleaseMode)');
      final iApi = govde.indexOf("if (raw == 'api')");
      final iMockReturn = govde.indexOf('return DataSourceMode.mock;');
      expect(iRelease, greaterThan(0), reason: 'release kontrolü yok');
      expect(iRelease, lessThan(iApi),
          reason: 'release kontrolü diğer dallardan ÖNCE olmalı');
      expect(iRelease, lessThan(iMockReturn),
          reason: 'release dalı mock dönüşünden ÖNCE olmalı');
      // Release dalı doğrudan api döner.
      expect(
          RegExp(r'if \(kReleaseMode\) \{\s*return DataSourceMode\.api;')
              .hasMatch(govde),
          isTrue);
    });

    test('2) DEBUG + DATA_SOURCE=api → api', () {
      expect(
          RegExp(r"if \(raw == 'api'\) \{\s*return DataSourceMode\.api;")
              .hasMatch(govde),
          isTrue);
    });

    test('3) DEBUG + mock/boş → mock (varsayılan dönüş)', () {
      // Metodun SON dönüşü mock olmalı: boş değer buraya düşer.
      expect(govde.trimRight().endsWith('return DataSourceMode.mock;\n  }'),
          isTrue,
          reason: 'debug varsayılanı mock olmalı');
    });

    test('release\'te mock İMKÂNSIZ — mock dönüşü release dalından sonra', () {
      // `kReleaseMode` erken dönüş yaptığı için mock satırına
      // release derlemede ULAŞILAMAZ.
      final iRelease = govde.indexOf('return DataSourceMode.api;');
      final iMock = govde.indexOf('return DataSourceMode.mock;');
      expect(iRelease, lessThan(iMock));
      // Eski hatalı desen geri gelmemeli.
      expect(govde.contains('kReleaseMode ? DataSourceMode.api'), isFalse,
          reason: 'release kontrolü mock dalının İÇİNDE olmamalı');
    });
  });

  group('Codemagic — mock build sözleşmesi', () {
    final yaml = File('codemagic.yaml').readAsStringSync();

    test('debug APK MOCK modda derlenir', () {
      final i = yaml.indexOf('name: Debug APK');
      expect(i, greaterThan(0), reason: 'Debug APK adımı yok');
      final blok = yaml.pencere(i, 500);
      final komut = RegExp(r'script: (flutter build apk[^\n]*)')
          .firstMatch(blok)
          ?.group(1);
      expect(komut, isNotNull, reason: 'build komutu bulunamadı');
      expect(komut!.contains('--dart-define=DATA_SOURCE=mock'), isTrue,
          reason: 'mock olmadan APK backend bekler ve splash uzar');
      expect(komut.contains('--debug'), isTrue);
    });
  });
}
