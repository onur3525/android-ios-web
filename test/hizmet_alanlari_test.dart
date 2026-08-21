// HİZMET ALANLARI — ANA SAYFA ÇATI KATMANI
//
// ⚠ BUNLAR ANA KATEGORİ DEĞİLDİR. Gerçek katalog değişmez; bu katman
// yalnız ana sayfada gösterilen kısayol yüzeyidir.
//
// ⚠ Bu testin asıl işi: katalog büyüdüğünde bir kategorinin çatısız
// kalmasını ENGELLEMEK. Çatısız kategori ana sayfadan ERİŞİLEMEZ
// hâle gelir ve bu sessizce olur.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/data/hizmet_alanlari.dart';

void main() {
  group('KAPSAM', () {
    test('ON BEŞ ÇATI — ne eksik ne fazla', () {
      // ⚠ 15 ÇATI KESİN YAPI (kullanıcı talimatı §2).
      //
      // 16. çatı ve "Diğer" çatısı OLUŞTURULMAZ. Adlar talimattaki
      // kesin adlardır; sıra ana ekrandaki 3×5 kart düzenini verir.
      expect(kHizmetAlanlari.length, 15);
      expect(
          kHizmetAlanlari.map((a) => a.ad).toList(),
          const [
            'Ev & Yaşam',
            'Araç Hizmetleri',
            'Beyaz Eşya & Elektronik Servis',
            'Temizlik',
            'Taşıma & Nakliyat',
            'Güzellik & Kişisel Bakım',
            'Evcil Hayvan Hizmetleri',
            'Eğitim',
            'Dijital Hizmetler',
            'Organizasyon & Etkinlik',
            'İnşaat & Dekorasyon',
            'Teknik Hizmetler',
            'Giyim & Tekstil',
            'Mühendislik & Proje',
            'Hukuk, Finans & Kurumsal',
          ]);
    });

    test('⚠ 3×5 DÜZENİ — satır çatı sayısından türer', () {
      // Ekran kodu satırı hesaplıyor; 15 çatı 3 sütunda 5 satır eder.
      expect((kHizmetAlanlari.length + 2) ~/ 3, 5);
    });

    test('⚠ TALİMATTA GEÇMEYEN KATEGORİLER MEVCUT ÇATISINI KORUDU', () {
      // ── NİÇİN ──
      //
      // Talimatın §3 yerleşim listesi 47 kategori sayıyor; katalogda
      // 63 var. Kalan 16'sı listede HİÇ geçmiyor.
      //
      // ⚠ VARSAYIMLA YERLEŞTİRİLMEDİLER. Talimat "mevcut hiçbir
      // kategori silinmeyecek" (§4) ve "mevcut çalışan davranış
      // korunacak" (§9) diyor. Değinilmeyen kategoriler bu yüzden
      // MEVCUT çatılarını korudu; çatı adları yalnız §2'deki eşlemeye
      // göre değişti.
      // ⚠ DÜZELTİLDİ: "Kombi Montaj" ısıtma tesisatı işidir; Ev &
      // Yaşam'da değil Teknik Hizmetler'de olmalı (Kombi Servis'in
      // yanında).
      expect(kKategoriAlani['Kombi Montaj'], 'Teknik Hizmetler');
      expect(kKategoriAlani['Oto Çekici ve Yol Yardım'], 'Araç Hizmetleri');
      expect(kKategoriAlani['Müzik Dersleri'], 'Eğitim');
      expect(kKategoriAlani['Fayans ve Seramik Döşeme'], 'İnşaat & Dekorasyon');
      // ⚠ DÜZELTİLDİ: asansör bir YAPI işi değil, süregelen teknik
      // servis işidir.
      expect(kKategoriAlani['Asansör Montaj ve Bakım'], 'Teknik Hizmetler');
    });

    test('⚠ TALİMATIN §3 YERLEŞİMİ BİREBİR UYGULANDI', () {
      // Örnekleme: her yeni/taşınan çatıdan en az bir kategori.
      expect(kKategoriAlani['Bahçe ve Peyzaj'], 'Ev & Yaşam');
      expect(kKategoriAlani['Su Tesisatı'], 'Teknik Hizmetler');
      expect(kKategoriAlani['Elektrik'], 'Teknik Hizmetler');
      expect(kKategoriAlani['Kombi Servis'], 'Teknik Hizmetler');
      expect(kKategoriAlani['Terzilik ve Dikiş'], 'Giyim & Tekstil');
      expect(kKategoriAlani['Ev Tekstili'], 'Giyim & Tekstil');
      expect(kKategoriAlani['Avukatlık ve Hukuk'], 'Hukuk, Finans & Kurumsal');
      expect(kKategoriAlani['Sigorta'], 'Hukuk, Finans & Kurumsal');
      expect(kKategoriAlani['Beyaz Eşya Servisi'],
          'Beyaz Eşya & Elektronik Servis');
      expect(kKategoriAlani['Spor ve Kişisel Antrenör'],
          'Güzellik & Kişisel Bakım');
      expect(kKategoriAlani['Fotoğraf Çekimi'], 'Dijital Hizmetler');
    });

    test('HER KATEGORİ bir çatıya bağlı', () {
      // ⚠ Çatısız kategori ana sayfadan erişilemez.
      final bagli = kKategoriAlani.keys.toSet();
      final eksik = kCategoryTree.keys.where((c) => !bagli.contains(c));
      expect(eksik, isEmpty, reason: 'çatısız kategori: $eksik');
      expect(alanKapsamiTam(), isTrue);
    });

    test('KATALOGDA OLMAYAN kategoriye bağlanmamış', () {
      for (final a in kHizmetAlanlari) {
        for (final c in a.kategoriler) {
          expect(kCategoryTree.containsKey(c), isTrue,
              reason: '${a.ad} → $c katalogda yok');
        }
      }
    });

    test('BİR KATEGORİ İKİ ÇATIDA olamaz', () {
      final tum = [for (final a in kHizmetAlanlari) ...a.kategoriler];
      expect(tum.length, tum.toSet().length,
          reason: 'aynı kategori iki çatıda');
      expect(tum.length, kCategoryTree.length);
    });
  });

  group('KATALOG DEĞİŞMEDİ', () {
    test('çatı katmanı SAYILARA karışmaz', () {
      // ⚠ Çatılar ana kategori DEĞİL: katalog sayıları aynı kalır.
      expect(kCategoryTree.length, 63);
      expect(kCategoryTree.values.fold<int>(0, (a, b) => a + b.length), 640);
    });

    test('çatı adı KATEGORİ adı DEĞİL', () {
      for (final a in kHizmetAlanlari) {
        expect(kCategoryTree.containsKey(a.ad), isFalse,
            reason: '${a.ad} kategori olarak da açılmış');
      }
    });
  });

  group('GÖRSELLER', () {
    test('her çatının fotoğrafı ve ikonu VAR', () {
      for (final a in kHizmetAlanlari) {
        expect(File(a.gorsel).existsSync(), isTrue,
            reason: '${a.ad} → ${a.gorsel} yok');
        expect(File(a.ikon).existsSync(), isTrue,
            reason: '${a.ad} → ${a.ikon} yok');
      }
    });

    test('her çatının AÇIKLAMASI var', () {
      for (final a in kHizmetAlanlari) {
        expect(a.aciklama.trim(), isNotEmpty, reason: a.ad);
        // ⚠ NOKTA ŞARTI KALKTI: açıklamalar kart genişliğine sığsın
        // diye kısaltıldı ve etiket gibi yazıldı ("Tesisat, elektrik,
        // ısıtma"). Cümle değiller; nokta gereksiz.
        expect(a.aciklama.length, lessThanOrEqualTo(40),
            reason: '${a.ad}: açıklama karta sığmayacak kadar uzun');
      }
    });

    test('pubspec KLASÖRLERİ bildirmiş', () {
      // Bildirilmezse görseller pakete girmez ve ekranda kırık çıkar.
      final pub = File('pubspec.yaml').readAsStringSync();
      expect(pub.contains('assets/alanlar/'), isTrue);
      expect(pub.contains('assets/svg/alanlar/'), isTrue);
    });
  });

  group('YERLEŞTİRME KARARLARI', () {
    // ⚠ 12 ÇATI (15 Ağu). Kararlar kullanıcı tarafından tek tek
    // verildi; buradaki iddialar o kararların kilididir.
    test('yapı işleri İNŞAAT & DEKORASYON altında', () {
      // ⚠ 12 çatılı yapıda yapı işleri kendi çatısına ayrıldı;
      // eskiden Ev Hizmeti 264 hizmetle katalogun yarısını taşıyordu.
      const yapi = [
        'İnşaat ve Kaba Yapı',
        'Çatı Yapım ve Onarım',
        'Mobilya Yapım ve Montaj',
        'Marangozluk ve Ahşap İşleri',
        'Cam Balkon Sistemleri',
        'PVC ve Alüminyum Doğrama',
        'Demir Doğrama ve Kaynak',
        // ⚠ 'Havuz Yapım ve Bakım' ÇIKARILDI → Ev & Yaşam
        // (talimat §3 yerleşimi; Paket A'da taşındı, bu liste
        // güncellenmemişti).
        //
        // ⚠ 'Asansör Montaj ve Bakım' ÇIKARILDI → Teknik Hizmetler.
        'Kapı Montaj ve Tamir',
      ];
      for (final k in yapi) {
        expect(kKategoriAlani[k], 'İnşaat & Dekorasyon', reason: k);
      }
    });

    test('EV HİZMETİ ürün kararlarına uyuyor', () {
      // Bahçe bakım ağırlıklı, güvenlik kurulum ağırlıklı, ev tekstili
      // eve ait ürünler → üçü de Ev Hizmeti (kullanıcı kararı).
      
      expect(kKategoriAlani['Güvenlik Sistemleri'], 'Teknik Hizmetler');
      
    });

    test('SPOR DERSLERİ Eğitim değil KİŞİSEL HİZMET', () {
      // Eğitim çatısı okul/dil/müzik/sürücü için temiz tutulur.
      
      for (final d in const [
        'Yüzme Dersi',
        'Fitness Özel Ders',
        'Pilates Dersi',
        'Tenis Dersi',
        'Yoga Dersi',
      ]) {
        expect(hizmetAlani('Spor ve Kişisel Antrenör', d), 'Güzellik & Kişisel Bakım',
            reason: d);
      }
    });

    test('EVCİL HAYVAN kendi çatısında', () {
      expect(kKategoriAlani['Evcil Hayvan Hizmetleri'], 'Evcil Hayvan Hizmetleri');
      for (final h in const ['Köpek Eğitimi', 'Evcil Hayvan Taşıma']) {
        expect(hizmetAlani('Evcil Hayvan Hizmetleri', h), 'Evcil Hayvan Hizmetleri',
            reason: h);
      }
    });

    test('HİZMET DÜZEYİNDE İSTİSNA çalışıyor', () {
      // ⚠ Kategori bir çatıda, hizmet başka çatıda olabilir.
      expect(kKategoriAlani['Çilingir ve Kilit'], 'Teknik Hizmetler');
      expect(hizmetAlani('Çilingir ve Kilit', 'Oto Anahtarcı'),
          'Araç Hizmeti');

      expect(kKategoriAlani['Koltuk ve Döşeme Yıkama'], 'Temizlik');
      expect(hizmetAlani('Koltuk ve Döşeme Yıkama', 'Araç Döşeme Yıkama'),
          'Araç Hizmeti');

      // İstisnası olmayan hizmet kategorisinin çatısını izler.
      expect(hizmetAlani('Çilingir ve Kilit', 'Kapı Açma'), 'Teknik Hizmetler');
      // Hizmet verilmezse kategori çatısı döner.
      expect(hizmetAlani('Çilingir ve Kilit', null), 'Teknik Hizmetler');
    });

    test('İSTİSNALAR KATALOGDA GERÇEKTEN VAR', () {
      final tum = {for (final v in kCategoryTree.values) ...v};
      for (final h in kHizmetCatiIstisnasi.keys) {
        expect(tum, contains(h), reason: '$h katalogda yok');
      }
      final adlar = kHizmetAlanlari.map((a) => a.ad).toSet();
      for (final a in kHizmetCatiIstisnasi.values) {
        expect(adlar, contains(a), reason: '$a diye çatı yok');
      }
    });

    test('İSTİSNA AZ — kategori ilişkisi zayıflamasın', () {
      expect(kHizmetCatiIstisnasi.length, lessThanOrEqualTo(5),
          reason: 'istisna listesi şişmiş; kategori mi yanlış yerde?');
    });

    test('alanHizmetleri istisnayı HESABA KATAR', () {
      final arac = alanHizmetleri('Araç Hizmeti').map((e) => e.hizmet);
      expect(arac, contains('Oto Anahtarcı'));
      expect(arac, contains('Araç Döşeme Yıkama'));

      final ev = alanHizmetleri('Teknik Hizmetler').map((e) => e.hizmet);
      expect(ev, isNot(contains('Oto Anahtarcı')));

      // Toplam korunur: hiçbir hizmet kaybolmaz veya iki kez sayılmaz.
      var toplam = 0;
      for (final a in kHizmetAlanlari) {
        toplam += alanHizmetleri(a.ad).length;
      }
      expect(toplam, 640);
    });
  });

  group('ÇATI EKRANI', () {
    String _kod(String yol) => File(yol)
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    final e = _kod('lib/screens/hizmet_alani_screen.dart');

    test('geri düğmesi ve ÇATI ADI başlıkta', () {
      expect(e.contains('RefBackButton'), isTrue);
      expect(e.contains('RefPageTitle(widget.alan.ad'), isTrue);
    });

    test('ARAMA ÇUBUĞU var ve metni ortak', () {
      expect(e.contains("hint: 'Hangi hizmete ihtiyacınız var?'"), isTrue);
    });

    test('arama YALNIZ bu çatının içinde', () {
      // ⚠ Ortak servis tüm katalogu tarar; sonuç bu çatıya bağlı
      // kategorilere daraltılır. Aksi hâlde "Ev Hizmeti" ekranında
      // araç ya da eğitim kategorisi çıkardı.
      // ⚠ Kapsam artık MERKEZİ fonksiyondan; ekran kategori listesini
      // kendi süzmüyor (hizmet düzeyinde istisna var).
      expect(e.contains('alanHizmetleri(widget.alan.ad)'), isTrue);
      expect(e.contains('izin.contains('), isTrue);
      expect(e.contains('SearchService.services('), isTrue);
    });

    test('ARAMADAN ÖNCE çatının kategorileri listelenir', () {
      // ⚠ Kapsam merkezi çözümden geldiği için liste `_kategoriler`
      // üzerinden döner (istisna ile gelen kategoriler dahil).
      expect(e.contains('return _kategoriler;'), isTrue);
    });

    test('kategoriye dokununca GERÇEK HİZMET seçimine gider', () {
      // ⚠ Doğrudan ilan formu AÇILMAZ: amaç kullanıcıyı doğru gerçek
      // hizmete ulaştırmak. Kategori ekranı hizmetleri listeler.
      expect(e.contains('CategoryScreen(category: kategori, alan: alan)'),
          isTrue);
    });

    test('SONUÇ YOKSA açık metin', () {
      expect(e.contains("'Sonuç bulunamadı'"), isTrue);
    });

    test('ana sayfadaki ÇATI KARTI bu ekranı açar', () {
      final h = _kod('lib/screens/home_screen.dart');
      expect(h.contains('HizmetAlaniScreen(alan: alan)'), isTrue);
      // On iki çatının hepsi aynı karttan çizilir.
      // ⚠ Girinti değişebilir; ADI aranır, biçimi değil.
      expect(h.contains('satir * _kSutun + s'), isTrue);
    });
  });


  group('EKRAN — 12 ÇATI', () {
    String _k(String yol) => File(yol)
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    test('ana sayfada TAM 12 ÇATI, eski kartlar YOK', () {
      final h = _k('lib/screens/home_screen.dart');
      expect(kHizmetAlanlari.length, 12);
      expect(h.contains('HizmetAlanlariPaneli'), isTrue);
      expect(h.contains('kHizmetAlanlari'), isTrue);
      expect(h.contains('kHizliKategoriler = ['), isFalse);
      expect(h.contains('class _CategoryItem'), isFalse);
    });

    test('TÜM KATEGORİLER bağlantısı KALDIRILDI', () {
      // ⚠ 12 çatının tamamı panelde; 58 kategorinin hepsi bir çatıya
      // bağlı. Ayrı tam liste bağlantısı çatı ayrımını zayıflatıyordu.
      final h = _k('lib/screens/home_screen.dart');
      expect(h.contains('AllCategoriesScreen'), isFalse);
      expect(h.contains('Tüm Kategoriler'), isFalse);
    });

    test('PANEL SABİT — 12 kart birden görünür', () {
      final h = _k('lib/screens/home_screen.dart');
      // ⚠ Satır sayısı çatı sayısından TÜRER; sabit değil.
      expect(h.contains('kGorunenSatir =>'), isTrue);
      // ⚠ GÖZ KARARI KATSAYI YASAK: yükseklik kartın parçalarından
      // toplanır, elle bulunmuş bir çarpanla değil.
      expect(h.contains('0.53'), isFalse, reason: 'sihirli katsayı geri gelmiş');
      expect(h.contains('static double panelYuksekligi('), isTrue);
      expect(h.contains('LayoutBuilder'), isTrue);
      expect(h.contains('ListView.builder'), isTrue);
      // Sayfanın tamamı değil panelin içi kayar.
// ⚠ PANEL ARTIK KAYMIYOR (15 Ağu): 12 kart dört satır hâlinde
      // birden çizilir, gerekiyorsa SAYFA kayar.
      expect(h.contains('NeverScrollableScrollPhysics'), isTrue);
      expect(h.contains('shrinkWrap: true'), isTrue);
      // ⚠ GÖRÜNÜR ÇUBUK YOK (ürün kararı).
      expect(h.contains('Scrollbar('), isFalse,
          reason: 'kaydırma çubuğu geri gelmiş');
    });

    test('12 ÇATININ HEPSİ tıklanabilir ve kendi ekranını açar', () {
      final h = _k('lib/screens/home_screen.dart');
      // Tek kart sınıfından çizilir; biri hariç kalamaz.
      // ⚠ Girinti değişebilir; ADI aranır, biçimi değil.
      expect(h.contains('satir * _kSutun + s'), isTrue);
      expect(h.contains('HizmetAlaniScreen(alan: alan)'), isTrue);
      expect(h.contains('class _AlanKarti'), isTrue);
    });

    test('KARTTA ÇATI İKONU ÇİZİLMEZ', () {
      // ⚠ KESİN KARAR (15 Ağu): hiyerarşi yalnız fotoğraf → başlık →
      // açıklama. `HizmetAlani.ikon` alanı veri modelinde DURUYOR
      // ama kart onu kullanmıyor.
      final h = _k('lib/screens/home_screen.dart');
      expect(h.contains('RefSvg(alan.ikon'), isFalse,
          reason: 'çatı ikonu geri gelmiş');
      expect(h.contains('alan.ikon'), isFalse);
    });

    test('GÖRÜNTÜ ESNETİLMEZ', () {
      // 240×240 görsel 1.5 orana kırpılır; geometrik bozulma yok.
      final h = _k('lib/screens/home_screen.dart');
      expect(h.contains('fit: BoxFit.cover'), isTrue);
      expect(h.contains('BoxFit.fill'), isFalse);
    });
  });

  group('EKRAN — ÇATI KAPSAMI MERKEZDEN ÇÖZÜLÜR', () {
    String _k(String yol) => File(yol)
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    test('çatı ekranı ELLE KURAL yazmaz', () {
      // ⚠ Ekranlar kendi çatı kuralını yazamaz; istisna listesi
      // büyüyünce ekran kendiliğinden uymalı.
      final e = _k('lib/screens/hizmet_alani_screen.dart');
      expect(e.contains('alanHizmetleri(widget.alan.ad)'), isTrue);
      expect(e.contains('Oto Anahtarcı'), isFalse,
          reason: 'ekrana hizmet adı gömülmüş');
      expect(e.contains('kHizmetCatiIstisnasi'), isFalse,
          reason: 'ekran istisna listesini kendi okumamalı');
    });

    test('kategori ekranı ÇATI BAĞLAMINI korur', () {
      final c = _k('lib/screens/category_screen.dart');
      expect(c.contains('final String? alan;'), isTrue);
      expect(c.contains('hizmetAlani(category, h) == alan'), isTrue);
      final e = _k('lib/screens/hizmet_alani_screen.dart');
      expect(e.contains('CategoryScreen(category: kategori, alan: alan)'),
          isTrue);
    });

    test('OTO ANAHTARCI Araç Hizmeti kapsamında, Ev Hizmeti değil', () {
      final arac = alanHizmetleri('Araç Hizmeti').map((e) => e.hizmet);
      final ev = alanHizmetleri('Teknik Hizmetler').map((e) => e.hizmet);
      expect(arac, contains('Oto Anahtarcı'));
      expect(ev, isNot(contains('Oto Anahtarcı')));
    });

    test('ARAÇ DÖŞEME YIKAMA Araç Hizmeti kapsamında, Temizlik değil', () {
      final arac = alanHizmetleri('Araç Hizmeti').map((e) => e.hizmet);
      final tem = alanHizmetleri('Temizlik').map((e) => e.hizmet);
      expect(arac, contains('Araç Döşeme Yıkama'));
      expect(tem, isNot(contains('Araç Döşeme Yıkama')));
    });

    test('İSTİSNA GELEN KATEGORİ çatı ekranında görünür', () {
      // Çilingir kategorisi Ev Hizmeti'nde ama Araç Hizmeti ekranında
      // da satır olarak çıkmalı — yoksa Oto Anahtarcı'ya ulaşılamaz.
      final arac = alanHizmetleri('Araç Hizmeti').map((e) => e.kategori);
      expect(arac, contains('Çilingir ve Kilit'));
      expect(arac, contains('Koltuk ve Döşeme Yıkama'));
    });

    test('HİÇBİR HİZMET ERİŞİLEMEZ KALMIYOR', () {
      // ⚠ En kritik denetim: UI süzgeci 517 hizmetten birini bile
      // düşürürse o hizmet çatı yolundan bulunamaz.
      final gorunen = <String>{};
      for (final a in kHizmetAlanlari) {
        for (final e in alanHizmetleri(a.ad)) {
          gorunen.add('${e.kategori}|${e.hizmet}');
        }
      }
      final tum = <String>{};
      for (final e in kCategoryTree.entries) {
        for (final h in e.value) {
          tum.add('${e.key}|$h');
        }
      }
      expect(gorunen.length, 640);
      expect(tum.difference(gorunen), isEmpty,
          reason: 'çatı yolundan erişilemeyen hizmet var');
    });

    test('İLAN VERME ekranı ARAMA-ONLY kalıyor', () {
      final cre = _k('lib/screens/create_listing_screen.dart');
      expect(cre.contains('KategoriKarti('), isFalse);
      expect(cre.contains('GridView.count'), isFalse);
      expect(cre.contains('kKartKategorileri'), isFalse);
      expect(cre.contains('SearchService.services('), isTrue);
    });
  });


  group('KATEGORİ EKRANI — TEK HİZMET SEÇİMİ', () {
    String _k(String yol) => File(yol)
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    final c = _k('lib/screens/category_screen.dart');

    test('UYGUN İLANLAR bölümü KALDIRILDI', () {
      // ⚠ Ekranın işi hizmet seçtirmek; açık ilan listesi burada
      // kullanıcıyı akıştan çıkarıyordu.
      expect(c.contains('Uygun İlanlar'), isFalse);
      expect(c.contains('JobDetailScreen'), isFalse);
      expect(c.contains('ListingController'), isFalse,
          reason: 'ilan verisi hâlâ okunuyor');
    });

    test('DÜĞME METNİ ve ikon', () {
      expect(c.contains("'Devam Et'"), isTrue);
      expect(c.contains('Bu kategoride ilan ver'), isFalse);
      expect(c.contains('ic_addbox'), isFalse, reason: '+ ikonu geri gelmiş');
    });

    test('TEK SEÇİM — çoklu seçim yok', () {
      // Tek bir `String?` tutulur; küme/liste tutulsaydı çoklu seçim
      // mümkün olurdu.
      expect(c.contains('String? _secili;'), isTrue);
      expect(c.contains('Set<String> _secili'), isFalse);
      expect(c.contains('List<String> _secili'), isFalse);
    });

    test('DÜĞME HER ROLDE ÇİZİLİR', () {
      // ⚠ Düğme yalnız müşteriye gösterilirse hizmet veren rolündeki
      // kullanıcı hizmeti seçer ama devam edemez — sessiz ölü dal.
      // Rol kararı `startFlow` içinde verilir.
      expect(c.contains('auth.activeRole == Role.customer || !auth.loggedIn'),
          isFalse, reason: 'düğme role bağlanmış');
    });

    test('SEÇİM YOKKEN düğme PASİF', () {
      expect(c.contains('_secili == null ? null :'), isTrue);
    });

    test('TEK HİZMET KURALI kullanıcıya YAZILI', () {
      expect(
          c.contains('Her ilan için yalnızca bir hizmet seçebilirsiniz.'),
          isTrue);
    });

    test('SATIRLAR TEK SÜTUN — Wrap değil', () {
      // ⚠ `Wrap` satır başına değişken sayıda kart koyuyordu; düzen
      // ada göre değişiyordu.
      expect(c.contains('Wrap('), isFalse, reason: 'düzensiz dizilim geri gelmiş');
      expect(c.contains('class _HizmetSatiri'), isTrue);
    });

    test('SEÇİLİ hâl yalnız RENKLE anlatılmaz', () {
      // Renk körü kullanıcı için kenarlık ve işaret de değişir.
      expect(c.contains('width: secili ? 1.4 : 1'), isTrue);
      expect(c.contains('ic_checksm.svg'), isTrue);
    });
  });
}
