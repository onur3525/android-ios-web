import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/theme.dart';
import 'package:hizmetcep/data/remote/api/storage_api.dart';
import 'package:hizmetcep/screens/widgets/photo_picker.dart';

/// FOTOĞRAF DISCARD (önizlemeden kaldırma)
///
/// Fotoğraf yalnız yerel listeden çıkarılmaz: sunucudaki BEKLEYEN
/// yükleme de iptal edilir. Hata durumunda öğe görünür kalır.
class _FakeStorageApi implements StorageApi {
  final List<String> discarded = [];
  int calls = 0;

  /// Belirli referanslar için fırlatılacak hata (ağ/timeout benzetimi).
  final Map<String, Object> failures;

  /// Belirli referanslar için ok:false cevabı (storage silinemedi).
  final Map<String, DiscardUploadResult> results;

  /// Bir referans için ilk çağrı başarısız, sonraki başarılı olsun.
  final Set<String> failFirstOnly;

  /// KONTROLLÜ CEVAP — yalnız çift tıklama testinde kullanılır.
  ///
  /// Doluysa `discardPending()` bu Completer tamamlanana kadar BEKLER.
  /// Böylece "istek sürerken ikinci tıklama" durumu deterministik
  /// olarak üretilir; sabit `sleep` veya sanal saat gerekmez.
  ///
  /// Boş bırakılırsa fake eskisi gibi anında cevap verir.
  Completer<void>? askiyaAl;

  _FakeStorageApi({
    this.failures = const {},
    this.results = const {},
    this.failFirstOnly = const {},
    this.askiyaAl,
  });

  final Map<String, int> _seen = {};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);

  @override
  Future<DiscardUploadResult> discardPending(String storageRef) async {
    calls++;
    final n = (_seen[storageRef] ?? 0) + 1;
    _seen[storageRef] = n;

    // İstek "uçuşta" kalsın: çağrı sayıldı ama cevap henüz dönmedi.
    final bekle = askiyaAl;
    if (bekle != null && !bekle.isCompleted) {
      await bekle.future;
    }

    if (failFirstOnly.contains(storageRef) && n == 1) {
      return const DiscardUploadResult(ok: false, retryScheduled: true);
    }
    final f = failures[storageRef];
    if (f != null) {
      throw f;
    }
    final r = results[storageRef];
    if (r != null) {
      if (r.ok) {
        discarded.add(storageRef);
      }
      return r;
    }
    // Sunucu idempotenttir: aynı referans iki kez gelse de başarı döner.
    discarded.add(storageRef);
    return const DiscardUploadResult(ok: true, retryScheduled: false);
  }
}

void main() {

  PhotoItem uploaded(String ref) => PhotoItem(
        localPath: '/tmp/a.jpg',
        sizeBytes: 1024,
        contentType: 'image/jpeg',
        storageRef: ref,
      );

  Widget host({
    required List<PhotoItem> photos,
    required StorageApi api,
    required void Function(List<PhotoItem>) onChanged,
  }) =>
      MaterialApp(
        theme: HC.theme(),
        home: Scaffold(
          body: ListingPhotoPicker(
            photos: photos,
            storage: api,
            onChanged: onChanged,
          ),
        ),
      );

  testWidgets('önizlemeden silme BACKEND portunu çağırır ve listeden çıkarır',
      (t) async {
    final api = _FakeStorageApi();
    final photos = [uploaded('s3://listing-photo/u1/a.jpg')];
    var next = photos;

    await t.pumpWidget(host(
      photos: photos, api: api, onChanged: (v) => next = v,
    ));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pumpAndSettle();

    expect(api.calls, 1, reason: 'backend discard çağrılmalı');
    expect(api.discarded, ['s3://listing-photo/u1/a.jpg']);
    expect(next, isEmpty, reason: 'başarıda listeden çıkar');
  });

  testWidgets('YÜKLENMEMİŞ fotoğraf backend çağırmadan çıkarılır', (t) async {
    final api = _FakeStorageApi();
    final photos = [
      PhotoItem(
        localPath: '/tmp/b.jpg', sizeBytes: 10, contentType: 'image/jpeg',
      ),
    ];
    var next = photos;

    await t.pumpWidget(host(
      photos: photos, api: api, onChanged: (v) => next = v,
    ));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pumpAndSettle();

    expect(api.calls, 0, reason: 'sunucuda kayıt yok, çağrı yapılmamalı');
    expect(next, isEmpty);
  });

  testWidgets('BAŞARISIZ discard fotoğrafı GÖRÜNÜR tutar ve hata gösterir',
      (t) async {
    const ref = 's3://listing-photo/u1/fail.jpg';
    final api = _FakeStorageApi(failures: {ref: Exception('sunucu hatası')});
    final photos = [uploaded(ref)];
    var next = photos;

    await t.pumpWidget(host(
      photos: photos, api: api, onChanged: (v) => next = v,
    ));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pumpAndSettle();

    expect(api.calls, 1);
    expect(next, hasLength(1), reason: 'hata durumunda listede KALIR');
    expect(find.textContaining('tekrar deneyin'), findsOneWidget);
  });

  testWidgets('ATTACHED (yayınlanmış) fotoğraf discard EDİLMEZ', (t) async {
    final api = _FakeStorageApi();
    final p = uploaded('s3://listing-photo/u1/att.jpg')..attached = true;
    final photos = [p];
    var next = photos;

    await t.pumpWidget(host(
      photos: photos, api: api, onChanged: (v) => next = v,
    ));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pumpAndSettle();

    expect(api.calls, 0, reason: 'ilana bağlı dosya için çağrı yapılmamalı');
    expect(next, hasLength(1));
    expect(find.textContaining('kaldırılamaz'), findsOneWidget);
  });

  testWidgets('DUPLICATE discard idempotenttir (çift tıklama)', (t) async {
    // Backend cevabı ELDE TUTULUR: ilk istek tamamlanmadan ikinci
    // tıklama denenir. Aksi hâlde fake aynı event döngüsünde biter,
    // `discarding` kapanır ve kilit hiç sınanmamış olur.
    final kapi = Completer<void>();
    final api = _FakeStorageApi(askiyaAl: kapi);
    final photos = [uploaded('s3://listing-photo/u1/dup.jpg')];

    await t.pumpWidget(host(
      photos: photos, api: api, onChanged: (_) {},
    ));
    await t.pump();

    // 1) İlk tıklama → istek başlar, discarding = true
    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pump();
    expect(api.calls, 1, reason: 'ilk tıklama tek çağrı başlatır');

    // 2) İstek HÂLÂ uçuşta iken ikinci tıklama: kilit devrede olmalı.
    if (find.byKey(const ValueKey('photo-discard')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const ValueKey('photo-discard')).first);
      await t.pump();
    }
    expect(api.calls, 1, reason: 'istek sürerken ikinci çağrı ÜRETİLMEZ');

    // 3) Backend cevabı serbest bırakılır ve akış tamamlanır.
    kapi.complete();
    await t.pumpAndSettle();

    expect(api.calls, 1, reason: 'çift tıklamada tek çağrı');
  });

  testWidgets('BACKEND ok:false dönerse fotoğraf LİSTEDE KALIR', (t) async {
    const ref = 's3://listing-photo/u1/nok.jpg';
    final api = _FakeStorageApi(results: {
      ref: const DiscardUploadResult(ok: false, retryScheduled: false),
    });
    final photos = [uploaded(ref)];
    var next = photos;

    await t.pumpWidget(host(
      photos: photos, api: api, onChanged: (v) => next = v,
    ));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pumpAndSettle();

    expect(api.calls, 1);
    expect(api.discarded, isEmpty);
    expect(next, hasLength(1), reason: 'ok:false ise listeden ÇIKARILMAZ');
    expect(find.textContaining('tekrar deneyin'), findsOneWidget);
  });

  testWidgets('retryScheduled:true için otomatik yeniden deneme mesajı',
      (t) async {
    const ref = 's3://listing-photo/u1/retry.jpg';
    final api = _FakeStorageApi(results: {
      ref: const DiscardUploadResult(ok: false, retryScheduled: true),
    });
    final photos = [uploaded(ref)];
    var next = photos;

    await t.pumpWidget(host(
      photos: photos, api: api, onChanged: (v) => next = v,
    ));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pumpAndSettle();

    expect(next, hasLength(1));
    expect(find.textContaining('yeniden denenecek'), findsOneWidget);
  });

  testWidgets('NETWORK hatasında fotoğraf listede kalır', (t) async {
    const ref = 's3://listing-photo/u1/net.jpg';
    final api = _FakeStorageApi(failures: {ref: Exception('bağlantı yok')});
    final photos = [uploaded(ref)];
    var next = photos;

    await t.pumpWidget(host(
      photos: photos, api: api, onChanged: (v) => next = v,
    ));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pumpAndSettle();

    expect(next, hasLength(1));
    expect(find.textContaining('tekrar deneyin'), findsOneWidget);
  });

  testWidgets('SONRAKİ BAŞARILI denemede fotoğraf kaldırılır', (t) async {
    const ref = 's3://listing-photo/u1/second.jpg';
    final api = _FakeStorageApi(failFirstOnly: {ref});
    final photos = [uploaded(ref)];
    var next = photos;

    await t.pumpWidget(host(
      photos: photos, api: api, onChanged: (v) => next = v,
    ));
    await t.pump();

    // 1. deneme → ok:false, listede kalır
    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pumpAndSettle();
    expect(next, hasLength(1));

    // 2. deneme → başarı, listeden çıkar
    await t.tap(find.byKey(const ValueKey('photo-discard')).first);
    await t.pumpAndSettle();
    expect(api.calls, 2);
    expect(next, isEmpty);
  });

  testWidgets('discardAllPending yalnız BEKLEYEN dosyaları iptal eder',
      (t) async {
    final api = _FakeStorageApi();
    final pending = uploaded('s3://listing-photo/u1/p.jpg');
    final attached = uploaded('s3://listing-photo/u1/a.jpg')..attached = true;
    final notUploaded = PhotoItem(
      localPath: '/tmp/c.jpg', sizeBytes: 5, contentType: 'image/jpeg',
    );

    final key = GlobalKey<State<ListingPhotoPicker>>();
    await t.pumpWidget(MaterialApp(
      theme: HC.theme(),
      home: Scaffold(
        body: ListingPhotoPicker(
          key: key,
          photos: [pending, attached, notUploaded],
          storage: api,
          onChanged: (_) {},
        ),
      ),
    ));
    await t.pump();

    // ignore: avoid_dynamic_calls
    await (key.currentState as dynamic).discardAllPending();

    expect(api.discarded, ['s3://listing-photo/u1/p.jpg']);
  });
}
