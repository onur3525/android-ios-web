// 15 Eki kullanıcı bulguları:
//  · "Numaraya basınca siyah ekran gelip kayboluyor" — web'de tel: yeni
//    sekmede açılıyordu.
//  · "1. girişimde ana sayfaya, 2. girişimde rol ekranıma gidiyor" — sunucu
//    uykudayken oturum zamanında yenilenemiyordu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String p) => File(p).readAsStringSync();

void main() {
  group('telefonla arama tek kaynak', () {
    test('ekranlarda kopya yok; hepsi telefonuAra çağırır', () {
      for (final yol in const [
        'lib/screens/job_detail_screen.dart',
        'lib/screens/offer_detail_screen.dart',
        'lib/screens/chat_screen.dart',
        'lib/screens/teklif_talebi_detay_screen.dart',
      ]) {
        final k = _oku(yol);
        expect(k.contains("Uri.parse('tel:"), isFalse, reason: yol);
        expect(k.contains('telefonuAra(context,'), isTrue, reason: yol);
      }
    });

    test("web'de aynı sekmede açılır; mobil mod değişmez", () {
      final k = _oku('lib/core/telefon_arama.dart');
      expect(k.contains("webOnlyWindowName: kIsWeb ? '_self' : null"), isTrue);
      expect(k.contains('mode: acilisModu()'), isTrue);
      expect(k.contains("'Arama uygulaması açılamadı'"), isTrue,
          reason: 'sahte başarı uyarısı korunmalı');
    });
  });

  group('sunucu uykudayken oturumlu web açılışı', () {
    test('oturum izi yalnız web dalında yazılır ve çıkışta silinir', () {
      final k = _oku('lib/data/remote/token_store.dart');
      expect(k.contains("kaliciYaz(kOturumIzi, '1');"), isTrue);
      expect(k.contains("kaliciYaz(kOturumIzi, '0');"), isTrue);
      final c = _oku('lib/data/remote/api_client.dart');
      expect(c.contains('if (cerezliOturum && res.statusCode == 401) {'), isTrue,
          reason: 'sunucu çerezi reddedince iz silinmeli');
    });

    test('iz varsa ana sayfa yerine Bağlanılıyor ekranı, yoksa ana sayfa', () {
      final m = _oku('lib/main.dart');
      expect(m.contains('} on TimeoutException {'), isTrue);
      expect(m.contains('if (oturumIziVar()) {'), isTrue);
      expect(m.contains('ilkRota = BaglaniyorEkrani.rota;'), isTrue);
      expect(m.contains('BaglaniyorEkrani.rota: (_) => const BaglaniyorEkrani(),'),
          isTrue);
      expect(_oku('lib/ui/global_web_kabugu.dart').contains("yeni != '/baglaniyor'"),
          isTrue, reason: 'geçici ekran sekme rotası olarak saklanmamalı');
    });
  });
}
