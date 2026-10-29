// İLETİŞİM İKİ TARAF İÇİN DE AÇIK (29 Eki, kullanıcı isteği): "İletişimi
// hangi taraf açarsa açsın iki taraf için de otomatik olarak açılmalı."
// Sunucu teklif listelerinde `contactOpen` döndürür; uygulama bunu
// iletişim deposuna işler, karşı taraf "İletişimi Aç"a basmadan açık görür.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/api/contact_api.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';

import 'support/fake_backend.dart';

void main() {
  test('ham listeden yalnız contactOpen=true olan teklifler alınır', () {
    expect(
        iletisimiAcikTeklifler(<dynamic>[
          {'id': 'o1', 'contactOpen': true},
          {'id': 'o2', 'contactOpen': false},
          {'id': 'o3'},
          {'contactOpen': true},
          'bozuk',
        ]),
        ['o1']);
  });

  test('sunucudan gelen açık iletişim depoya işlenir; değişmezse haber verilmez', () {
    final repo = ApiContactRepository(ContactApi(FakeBackend({}).client()));
    var haber = 0;
    repo.addListener(() => haber++);
    expect(repo.isOpen('o1'), isFalse);
    repo.sunucudanAcik(['o1']);
    expect(repo.isOpen('o1'), isTrue);
    expect(haber, 1);
    repo.sunucudanAcik(['o1']);
    expect(haber, 1, reason: 'aynı bilgi tekrar gelince ekranlar boşuna çizilmez');
    repo.sunucudanAcik(const []);
    expect(repo.isOpen('o1'), isTrue, reason: 'iletişim açıldıktan sonra kapanmaz');
  });

  test('teklif ve ilan depoları AYNI iletişim deposuna bağlı', () {
    final m = File('lib/main.dart').readAsStringSync();
    expect(m.contains('offerRepo.iletisimAciklariAktar = contactRepo.sunucudanAcik;'), isTrue);
    expect(m.contains('listingRepo.iletisimAciklariAktar = contactRepo.sunucudanAcik;'), isTrue);
    expect(m.contains('contact: ApiContactPort(contactRepo),'), isTrue);
  });
}
