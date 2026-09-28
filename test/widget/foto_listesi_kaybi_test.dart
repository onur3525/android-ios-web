import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/theme.dart';
import 'package:hizmetcep/data/remote/api/storage_api.dart';
import 'package:hizmetcep/screens/widgets/photo_picker.dart';

/// GALERİDEN EKLENEN FOTOĞRAFIN KAYBOLMASI
///
/// ⚠ BU TESTİN VAR OLMA NEDENİ — EBEVEYNİN GERÇEK DESENİ
///
/// `create_listing_screen` fotoğraf listesini ŞÖYLE günceller:
///
///     final List<PhotoItem> _photos = [];
///     ...
///     ListingPhotoPicker(
///       photos: _photos,
///       onChanged: (next) => setState(() {
///         _photos..clear()..addAll(next);
///       }),
///     )
///
/// Yani `photos` olarak verilen liste ile `onChanged`'in yazdığı liste
/// AYNI NESNEDİR. Picker ebeveyne `widget.photos`'un kendisini
/// gönderirse `next` ile hedef aynı listeye işaret eder: `clear()`
/// listeyi boşaltır, ardından `addAll` artık boş olan listeyi ekler ve
/// TÜM FOTOĞRAFLAR SİLİNİR.
///
/// Sahada görülen belirti buydu: kullanıcı galeriden fotoğraf seçiyor,
/// fotoğraf listeye doğru ekleniyor, hemen ardından çalışan yükleme
/// bildirimi listeyi sıfırlıyor ve ekranda hiçbir şey görünmüyordu.
/// Hata mesajı da çıkmıyordu.
///
/// ⚠ ESKİ TEST NEDEN YAKALAMADI: `photo_discard_test` sahte ebeveyni
/// `onChanged: (v) => next = v` yapıyor — kaynak listeyi hiç
/// temizlemiyor. Bu dosyadaki sahte ebeveyn GERÇEK ekranın desenini
/// birebir taklit eder; hata yeniden girerse burası düşer.
class _FakeStorageApi implements StorageApi {
  final List<String> discarded = [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);

  @override
  Future<DiscardUploadResult> discardPending(String storageRef) async {
    discarded.add(storageRef);
    return const DiscardUploadResult(ok: true, retryScheduled: false);
  }
}

/// GERÇEK EKRANIN DESENİ: liste bir kez kurulur, geri çağrıda
class _EbeveynGibi extends StatefulWidget {
  const _EbeveynGibi({required this.baslangic, required this.api, this.anahtar});

  final List<PhotoItem> baslangic;
  final StorageApi api;
  final GlobalKey<State<ListingPhotoPicker>>? anahtar;

  @override
  State<_EbeveynGibi> createState() => _EbeveynGibiState();
}

class _EbeveynGibiState extends State<_EbeveynGibi> {
  final List<PhotoItem> photos = [];

  @override
  void initState() {
    super.initState();
    photos.addAll(widget.baslangic);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: HC.theme(),
        home: Scaffold(
          body: ListingPhotoPicker(
            key: widget.anahtar,
            photos: photos,
            storage: widget.api,
            // ⚠ create_listing_screen ile BİREBİR aynı gövde.
            onChanged: (next) => setState(() {
              photos
                ..clear()
                ..addAll(next);
            }),
          ),
        ),
      );
}

PhotoItem _yerel(String yol) => PhotoItem(
      localPath: yol,
      sizeBytes: 1024,
      contentType: 'image/jpeg',
    );

void main() {
  /// ⚠ YORUMSUZ metin — YOKLUK denetimi için.
  /// Ham metinde arama yapılırsa açıklamada geçen ad kod sanılır; bu
  /// dosyanın kendi açıklamaları da yanlış alarm üretir.
  String kodu(String p) => File(p)
      .readAsStringSync()
      .split('\n')
      .where((l) =>
          !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');

  group('1 — Yükleme bildirimi listeyi SİLMEZ', () {
    testWidgets('mock modda yükleme bittiğinde fotoğraf listede KALIR',
        (t) async {
      final api = _FakeStorageApi();
      final foto = _yerel('/tmp/a.jpg');
      final anahtar = GlobalKey<State<ListingPhotoPicker>>();

      await t.pumpWidget(_EbeveynGibi(
        baslangic: [foto], api: api, anahtar: anahtar,
      ));
      await t.pump();

      final ebeveyn =
          t.state<_EbeveynGibiState>(find.byType(_EbeveynGibi));
      expect(ebeveyn.photos, hasLength(1), reason: 'başlangıç durumu');

      // Galeriden seçim sonrası çalışan yol: seçilen her dosya için
      // yükleme başlatılır. Mock modda anında "yerel referans" verilir
      // ve ebeveyne bildirim gider.
      // ignore: avoid_dynamic_calls
      (anahtar.currentState as dynamic).unawaitedUpload(foto);
      await t.pumpAndSettle();

      expect(ebeveyn.photos, hasLength(1),
          reason: 'yükleme bildirimi fotoğrafı SİLMEMELİ — '
              'ebeveyn clear()+addAll deseni kullanıyor');
      expect(ebeveyn.photos.first.isUploaded, isTrue,
          reason: 'mock modda yerel yol referans olur');
      expect(foto.yerelRef, isTrue);
    });

    testWidgets('birden fazla fotoğrafta da hiçbiri kaybolmaz', (t) async {
      final api = _FakeStorageApi();
      final a = _yerel('/tmp/a.jpg');
      final b = _yerel('/tmp/b.jpg');
      final anahtar = GlobalKey<State<ListingPhotoPicker>>();

      await t.pumpWidget(_EbeveynGibi(
        baslangic: [a, b], api: api, anahtar: anahtar,
      ));
      await t.pump();

      // ignore: avoid_dynamic_calls
      (anahtar.currentState as dynamic).unawaitedUpload(a);
      // ignore: avoid_dynamic_calls
      (anahtar.currentState as dynamic).unawaitedUpload(b);
      await t.pumpAndSettle();

      final ebeveyn =
          t.state<_EbeveynGibiState>(find.byType(_EbeveynGibi));
      expect(ebeveyn.photos, hasLength(2));
      expect(ebeveyn.photos.map((p) => p.localPath),
          containsAll(<String>['/tmp/a.jpg', '/tmp/b.jpg']));
    });
  });

  group('2 — Yerel referanslı kaldırma yalnız SEÇİLENİ kaldırır', () {
    testWidgets('iki fotoğraftan biri silinince öteki yerinde kalır',
        (t) async {
      final api = _FakeStorageApi();
      final a = _yerel('/tmp/a.jpg')
        ..storageRef = '/tmp/a.jpg'
        ..yerelRef = true;
      final b = _yerel('/tmp/b.jpg')
        ..storageRef = '/tmp/b.jpg'
        ..yerelRef = true;

      await t.pumpWidget(_EbeveynGibi(baslangic: [a, b], api: api));
      await t.pump();

      await t.tap(find.byKey(const ValueKey('photo-discard')).first);
      await t.pumpAndSettle();

      final ebeveyn =
          t.state<_EbeveynGibiState>(find.byType(_EbeveynGibi));
      expect(ebeveyn.photos, hasLength(1),
          reason: 'bir fotoğrafı kaldırmak HEPSİNİ kaldırmamalı');
      expect(ebeveyn.photos.single.localPath, '/tmp/b.jpg');

      // Yerel referansın sunucuda karşılığı yoktur: iptal isteği
      // gönderilmez.
      expect(api.discarded, isEmpty);
    });
  });

  group('3 — Kaynak sözleşmesi: ebeveyne her zaman KOPYA gider', () {
    test('widget.onChanged yalnız _bildir geçidinde çağrılır', () {
      final k = kodu('lib/screens/widgets/photo_picker.dart');
      final cagrilar = RegExp(r'widget\.onChanged\(').allMatches(k).length;
      expect(cagrilar, 1,
          reason: 'ebeveyne giden tek çıkış _bildir olmalı; '
              'doğrudan çağrı listenin sıfırlanmasına yol açar');
      expect(k.contains('void _bildir(List<PhotoItem> liste) => '
          'widget.onChanged(List.of(liste));'), isTrue,
          reason: 'geçit KOPYA göndermeli');
    });

    test('ebeveyn deseni değişmediyse bu kilit anlamlıdır', () {
      final c = kodu('lib/screens/create_listing_screen.dart');
      expect(c.contains('photos: _photos'), isTrue);
      expect(c.contains('..clear()'), isTrue,
          reason: 'ebeveyn hâlâ clear()+addAll kullanıyor; '
              'desen değişirse bu testin gerekçesi gözden geçirilmeli');
    });
  });
}
