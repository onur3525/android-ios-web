// SOHBET FOTOĞRAFI YÜKLEME (29 Eki, kullanıcı bulgusu: "Bir sorun oluştu —
// Geçersiz fotoğraf"). Sohbet ekranları fotoğrafı HİÇ yüklemeden telefondaki
// dosya yolunu gönderiyordu. Artık: yerel yol → depoya yükle → sunucu kaydı
// (storageRef) mesajla gider. Kamera ve galeri aynı yoldan geçer.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/chat_controller.dart';
import 'package:hizmetcep/data/models/chat.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/remote/api/chat_api.dart';
import 'package:hizmetcep/data/remote/api/storage_api.dart';
import 'package:hizmetcep/data/remote/api_teklif_talebi_port.dart';
import 'package:hizmetcep/data/remote/fotograf_yukleyici.dart';
import 'package:hizmetcep/data/remote/repositories/api_chat_repositories.dart';

import 'support/fake_backend.dart';

const _ref = 'u/11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222.jpg';
final _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46, 0, 1];
final _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];
final _webp = [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50];

Map<String, dynamic> _mesaj(Map<String, dynamic> b) => {
      'id': 'srv-1', 'offerId': 'o1', 'senderId': 'u1', 'text': b['text'],
      'storageRef': b['storageRef'], 'status': 'SENT', 'createdAt': '2026-10-29T12:00:00.000Z',
    };

class _SahteDepo extends StorageApi {
  _SahteDepo(super.c, {this.yuklemeBasarili = true});
  final bool yuklemeBasarili;
  final List<String> olaylar = [];
  @override
  Future<Map<String, dynamic>> createUploadRef(
      {required String kind, required String contentType, required int sizeBytes}) async {
    olaylar.add('ref:$kind:$contentType');
    return {'storageRef': _ref, 'uploadUrl': 'https://depo.ornek/yukle'};
  }

  @override
  Future<void> uploadBytes(
      {required String uploadUrl, required List<int> bytes, required String contentType}) async {
    olaylar.add('yukle:${bytes.length}');
    if (!yuklemeBasarili) throw Exception('ağ');
  }

  @override
  Future<DiscardUploadResult> discardPending(String storageRef) async {
    olaylar.add('at:$storageRef');
    return const DiscardUploadResult(ok: true, retryScheduled: false);
  }
}

void main() {
  group('FotografYukleyici — tür ve kayıt', () {
    test('tür dosya İÇERİĞİNDEN bulunur (web blob adresinde uzantı yok)', () {
      expect(FotografYukleyici.icerikTuru(_jpeg), 'image/jpeg');
      expect(FotografYukleyici.icerikTuru(_png), 'image/png');
      expect(FotografYukleyici.icerikTuru(_webp), 'image/webp');
      expect(FotografYukleyici.icerikTuru(utf8.encode('....ftypheic')), isNull, reason: 'HEIC kabul edilmez');
      expect(FotografYukleyici.icerikTuru(const []), isNull);
    });

    test('sunucu kaydı yerel yoldan ayrılır', () {
      expect(FotografYukleyici.sunucuRefMi(_ref), isTrue);
      expect(FotografYukleyici.sunucuRefMi('/data/user/0/app/cache/IMG_1.jpg'), isFalse);
      expect(FotografYukleyici.sunucuRefMi('blob:https://hizmetcep.com/1234'), isFalse);
    });

    test('veri: blob/dosya yolu (uzantısız) ve data: adresi okunur; desteklenmeyen null', () async {
      final v = await FotografYukleyici.veri('blob:https://x/abc', okuyucu: (_) async => _png);
      expect(v!.$2, 'image/png');
      final d = await FotografYukleyici.veri('data:image/jpeg;base64,${base64Encode(_jpeg)}');
      expect(d!.$2, 'image/jpeg');
      expect(await FotografYukleyici.veri('x', okuyucu: (_) async => [1, 2, 3]), isNull);
    });

    test('yükle: upload-ref → baytlar → ref; başarısızlıkta bekleyen kayıt atılır', () async {
      final dizin = await Directory.systemTemp.createTemp('hc_foto');
      final dosya = File('${dizin.path}/kamera')..writeAsBytesSync(_jpeg);
      final c = FakeBackend({}).client();

      final iyi = _SahteDepo(c);
      expect(await FotografYukleyici.yukle(c, dosya.path, depo: iyi), _ref);
      expect(iyi.olaylar, ['ref:listing-photo:image/jpeg', 'yukle:${_jpeg.length}']);

      final kotu = _SahteDepo(c, yuklemeBasarili: false);
      await expectLater(FotografYukleyici.yukle(c, dosya.path, depo: kotu),
          throwsA(isA<FotografYuklemeHatasi>().having((e) => e.mesaj, 'mesaj', FotografYukleyici.yuklemeHatasi)));
      await Future<void>.delayed(Duration.zero);
      expect(kotu.olaylar.last, 'at:$_ref');

      final yanlis = File('${dizin.path}/belge')..writeAsBytesSync(utf8.encode('metin dosyası'));
      await expectLater(FotografYukleyici.yukle(c, yanlis.path, depo: iyi),
          throwsA(isA<FotografYuklemeHatasi>().having((e) => e.mesaj, 'mesaj', FotografYukleyici.turHatasi)));
      await dizin.delete(recursive: true);
    });
  });

  group('İlan sohbeti', () {
    test('yerel fotoğraf önce yüklenir; mesaj sunucu kaydıyla gider', () async {
      final govdeler = <Map<String, dynamic>>[];
      final be = FakeBackend({'POST /messages': (b) { govdeler.add(b); return _mesaj(b); }});
      final yuklenen = <String>[];
      final ctl = ChatController(ApiChatPort(ApiChatRepository(ChatApi(be.client()),
          fotografYukleyici: (yol) async { yuklenen.add(yol); return _ref; })));

      final r = await ctl.sendDelivered('o1', senderId: 'u1', imagePath: '/data/cache/IMG_7.jpg');

      expect(r.error, isNull);
      expect(yuklenen, ['/data/cache/IMG_7.jpg']);
      expect(govdeler.single['storageRef'], _ref, reason: 'telefon yolu sunucuya GİTMEZ');
    });

    test('yükleme başarısızsa mesaj gönderilmez, "gönderilemedi" olur; tekrar deneyince yüklenip gider', () async {
      final be = FakeBackend({'POST /messages': _mesaj});
      var deneme = 0;
      final port = ApiChatPort(ApiChatRepository(ChatApi(be.client()), fotografYukleyici: (yol) async {
        deneme++;
        if (deneme == 1) throw const FotografYuklemeHatasi(FotografYukleyici.yuklemeHatasi);
        return _ref;
      }));
      final ctl = ChatController(port);

      final r = await ctl.sendDelivered('o1', senderId: 'u1', imagePath: '/data/cache/IMG_8.jpg');
      expect(r.error!.message, FotografYukleyici.yuklemeHatasi);
      expect(r.message!.status, MessageStatus.failed);
      expect(be.countOf('POST /messages'), 0);

      expect(await ctl.retry('o1', r.message!), isTrue);
      expect(deneme, 2);
      expect(be.countOf('POST /messages'), 1);
    });

    test('fotoğraf yüklendi ama mesaj gönderilemediyse tekrar denemede fotoğraf YENİDEN yüklenmez', () async {
      var mesajDenemesi = 0;
      final refler = <Object?>[];
      final be = FakeBackend({'POST /messages': (b) {
        mesajDenemesi++;
        refler.add(b['storageRef']);
        return mesajDenemesi == 1 ? apiError(503, 'EXTERNAL_SERVICE_ERROR', 'Geçici hata') : _mesaj(b);
      }});
      var yukleme = 0;
      final ctl = ChatController(ApiChatPort(ApiChatRepository(ChatApi(be.client()),
          fotografYukleyici: (_) async { yukleme++; return _ref; })));

      final r = await ctl.sendDelivered('o1', senderId: 'u1', imagePath: '/data/cache/IMG_9.jpg');
      expect(r.error, isNotNull);
      expect(await ctl.retry('o1', r.message!), isTrue);
      expect(yukleme, 1);
      expect(refler, [_ref, _ref]);
    });

    test('metin mesajı ve zaten sunucuda olan kayıt yükleyiciye uğramaz', () async {
      final be = FakeBackend({'POST /messages': _mesaj});
      var yukleme = 0;
      final ctl = ChatController(ApiChatPort(ApiChatRepository(ChatApi(be.client()),
          fotografYukleyici: (_) async { yukleme++; return _ref; })));
      expect((await ctl.sendDelivered('o1', senderId: 'u1', text: 'merhaba')).error, isNull);
      expect((await ctl.sendDelivered('o1', senderId: 'u1', imagePath: _ref)).error, isNull);
      expect(yukleme, 0);
    });
  });

  group('Teklif talebi sohbeti', () {
    test('yerel fotoğraf önce yüklenir; fotografRef sunucu kaydıdır', () async {
      final govdeler = <Map<String, dynamic>>[];
      final be = FakeBackend({'POST /teklif-talepleri/t1/mesajlar': (b) { govdeler.add(b); return <String, dynamic>{}; }});
      final port = ApiTeklifTalebiPort(be.client(), fotografYukleyici: (_) async => _ref);
      final err = await port.mesajGonder('t1', gonderenId: 'u1', fotografYolu: 'blob:https://x/1');
      expect(err, isNull);
      expect(govdeler.single['fotografRef'], _ref);
    });

    test('yükleme başarısızsa mesaj gönderilmez ve anlaşılır hata döner', () async {
      final be = FakeBackend({'POST /teklif-talepleri/t1/mesajlar': (_) => <String, dynamic>{}});
      final port = ApiTeklifTalebiPort(be.client(),
          fotografYukleyici: (_) async => throw const FotografYuklemeHatasi(FotografYukleyici.boyutHatasi));
      final err = await port.mesajGonder('t1', gonderenId: 'u1', fotografYolu: '/data/cache/b.jpg');
      expect(err!.message, FotografYukleyici.boyutHatasi);
      expect(be.countOf('POST /teklif-talepleri/t1/mesajlar'), 0);
    });
  });
}
