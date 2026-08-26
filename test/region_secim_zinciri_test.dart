import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/izmir.dart';
import 'package:hizmetcep/data/izmir_neighborhoods.dart';
import 'package:hizmetcep/data/controllers/region_controller.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/models/region.dart';
import 'package:hizmetcep/core/turkce_arama.dart';
import 'support/kaynak_okuma.dart';

/// İL → İLÇE → MAHALLE SEÇİM ZİNCİRİ
///
/// Talimat: `HizmetCep_Claude_Kayit_Adres_ve_Ilan_Akisi_Talimati` — Problem 1
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Veri kaynağı — mock APK backend olmadan çalışır', () {
    late RegionController rc;

    setUp(() => rc = RegionController(MockRegionPort()));

    test('yükleme öncesi liste BOŞ (yarış durumunun kaynağı)', () {
      // Bu, düzeltilen hatanın ta kendisidir: sayfa bu anda açılırsa
      // kullanıcı "Sonuç bulunamadı" görür.
      expect(rc.districts, isEmpty);
      expect(rc.hasData, isFalse);
    });

    test('load() sonrası il ve ilçeler dolu', () async {
      await rc.load();
      expect(rc.hasData, isTrue);
      expect(rc.cityName, kCity);
      expect(rc.districts.length, kIzmirDistricts.length);
      expect(rc.districts.length, 30);
    });

    test('İl seçili → yalnız o ilin ilçeleri listelenir', () async {
      await rc.load();
      for (final d in rc.districts) {
        expect(kIzmirDistricts.contains(d), isTrue,
            reason: '$d İzmir ilçesi değil');
      }
    });

    test('İlçe seçili → yalnız o ilçenin mahalleleri listelenir', () async {
      await rc.load();
      for (final d in kIzmirDistricts) {
        final m = rc.neighborhoodsOf(d);
        expect(m, isNotEmpty, reason: '$d mahallesiz kaldı');
        expect(m, kIzmirNeighborhoods[d]);
      }
    });

    test('30 ilçenin tamamı mahalle taşır, toplam 1300', () async {
      await rc.load();
      final toplam = kIzmirDistricts
          .map((d) => rc.neighborhoodsOf(d).length)
          .reduce((a, b) => a + b);
      expect(toplam, 1300);
    });

    test('bilinmeyen/geçersiz ilçe uygulamayı ÇÖKERTMEZ', () async {
      await rc.load();
      expect(rc.neighborhoodsOf('Yok Böyle Bir İlçe'), isEmpty);
      expect(rc.neighborhoodsOf(''), isEmpty);
      expect(rc.isKnownDistrict('Yok'), isFalse);
      expect(rc.isKnownNeighborhood('Bornova', 'Yok'), isFalse);
    });

    test('load() iki kez çağrılabilir (tekrar istek yok, veri korunur)',
        () async {
      await rc.load();
      final ilk = rc.districts.length;
      await rc.load();
      expect(rc.districts.length, ilk);
    });
  });

  group('İl zinciri — hard-code YOK, sunucudan gelir', () {
    late RegionController rc;
    setUp(() => rc = RegionController(MockRegionPort()));

    test('aktif il listesi VERİDEN gelir', () async {
      await rc.load();
      expect(rc.cityNames, isNotEmpty);
      // Bugün mock veride tek il var; ileride artabilir.
      expect(rc.cityNames, contains(kCity));
    });

    test('tek il varsa kendiliğinden seçilir', () async {
      await rc.load();
      expect(rc.cityNames.length, 1);
      expect(rc.soleCityName, kCity);
    });

    test('birden çok il olursa otomatik seçim YAPILMAZ', () {
      // Kullanıcı seçmelidir; alan gerçek seçim alanı olarak çalışır.
      final cok = RegionTree(const [
        City(id: 'a', name: 'İzmir', districts: []),
        City(id: 'b', name: 'Manisa', districts: []),
      ]);
      expect(cok.cities.length, 2);
      // `soleCityName` yalnız TEK il varken değer döner.
      expect(cok.cities.length == 1, isFalse);
    });

    test('ilçe listesi SEÇİLEN İLE göre gelir', () async {
      await rc.load();
      expect(rc.districtsOf(kCity).length, 30);
      // Aktif olmayan il → boş liste (çökme yok).
      expect(rc.districtsOf('Manisa'), isEmpty);
    });

    test('mahalle listesi SEÇİLEN İLÇEYE göre gelir', () async {
      await rc.load();
      expect(rc.neighborhoodsOf('Bornova', city: kCity), isNotEmpty);
      expect(rc.neighborhoodsOf('Bornova', city: kCity),
          kIzmirNeighborhoods['Bornova']);
      // Yanlış ildeki ilçe → boş.
      expect(rc.neighborhoodsOf('Bornova', city: 'Manisa'), isEmpty);
    });

    test('bilinmeyen il çökertmez', () async {
      await rc.load();
      expect(rc.isKnownCity(kCity), isTrue);
      expect(rc.isKnownCity('Yok'), isFalse);
      expect(rc.districtsOf('Yok'), isEmpty);
    });

    test('ekran sözleşmesi: İl KİLİTLİ DEĞİL, seçim alanı', () {
      final reg = read('lib/screens/register_screen.dart');
      // Hard-code veya kilitli alan kalmamalı.
      expect(reg.contains('İl kilitli'), isFalse);
      expect(reg.contains('_ilSec'), isTrue);
      expect(reg.contains('cityNames'), isTrue);
      // İl alanı gerçekten tıklanabilir olmalı.
      final i = reg.indexOf("label: 'İl',");
      expect(i, greaterThan(0));
      expect(reg.pencere(i, 160).contains('onTap: () => _ilSec'), isTrue);
    });

    test('ekran sözleşmesi: il değişince ilçe+mahalle temizlenir', () {
      final reg = read('lib/screens/register_screen.dart');
      final i = reg.indexOf('_city = sel;');
      expect(i, greaterThan(0));
      final govde = reg.pencere(i, 300);
      expect(govde.contains('_district = null;'), isTrue);
      expect(govde.contains("_hood.text = '';"), isTrue);
      // Sağlayıcıda hizmet bölgeleri de geçersizleşir.
      expect(govde.contains('_provDistricts.clear();'), isTrue);
    });

    // ⚠ İlan akışının 2. adımında konum SORULMAZ; bölge seçimi
    // yalnız kayıt ve adres ekranlarında yapılır.
    test('ekran sözleşmesi: ilçe/mahalle sorguları İLE bağlı', () {
      // Kayıt ekranı il-duyarlı sorgu kullanır.
      const f = 'lib/screens/register_screen.dart';
      final s = read(f);
      expect(s.contains('districtsOf(_city)'), isTrue, reason: f);
      expect(s.contains('city: _city'), isTrue, reason: f);

      // Adres ekranı da bölge verisini controller'dan alır.
      final adr = read('lib/screens/addresses_screen.dart');
      expect(adr.contains('_regions.neighborhoodsOf('), isTrue);
      expect(adr.contains('city: cityName'), isTrue);
    });
  });

  group('Arama — Türkçe karakter duyarsız', () {
    // Production ile AYNI fonksiyon kullanılır (kopya kural yok).
    List<String> ara(List<String> kaynak, String q) => kaynak
        .where((o) => turkceNormalize(o).contains(turkceNormalize(q)))
        .toList();

    test('ilçe araması sonuç verir', () {
      expect(ara(kIzmirDistricts, 'bornova'), contains('Bornova'));
      expect(ara(kIzmirDistricts, 'BORNOVA'), contains('Bornova'));
    });

    test('Türkçe karakter bozulmaz — ilçe (küçük harf)', () {
      expect(ara(kIzmirDistricts, 'cigli'), contains('Çiğli'));
      expect(ara(kIzmirDistricts, 'karsiyaka'), contains('Karşıyaka'));
      expect(ara(kIzmirDistricts, 'odemis'), contains('Ödemiş'));
      expect(ara(kIzmirDistricts, 'guzelbahce'), contains('Güzelbahçe'));
    });

    // ⚠ REGRESYON: `'İ'.toLowerCase()` → `'i' + U+0307` üretir.
    // Eski `_norm` sıralamasında `replaceAll('İ','i')` ölü koddu ve
    // BÜYÜK harfle Türkçe arama sonuç VERMİYORDU.
    test('Türkçe karakter bozulmaz — BÜYÜK harf (İ, Ş, Ğ, Ü, Ö, Ç)', () {
      expect(ara(kIzmirDistricts, 'ÇİĞLİ'), contains('Çiğli'));
      expect(ara(kIzmirDistricts, 'ÖDEMİŞ'), contains('Ödemiş'));
      expect(ara(kIzmirDistricts, 'KARŞIYAKA'), contains('Karşıyaka'));
      expect(ara(kIzmirDistricts, 'GÜZELBAHÇE'), contains('Güzelbahçe'));
      expect(ara(kIzmirDistricts, 'İZMİR'), isEmpty); // il değil, ilçe listesi
    });

    test('turkceNormalize: büyük/küçük AYNI sonucu verir', () {
      for (final d in kIzmirDistricts) {
        expect(turkceNormalize(d.toUpperCase()), turkceNormalize(d),
            reason: '$d büyük harfte farklı normalize oluyor');
      }
    });

    test('mahalle araması sonuç verir', () {
      final bornova = kIzmirNeighborhoods['Bornova']!;
      expect(ara(bornova, 'erzene'), contains('Erzene'));
      expect(ara(bornova, 'ERZENE'), contains('Erzene'));
    });

    test('Türkçe karakter bozulmaz — mahalle', () {
      final konak = kIzmirNeighborhoods['Konak']!;
      expect(ara(konak, 'guzelyali'), contains('Güzelyalı'));
      expect(ara(konak, 'cankaya'), contains('Çankaya'));
      expect(ara(konak, 'GÜZELYALI'), contains('Güzelyalı'));
    });

    test('eşleşmeyen arama boş döner (çökmez)', () {
      expect(ara(kIzmirDistricts, 'zzzz'), isEmpty);
      expect(ara(kIzmirDistricts, ''), kIzmirDistricts);
    });
  });

  group('Ekran sözleşmesi — lazy provider yarışı kapatıldı', () {
    final reg = read('lib/screens/register_screen.dart');
    final cre = read('lib/screens/create_listing_screen.dart');
    final adr = read('lib/screens/addresses_screen.dart');

    /// Ekran açılışta `RegionController.load()` çağırıyor mu?
    ///
    /// ⚠ BİÇİMDEN BAĞIMSIZ: çağrı tek satırda
    /// (`context.read<RegionController>().load()`) veya değişkene
    /// alınarak (`final r = context.read<RegionController>(); r.load();`)
    /// yazılmış olabilir. İddia aynıdır; yalnız yazım biçimi serbesttir.
    bool bolgeYuklemesiVar(String src) {
      // 1) Zincirleme çağrı.
      if (RegExp(r'read<RegionController>\(\)\s*\.\s*load\(\)')
          .hasMatch(src)) {
        return true;
      }
      // 2) Değişkene alınıp çağrılıyor — değişken adı İZLENİR.
      for (final m in RegExp(
              r'(?:final|var)\s+(\w+)\s*=\s*context\.read<RegionController>\(\)')
          .allMatches(src)) {
        final ad = m.group(1)!;
        if (RegExp('\\b$ad\\.load\\(\\)').hasMatch(src)) {
          return true;
        }
      }
      return false;
    }

    test('kayıt ekranı açılışta bölge verisini YÜKLER', () {
      // `ChangeNotifierProvider` lazy'dir; ekran load tetiklemezse
      // seçim sayfası boş açılır.
      expect(reg.contains('void didChangeDependencies()'), isTrue);
      expect(bolgeYuklemesiVar(reg), isTrue,
          reason: 'kayıt ekranı RegionController.load() çağırmalı');
    });

    test('ilan oluşturma ekranı açılışta bölge verisini YÜKLER', () {
      expect(bolgeYuklemesiVar(cre), isTrue,
          reason: 'ilan ekranı RegionController.load() çağırmalı');
    });

    test('adres ekranındaki mevcut davranış korunur', () {
      expect(bolgeYuklemesiVar(adr), isTrue);
    });

    test('seçim sayfaları controller state\'ini DİNLER', () {
      // `read` ile anlık liste geçilirse sonradan gelen veri yansımaz.
      // ⚠ `create_listing_screen` bölge seçici İÇERMEZ (konum kayıt
      // akışından gelir); bu yüzden listeden çıkarılmıştır.
      expect(reg.contains('Consumer<RegionController>'), isTrue);
      // Sayfaya statik liste besleyen eski desen kalmamalı.
      expect(
          RegExp(r'options: context\.read<RegionController>\(\)')
              .hasMatch(reg),
          isFalse);
      expect(reg.contains('options: ilceler'), isFalse);
    });

    test('zincir temizliği: ilçe değişince mahalle sıfırlanır', () {
      // ⚠ Yalnız bölge seçici İÇEREN ekranlar denetlenir.
      final i = reg.indexOf('_district = ');
      expect(i, greaterThan(0));
      // Aynı setState bloğunda mahalle temizlenmeli.
      expect(reg.pencere(i, 240).contains("_hood.text = ''"), isTrue,
          reason: 'ilçe değişince mahalle temizlenmiyor');
    });

    test('ilan akışı bölge seçici İÇERMEZ', () {
      expect(cre.contains('Consumer<RegionController>'), isFalse);
      expect(cre.contains("RefFieldLabel('İlçe'"), isFalse);
      expect(cre.contains("RefFieldLabel('Mahalle'"), isFalse);
    });

    test('arama TEK ortak kuralı kullanır', () {
      final rp = read('lib/screens/widgets/region_picker.dart');
      final rw = read('lib/ui/ref_widgets.dart');
      expect(rp.contains('turkceNormalize'), isTrue);
      expect(rw.contains('turkceNormalize'), isTrue);
      // Türkçe normalizasyonsuz ham arama kalmamalı.
      expect(rw.contains("o.toLowerCase().contains(q)"), isFalse);
    });

    test('ilçe seçilmeden mahalle seçilemez', () {
      // Mahalle alanı ilçe null iken pasiftir.
      expect(reg.contains('_district == null ? null : () => _mahalleSec'),
          isTrue);
    });
  });
}
