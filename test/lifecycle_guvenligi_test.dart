import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ASYNC LIFECYCLE GÜVENLİĞİ — `BuildContext` ömrü.
///
/// ⚠ NİÇİN KRİTİK: `await` sonrası `BuildContext` kullanımı, widget
/// o sırada ağaçtan kalkmışsa şu hatayı verir:
///
///   Looking up a deactivated widget's ancestor is unsafe
///
/// Kullanıcı işlem sürerken geri tuşuna basarsa uygulama ÇÖKER.
///
/// ⚠ İKİ FARKLI `mounted` VARDIR:
///   • `State.mounted`    → `setState` için gerekli
///   • `context.mounted`  → o BuildContext ağaçta mı
///
/// Metot `BuildContext`'i PARAMETRE olarak alıyorsa State'in
/// `mounted`'ı YETMEZ; iki nesnenin ömrü aynı değildir.
///
/// ⚠ BU TESTLER SÖZLEŞME TESTİDİR. Gerçek dispose senaryosunu
/// simüle etmezler — o widget testi gerektirir ve bu turda
/// yazılmadı. Burada denetlenen: kalıbın kaynakta korunduğu.
String _oku(String p) => File(p).readAsStringSync();

void main() {
  group('Bağımlılıklar await ÖNCESİ alınır', () {
    test('create_listing: controller ve şehir önceden alınır', () {
      // ⚠ Fotoğraf döngüsü her dosya için ağ çağrısı yapar; uzun
      // sürer. `context.read` döngüden SONRA çağrılırsa çöker.
      final k = _oku('lib/screens/create_listing_screen.dart');
      expect(k.contains('final listingCtl = context.read<ListingController>();'),
          isTrue);
      expect(k.contains('final sehir = context.read<RegionController>()'),
          isTrue);
      // ⚠ Fotoğraflı yayın akışı artık context'e dokunmaz.
      expect(k.contains('await listingCtl.publish('), isTrue);

      // ⚠ İKİNCİ BİR publish DAHA VAR (oturumlu kullanıcı akışı,
      // ~satır 491). O çağrıdan ÖNCE `await` yoktur — `context.read`
      // orada güvenlidir ve bilinçli olarak bırakılmıştır.
    });

    test('register: storage · controller · şehir önceden alınır', () {
      final k = _oku('lib/screens/register_screen.dart');
      expect(k.contains('final listingCtl = c.read<ListingController>();'),
          isTrue);
      expect(k.contains('final sehir = c.read<RegionController>()'), isTrue);
      expect(k.contains('await listingCtl.publish('), isTrue);
      expect(k.contains('await c.read<ListingController>().publish('), isFalse);
    });

    test('_kayitKonumu artık BuildContext ALMAZ', () {
      // ⚠ Bu metot fotoğraf döngüsünden SONRA çalışıyordu ve içinde
      // `c.read` vardı. Artık saf: şehir adı hazır gelir.
      final k = _oku('lib/screens/register_screen.dart');
      expect(k.contains('String? _kayitKonumu(String varsayilanIl)'), isTrue);
      expect(k.contains('String? _kayitKonumu(BuildContext c)'), isFalse);
    });
  });

  group('context.mounted kullanımı', () {
    test('PARAMETRE context taşıyan metotlarda context.mounted', () {
      // State.mounted yetmez — farklı nesneler.
      final k = _oku('lib/screens/listing_detail_screen.dart');
      expect(k.contains('if (sil != true || !context.mounted) {'), isTrue);
      expect(k.contains('if (neden == null || !context.mounted) {'), isTrue);
      expect(k.contains('if (!ok || !context.mounted) {'), isTrue);
    });

    test('B12/B13: delete/cancel SONRASI context guard — BLOK SIRASI', () {
      // ⚠ Dosyanın herhangi bir yerinde `context.mounted` geçmesi
      // YETMEZ. Bu test İLGİLİ BLOĞU hedefler: async gap ile context
      // kullanımı arasında guard gerçekten duruyor mu?
      final k = _oku('lib/screens/listing_detail_screen.dart');

      final iDelete = k.indexOf('await ctl.delete(');
      final iCancel = k.indexOf('await ctl.cancel(');
      expect(iDelete, greaterThan(-1), reason: 'delete çağrısı yok');
      expect(iCancel, greaterThan(iDelete), reason: 'cancel delete sonrası');

      // ⚠ YORUM SATIRLARI ELENİR.
      //
      // Bu bloktaki açıklama yorumları `geriGit(context)` ve
      // `sysToastOk(context, ...)` metinlerini İÇERİYOR. Ham metinde
      // arama yapmak yorumu gerçek çağrı sanıp testi yanlış yerden
      // geçirir. Yalnız KOD satırları incelenir.
      final kod = const LineSplitter()
          .convert(k)
          .where((l) => !l.trimLeft().startsWith('//'))
          .join(' ');

      final jCancel = kod.indexOf('await ctl.cancel(');
      expect(jCancel, greaterThan(-1));
      final pencere = kod.substring(jCancel);

      final iGuard = pencere.indexOf('context.mounted');
      final iToast = pencere.indexOf("sysToastOk(context, 'İlanınız silindi");
      final iGeri = pencere.indexOf('geriGit(context)');

      expect(iGuard, greaterThan(-1),
          reason: 'delete/cancel sonrası context.mounted guard YOK');
      expect(iToast, greaterThan(iGuard),
          reason: 'toast guard ÖNCESİNDE çağrılıyor');
      expect(iGeri, greaterThan(iToast),
          reason: 'geriGit toast sonrasında ve guard içinde olmalı');

      // ⚠ `mounted` da korunmalı: `_run` içinde `setState` yapılır.
      expect(pencere.contains('mounted && context.mounted'), isTrue,
          reason: 'State ve context birlikte denetlenmeli');
    });

    test('selectOffer: State ve context AYRI denetlenir — BLOK SIRASI', () {
      // ⚠ Test adı "ayrı denetlenir" diyorsa ikisini de kanıtlamalı.
      // Yalnız `context.mounted` aramak bu iddiayı taşımaz.
      final k = _oku('lib/screens/offer_detail_screen.dart');
      final i = k.indexOf('.selectOffer(');
      expect(i, greaterThan(-1));

      final sonrasi = k.substring(i);
      final iState = sonrasi.indexOf('if (!mounted) {');
      final iSetState = sonrasi.indexOf('setState(() => _busySelect = false);');
      final iCtx = sonrasi.indexOf('if (!context.mounted) {');

      expect(iState, greaterThan(-1), reason: 'State guard yok');
      expect(iSetState, greaterThan(iState),
          reason: 'setState State guard SONRASINDA olmalı');
      expect(iCtx, greaterThan(iSetState),
          reason: 'context guard setState sonrasında olmalı');
    });

    test('job_detail: toast öncesi context guard', () {
      final k = _oku('lib/screens/job_detail_screen.dart');
      expect(k.contains('if (!context.mounted) {'), isTrue);
    });

    test('Scrollable.ensureVisible öncesi c.mounted', () {
      // `endOfFrame` bir async gap'tir.
      for (final f in [
        'lib/screens/register_screen.dart',
        'lib/screens/widgets/ilan_kayit_adimi.dart',
      ]) {
        final k = _oku(f);
        expect(k.contains('if (!mounted || c == null || !c.mounted) {'), isTrue,
            reason: f);
      }
    });
  });

  group('İŞ KURALI KORUNDU', () {
    test('publish çağrısı TEK yerde — çift yayın yok', () {
      // ⚠ Lifecycle düzeltmesi çağrı SAYISINI değiştirmemeli.
      final k = _oku('lib/screens/register_screen.dart');
      final sayi = RegExp(r'await listingCtl\.publish\(').allMatches(k).length;
      expect(sayi, 1, reason: 'publish birden fazla yerde çağrılıyor');
    });

    test('iletişim açma çağrısı korundu', () {
      final k = _oku('lib/screens/offer_detail_screen.dart');
      expect(k.contains('.openShared(offer.id, actorId: me.id)'), isTrue);
    });

    test('teklif seçme çağrısı korundu', () {
      final k = _oku('lib/screens/offer_detail_screen.dart');
      expect(k.contains('.selectOffer('), isTrue);
    });

    test('⚠ işi tamamlama çağrısı KALDIRILDI (§11)', () {
      // Nihai akışta ayrı tamamlama adımı yok; teklif seçimi ilanı
      // tamamlanmış duruma getirir.
      final k = _oku('lib/screens/listing_detail_screen.dart');
      expect(k.contains('.completeWork('), isFalse);
      expect(k.contains('.startWork('), isFalse);
    });
  });
}
