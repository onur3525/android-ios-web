import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/arama_es_anlamlilari.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/data/services/search_service.dart';

/// ARAMA EŞ ANLAMLILARI — kapsam ve davranış.
///
/// ⚠ Bu testler bir İŞ KURALINI korur: kataloğa yeni bir alt hizmet
/// eklendiğinde `arama_es_anlamlilari.dart` dosyasına da terimleri
/// eklenmelidir. Terim eklenmezse ilk test düşer ve eksik hemen
/// görülür.
void main() {
  group('Kapsam', () {
    test('KATALOGDAKİ HER ALT HİZMETİN ARAMA TERİMİ VARDIR', () {
      final eksik = <String>[];
      for (final subs in kCategoryTree.values) {
        for (final s in subs) {
          if (!kAramaEsAnlamlilari.containsKey(s)) {
            eksik.add(s);
          }
        }
      }
      expect(eksik, isEmpty,
          reason: 'Bu hizmetlere arama terimi eklenmeli: $eksik');
    });

    test('SÖZLÜKTE KATALOGDA OLMAYAN ANAHTAR YOKTUR', () {
      final tumAlt = <String>{
        for (final subs in kCategoryTree.values) ...subs,
      };
      final fazla =
          kAramaEsAnlamlilari.keys.where((k) => !tumAlt.contains(k)).toList();
      expect(fazla, isEmpty,
          reason: 'Katalogda karşılığı olmayan anahtar: $fazla');
    });

    test('her hizmetin EN AZ İKİ terimi vardır', () {
      final az = kAramaEsAnlamlilari.entries
          .where((e) => e.value.length < 2)
          .map((e) => e.key)
          .toList();
      expect(az, isEmpty, reason: 'Terimi yetersiz hizmetler: $az');
    });

    test('terimler KÜÇÜK HARFLE yazılır', () {
      final buyuk = <String>[];
      for (final e in kAramaEsAnlamlilari.entries) {
        for (final t in e.value) {
          if (t != t.toLowerCase()) {
            buyuk.add('${e.key} → $t');
          }
        }
      }
      expect(buyuk, isEmpty, reason: 'Büyük harf içeren terimler: $buyuk');
    });
  });

  group('Çok kelimeli arama', () {
    test('"kombi bakım" → Kombi Bakımı', () {
      // ⚠ Önceden SIFIR sonuç dönüyordu: sorgu tek parça aranıyor,
      // katalogdaki ad "Kombi Bakımı" olduğu için tutmuyordu.
      final r = SearchService.services('kombi bakım');
      expect(r.any((h) => h.subService == 'Kombi Bakımı'), isTrue);
    });

    test('"ev temizlik" → Ev Temizliği', () {
      final r = SearchService.services('ev temizlik');
      expect(r.any((h) => h.subService == 'Ev Temizliği'), isTrue);
    });
  });

  group('Eş anlamlı arama', () {
    test('"gaz kaçağı" → Doğalgaz Kaçak Kontrolü', () {
      // Kullanıcı hizmet adını değil DERDİNİ yazar.
      final r = SearchService.services('gaz kaçağı');
      expect(r.any((h) => h.subService == 'Doğalgaz Kaçak Kontrolü'), isTrue);
    });

    test('"kapı kilitli kaldı" → Kapı Açma', () {
      // ⚠ TERİM DEĞİŞTİ: kişisel anlatım ("kapıda kaldım") öneri
      // listesinden çıkarıldı; yerine durum cümlesi kondu.
      final r = SearchService.services('kapı kilitli kaldı');
      expect(r.any((h) => h.subService == 'Kapı Açma'), isTrue);
    });

    test('"badana" → Boya Badana', () {
      // Yeni katalogda `Saten Boya Badana` yerine `Boya Badana`.
      final r = SearchService.services('badana');
      expect(r.any((h) => h.subService == 'Boya Badana'), isTrue);
    });

    test('"çatı akıyor" → Çatı Tamiri', () {
      final r = SearchService.services('çatı akıyor');
      expect(r.any((h) => h.subService == 'Çatı Tamiri'), isTrue);
    });

    test('"buzdolabı soğutmuyor" → Buzdolabı Tamiri', () {
      final r = SearchService.services('buzdolabı soğutmuyor');
      expect(r.any((h) => h.subService == 'Buzdolabı Tamiri'), isTrue);
    });

    test('"tıkalı" → Tıkanıklık Açma', () {
      final r = SearchService.services('tıkalı');
      expect(r.any((h) => h.subService == 'Tıkanıklık Açma'), isTrue);
    });
  });

  group('Çakışma', () {
    test('"kaçak" HEM su HEM doğalgaz sonucunu getirir', () {
      // ⚠ Çakışma SORUN DEĞİLDİR: kullanıcı hangisini kastettiğini
      // listeden seçer. Tek sonuca zorlamak yanlış olurdu.
      //
      // ⚠ `Tesisat Kaçağı Tespiti` yeni katalogda `Su Kaçağı Tespiti`
      // adıyla duruyor; `Doğalgaz Tesisatı` yerine kaçak karşılığı
      // artık `Doğalgaz Kaçak Kontrolü`dür.
      final r = SearchService.services('kaçak');
      expect(r.any((h) => h.subService == 'Su Kaçağı Tespiti'), isTrue);
      expect(r.any((h) => h.subService == 'Doğalgaz Kaçak Kontrolü'), isTrue);
    });
  });

  group('Sınırlar', () {
    test('boş sorgu sonuç döndürmez', () {
      expect(SearchService.services(''), isEmpty);
      expect(SearchService.services('   '), isEmpty);
    });

    test('anlamsız sorgu sonuç döndürmez', () {
      expect(SearchService.services('zzzqqqxxx'), isEmpty);
    });
  });


  group('DOĞALGAZ — TÜREV KAPSAMI', () {
    // ⚠ KURAL: "doğalgaz" geçen her iş doğalgaz hizmetlerine bağlanır.
    // Katalog BÜYÜTÜLMEZ; kullanıcı ne yazarsa yazsın mevcut DÖRT
    // hizmetten birine düşer ve onunla ilan açar.

    test('sahadaki yaygın ifadeler bir hizmete DÜŞER', () {
      const sorgular = [
        'doğalgaz ocak bağlama',
        'ankastre ocak bağlantısı',
        'ocak hortumu',
        'lpg doğalgaz dönüşümü',
        'meme değişimi',
        'daire içi doğalgaz',
        'bina içi tesisat',
        'doğalgaz sobası',
        'doğalgazlı şofben',
        'endüstriyel doğalgaz tesisatı',
        'merkezi sistem doğalgaz',
        'gaz açma',
        'doğalgaz aboneliği',
        'uygunluk belgesi',
        'kolon projesi',
        'doğalgaz kaçağı tamiri',
        'gaz kaçağı onarımı',
        'gaz dedektörü kontrolü',
        'sayaç yeri değişikliği',
        'kolon tesisatı',
        'doğalgaz hattı uzatma',
      ];
      final bulunamayan = <String>[];
      for (final q in sorgular) {
        final r = SearchService.services(q);
        if (r.isEmpty) {
          bulunamayan.add(q);
        }
      }
      expect(bulunamayan, isEmpty,
          reason: 'sonuç dönmeyen ifadeler: $bulunamayan');
    });

    test('ocak ve dönüşüm işleri DOĞALGAZ TESİSATINA gider', () {
      for (final q in const [
        'ocak bağlama',
        'ankastre ocak bağlantısı',
        'lpg doğalgaz dönüşümü',
        'doğalgaz sobası montajı',
      ]) {
        final r = SearchService.services(q);
        expect(r.any((h) => h.subService == 'Doğalgaz Tesisatı'), isTrue,
            reason: q);
      }
    });

    test('abonelik ve gaz açma PROJEYE gider', () {
      for (final q in const [
        'gaz açımı',
        'doğalgaz aboneliği',
        'izmirgaz abonelik',
        'tadilat uygunluk belgesi',
      ]) {
        final r = SearchService.services(q);
        expect(r.any((h) => h.subService == 'Doğalgaz Projesi'), isTrue,
            reason: q);
      }
    });

    test('kaçakla ilgili her iş DOĞALGAZ kategorisinde kalır', () {
      // ⚠ Ayrı bir "kaçak tamiri" kaydı YOK. Tespit ve onarım aynı
      // ustanın işi; sorgu "Doğalgaz Tesisatı" ya da "Kaçak
      // Kontrolü"ne düşebilir — ikisi de doğrudur, çünkü ilan aynı
      // kategoriye açılır.
      for (final q in const [
        'doğalgaz kaçağı tamiri',
        'gaz kaçağı onarımı',
        'gaz kaçak testi',
        'gaz dedektörü kontrolü',
      ]) {
        final r = SearchService.services(q);
        expect(
            r.any((h) => h.category == 'Doğalgaz'), isTrue,
            reason: q);
      }
    });

    test('KATALOG BÜYÜMEDİ — doğalgaz altında hâlâ dört hizmet', () {
      // Türev zenginliği katalog kaydı açmaz.
      // ⚠ 4 → 8: doğalgaz hizmetleri ürün kararıyla ayrıldı
      // (iç tesisat, kolon hattı, kaçak tespiti, kaçak onarımı).
      // ⚠ 8 → 13: sonraki turda ocak bağlantısı, ocak dönüşümü, soba
      // montajı, abonelik ve sayaç taşıma da gerçek hizmet oldu.
      // ⚠ 13 → 11: abonelik işlemleri ve sayaç taşıma KALDIRILDI
      // (dağıtım şirketi işi, usta yapmaz).
      expect(kCategoryTree['Doğalgaz']!.length, 11);
    });
  });


  group('55 KATEGORİ TÜREV KAPSAMI', () {
    // ⚠ Kullanıcının DERDİYLE aradığı ifadeler sonuç döndürmeli.
    // Katalog BÜYÜMEDEN, yalnız sözlük genişletilerek sağlanır.
    //
    // ⚠ TERİM YAZIM KURALLARI (14 Ağu, kullanıcı kararı):
    //   · fiyat geçen terim YOK
    //   · bağlamsız canlı/nesne adı YOK ("hamamböceği" değil
    //     "hamamböceği ilaçlama")
    //   · kişisel anlatım YOK ("kapıda kaldım" değil "kapı kilitli
    //     kaldı")

    test('her kategoriden örnek sorgu sonuç döndürür', () {
      const sorgular = [
        'gündelikçi', 'boş ev temizliği', 'inşaat sonrası',
        'kilim yıkama', 'koltuk temizliği', 'yatak temizliği',
        'hamamböceği ilaçlama', 'fare ilaçlama', 'tahtakurusu ilaçlama',
        'lavabo tıkandı', 'boru patladı', 'batarya değişimi',
        'kombi arızası', 'eşanjör temizliği',
        'petek temizletme', 'termosifon arızası',
        'sigorta attı', 'priz takma', 'avize takma',
        'güvenlik kamerası', 'diafon montajı', 'parmak izli kilit',
        'klima soğutmuyor', 'klima gaz dolumu',
        'buzdolabı soğutmuyor', 'davlumbaz tamiri',
        'laptop tamiri', 'ekran değişimi',
        'çanak ayarı', 'tv askı aparatı',
        'wifi çekmiyor', 'modem kurulumu',
        'boyacı', 'dış cephe boya', 'tavan boyama',
        'alçıpan bölme', 'kartonpiyer montajı',
        'duvar kağıdı yapıştırma',
        'ev yenileme', 'anahtar teslim',
        'banyo yenileme', 'duşakabin kurulumu',
        'mutfak dolabı', 'tezgah değişimi',
        'duvar örme', 'şap atma', 'moloz taşıma',
        'fayans ustası', 'derz yenileme',
        'laminat parke', 'parke zımpara', 'epoksi zemin',
        'mantolama yaptırma', 'ses izolasyonu',
        'çatı akıtıyor', 'oluk değişimi',
        'ikea montajı', 'gömme dolap yapımı',
        'marangoz ustası', 'raf yapımı',
        'çelik kapı takma', 'kapı kolu değişimi',
        'katlanır cam', 'kırık cam değişimi',
        'sineklik takma', 'panjur montajı',
        'ferforje korkuluk', 'argon kaynak işi',
        'kapı kilitli kaldı', 'barel değiştirme',
        'peyzaj düzenleme', 'ağaç budama', 'damlama sulama sistemi',
        'havuz temizliği', 'havuz kaçağı onarımı',
        'nakliyeci', 'asansörlü nakliyat', 'piyano nakliyesi',
        'moto kurye', 'asansör arızası',
        'statik hesap', 'zemin etüt raporu',
        'oto çekici çağır', 'akü takviyesi',
        'balata değişimi', 'yağ değişimi',
        'pasta cila uygulaması', 'oto koltuk yıkama',
        'lgs matematik', 'ödev desteği',
        'ingilizce öğretmeni', 'online ders',
        'direksiyon eğitimi',
        'personal trainer', 'pilates eğitmeni',
        'gitar öğretmeni', 'vokal dersi',
        'site yaptırma', 'wordpress kurulumu',
        'logo yaptırma', 'kartvizit tasarımı',
        'instagram yönetimi', 'seo danışmanı',
        'ürün çekimi', 'kurumsal çekim',
        'balon süsleme', 'nişan organizasyonu',
        'köpek yürüyüşü', 'evde hayvan bakıcısı',
        'gelin makyajı', 'kalıcı oje', 'evde kuaför',
      ];
      final bulunamayan = <String>[];
      for (final q in sorgular) {
        if (SearchService.services(q).isEmpty) {
          bulunamayan.add(q);
        }
      }
      expect(bulunamayan, isEmpty,
          reason: 'sonuç dönmeyen ifadeler: $bulunamayan');
    });

    test('FİYAT geçen terim YOK', () {
      final fiyatli = <String>[];
      for (final e in kAramaEsAnlamlilari.entries) {
        for (final t in e.value) {
          if (t.contains('fiyat') || t.contains('ne kadar') ||
              t.contains('ucuz')) {
            fiyatli.add('${e.key} → $t');
          }
        }
      }
      expect(fiyatli, isEmpty, reason: 'fiyat terimi: $fiyatli');
    });

    test('KİŞİSEL ANLATIM YOK', () {
      // "kapıda kaldım" gibi birinci tekil şahıs ifadeler öneri
      // listesine girmez; durum cümlesi girer ("kapı kilitli kaldı").
      final kisisel = <String>[];
      // ⚠ "yardım" gibi normal sözcükler yanlış eşleşmesin diye
      // kalıp KİŞİ EKİYLE sınırlı: en az iki harflik gövde + ek.
      final ek = RegExp(r'^(?!yardım$)\w{3,}(dım|dim|dum|düm|yorum)$');
      for (final e in kAramaEsAnlamlilari.entries) {
        for (final t in e.value) {
          if (t.split(' ').any(ek.hasMatch)) {
            kisisel.add('${e.key} → $t');
          }
        }
      }
      expect(kisisel, isEmpty, reason: 'kişisel anlatım: $kisisel');
    });

    test('KATALOG BÜYÜMEDİ', () {
      expect(kCategoryTree.length, 160);
      expect(kCategoryTree.values.fold<int>(0, (a, b) => a + b.length), 640);
      expect(kAramaEsAnlamlilari.length, 640);
    });
  });


  group('DOĞALGAZ GENİŞLETİLDİ — 4 → 8 HİZMET', () {
    // ⚠ Bu dördü eskiden yalnız TERİMDİ; kullanıcı "kolon hattı"
    // seçtiğinde ilanı "Doğalgaz Tesisatı" adıyla açılıyordu — yani
    // seçtiğiyle ilanında yazan farklı oluyordu.

    test('yeni hizmetler KATALOGDA', () {
      const yeni = [
        'Doğalgaz İç Tesisatı',
        'Doğalgaz Kolon Hattı',
        'Doğalgaz Kaçak Tespiti',
        'Doğalgaz Kaçak Onarımı',
      ];
      final altlar = kCategoryTree['Doğalgaz'] ?? const <String>[];
      for (final y in yeni) {
        expect(altlar, contains(y), reason: y);
      }
      expect(altlar.length, 11);
    });

    test('birleşik kategori adı KALDIRILDI', () {
      // "Doğalgaz Tesisatı ve Proje" iki işi tek başlıkta
      // birleştiriyordu; ürün kararıyla ad tek sözcüğe indi.
      expect(kCategoryTree.containsKey('Doğalgaz Tesisatı ve Proje'),
          isFalse);
      expect(kCategoryTree.containsKey('Doğalgaz'), isTrue);
    });

    test('her yeni hizmet KENDİ adıyla bulunur', () {
      const sorgular = {
        'doğalgaz iç tesisatı': 'Doğalgaz İç Tesisatı',
        'doğalgaz kolon hattı': 'Doğalgaz Kolon Hattı',
        'doğalgaz kaçak tespiti': 'Doğalgaz Kaçak Tespiti',
        'doğalgaz kaçak onarımı': 'Doğalgaz Kaçak Onarımı',
      };
      sorgular.forEach((q, hedef) {
        final r = SearchService.services(q);
        expect(r.any((h) => h.subService == hedef), isTrue, reason: q);
      });
    });

    test('KISA sorgu doğru hizmete gider', () {
      // Kullanıcı "doğalgaz" demeden de arar.
      const sorgular = {
        'iç tesisat': 'Doğalgaz İç Tesisatı',
        'kolon hattı': 'Doğalgaz Kolon Hattı',
        'kaçak tespiti': 'Doğalgaz Kaçak Tespiti',
      };
      sorgular.forEach((q, hedef) {
        final r = SearchService.services(q);
        expect(r.first.subService, hedef, reason: '$q → ilk sonuç');
      });
    });

    test('KAÇAK terimleri genel tesisata DÜŞMEZ', () {
      // Kaçak artık üç ayrı hizmet; genel "gaz kaçağı" terimleri
      // Doğalgaz Tesisatı'ndan çıkarıldı, yoksa asıl hedefin önüne
      // geçiyordu.
      final r = SearchService.services('gaz kaçağı onarımı');
      expect(r.first.subService, isNot('Doğalgaz Tesisatı'));
      expect(r.any((h) => h.subService == 'Doğalgaz Kaçak Onarımı'), isTrue);
    });
  });


  group('KATALOG GENİŞLETMESİ — 255 → 439 → 517', () {
    // ⚠ Onaylı öneri listesindeki maddelerden AYRI BİR İŞ olanlar
    // gerçek hizmet kaydına çevrildi. Meslek adları ("boyacı"),
    // şikâyet cümleleri ("sigorta attı") ve eş anlamlılar TERİM
    // olarak kaldı.

    test('58 kategori · 517 hizmet · tekrar yok', () {
      expect(kCategoryTree.length, 160);
      final tum = [for (final v in kCategoryTree.values) ...v];
      expect(tum.length, 640);
      expect(tum.toSet().length, 640, reason: 'aynı hizmet iki kez');
    });

    test('her hizmetin sözlük karşılığı var', () {
      final eksik = <String>[];
      for (final v in kCategoryTree.values) {
        for (final s in v) {
          if (!kAramaEsAnlamlilari.containsKey(s)) {
            eksik.add(s);
          }
        }
      }
      expect(eksik, isEmpty, reason: 'sözlükte olmayan: $eksik');
    });

    test('örnek yeni hizmetler KENDİ adıyla bulunur', () {
      const ornekler = [
        'Doğalgaz Ocak Bağlantısı',
        'Kombi Baca Montajı',
        'Ankastre Cihaz Montajı',
        'Klima Gaz Dolumu',
        'Asma Tavan Yapımı',
        'Granit Tezgah Montajı',
        'Parke Zımpara ve Cila',
        'Balkon Korkuluğu Montajı',
        'Otomatik Sulama Montajı',
        'Asansörlü Taşıma',
        'Güçlendirme Projesi',
        'Kimya Özel Ders',
        'IELTS ve TOEFL Hazırlık',
        'Düğün ve Nişan Fotoğrafçısı',
        'Pet Kuaför',
        'Gelin Saçı ve Makyajı',
      ];
      final bulunamayan = <String>[];
      for (final o in ornekler) {
        final r = SearchService.services(o);
        if (!r.any((h) => h.subService == o)) {
          bulunamayan.add(o);
        }
      }
      expect(bulunamayan, isEmpty, reason: 'bulunamayan: $bulunamayan');
    });

    test('kullanıcı dilinden de bulunur', () {
      const sorgular = {
        'ocak bağlama': 'Doğalgaz Ocak Bağlantısı',
        'ankastre montajı': 'Ankastre Cihaz Montajı',
        'klima gazı': 'Klima Gaz Dolumu',
        'asma tavan': 'Asma Tavan Yapımı',
        'deprem raporu': 'Deprem Performans Analizi',
        'düğün fotoğrafçısı': 'Düğün ve Nişan Fotoğrafçısı',
        'köpek tıraşı': 'Pet Kuaför',
        'ütücü': 'Ütü Hizmeti',
      };
      sorgular.forEach((q, hedef) {
        final r = SearchService.services(q);
        expect(r.any((h) => h.subService == hedef), isTrue, reason: q);
      });
    });
  });


  group('HİZMET LİDERİ YAPISI — 77 YENİ HİZMET', () {
    // ⚠ ÜRÜN ADI KATEGORİ OLMAZ. Kullanıcı "ayakkabı" yazınca
    // "AYAKKABI" diye bir kategori değil, `Ayakkabı Tamiri` hizmetini
    // görür. Liderin altındaki işler de aranabilir ve seçilebilir.

    test('üç yeni kategori KATALOGDA', () {
      for (final k in const [
        'Ayakkabı ve Deri İşleri',
        'Terzilik ve Dikiş',
        'Ev Tekstili',
      ]) {
        expect(kCategoryTree.containsKey(k), isTrue, reason: k);
      }
    });

    test('21 LİDER hizmet katalogda GERÇEK HİZMET', () {
      final tum = {for (final v in kCategoryTree.values) ...v};
      for (final l in kLiderHizmetler) {
        expect(tum, contains(l), reason: '$l hizmet değil');
      }
      expect(kLiderHizmetler.length, 21);
    });

    test('ÜRÜN ADIYLA arayan LİDERİ görür', () {
      const beklenen = {
        'ayakkabı': 'Ayakkabı Tamiri',
        'çanta': 'Çanta Tamiri',
        'deri': 'Deri Tamiri',
        'kemer': 'Kemer Tamiri',
        'cüzdan': 'Cüzdan Tamiri',
        'yorgan': 'Yorgan Dikimi',
        'yatak': 'Yatak Yenileme',
        'örgü': 'Örgü Yapımı',
        'triko': 'Triko Tamiri',
        'kilim': 'Kilim Tamiri',
        'kumaş': 'Kumaş Dokuma',
        'perde': 'Perde Dikimi',
        'halı': 'Halı Tamiri',
      };
      beklenen.forEach((q, hedef) {
        final r = SearchService.services(q);
        expect(r.first.subService, hedef, reason: '$q → ilk sonuç');
      });
    });

    test('LİDER ALTINDAKİ işler de bulunur', () {
      const ornekler = [
        'Bot Tamiri',
        'Sneaker Tamiri',
        'Çanta Boyama',
        'Deri Restorasyonu',
        'Yorgan İçi Değişimi',
        'Bilgisayarlı Nakış',
        'Halı Saçak Yenileme',
        'Fon Perde Dikimi',
        'Numune Dikimi',
        'İlik Açma',
      ];
      for (final o in ornekler) {
        final r = SearchService.services(o);
        expect(r.any((h) => h.subService == o), isTrue, reason: o);
      }
    });

    test('MİKRO İŞLER ayrı hizmet DEĞİL, terim', () {
      // Taban değişimi, fermuar tamiri, sap değişimi gibi işler
      // liderin kapsamındadır; katalogda kayıtları YOKTUR.
      final tum = {for (final v in kCategoryTree.values) ...v};
      for (final m in const [
        'Ayakkabı Taban Tamiri',
        'Ayakkabı Taban Değişimi',
        'Ayakkabı Fermuar Tamiri',
        'Çanta Sap Değişimi',
        'Çanta Astar Değişimi',
        'Kemer Toka Değişimi',
      ]) {
        expect(tum.contains(m), isFalse, reason: '$m mikro hizmet açılmış');
      }
      // Ama TERİM olarak bulunurlar.
      expect(SearchService.services('taban değişimi'), isNotEmpty);
      expect(SearchService.services('çanta sapı tamiri'), isNotEmpty);
    });

    test('VAR OLAN hizmet TEKRAR EKLENMEDİ', () {
      // "Halı Yıkama" katalogda kendi kategorisi olarak duruyordu;
      // Halı Tamiri liderinin altına ikinci kez konmadı.
      final tum = [for (final v in kCategoryTree.values) ...v];
      expect(tum.where((s) => s == 'Halı Yıkama'), isEmpty);
      expect(kCategoryTree.containsKey('Halı Yıkama'), isTrue);
      expect(tum.length, tum.toSet().length, reason: 'tekrar eden hizmet');
    });

    test('LİDER AVANSI KADEME ATLATMAZ', () {
      // Tam eşleşme, liderin başlangıç eşleşmesinden ÖNCE gelir.
      final r = SearchService.services('halı yıkama');
      expect(r.first.category, 'Halı Yıkama');
      expect(r.first.subService, isNull);
    });
  });
}
