import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/incelenen_ilan_controller.dart';
import 'package:hizmetcep/data/repositories/incelenen_ilan_store.dart';

/// Bellek içi sahte depo — platform kanalı gerekmez.
class _FakeStore implements IncelenenIlanStore {
  List<String> veri = [];
  int yazma = 0;

  @override
  Future<List<String>> read() async => veri;

  @override
  Future<void> save(List<String> idler) async {
    veri = List.of(idler);
    yazma++;
  }

  @override
  Future<void> clear() async => veri = [];
}

void main() {
  String read(String p) => File(p).readAsStringSync();

  group('İncelenen ilan durumu', () {
    late _FakeStore store;
    late IncelenenIlanController c;

    setUp(() {
      store = _FakeStore();
      c = IncelenenIlanController(store);
    });

    test('başlangıçta hiçbir ilan incelenmemiş', () async {
      await c.load();
      expect(c.incelendiMi('l1'), isFalse);
    });

    test('işaretlenen ilan incelenmiş sayılır', () async {
      await c.load();
      await c.isaretle('l1');
      expect(c.incelendiMi('l1'), isTrue);
      expect(c.incelendiMi('l2'), isFalse);
    });

    test('aynı ilan iki kez işaretlenirse TEKRAR YAZILMAZ', () async {
      await c.load();
      await c.isaretle('l1');
      final ilk = store.yazma;
      await c.isaretle('l1');
      expect(store.yazma, ilk, reason: 'gereksiz yazma olmamalı');
    });

    test('boş kimlik yok sayılır', () async {
      await c.load();
      await c.isaretle('');
      expect(store.yazma, 0);
    });

    test('uygulama yeniden açılınca durum KORUNUR', () async {
      await c.load();
      await c.isaretle('l1');
      await c.isaretle('l2');

      // Yeni yaşam döngüsü, AYNI kalıcı depo.
      final yeni = IncelenenIlanController(store);
      await yeni.load();
      expect(yeni.incelendiMi('l1'), isTrue);
      expect(yeni.incelendiMi('l2'), isTrue);
      expect(yeni.incelendiMi('l3'), isFalse);
    });

    test('temizleme tüm durumu siler', () async {
      await c.load();
      await c.isaretle('l1');
      await c.clear();
      expect(c.incelendiMi('l1'), isFalse);
      expect(store.veri, isEmpty);
    });
  });

  group('Ekran sözleşmesi', () {
    final js = read('lib/screens/jobs_screen.dart');
    final jd = read('lib/screens/job_detail_screen.dart');

    test('incelenmemiş: KALIN yazı + KALIN YEŞİL çerçeve', () {
      // ⚠ Renk MAVİDEN YEŞİLE çevrildi.
      //
      // Mavi uygulamanın her yerinde kullanılan ana renktir; "yeni"
      // anlamı taşımıyordu. Yeşil bu ekranda başka hiçbir yerde
      // kullanılmaz, bakışta ayırt edilir.
      //
      // Test GEVŞETİLMEDİ: kalınlık farkları korundu, üstüne renk
      // ayrımı ve okunmuş/okunmamış metin rengi de denetleniyor.
      expect(js.contains('incelendi ? FontWeight.w600 : FontWeight.w800'),
          isTrue,
          reason: 'incelenmemiş başlık kalın olmalı');
      expect(js.contains('width: incelendi ? 1 : 2'), isTrue,
          reason: 'incelenmemiş çerçeve kalın olmalı');
      expect(js.contains('color: incelendi ? HC.border : _kYeniRenk'), isTrue,
          reason: 'incelenmemiş çerçeve YEŞİL olmalı');
      expect(js.contains('const Color _kYeniRenk = Color(0xFF16A34A)'), isTrue,
          reason: 'yeşil tek yerde tanımlı olmalı');
      // Okunduktan sonra metinler grileşir.
      expect(js.contains('color: incelendi ? HC.dark : _kYeniKoyu'), isTrue);
      // ⚠ AÇIKLAMA RENGİ TOKEN DEĞİŞTİRDİ, KURAL DEĞİŞMEDİ.
      //
      // Açıklama tipografisi tek standarda çekilirken bu satır ham
      // `TextStyle`dan `refText`e taşındı; renkler de HC yerine RC
      // tokenlarıyla yazıldı:
      //   okunmamış  HC.grey (#5B6472)      → RC.textSoft (#5B6472) — AYNI renk
      //   okunmuş    HC.lightGrey (#98A2B3) → RC.grey (#8A94A6)     — bir tık koyu
      //
      // Kural aynen duruyor: okunmuş ilanın açıklaması SOLGUNLAŞIR.
      // Test gevşetilmedi, yeni sözleşmeye göre güncellendi
      // (bkz. test/ilan_aciklama_tipografisi_test.dart).
      expect(js.contains('color: incelendi ? RC.grey : RC.textSoft'), isTrue);
    });

    test('okunmamış için AYRI işaret bileşeni yok', () {
      // Fark yalnız YAZI ve ÇERÇEVE görünümünde olmalı:
      // nokta, "Yeni" rozeti veya renkli badge KULLANILMAZ.
      final i = js.indexOf('Widget _jobCard(');
      expect(i, greaterThan(0));
      // ⚠ SABİT PENCERE TERK EDİLDİ.
      //
      // Önce 1600, sonra 3200 karakter denendi; kart her açıklama
      // veya yorum eklendiğinde sınırı aşıyor ve test KURAL
      // BOZULMADAN düşüyordu. Sınır artık metnin kendisinden okunur:
      // `_jobCard` sınıfın SON üyesidir, gövdesi sınıfı kapatan
      // satırda biter.
      final son = js.indexOf('\n}', i);
      expect(son, greaterThan(i), reason: 'kart gövdesinin sonu bulunamadı');
      final kart = js.substring(i, son);
      expect(kart.contains("'Yeni'"), isFalse);
      expect(kart.contains('Badge('), isFalse);

      // ⚠ SAYI DEĞİL, HANGİ ÖZELLİKLER olduğu denetlenir.
      //
      // Çıplak bir sayı beklemek kırılgandır: her görsel iyileştirme
      // testi düşürür ama kuralı bozmaz. Asıl kural şudur —
      // `incelendi` YALNIZ görünüm özelliklerini değiştirir, ayrı bir
      // işaret bileşeni doğurmaz.
      for (final ozellik in [
        'incelendi ? HC.border : _kYeniRenk', // çerçeve rengi
        'incelendi ? 1 : 2', // çerçeve kalınlığı
        'incelendi ? FontWeight.w600 : FontWeight.w800', // başlık
        'incelendi ? HC.dark : _kYeniKoyu', // başlık rengi
        'incelendi ? FontWeight.w400 : FontWeight.w600', // konum
        'incelendi ? RC.grey : RC.textSoft', // açıklama rengi
      ]) {
        expect(kart.contains(ozellik), isTrue, reason: ozellik);
      }
    });

    test('teklif sayısı sağlayıcıya GÖSTERİLİR', () {
      expect(js.contains('_TeklifRozeti'), isTrue);
      expect(js.contains('offersForListing(l.id).length'), isTrue);
      // Metinler referansla aynı.
      expect(js.contains('Henüz teklif verilmedi'), isTrue);
      expect(js.contains("'\$adet teklif verildi'"), isTrue);
    });

    test('liste durumu controller\'dan okur', () {
      expect(js.contains('incelenenCtl.incelendiMi(l.id)'), isTrue);
      expect(js.contains('watch<IncelenenIlanController>()'), isTrue);
    });

    test('ilan detayı açılınca İŞARETLENİR', () {
      expect(
          jd.contains(
              'read<IncelenenIlanController>().isaretle(widget.listingId)'),
          isTrue);
    });

    test('durum KALICI saklanır (yeni bağımlılık yok)', () {
      final st = read('lib/data/repositories/incelenen_ilan_store.dart');
      expect(st.contains('FlutterSecureStorage'), isTrue);
      final pub = read('pubspec.yaml');
      // Yalnız mevcut paket kullanılmalı.
      expect(pub.contains('flutter_secure_storage'), isTrue);
      expect(pub.contains('shared_preferences'), isFalse);
    });

    test('depo sınırlı büyür (şişme koruması)', () {
      final st = read('lib/data/repositories/incelenen_ilan_store.dart');
      expect(st.contains('_enFazla'), isTrue);
    });
  });

  group('Bölge genişleme tetiği', () {
    final js = read('lib/screens/jobs_screen.dart');

    test('seçili ilçelerde 1 saat ilan yoksa İL GENELİ', () {
      expect(js.contains('DomainConfig.areaExpandAfter'), isTrue);
      expect(js.contains('sonSaatteIlanVar'), isTrue);
      expect(js.contains('genislet ? kategoriUyanlar.toList() : ilceIcindekiler'),
          isTrue);
    });

    test('genişleme SESSİZ — kullanıcıya bildirilmez', () {
      expect(js.contains('RefInfoBox'), isFalse);
    });
  });
}
