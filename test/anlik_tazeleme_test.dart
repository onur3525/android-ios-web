// ANLIK TAZELEME (28 Eki, kullanıcı kararı): "Ekran 30 saniyede bir
// yenilenmesin; yeni teklif veya ilan gelince yenilensin." Zamanlayıcılar
// kaldırıldı; tazeleme sunucunun anlık haberiyle, push ile, öne gelmede ve
// yeniden bağlanmada uygulama genelinde tek yerden, sessizce yapılır. Veri
// değişmediyse ekran yeniden çizilmez.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/base_controller.dart';
import 'package:hizmetcep/data/models/account.dart' show Role;
import 'package:hizmetcep/data/remote/api/listing_api.dart';
import 'package:hizmetcep/data/remote/api/notification_api.dart';
import 'package:hizmetcep/data/remote/api/offer_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/repositories/api_chat_repositories.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';
import 'package:hizmetcep/data/remote/veri_imzasi.dart';
import 'package:hizmetcep/data/remote/ws_auth.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/ui/anlik_tazeleme.dart';

String _kod(String p) => File(p).readAsStringSync();

class _SahteIlanApi extends ListingApi {
  _SahteIlanApi() : super(ApiClient());
  List<dynamic> yanit = [];
  @override
  Future<List<dynamic>> my() async => yanit;
  @override
  Future<List<dynamic>> available({String? category, String? district}) async => yanit;
}

class _SahteTeklifApi extends OfferApi {
  _SahteTeklifApi() : super(ApiClient());
  List<dynamic> yanit = [];
  @override
  Future<List<dynamic>> my() async => yanit;
}

class _SahteBildirimApi extends NotificationApi {
  _SahteBildirimApi() : super(ApiClient());
  List<dynamic> yanit = [];
  int sayi = 0;
  @override
  Future<List<dynamic>> list() async => yanit;
  @override
  Future<Map<String, dynamic>> unreadCount() async => {'count': sayi};
}

class _Denetleyici extends BaseController {
  _Denetleyici() : super(const []);
}

Map<String, dynamic> _ilan(String id, {String baslik = 'Musluk tamiri'}) => {
      'id': id, 'ownerId': 'u1', 'title': baslik, 'location': 'Bornova',
      'description': 'Mutfak musluğu damlatıyor', 'status': 'ACTIVE',
      'photoPaths': <String>[], 'createdAt': '2026-01-01T10:00:00.000Z',
    };

Map<String, dynamic> _teklif(String id, {int tutar = 750}) => {
      'id': id, 'listingId': 'l1', 'providerId': 'p1', 'amountTl': tutar,
      'note': '', 'status': 'PENDING', 'createdAt': '2026-01-01T10:00:00.000Z',
    };

Map<String, dynamic> _bildirim(String id) => {
      'id': id, 'userId': 'u1', 'type': 'NEW_OFFER', 'title': 'Yeni teklif',
      'body': 'x', 'refId': 'l1', 'readAt': null,
      'createdAt': '2026-10-02T09:00:00.000Z',
    };

void main() {
  group('1 — haber türü → yalnız ilgili veri', () {
    test('yeni ilan: hizmet verende Yeni işler; hizmet alanda yalnız bildirim', () {
      expect(AnlikTazeleme.isler('NEW_LISTING', Role.provider),
          {TazelemeIsi.bildirimler, TazelemeIsi.yeniIsler});
      expect(AnlikTazeleme.isler('NEW_LISTING', Role.customer), {TazelemeIsi.bildirimler});
    });

    test('teklif olayları: hizmet alanda ilanlarım, hizmet verende tekliflerim', () {
      for (final t in ['NEW_OFFER', 'OFFER_SELECTED', 'CONTACT_OPENED', 'LISTING_EXPIRED']) {
        expect(AnlikTazeleme.isler(t, Role.customer),
            {TazelemeIsi.bildirimler, TazelemeIsi.ilanlarim}, reason: t);
        expect(AnlikTazeleme.isler(t, Role.provider),
            {TazelemeIsi.bildirimler, TazelemeIsi.tekliflerim}, reason: t);
      }
    });

    test('talep olayları iki rolde de talepleri tazeler', () {
      for (final t in ['TALEP_REQUEST', 'TALEP_OFFER', 'TALEP_ACCEPTED', 'TALEP_DECLINED', 'TALEP_MESSAGE']) {
        for (final r in Role.values) {
          expect(AnlikTazeleme.isler(t, r), {TazelemeIsi.bildirimler, TazelemeIsi.talepler},
              reason: '$t $r');
        }
      }
    });

    // 29 Eki: yeni mesaj kartlardaki okunmamış sayıları da tazeler.
    test('yeni mesaj sohbet sayılarını tazeler', () {
      for (final r in Role.values) {
        expect(AnlikTazeleme.isler('NEW_MESSAGE', r), {TazelemeIsi.bildirimler, TazelemeIsi.sohbetler});
      }
    });

    test('duyuru ve bilinmeyen tür yalnız bildirimleri tazeler', () {
      for (final t in ['ANNOUNCEMENT', 'BILINMEYEN', null]) {
        expect(AnlikTazeleme.isler(t, Role.provider), {TazelemeIsi.bildirimler}, reason: '$t');
      }
    });

    test('öne gelme / yeniden bağlanma: etkin rolün bütün listeleri', () {
      expect(AnlikTazeleme.hepsi(Role.provider), {
        TazelemeIsi.bildirimler, TazelemeIsi.talepler, TazelemeIsi.sohbetler,
        TazelemeIsi.tekliflerim, TazelemeIsi.yeniIsler,
      });
      expect(AnlikTazeleme.hepsi(Role.customer),
          {TazelemeIsi.bildirimler, TazelemeIsi.talepler, TazelemeIsi.sohbetler, TazelemeIsi.ilanlarim});
    });
  });

  group('2 — değişmeyen veride ekran yeniden çizilmez', () {
    test('imza aynı yanıtta aynı, farklı yanıtta farklı', () {
      expect(veriImzasi([_ilan('l1')]), veriImzasi([_ilan('l1')]));
      expect(veriImzasi([_ilan('l1')]), isNot(veriImzasi([_ilan('l1', baslik: 'Kapı')])));
    });

    test('ilan deposu: aynı liste haber vermez; değişen liste verir', () async {
      final api = _SahteIlanApi()..yanit = [_ilan('l1')];
      final repo = ApiListingRepository(api);
      var haber = 0;
      repo.addListener(() => haber++);
      await repo.loadMine();
      expect(haber, 1);
      await repo.loadMine();
      await repo.loadAvailable();
      expect(haber, 1, reason: 'aynı yanıt yeniden uygulanmamalı');
      api.yanit = [_ilan('l1'), _ilan('l2')];
      await repo.loadMine();
      expect(haber, 2);
      expect(repo.all.length, 2);
    });

    test('ilan deposu: liste dışı değişiklikten sonra aynı liste yine uygulanır', () async {
      final api = _SahteIlanApi()..yanit = [_ilan('l1')];
      final repo = ApiListingRepository(api);
      await repo.loadMine();
      expect(_kod('lib/data/remote/repositories/api_repositories.dart')
          .split('_listeImzasi = null;').length - 1, 3,
          reason: 'tek ilan yükleme, ekleme ve silme imzayı sıfırlamalı');
    });

    test('teklif deposu: aynı /offers/my yanıtı haber vermez', () async {
      final api = _SahteTeklifApi()..yanit = [_teklif('o1')];
      final repo = ApiOfferRepository(api);
      var haber = 0;
      repo.addListener(() => haber++);
      await repo.loadMine();
      await repo.loadMine();
      expect(haber, 1);
      api.yanit = [_teklif('o1', tutar: 800)];
      await repo.loadMine();
      expect(haber, 2);
      expect(repo.byId('o1')!.amount, 800);
    });

    test('bildirim deposu: aynı liste ve aynı rozet sayısı haber vermez', () async {
      final api = _SahteBildirimApi()..yanit = [_bildirim('n1')]..sayi = 1;
      final repo = ApiNotificationRepository(api);
      var haber = 0;
      repo.addListener(() => haber++);
      await repo.load();
      await repo.load();
      await repo.loadUnreadCount();
      expect(haber, 1);
      api.yanit = [_bildirim('n2'), _bildirim('n1')];
      api.sayi = 2;
      await repo.load();
      await repo.loadUnreadCount();
      expect(haber, 2);
      expect(repo.unread, 2);
    });

    test('talep deposu: okumada 15 sn yoklama yok; aynı yanıt haber vermez', () {
      final k = _kod('lib/data/remote/api_teklif_talebi_port.dart');
      expect(k.contains('_tazelemeAraligi'), isFalse);
      expect(k.contains('if (_tazeleniyor || _sonTazeleme != null) {'), isTrue);
      expect(k.contains('if (imza != null && imza == _imza) {'), isTrue);
    });
  });

  group('3 — sessiz yükleme', () {
    test('sessiz yüklemede yükleniyor bayrağı haber vermez', () async {
      final d = _Denetleyici();
      var haber = 0;
      d.addListener(() => haber++);
      await d.runLoad(() async => null, sessiz: true);
      expect(haber, 0);
      expect(d.loading, isFalse);
      await d.runLoad(() async => null);
      expect(haber, 2, reason: 'normal yükleme başta ve sonda haber verir');
    });

    test('sessiz yüklemede yalnız hata durumu değişince haber verilir', () async {
      final d = _Denetleyici();
      var haber = 0;
      d.addListener(() => haber++);
      const hata = ValidationError('ağ yok');
      await d.runLoad(() async => hata, sessiz: true);
      await d.runLoad(() async => hata, sessiz: true);
      expect(haber, 1);
      expect(d.lastError?.message, 'ağ yok');
      await d.runLoad(() async => null, sessiz: true);
      expect(haber, 2);
      expect(d.lastError, isNull);
    });
  });

  group('4 — bağlantı ve zamanlayıcılar', () {
    test('sunucu olayı ve istemci akışı aynı ad', () {
      expect(WsAuth.eventNotificationNew, 'notification.new');
      expect(_kod('backend/src/anlik_haber.js')
          .contains("export const ANLIK_HABER_KANALI = 'notification.new';"), isTrue);
      expect(_kod('lib/data/remote/ws_client.dart')
          .contains('s.on(WsAuth.eventNotificationNew, (d) => _emit(_notificationNew, d));'), isTrue);
    });

    test('İşlerim ve ilan detayında 30 sn zamanlayıcı yok', () {
      for (final p in ['lib/screens/jobs_screen.dart', 'lib/screens/listing_detail_screen.dart']) {
        final k = _kod(p);
        expect(k.contains('Timer.periodic'), isFalse, reason: p);
        expect(k.contains('WidgetsBindingObserver'), isFalse, reason: p);
      }
    });

    test('kapı: girişte bağlanır, çıkışta kapanır, öne gelmede ve yeniden '
        'bağlanmada tazeler; push aynı eşlemeyi kullanır', () {
      final k = _kod('lib/ui/anlik_tazeleme.dart');
      expect(k.contains('unawaited(_ws?.connect());'), isTrue);
      expect(k.contains('unawaited(_ws?.disconnect());'), isTrue);
      expect(k.contains('AppLifecycleState.resumed'), isTrue);
      expect(k.contains('ws.onConnectionChange.listen('), isTrue);
      expect(k.contains('AnlikTazeleme.habereGore(context, tur);'), isTrue);
      final m = _kod('lib/main.dart');
      expect(m.contains('child: AnlikTazelemeKapisi('), isTrue);
      expect(m.contains('anlikBaglanti: ws,'), isTrue);
      expect(_kod('lib/ui/push_kapisi.dart').contains('AnlikTazeleme.habereGore(context,'), isTrue);
    });
  });
}
