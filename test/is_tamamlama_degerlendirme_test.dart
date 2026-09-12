import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/config.dart';

import 'support/kaynak_okuma.dart';

/// Kaynak dosyayı okur — `incelenen_ilan_test` ile aynı yaklaşım.
String read(String p) => File(p).readAsStringSync();

/// İŞ TAMAMLAMA → DEĞERLENDİRME AKIŞI — EKRAN SÖZLEŞMESİ
///
/// ⚠ Bu testler DAVRANIŞ KURALLARINI kaynak metin üzerinden kilitler.
/// İş kuralı testleri (`business_rules_test`) durum makinesini ve
/// cüzdan etkilerini ayrıca doğrular; burada denetlenen şey, o
/// kuralların EKRANDA doğru bağlanmış olmasıdır.
void main() {
  final ilanDetay = read('lib/screens/listing_detail_screen.dart');
  final teklifDetay = read('lib/screens/offer_detail_screen.dart');
  final degerlendirme = read('lib/screens/review_screen.dart');

  group('İş tamamlama', () {
    test('AYRI "İşi Başlat" adımı YOKTUR', () {
      // ⚠ Ürün kararı: teklif seçildikten sonra iş fiilen başlamıştır.
      // Ayrı bir başlatma adımı unutulduğunda ilan tamamlanamaz
      // duruma düşüyordu.
      expect(ilanDetay.contains("'İşi Başlat'"), isFalse,
          reason: 'ara adım kaldırıldı');
      expect(ilanDetay.contains('startWork('), isFalse,
          reason: 'ekran artık startWork çağırmaz');
    });

    test('⚠ "İŞİ TAMAMLA" AKSİYONU DA KALDIRILDI', () {
      // API sözleşmesi §11: nihai akış İletişimi Aç → Teklifi Seç →
      // Yorum Yap. Ayrı bir tamamlama adımı YOKTUR; teklif seçildiği
      // anda iş tamamlanmış sayılır.
      expect(ilanDetay.contains("SysButton('İşi Tamamla'"), isFalse,
          reason: 'tamamlama düğmesi kalmış');
      expect(ilanDetay.contains('completeWork('), isFalse,
          reason: 'ekran hâlâ completeWork çağırıyor');
      // ⚠ Değerlendirme yolu KORUNUR — kaldırılan yalnız tamamlama.
      expect(ilanDetay.contains('ReviewScreen('), isTrue,
          reason: 'değerlendirme yolu da silinmiş');
    });

  });

  group('SEÇİLMİŞ TEKLİFTE "İletişimi Aç" ÇIKMAZ', () {
    test('open bayrağı ilan durumuna BAĞLANMAZ', () {
      // ⚠ Önce `l.status == completed` şartı vardı; seçim yapılmış
      // ESKİ kayıtlarda ilan `providerSelected` kalabildiği için o
      // ilanlarda düğme yeniden çıkıyordu. Belirleyici olan tek şey
      // SEÇİLMİŞ OLMAKTIR — seçim ancak iletişim açıkken yapılır.
      expect(teklifDetay.contains('l.selectedOfferId == offer.id ||'), isTrue);
      expect(teklifDetay.contains('offer.status == OfferStatus.selected;'),
          isTrue);
      expect(
          teklifDetay.contains(
              "l.status == ListingStatus.completed"),
          isFalse,
          reason: 'durum şartı geri gelmiş');
    });

    test('seçilmiş teklifte düğme YORUM dalına düşer', () {
      // Zincir: `if (!open)` → `else if (ilan açık && teklif aktif)`
      // → `else if (teklif seçili)`. Seçilmiş teklifte `open` daima
      // true olduğu için ilk dal ATLANIR.
      final i = teklifDetay.indexOf('if (!open) ...[');
      final j = teklifDetay.indexOf('else if (offer.status == OfferStatus.selected)');
      expect(i, greaterThan(0));
      expect(j, greaterThan(i), reason: 'yorum dalı zincirin sonunda olmalı');
      expect(teklifDetay.contains("'Yorum Yaz'"), isTrue);
      // ⚠ AD DEĞİŞTİ (12 Eyl): puan şeritten kalktı, eylem ikinci
      // satıra indi — "Yorum yapıldı" + "Görüntüle".
      expect(teklifDetay.contains("'Yorum yapıldı'"), isTrue);
      expect(teklifDetay.contains('Yorum yazmak ücretsizdir'), isFalse,
          reason: 'kaldırılan ücretsizlik yazısı geri gelmiş');
      expect(teklifDetay.contains('Teklif seçmek ücretsizdir.'), isFalse,
          reason: 'kaldırılan ücretsizlik yazısı geri gelmiş');
      // ⚠ BEDEL ALINAN işlemde şerit KALIR — tek kalan budur.
      expect(teklifDetay.contains('İletişimi açmak ücretsizdir.'), isTrue);
    });
  });

  group('Değerlendirme', () {
    test('TEK SEFERLİK — gönderilmiş değerlendirme değiştirilemez', () {
      // ⚠ KİLİT CÜMLEDEN DAVRANIŞA TAŞINDI (9 Eyl): yeşil bilgi
      // şeridi kullanıcı isteğiyle kaldırıldı. Kural aynen duruyor —
      // kayıt varken ekran form dalını hiç çizmez.
      expect(degerlendirme.contains('done == null'), isTrue,
          reason: 'yorum var/yok ayrımı kaybolmuş — yazılmış '
              'değerlendirme yeniden düzenlenebilir hâle gelir');
      // ⚠ TEK KİLİT KALDI: `reviewed`.
      //
      // Referans `vOffer`: `reviewed ? "Değerlendirme" : "Teklifi Seç"`.
      // Durum koşulu YOK — çünkü "Teklifi Seç" düğmesi zaten yalnız
      // iletişim AÇIKKEN çiziliyor ve değerlendirme gönderimi ilanı o
      // anda tamamlıyor (`submitReviewDo`).
      expect(teklifDetay.contains('onPressed: !reviewed'), isTrue);
    });

    test('YORUM SATIRINDA "5 puan", ortalamada "5.0"', () {
      // ⚠ İKİ AYRI SAYI, İKİ AYRI BİÇİM.
      //
      // Yorumun kendi puanı TAM SAYIDIR (1-5): "5 puan". Ondalıklı
      // yazılınca ("5.0") ortalama sanılıyor ve satır "bu yorumu
      // yapanın puanı 5.0" diye okunuyordu — oysa hizmet alanların
      // puanı diye bir kavram YOK, yalnız hizmet verenler puanlanır.
      //
      // Hizmet verenin ORTALAMASI ise ondalıklı kalır: 4 ve 5'ten
      // 4.5 çıkabilir.
      expect(teklifDetay.contains("'\${review.stars} puan'"), isTrue,
          reason: 'yorum puanı tam sayı olarak yazılmalı');
      expect(teklifDetay.contains('review.stars.toStringAsFixed(1)'), isFalse,
          reason: 'yorum puanı yine ondalıklı yazılmış');
      // Ortalama gösterimleri KORUNUR.
      expect(teklifDetay.contains('avg.toStringAsFixed(1)'), isTrue);
      expect(teklifDetay.contains('ortalama!.toStringAsFixed(1)'), isTrue);
    });

    test('⚠ PUAN ZORUNLU, YORUM TAMAMEN İSTEĞE BAĞLI', () {
      // ── ÜRÜN KARARI ──
      //
      // Bir süre "yorum yazıldıysa en az 5 kelime olsun" kuralı
      // vardı. Kısa ama geçerli yorumları ("işini iyi yaptı")
      // engelliyor ve kullanıcıyı yorum yazmaktan caydırıyordu.
      expect(degerlendirme.contains('kYorumMinKelime'), isFalse,
          reason: 'asgari kelime kuralı geri gelmiş');
      expect(degerlendirme.contains('yorumKisa'), isFalse);
      // Sabit ve mesaj kaynaktan da kalkmalı.
      expect(read('lib/domain/config.dart').contains('int kYorumMinKelime'),
          isFalse);
      expect(read('lib/domain/form_mesajlari.dart').contains('static final yorumKisa'),
          isFalse);

      // ⚠ PUAN ZORUNLU — iki katmanda birden.
      expect(degerlendirme.contains('if (_stars < 1)'), isTrue,
          reason: 'gönderimde puan denetimi yok');
      expect(degerlendirme.contains('onPressed: _stars < 1 ? null : _submit'),
          isTrue, reason: 'puansızken düğme pasif değil');

      // ⚠ ÜST SINIR DURUYOR — kaldırılan yalnız alt sınır.
      expect(DomainConfig.kYorumMaxKarakter, 1000);
      expect(degerlendirme.contains('DomainConfig.kYorumMaxKarakter'), isTrue);
      expect(degerlendirme.contains('maxLength: 500'), isFalse);
    });

    test('⚠ SÖZLEŞME DE AYNI KURALI SÖYLER', () {
      // İstemci ve sunucu ayrışırsa boş yorum istemcide geçer,
      // sunucuda reddedilirdi.
      final y = File('docs/openapi.yaml').readAsStringSync();
      expect(y.contains('EN AZ 5 KELİME'), isFalse,
          reason: 'sözleşmede eski kural kalmış');
      expect(y.contains('YORUM İSTEĞE BAĞLIDIR'), isTrue);
      // `ReviewCreate` yalnız `stars` zorunlu.
      expect(y.contains('      required: [stars]'), isTrue);
    });

    test('⚠ FORM ATLANMAZ — düğme yalnız YAPILMAMIŞSA çizilir', () {
      // ── YAŞANAN HATA ──
      //
      // İlan detayındaki "Hizmeti Değerlendir" düğmesi koşulu yalnız
      // `isTamamlanmisIs` idi. Değerlendirme ZATEN yapılmış olsa bile
      // düğme çiziliyor, kullanıcı basınca ekran gerçek kaydı bulup
      // doğrudan "gönderildi" görünümüne düşüyordu — dışarıdan
      // "form atlanıyor" gibi görünüyordu.
      expect(ilanDetay.contains('byOffer(l.selectedOfferId!) == null'), isTrue,
          reason: 'yapılmış değerlendirmede düğme yine çiziliyor');
      // Yapılmışsa düğme yerine durum yazısı.
      expect(ilanDetay.contains('Değerlendirmeniz alındı'), isTrue);
    });

    test('⚠ DÜĞME ADI VE İKONU İKİ EKRANDA AYNI', () {
      // Aynı iş iki ekranda farklı adla ("Hizmeti Değerlendir" /
      // "Yorum Yaz") görünüyordu; kullanıcıya iki ayrı işmiş gibi
      // geliyordu.
      expect(ilanDetay.contains("'Yorum Yaz'"), isTrue);
      expect(teklifDetay.contains("'Yorum Yaz'"), isTrue);
      expect(ilanDetay.contains('Hizmeti Değerlendir'), isFalse);
      // ⚠ İkon: `SysButton` ikon almıyordu ve metnin yanında sahipsiz
      // bir işaret kalıyordu. İki ekran da `RefPrimaryButton` +
      // yıldız ikonu kullanır.
      expect(ilanDetay.contains("iconAsset: 'assets/svg/ic_starw.svg'"), isTrue);
      expect(teklifDetay.contains("iconAsset: 'assets/svg/ic_starw.svg'"), isTrue);
      expect(File('assets/svg/ic_starw.svg').existsSync(), isTrue,
          reason: 'ikon dosyası yok — düğmede boşluk kalır');
    });

    test('⚠ PUAN ZORUNLU, YORUM İSTEĞE BAĞLI', () {
      // Puan olmadan gönderim yapılamaz.
      expect(degerlendirme.contains('if (_stars < 1)'), isTrue);
      // ⚠ Boş yorum gönderimi ENGELLEMEZ: kelime kuralı yalnız DOLU
      // yoruma uygulanır.
      expect(degerlendirme.contains('if (yorum.isNotEmpty)'), isTrue,
          reason: 'boş yorum gönderimi engelliyor');
    });

    test('⚠ API BAŞARILI DÖNMEDEN "yapıldı" GÖSTERİLMEZ', () {
      final i = degerlendirme.indexOf('_submit()');
      final blok = degerlendirme.substring(i, i + 2200);
      // Sıra: submit → hata denetimi → başarı.
      expect(blok.indexOf('.submit('), lessThan(blok.indexOf('if (err != null)')));
      expect(blok.contains('setState(() => _error = err.message);'), isTrue,
          reason: 'hata ekranda gösterilmiyor');
      // "Gönderildi" görünümü GERÇEK KAYDA bakar, yerel bayrağa değil.
      expect(degerlendirme.contains('byOffer(widget.offerId)'), isTrue);
    });

    test('⚠ DEĞERLENDİRME ANINDA YANSIR (kullanıcı kararı, 9 Eyl)', () {
      // ⚠ ÖNCEKİ KURAL EZİLDİ: §14 / kabul testi 15 bir GÜN gecikme
      // istiyordu. Kullanıcı, yorum ve puanın hizmet verenin
      // profiline ve tüm kartlarına ANINDA yansımasını istedi.
      //
      // ⚠ MEKANİZMA SİLİNMEDİ: süzgeç yerinde, yalnız süre sıfır.
      // Karar değişirse tek satır yeter.
      expect(DomainConfig.yorumYayinGecikmesi, Duration.zero);
      final r = read('lib/data/repositories/review_repository.dart');
      expect(r.contains('DomainConfig.yorumYayinGecikmesi'), isTrue);
      // ⚠ `isBefore` DEĞİL `!isAfter`: süre sıfırken sınır
      // "şimdi"dir; aynı milisaniyede yazılan yorum `isBefore` ile
      // elenir ve "anında yansısın" kuralı ilk saniyede bozulurdu.
      expect(r.contains('!r.createdAt.isAfter(sinir)'), isTrue,
          reason: 'sınır karşılaştırması anlık yorumu eliyor');
      // ⚠ `byOffer` SÜZÜLMEZ: yazan kişi kendi yorumunu hemen görmeli.
      final i = r.indexOf('Review? byOffer(');
      final j = r.indexOf('List<Review> byProvider(');
      expect(i, greaterThan(0));
      expect(r.substring(i, j).contains('yorumYayinGecikmesi'), isFalse);
    });

    test('⚠ TEKLİF GERİ ÇEKİLEMEZ (§1, kabul testi 2)', () {
      final j = read('lib/screens/job_detail_screen.dart');
      expect(j.contains("'Teklifi Geri Çek'"), isFalse,
          reason: 'geri çekme düğmesi geri gelmiş');
    });

    test('referans ölçüleri: 42px yıldız, 26px başlık, 16.5px bölüm', () {
      // ⚠ `bigStar()` referansta 42×42'dir; 40 idi.
      expect(degerlendirme.contains('boyut: 42'), isTrue,
          reason: 'seçim yıldızı 42px');
      expect(degerlendirme.contains('boyut: 20'), isTrue,
          reason: 'gönderilmiş görünümdeki yıldız 20px');
      expect(degerlendirme.contains('size: 26'), isTrue,
          reason: '.rv-title 26px');
      expect(degerlendirme.contains('size: 16.5'), isTrue,
          reason: '.rv-h3 16.5px');
      expect(degerlendirme.contains('size: 19'), isTrue,
          reason: '.rv-pname 19px');
    });

    test('referans metinleri birebir', () {
      for (final metin in [
        // ⚠ Başlık "Hizmeti Değerlendir" → "Yorum Yaz" (ürün kararı):
        // düğme ile ekran başlığı aynı adı taşımalı.
        'Yorum Yaz',
        'Aldığınız hizmet için puan ve yorumunuzu paylaşın.',
        'Puanınız',
        'Hizmet kalitesini puanlayın',
        '1 yıldız çok kötü, 5 yıldız mükemmel',
        'Yorumunuz',
        'Deneyiminizi paylaşabilirsiniz...',
        'Değerlendirmeyi Gönder',
        'Yorum eklenmedi.',
      ]) {
        expect(degerlendirme.contains(metin), isTrue, reason: metin);
      }
    });
  });
}
