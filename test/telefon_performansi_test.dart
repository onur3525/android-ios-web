// TELEFON PERFORMANSI (28 Eki, kullanıcı isteği): gereksiz yeniden çizim
// ve gereksiz indirme kaldırıldı. (Anlık tazeleme: anlik_tazeleme_test;
// değişmediyse 304: okuma_onbellegi_test.)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/katalog_tazeleme.dart';

String _kod(String p) => File(p).readAsStringSync();

void main() {
  group('1 — alt bar rozetleri ekranı boşuna çizdirmez', () {
    test('rozetler select ile okunur (watch yok)', () {
      final k = _kod('lib/screens/nav_actions.dart');
      expect(k.contains('context.select<AuthController, String?>((a) => a.currentAccount?.id)'), isTrue);
      expect(k.contains('context.select<NotificationController, bool>('), isTrue);
      expect(k.contains('context.select<TeklifTalebiController, int>('), isTrue);
      expect(k.contains('context.watch<NotificationController>()'), isFalse);
      expect(k.contains('context.watch<TeklifTalebiController>()'), isFalse);
      // Ölçüt aynı: role göre süzülmüş okunmamış sayısı.
      expect(k.contains('rolOkunmamisSayisi(n.forUser(meId), rol) > 0'), isTrue);
    });
  });

  group('2 — karşı taraf özeti değişmediyse haber yok', () {
    test('2 dk tazelemesinde aynı özet bütün ekranları yeniden çizdirmez', () {
      final k = _kod('lib/data/ports/api_ports.dart');
      final i = k.indexOf('Future<void> _ozetGetir(String id) async {');
      final govde = k.substring(i, k.indexOf('\n  }', i));
      expect(govde.contains('_ozetImzasi(onceki) == _ozetImzasi(hesap)'), isTrue);
      expect(govde.indexOf('return;\n    }\n    notifyListeners();'), greaterThan(0));
    });
  });

  group('3 — katalog öne gelmede yenilenir (tek kaynak)', () {
    test('açılış ve öne gelme aynı işlevi kullanır', () {
      expect(_kod('lib/screens/splash_screen.dart')
          .contains('await KatalogTazeleme.tazele(client!).timeout(_kConfigButce);'), isTrue);
      final kapi = _kod('lib/ui/anlik_tazeleme.dart');
      expect(kapi.contains('unawaited(KatalogTazeleme.gerekirseTazele(client));'), isTrue);
      // Katalog herkese açık: oturum yokken de denetlenir.
      final i = kapi.indexOf('void didChangeAppLifecycleState(');
      final govde = kapi.substring(i, kapi.indexOf('\n  }\n', i));
      expect(govde.indexOf('KatalogTazeleme'), lessThan(govde.indexOf('if (_kullanici != null)')));
    });

    test('en sık 5 dakikada bir; değişmeyen katalog yeniden yerleştirilmez', () {
      expect(KatalogTazeleme.enAzAralik, const Duration(minutes: 5));
      final k = _kod('lib/ui/katalog_tazeleme.dart');
      expect(k.contains('if (imza != null && imza == _sonImza) {'), isTrue);
    });
  });

  group('4 — sunucu: sıkıştırma, 304 ve sabit fotoğraf adresi', () {
    test('kullanıcı API okumaları tek yerden', () {
      final s = _kod('backend/src/server.js');
      expect(s.contains("if (req.method === 'GET' && yol.startsWith('/api/v1/')) return okumaYanitiGonder(req, res, sonuc, baslik);"), isTrue);
      expect(_kod('backend/src/gorsel_adresleri.js').contains('simdi: zaman'), isTrue);
      expect(_kod('backend/src/depo_dogrulama.js').contains('simdi: imzaZamani()'), isTrue);
    });
  });
}
