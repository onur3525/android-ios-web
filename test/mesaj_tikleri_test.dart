// MESAJ TİKLERİ (29 Eki, kullanıcı bulgusu): "mesaj karşıya ulaşmadan iki
// tik olmamalı; okunanların hepsi mavi olmalı, bazıları gri kalıyor."
//   · Sunucu SENT dönerse tek tik; alıcının uygulaması alınca iki gri;
//     okuyunca mavi. Tikler YALNIZ İLERİ gider.
//   · Sohbet ekranı açıkken gelen mesaj da okundu işaretlenir.
//   · Teklif talebi sohbeti aynı kural (gonderildi → iletildi → okundu).
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/chat_controller.dart';
import 'package:hizmetcep/data/models/chat.dart';
import 'package:hizmetcep/data/models/teklif_talebi.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/remote/api/chat_api.dart';
import 'package:hizmetcep/data/remote/api_teklif_talebi_port.dart';
import 'package:hizmetcep/data/remote/repositories/api_chat_repositories.dart';
import 'package:hizmetcep/data/remote/ws_auth.dart';
import 'package:hizmetcep/data/remote/ws_client.dart';
import 'package:hizmetcep/data/models/account.dart' show Role;
import 'package:hizmetcep/ui/anlik_tazeleme.dart';

import 'support/fake_backend.dart';

class _SahteWs extends WsClient {
  _SahteWs() : super(WsAuth(FakeTokenStore(access: 'AT')));
  final yeni = StreamController<Map<String, dynamic>>.broadcast();
  final iletildi = StreamController<Map<String, dynamic>>.broadcast();
  final okundu = StreamController<Map<String, dynamic>>.broadcast();
  final baglanti = StreamController<bool>.broadcast();
  @override
  Stream<Map<String, dynamic>> get onMessageNew => yeni.stream;
  @override
  Stream<Map<String, dynamic>> get onMessageDelivered => iletildi.stream;
  @override
  Stream<Map<String, dynamic>> get onMessageRead => okundu.stream;
  @override
  Stream<bool> get onConnectionChange => baglanti.stream;
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  void join(String offerId) {}
  @override
  void leave(String offerId) {}
}

Map<String, dynamic> _m(String id, String gonderen, String durum) => {
      'id': id, 'offerId': 'o1', 'senderId': gonderen, 'text': id, 'status': durum,
      'createdAt': '2026-10-29T12:00:00.000Z',
    };

Future<void> _bekle([int ms = 20]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('sunucu SENT dönerse tek tik (iki tik yalnız iletilince)', () async {
    final be = FakeBackend({'POST /messages': (_) => _m('s1', 'ben', 'SENT')});
    final ctl = ChatController(ApiChatPort(ApiChatRepository(ChatApi(be.client()))));
    final r = await ctl.sendDelivered('o1', senderId: 'ben', text: 'merhaba');
    expect(r.message!.status, MessageStatus.sent);
  });

  test('iletildi/okundu olayı yalnız BENİM mesajlarımı ilerletir; okunan geri düşmez', () async {
    final ws = _SahteWs();
    final be = FakeBackend({
      'GET /messages/o1': (_) => <dynamic>[
            _m('a', 'ben', 'READ'), _m('b', 'ben', 'SENT'), _m('c', 'karsi', 'DELIVERED'),
          ],
      'POST /messages/o1/read': (_) => {'ok': true},
    });
    final repo = ApiChatRepository(ChatApi(be.client()), ws: ws);
    await repo.loadThread('o1');
    ws.iletildi.add({'offerId': 'o1', 'aliciId': 'karsi'});
    await _bekle();
    final t = repo.threadFor('o1')!;
    expect(t.firstWhere((m) => m.id == 'a').status, MessageStatus.read, reason: 'mavi geri griye düşmez');
    expect(t.firstWhere((m) => m.id == 'b').status, MessageStatus.delivered);
    ws.okundu.add({'offerId': 'o1', 'readerId': 'karsi'});
    await _bekle();
    expect(t.firstWhere((m) => m.id == 'b').status, MessageStatus.read);
    expect(t.where((m) => m.senderId == 'ben').every((m) => m.status == MessageStatus.read), isTrue,
        reason: 'okunanların hepsi mavi');
  });

  test('olay gönderim yanıtından önce gelirse yanıt yine doğru tikle görünür', () async {
    final ws = _SahteWs();
    final be = FakeBackend({'POST /messages': (_) => _m('s2', 'ben', 'SENT')});
    final repo = ApiChatRepository(ChatApi(be.client()), ws: ws);
    final gonderim = repo.send('o1', senderId: 'ben', text: 'selam');
    ws.iletildi.add({'offerId': 'o1', 'aliciId': 'karsi'});
    final r = await gonderim;
    expect(r.message!.status, MessageStatus.delivered);
  });

  test('sohbet ekranı açıkken gelen mesaj okundu işaretlenir; kapalıyken işaretlenmez', () async {
    final ws = _SahteWs();
    final be = FakeBackend({'POST /messages/o1/read': (_) => {'ok': true}});
    final repo = ApiChatRepository(ChatApi(be.client()), ws: ws);
    repo.sohbetAcik('o1', 'ben');
    ws.yeni.add(_m('n1', 'karsi', 'DELIVERED'));
    ws.yeni.add(_m('n2', 'karsi', 'DELIVERED'));
    await _bekle(600);
    expect(be.countOf('POST /messages/o1/read'), 1, reason: 'art arda gelenler tek istekte');
    expect(repo.okunmamis('o1', 'ben'), 0);

    repo.sohbetKapandi('o1');
    ws.yeni.add(_m('n3', 'karsi', 'DELIVERED'));
    await _bekle(600);
    expect(be.countOf('POST /messages/o1/read'), 1, reason: 'ekran kapalı → okunmadı');
    expect(repo.okunmamis('o1', 'ben'), 1);
  });

  test('teklif talebi: iletildi/okundu alanları üç tike eşlenir', () async {
    Map<String, dynamic> talep(List<Map<String, dynamic>> mesajlar) => {
          'id': 't1', 'talepNo': 'T1', 'hizmetAlanId': 'ben', 'saglayiciId': 'karsi', 'saglayiciAdi': 'Usta',
          'kategori': 'K', 'hizmet': 'H', 'aciklama': 'a', 'fotograflar': <String>[], 'iletisimTercihi': 'yalnizMesaj',
          'durum': 'TEKLIF_GELDI', 'teklifFiyati': 500, 'createdAt': '2026-10-29T10:00:00.000Z', 'mesajlar': mesajlar,
        };
    final be = FakeBackend({
      'GET /teklif-talepleri': (_) => <dynamic>[talep([
            {'id': 'x1', 'gonderenId': 'ben', 'metin': 'a', 'createdAt': '2026-10-29T10:01:00.000Z', 'okundu': false, 'iletildi': false},
            {'id': 'x2', 'gonderenId': 'ben', 'metin': 'b', 'createdAt': '2026-10-29T10:02:00.000Z', 'okundu': false, 'iletildi': true},
            {'id': 'x3', 'gonderenId': 'ben', 'metin': 'c', 'createdAt': '2026-10-29T10:03:00.000Z', 'okundu': true, 'iletildi': true},
          ])],
    });
    final port = ApiTeklifTalebiPort(be.client());
    await port.yenile();
    final m = port.byId('t1')!.mesajlar;
    expect(m.map((x) => x.durum).toList(),
        [TeklifMesajDurumu.gonderildi, TeklifMesajDurumu.iletildi, TeklifMesajDurumu.okundu]);
  });

  test('TALEP_DURUM haberi yalnız talepleri tazeler (bildirim listesine dokunmaz)', () {
    for (final r in Role.values) {
      expect(AnlikTazeleme.isler('TALEP_DURUM', r), {TazelemeIsi.talepler});
    }
  });

  test('teklif talebi sohbeti açıkken gelen mesajı da okundu işaretler', () {
    final k = File('lib/screens/teklif_talebi_sohbet_screen.dart').readAsStringSync();
    expect(k.contains('_gelenleriOkunduYap(talep, me?.id);'), isTrue);
  });
}
