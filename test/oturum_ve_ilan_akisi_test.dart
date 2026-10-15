// OTURUM SÜREKLİLİĞİ VE İLAN AKIŞI (15 Eki, kullanıcı bulguları)
//
//   1. Mobil açılış: "Beni hatırla" bayrağı artık şart değil; GERÇEK
//      oturum varsa rol paneline gidilir. Sunucu kısa bütçede yanıt
//      vermezse ama cihazda jeton varsa "Bağlanılıyor" ekranı bekler.
//   2. Hizmet veren "Yeni işler" listesi kendiliğinden yenilenir (30 sn,
//      öne gelince, uygulama açıkken gelen yeni ilan bildirimi).
//   3. Hizmet alan gelen teklifleri görür: ilan uçlarının `offers` alanı
//      teklif deposuna aktarılır (web ve mobil API modu).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/notification.dart';
import 'package:hizmetcep/data/models/offer.dart';
import 'package:hizmetcep/data/remote/api/offer_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/mappers.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';

String _oku(String p) => File(p).readAsStringSync();

Offer _teklif(String id, String ilan, {String saglayici = 'p1'}) => Offer(
      id: id,
      listingId: ilan,
      providerId: saglayici,
      amount: 500,
      note: '',
      status: OfferStatus.active,
    );

void main() {
  group('1 — MOBİL AÇILIŞ', () {
    final sp = _oku('lib/screens/splash_screen.dart');

    test('"Beni hatırla" bayrağı açılışı engellemez; tek ölçüt gerçek oturum', () {
      expect(sp.contains('OturumTercihi().hatirlaniyor'), isFalse);
      expect(sp.contains('if (acc == null) {'), isTrue);
    });

    test('sunucu yavaşsa ve cihazda jeton varsa "Bağlanılıyor" ekranı bekler', () {
      expect(sp.contains('_oturumBekle = await _cihazdaOturumVar();'), isTrue);
      expect(sp.contains('BaglaniyorEkrani.bekleyen = _oturumuBekle('), isTrue);
      expect(sp.contains('pushReplacementNamed(BaglaniyorEkrani.rota)'), isTrue);
      // Sunucu jetonu reddederse beklemek bırakılır (sonsuz bekleme yok).
      expect(sp.contains('if (await TokenStore().refreshToken() == null) {'), isTrue);
      // Kesin kural: jeton durdukça süre sınırı olmadan beklenir.
      expect(sp.contains('while (auth.currentAccount == null) {'), isTrue);
    });
  });

  group('2 — HİZMET VEREN LİSTESİ KENDİLİĞİNDEN YENİLENİR', () {
    test('30 sn zamanlayıcı ve öne gelince tazeleme; ekran kapanınca durur', () {
      final j = _oku('lib/screens/jobs_screen.dart');
      expect(j.contains('Timer.periodic(_kOtomatikYenileme'), isTrue);
      expect(j.contains('AppLifecycleState.resumed'), isTrue);
      expect(j.contains('_zamanlayici?.cancel();'), isTrue);
    });

    test('ilk açılışta teklif verdiğim ilan bir an görünüp kaybolmaz: '
        'önce tekliflerim, sonra ilanlar yüklenir', () {
      final j = _oku('lib/screens/jobs_screen.dart');
      final iTeklif = j.indexOf('await context.read<OfferController>().loadMine();');
      final iIlan = j.indexOf('await context.read<ListingController>().loadAvailable();');
      expect(iTeklif, greaterThan(0));
      expect(iIlan, greaterThan(iTeklif));
    });

    test('uygulama açıkken gelen yeni ilan bildirimi listeyi tazeler', () {
      final p = _oku('lib/ui/push_kapisi.dart');
      expect(p.contains("tur == 'NEW_LISTING' && _auth?.activeRole == Role.provider"), isTrue);
      expect(p.contains('ilanlar?.loadAvailable()'), isTrue);
    });

    test('yeni ilan bildirimi türü tanınır', () {
      expect(Mappers.notifType('NEW_LISTING'), NotifType.newListing);
    });
  });

  group('3 — HİZMET ALAN TEKLİFLERİ GÖRÜR', () {
    test('ilan uçlarının teklifleri teklif deposuna aktarılır (main bağlar)', () {
      expect(_oku('lib/main.dart').contains('..teklifleriAktar = offerRepo.ilanTeklifleriniAl;'), isTrue);
      expect(_oku('lib/data/remote/repositories/api_repositories.dart').contains('_teklifleriAyikla(res);'), isTrue);
    });

    test('aktarılan teklifler ilan için listelenir; sunucuda kalmayan teklif düşer', () {
      final repo = ApiOfferRepository(OfferApi(ApiClient()));
      repo.ilanTeklifleriniAl('l1', [_teklif('o1', 'l1'), _teklif('o2', 'l1')]);
      expect(repo.forListing('l1').map((o) => o.id).toSet(), {'o1', 'o2'});
      repo.ilanTeklifleriniAl('l1', [_teklif('o2', 'l1')]);
      expect(repo.forListing('l1').map((o) => o.id), ['o2']);
      // Başka ilanın teklifleri etkilenmez.
      repo.ilanTeklifleriniAl('l2', [_teklif('o3', 'l2')]);
      expect(repo.forListing('l1').map((o) => o.id), ['o2']);
    });

    test('teklif seçiminin yanıtı (ilan) teklif gibi çözülmez', () {
      final r = _oku('lib/data/remote/repositories/api_repositories.dart');
      expect(r.contains('_mutate('), isFalse);
      expect(r.contains('final (_, err) = await _guard(() => _api.select(listingId,'), isTrue);
    });
  });
}
