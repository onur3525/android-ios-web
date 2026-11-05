// WEB: SEKME GERİ AÇILINCA "SAYFA BULUNAMADI" ÇIKMAZ (5 Kas, kullanıcı bulgusu)
//
// Kayıt/doğrulama akışı ekranları (önceki adımın bellekteki bilgisine
// muhtaç) kaldığı ekran olarak saklanmaz; eski kayıt yok sayılır; saklı
// ekran kurulamazsa 404 yerine başlangıç ekranına dönülür.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/global_web_kabugu.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('akış ekranları tek listede', () {
    expect(kGeriYuklenmeyenRotalar, {
      '/sosyal-kayit',
      '/profil-tamamla',
      '/kayit',
      '/dogrulama',
      '/sifremi-unuttum',
    });
  });

  test('akış ekranları sekme deposuna yazılmaz', () {
    final k = _kod('lib/ui/global_web_kabugu.dart');
    final i = k.indexOf('sekmeYaz(kSekmeRota, yeni);');
    final once = k.substring(k.lastIndexOf('if (kIsWeb &&', i), i);
    expect(once.contains('!kGeriYuklenmeyenRotalar.contains(yeni)'), isTrue);
  });

  test('açılışta eski akış kaydı yok sayılır; kurulamayan ekranda 404 yok', () {
    final m = _kod('lib/main.dart');
    expect(m.contains('!kGeriYuklenmeyenRotalar.contains(kayitli) &&'), isTrue);
    expect(m.contains('settings.name == geriYuklenenRota &&'), isTrue);
    expect(m.contains('builder: (_) => _BaslangicaDon(yedek),'), isTrue);
    expect(m.contains('builder: (_) => const BulunamadiScreen(),'), isTrue,
        reason: 'elle yazılan yanlış adres yine 404');
  });
}
