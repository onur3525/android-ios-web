// HİZMET BÖLGELERİM — KAYITLI İLÇELER GÖRÜNÜR (16 Eki, kullanıcı bulgusu)
//
// Kayıtta seçilen ilçeler ekranda işaretli gelmeli, il kayıtlı ilçelerin
// ilinden seçili olmalı ve kullanıcı değiştirip kaydedebilmeli.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/region_controller.dart';
import 'package:hizmetcep/data/models/region.dart';
import 'package:hizmetcep/data/ports/repository_ports.dart';
import 'package:hizmetcep/domain/failures.dart';

String _oku(String p) => File(p).readAsStringSync();

class _SahteBolge implements RegionPort {
  @override
  Future<(RegionTree?, DomainError?)> regionTree() async => (
        RegionTree.fromJson(const {
          'cities': [
            {
              'id': 'c1',
              'name': 'İstanbul',
              'districts': [
                {'id': 'd1', 'name': 'Kadıköy'},
              ],
            },
            {
              'id': 'c2',
              'name': 'İzmir',
              'districts': [
                {'id': 'd2', 'name': 'Konak'},
                {'id': 'd3', 'name': 'Bornova'},
              ],
            },
          ],
        }),
        null,
      );
}

void main() {
  test('kayıtlı ilçelerin ili bulunur (varsayılan il değil)', () async {
    final r = RegionController(_SahteBolge());
    await r.load();
    expect(r.ilceleriIcerenIl({'Bornova'}), 'İzmir');
    expect(r.ilceleriIcerenIl({'Kadıköy'}), 'İstanbul');
    expect(r.ilceleriIcerenIl(const {}), isNull);
    expect(r.ilceleriIcerenIl({'Olmayan'}), isNull);
  });

  group('ekran sözleşmesi', () {
    final s = _oku('lib/screens/my_areas_screen.dart');

    test('veri sonradan gelirse ekran yenilenir (watch) ve eşitlenir', () {
      expect(s.contains('context.watch<RegionController>()'), isTrue);
      expect(s.contains('_kayitliyaEsitle(bolge, context.watch<ProfileController>());'), isTrue);
      expect(s.contains('r.ilceleriIcerenIl(_selected) ?? r.soleCityName ?? r.cityName'), isTrue);
      expect(s.contains('didChangeDependencies'), isFalse);
    });

    test('kullanıcı değişikliği korunur ve kaydedilir', () {
      expect(s.contains('if (!_secimDegisti) {'), isTrue);
      expect(s.contains('_secimDegisti = true;'), isTrue);
      expect(s.contains('.setDistricts(_selected)'), isTrue);
    });

    test('"tümünü seç" seçili ilin ilçelerini alır', () {
      expect(s.contains('_selected = {...context.read<RegionController>().districtsOf(_il)};'), isTrue);
    });

    test('bölge ağacı yoksa yeniden yüklenir; hata ekranı tekrar dener', () {
      expect(s.contains('context.read<RegionController>().load();'), isTrue);
      expect(s.contains('onAction: bolge.retry'), isTrue);
    });
  });

  test('Rol Değiştir aynı kaynaktan il seçer', () {
    expect(_oku('lib/screens/role_switch_screen.dart').contains('r.ilceleriIcerenIl(_bolgeler)'), isTrue);
  });
}
