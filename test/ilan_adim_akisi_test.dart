import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/kaynak_okuma.dart';
import 'package:hizmetcep/data/izmir.dart';

/// TUR 1 — INLINE ARAMA ÇERÇEVESİ + İLAN ADIM YAPISI
void main() {
  String read(String p) => File(p).readAsStringSync();

  /// ⚠ YORUMSUZ metin — YOKLUK denetimleri için.
  /// Ham metinde arama yapılınca açıklamalarda geçen ad kod sanılır.
  String kodu(String p) => File(p)
      .readAsStringSync()
      .split('\n')
      .where((l) =>
          !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
  final box = read('lib/screens/widgets/inline_search_box.dart');
  final cre = read('lib/screens/create_listing_screen.dart');
  final ref = read('lib/ui/ref_widgets.dart');

  group('1 — Arama kutusu: ikinci çerçeve YOK', () {
    test('TextField hiçbir durumda kendi outline\'ını çizmez', () {
      final i = box.indexOf('decoration: InputDecoration(');
      expect(i, greaterThan(0));
      final dec = box.pencere(i, 700);
      for (final alan in const [
        'border: InputBorder.none',
        'enabledBorder: InputBorder.none',
        'focusedBorder: InputBorder.none',
        'disabledBorder: InputBorder.none',
        'errorBorder: InputBorder.none',
        'focusedErrorBorder: InputBorder.none',
      ]) {
        expect(dec.contains(alan), isTrue, reason: '$alan eksik');
      }
    });

    test('global tema dolgusu devre dışı', () {
      final i = box.indexOf('decoration: InputDecoration(');
      expect(box.pencere(i, 700).contains('filled: false'), isTrue,
          reason: 'tema fillColor ikinci kutu izi bırakır');
    });

    test('iç kutu üreten ikinci Container/Decoration YOK', () {
      // Görünen tek kutu dıştaki Container'dır (height: 53).
      expect('BoxDecoration('.allMatches(box).length, 2,
          reason: 'yalnız arama kutusu ve öneri paneli');
      expect(box.contains('OutlineInputBorder'), isFalse);
    });

    test('dış kutu görünümü korundu', () {
      final i = box.indexOf('height: 53');
      expect(i, greaterThan(0));
      final kutu = box.pencere(i, 600);
      expect(kutu.contains('RR.r13'), isTrue);
      expect(kutu.contains('RS.card'), isTrue);
      expect(kutu.contains('ic_search.svg'), isTrue);
    });
  });

  group('2 — Inline arama davranışı KORUNDU', () {
    test('aynı sayfada kalır (sayfa açan çağrı yok)', () {
      expect(box.contains('Navigator.push'), isFalse);
      expect(box.contains('onSecim'), isTrue);
    });

    test('öneri paneli aşağı açılır', () {
      // ⚠ PANEL ARTIK OVERLAY'DE. Kutunun altındaki `Column` çocuğu
      // olmaktan çıktı (sayfayı aşağı itiyordu), bu yüzden kaynakta
      // kutudan SONRA gelmiyor — ayrı bir metotta (`_panelYap`).
      // Kutuya `LayerLink` ile bağlı; görsel olarak yine altında.
      expect(box.contains('ListView.separated'), isTrue);
      expect(box.contains('CompositedTransformFollower'), isTrue);
      expect(box.contains('targetAnchor: Alignment.bottomLeft'), isTrue);
    });

    test('öneri kaynağı sabit liste DEĞİL', () {
      expect(box.contains('SearchService.services'), isTrue);
    });

    test('seçimde category + subService taşınır', () {
      expect(box.contains('widget.onSecim(h.category, h.subService)'), isTrue);
    });
  });

  group('3 — İlan akışı: 3 adım + kategori ızgarası', () {
    test('gösterge 3 adımlıdır', () {
      expect(cre.contains("'Kategori Seç',"), isTrue);
      expect(cre.contains("'Açıklama',"), isTrue);
      expect(cre.contains("'Önizle & Yayınla'"), isTrue);
      expect(cre.contains("'Adım \$_step/3'"), isFalse,
          reason: 'kaldırılan adım metni geri gelmiş');
      expect(cre.contains('RefStepper('), isTrue,
          reason: 'adım göstergesi de kaldırılmış — bilgi tamamen kayboldu');
    });

    test('başlık GERÇEKTEN ortalı', () {
      // ⚠ Adım metni kaldırılınca sağ taraf boşaldı. Denge boşluğu
      // konmasaydı `Expanded` içindeki başlık, soldaki geri düğmesi
      // kadar (38 dp) SAĞA KAYMIŞ görünürdü.
      expect(cre.contains('textAlign: TextAlign.center'), isTrue);
      expect(cre.contains('const SizedBox(width: 38)'), isTrue,
          reason: 'denge boşluğu yok — başlık ortalı değil');
    });

    // ⚠ Hizmet ana sayfadan seçildiyse kategori adımı GÖSTERİLMEZ:
    // kullanıcı aynı seçimi iki kez yapmaz.
    test('ön seçimde kategori adımı ATLANIR', () {
      expect(cre.contains('bool get _kategoriOnSecili'), isTrue);
      expect(cre.contains('_aramaCtl.text = widget.initialSubService'), isTrue);
      expect(cre.contains('_step = 2;'), isTrue);
      // Geri tuşu kategori adımına dönmez.
      //
      // ⚠ İFADE TAŞINDI, KURAL AYNI. Satır içi koşul kaldırılıp
      // `_ilkAdim` getter'ına alındı; cihazın geri tuşu da (PopScope)
      // aynı getter'ı kullanıyor, iki geri yolu ayrışmıyor.
      expect(
          cre.contains(
              'bool get _ilkAdim => _step <= (_kategoriOnSecili ? 2 : 1);'),
          isTrue);
    });

    // ⚠ Adım 2 yalnız Açıklama + Fotoğraf içerir.
    test('adım 2\'de konum alanları GÖSTERİLMEZ', () {
      expect(cre.contains("RefFieldLabel('İlçe'"), isFalse);
      expect(cre.contains("RefFieldLabel('Mahalle'"), isFalse);
      // Oturumlu kullanıcıda konum profil adresinden gelir.
      expect(cre.contains('ProfileController>().address'), isTrue);
      // Yayın anında konum yine ZORUNLUDUR — kontrol kayıt
      // akışına taşınmıştır (eksikse ilan yayınlanmaz).
      final reg = read('lib/screens/register_screen.dart');
      expect(reg.contains('_kayitKonumu'), isTrue);
      expect(
          reg.contains('İlçe ve mahalle bilgisi eksik — ilan yayınlanamadı'),
          isTrue);
    });

    test('KATEGORİ IZGARASI KALDIRILDI — seçim ARAMA ile', () {
      // ⚠ ÜRÜN KARARI (15 Ağu): ilan verme ekranında hizmet kartla
      // seçilmez. Katalog 517 hizmete çıktı; fotoğraflı ızgara yalnız
      // kategorileri gösterebiliyordu ve kullanıcı "kolon hattı" gibi
      // bir işi bulamayıp kategoriyi TAHMİN etmek zorunda kalıyordu.
      expect(cre.contains('KategoriKarti('), isFalse,
          reason: 'kart ızgarası geri gelmiş');
      expect(cre.contains('GridView.count'), isFalse);
      expect(cre.contains('kKartKategorileri'), isFalse);
      // Arama yolu DURUYOR.
      expect(cre.contains('SearchService.services('), isTrue);
      expect(cre.contains('_OneriPaneli'), isTrue);
    });

    test('arama önerisi ORTAK SERVİSTEN gelir, kırılım GÖSTERMEZ', () {
      expect(cre.contains('_OneriPaneli'), isTrue);
      expect(cre.contains('SearchService.services('), isTrue);
      expect(cre.contains('kategori} > '), isFalse,
          reason: 'kırılım geri gelmiş');
      expect(cre.contains('turkceNormalize'), isFalse,
          reason: 'yerel süzgeç geri gelmiş');
      // Sınır ortak servise verilir.
      expect(cre.contains('enFazla: 12'), isTrue);
    });

    test('arama yazılınca ızgara gizlenir', () {
      expect(cre.contains("if (_catQuery.trim().isEmpty && _cat == null)"),
          isTrue);
      expect(cre.contains("if (_catQuery.trim().isNotEmpty && _cat == null)"),
          isTrue);
    });

    test('IZGARA YOK — seçim aramadan besleniyor', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ (15 Ağu): katalog 517 hizmete çıktı ve
      // fotoğraflı ızgara yalnız kategorileri gösterebiliyordu.
      // Kullanıcı "kolon hattı" gibi bir işi ızgarada bulamıyordu.
      expect(cre.contains('for (final c in kKartKategorileri)'), isFalse);
      expect(cre.contains('GridView.count'), isFalse);
      expect(cre.contains('SearchService.services('), isTrue);
      // Katalog sayısı yine kilitli.
      expect(kHomeCategories.length, 63);
    });

    // ⚠ Gösterge SÜTUN DÜZENİNE geçti: nokta ve etiket aynı sütunda
    // hizalanır, bağlayıcı çizgi adım sayısına göre çizilir.
    // Eski `i < 3` sabiti 4 adımda son bağlantıyı çizmiyordu.
    test('RefStepper dinamik etiket destekler', () {
      expect(ref.contains('this.labels'), isTrue);
      expect(ref.contains('final etiketler = labels ?? _etiket;'), isTrue);
      // Adım sayısı etiketlerden gelir.
      expect(ref.contains('final n = etiketler.length;'), isTrue);
      // Nokta ve etiket eşit genişlikte sütunlarda.
      expect(ref.contains('Expanded(child: Center(child: nokta(i)))'), isTrue);
      expect(ref.contains('textAlign: TextAlign.center,'), isTrue);
      expect(ref.contains('if (i < 3) {'), isFalse);
    });
  });

  group('4 — Yayın sözleşmesi bozulmadı', () {
    test('fotoğraf ZORUNLU değil', () {
      // Ekran fotoğrafı OPSİYONEL olarak etiketler.
      expect(cre.contains('Fotoğraf (Opsiyonel)'), isTrue);
      // Fotoğrafsız yayını engelleyen bir doğrulama OLMAMALI.
      expect(cre.contains('fotoğraf zorunlu'), isFalse);
      expect(cre.contains('En az 1 fotoğraf'), isFalse);
      // Maksimum 5 kuralı seçici bileşende yaşar.
      final pp = read('lib/screens/widgets/photo_picker.dart');
      expect(pp.contains('kMaxListingPhotos = 5'), isTrue);
    });

    test('oturumsuzda taslak saklanır, publish YOK', () {
      final i = cre.indexOf('if (widget.preLogin)');
      expect(i, greaterThan(0));
      final govde = cre.pencere(i, 260);
      expect(govde.contains('_taslakKaydetVeKayitaGec'), isTrue);
      expect(govde.contains('ListingController'), isFalse);
    });

    test('kayıt akışına rol seçim ekranı OLMADAN gidilir', () {
      expect(cre.contains('RoleSelectScreen.startRegister'), isTrue);
      expect(cre.contains('const RoleSelectScreen()'), isFalse);
    });

    // ⚠ AKIŞ İKİYE AYRILDI.
    //
    // Oturumlu : ... → 3 Önizle & Yayınla → 4 Yayınlandı
    // Oturumsuz: ... → 3 Kayıt → 4 SMS Doğrulama → 5 Yayınlandı
    //
    // Her iki dalda da başarı adımına YALNIZ yayın başarılıysa geçilir.
    test('başarı adımı yalnız yayın sonrası', () {
      // ── Oturumlu dal: `_publish` sonunda `_step = 4`.
      expect(cre.contains('_published = true;'), isTrue);
      final iPub = cre.indexOf('_published = true;');
      expect(cre.pencere(iPub, 260).contains('_step = 4'), isTrue,
          reason: 'başarı adımı yayın tamamlandıktan sonra gelmeli');

      // ── Oturumsuz dal: `_kaydolVeYayinla` → yalnız `ok` ise 5.
      expect(cre.contains('_kaydolVeYayinla'), isTrue);
      final iKay = cre.indexOf('Future<void> _kaydolVeYayinla()');
      expect(iKay, greaterThan(0));
      // ⚠ PENCERE GENİŞLETİLDİ (1800 → 3200).
      //
      // `_kaydolVeYayinla` içine sunucu hatasını doğru yere yazan
      // blok eklendi; aranan satır 1800 karakterlik pencerenin
      // DIŞINDA kaldığı için test kırılıyordu. İDDİA AYNI, yalnız
      // bakılan alan büyütüldü.
      final govde = cre.pencere(iKay, 3200);
      // Yayın sonucu DEĞERLENDİRİLİR.
      expect(govde.contains('final ok = await _ilaniYayinla('), isTrue);
      expect(govde.contains('if (ok) {'), isTrue);
      expect(govde.contains('_step = 5;'), isTrue);
      // Hata durumunda başarı ekranı GÖSTERİLMEZ.
      expect(govde.contains('if (!ok) {'), isTrue);
      // Kayıt hatası da ilerlemeyi durdurur.
      expect(govde.contains('r.error != null'), isTrue);
    });
  });


  group('CİHAZIN GERİ TUŞU ADIMLAR ARASINDA GERİ GİDER', () {
    final c = kodu('lib/screens/create_listing_screen.dart');

    test('PopScope var ve yalnız İLK adımda rota kapanır', () {
      // Eskiden Android geri tuşu rotayı kapatıyordu: kullanıcı 3.
      // adımdayken tuşa basınca form tamamen kapanıyor, girdiği
      // kategori/açıklama kayboluyordu.
      expect(c.contains('return PopScope('), isTrue);
      expect(c.contains('canPop: _ilkAdim,'), isTrue);
      expect(c.contains('onPopInvokedWithResult: (didPop, _) {'), isTrue);
    });

    test('pop engellendiğinde BİR ADIM geri alınır', () {
      final i = c.indexOf('onPopInvokedWithResult: (didPop, _) {');
      final govde = c.substring(i, i + 220);
      expect(govde.contains('if (!didPop) {'), isTrue);
      expect(govde.contains('_geriAdim();'), isTrue);
    });

    test('ekrandaki ok ile cihaz tuşu AYNI yolu kullanır', () {
      // İki geri yolu ayrışmamalı.
      expect(c.contains('RefBackButton(onTap: _geriAdim)'), isTrue);
      expect(c.contains('void _geriAdim() {'), isTrue);
      // Eski satır içi mantık geri gelmemeli.
      expect(c.contains('? setState(() => _step--)'), isFalse,
          reason: 'geri mantığı yine iki yere kopyalanmış');
    });

    test('ilk adım tanımı kategori ön seçimini hesaba katar', () {
      expect(
          c.contains('bool get _ilkAdim => _step <= (_kategoriOnSecili ? 2 : 1);'),
          isTrue);
    });
  });

  group('YAYIN SONRASI EKRAN', () {
    final c = kodu('lib/screens/create_listing_screen.dart');

    test('"Ana Sayfaya Dön" bağlantısı KALDIRILDI', () {
      expect(c.contains('Ana Sayfaya Dön'), isFalse);
      expect(c.contains('onAnasayfa'), isFalse,
          reason: 'kullanılmayan geri çağrı kalmış');
    });

    test('asıl eylem KORUNDU', () {
      expect(c.contains("RefWideButton('Aktif İlanlarımı Gör'"), isTrue);
      expect(c.contains("'/customer/listings'"), isTrue);
    });
  });
}
