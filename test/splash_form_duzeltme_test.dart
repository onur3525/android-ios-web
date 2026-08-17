import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// SPLASH · ZORUNLU YILDIZ · HİZMET VEREN SEÇİM KUTULARI
///
/// Talimat: `HizmetCep_Claude_Talimat_Splash_Form_Duzeltmeleri`
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('A — Splash: lacivert ara ekran yok', () {
    const resDizin = 'android/app/src/main/res';
    test('karanlık tema açılış zemini LACİVERT DEĞİL', () {
      final night = read('android/app/src/main/res/values-night/colors.xml');
      expect(night.contains('#FF16233D'), isFalse,
          reason: 'lacivert launch_background kaldırılmalı');
      expect(night.contains('#FFFEFEFE'), isTrue,
          reason: 'Flutter splash zemini ile aynı olmalı');
    });

    test('açık tema açılış zemini Flutter splash ile aynı', () {
      final light = read('android/app/src/main/res/values/colors.xml');
      expect(light.contains('#FFFEFEFE'), isTrue);
    });

    test('Android 12+ sistem splash yapılandırılmış', () {
      final f = File('android/app/src/main/res/values-v31/styles.xml');
      expect(f.existsSync(), isTrue,
          reason: 'API 31+ sistem splash ayrı temaya ihtiyaç duyar');
      final s = f.readAsStringSync();
      expect(s.contains('windowSplashScreenBackground'), isTrue);
      expect(s.contains('windowSplashScreenAnimatedIcon'), isTrue);
      // Karanlık tema varyantı da aynı olmalı.
      final n =
          File('android/app/src/main/res/values-night-v31/styles.xml');
      expect(n.existsSync(), isTrue);
      expect(n.readAsStringSync().contains('windowSplashScreenBackground'),
          isTrue);
    });

    // ── NİHAİ MİMARİ: TEK KOMPOZİSYON ──
    //
    // ESKİ yapı: logo (`splash_logo.png`) yoğunluk kovasında + wordmark
    // ayrı asset + API seviyesine göre farklı layer-list'ler.
    // Bunlar SABİT dp konumlandırma kullandığı için ekran boyutlarına
    // ölçeklenmiyordu.
    //
    // YENİ yapı: logo + wordmark TEK kompozisyonda
    // (`drawable-nodpi/splash_brand.png`). Sistem görseli ikon
    // kutusuna ölçeklediği için tüm ekran boyutlarında aynı oranla
    // ortalanır. Bu yüzden eski assetler BİLİNÇLİ olarak kaldırıldı.
    test('marka görseli TEK kompozisyon ve TEK dosya', () {
      final f = File('$resDizin/drawable-nodpi/splash_brand.png');
      expect(f.existsSync(), isTrue,
          reason: 'tek kompozisyon asseti bulunmalı');

      // Aynı raster birden fazla yoğunluk kovasında OLMAMALI.
      final rasterlar = Directory('$resDizin')
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.split('/').last.startsWith('drawable'))
          .expand((d) => d.listSync().whereType<File>())
          .where((x) => x.path.endsWith('.png'))
          .toList();
      expect(rasterlar.length, 1,
          reason: 'splash rasteri tek kovada olmalı — bulunan: '
              '${rasterlar.map((x) => x.path).join(", ")}');

      // Yoğunluktan bağımsız kovada olmalı (dp ölçüsü sistemce belirlenir).
      expect(rasterlar.single.path.contains('drawable-nodpi'), isTrue);
    });

    test('eski sabit-dp splash assetleri geri GELMEMELİ', () {
      for (final p in const [
        'drawable-hdpi/splash_logo.png',
        'drawable/splash_logo.png',
        'drawable/splash_logo_layer.xml',
        'drawable/splash_logo_bitmap.xml',
        'drawable/splash_brand_full.xml',
        'drawable/splash_branding.xml',
        'drawable-hdpi/splash_wordmark.png',
      ]) {
        expect(File('$resDizin/$p').existsSync(), isFalse,
            reason: '$p sabit dp konumlandırma kullanıyordu');
      }
    });

    test('dört tema varyantı da TEK kompozisyonu gösterir', () {
      for (final d in const [
        'values',
        'values-night',
        'values-v31',
        'values-night-v31',
      ]) {
        final s = read('$resDizin/$d/styles.xml');
        expect(s.contains('@drawable/splash_brand'), isTrue, reason: d);
        // Wordmark kompozisyonun içinde — ayrı branding alanı gerekmez.
        expect(s.contains('windowSplashScreenBrandingImage'), isFalse,
            reason: d);
      }
    });
  });

  group('B — Zorunlu alan yıldızları #FF4D4F', () {
    test('tek renk tokeni tanımlı', () {
      final t = read('lib/ui/ref_tokens.dart');
      expect(t.contains('requiredStar = Color(0xFFFF4D4F)'), isTrue);
    });

    test('yıldız çizen TÜM yerler requiredStar kullanır', () {
      final dosyalar = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final yildiz = RegExp(
          r"""(?:Text\(\s*'\*'|text:\s*'\*')[\s\S]{0,180}?color:\s*([\w.]+)""");
      var toplam = 0;
      for (final f in dosyalar) {
        for (final m in yildiz.allMatches(f.readAsStringSync())) {
          toplam++;
          expect(m.group(1), 'RC.requiredStar',
              reason: '${f.path} yıldızı yanlış renkte');
        }
      }
      expect(toplam, greaterThan(0));
    });

    test('kayıt formu placeholder yıldızı gri MİRAS ALMAZ', () {
      final r = read('lib/screens/register_screen.dart');
      // Düz `hintText` kullanılırsa yıldız gri kalır.
      expect(r.contains('hintText: label'), isFalse);
      expect(r.contains('_hintYildizli'), isTrue);
    });
  });

  group('C — Hizmet Veren: chip yok, seçim kutusu var', () {
    final r = read('lib/screens/register_screen.dart');

    test('ana formda kategori/ilçe chip listesi YOK', () {
      expect(r.contains('FilterChip'), isFalse);
      expect(r.contains('_chipsSection'), isFalse);
    });

    test('tek seçim çubukları VAR', () {
      expect(r.contains("label: 'Hizmet Kategorileri'"), isTrue);
      expect(r.contains("label: 'Hizmet Verilen İl'"), isTrue);
      expect(r.contains("label: 'Hizmet Verilen İlçeler'"), isTrue);
      // ⚠ METİN TEK KAYNAĞA TAŞINDI (`FormMesaj.kategoriSec`).
      expect(r.contains('_altAciklama(FormMesaj.kategoriSec)'), isTrue);
      expect(r.contains('Bir veya birden fazla ilçe seçebilirsiniz.'), isTrue);
    });

    test('çoklu seçim sayfası açılır', () {
      expect(r.contains('RefMultiSelectSheet'), isTrue);
      expect(r.contains('_kategoriSec'), isTrue);
      expect(r.contains('_ilceSecCoklu'), isTrue);
    });

    test('sheet: arama + checkbox + TAMAM + Tüm İlçeler', () {
      final w = read('lib/ui/ref_widgets.dart');
      expect(w.contains('class RefMultiSelectSheet'), isTrue);
      expect(w.contains("hintText: 'Ara...'"), isTrue);
      expect(w.contains('RefCheckRow'), isTrue);
      expect(w.contains("'TAMAM'"), isTrue);
      // "Tüm İlçeler" satırı ilçe seçiminde geçirilir.
      expect(r.contains("tumuEtiketi: 'Tüm İlçeler'"), isTrue);
    });

    test('seçimler state\'te korunur (initial ile geri yüklenir)', () {
      // ⚠ KATEGORİ SEÇİMİ ARTIK ORTAK PANELDE.
      //
      // `RefMultiSelectSheet(initial: _cats)` yerine
      // `KategoriSecimPaneli(baslangic: _cats)` kullanılıyor —
      // Hizmet Kategorilerim ekranıyla aynı arama tabanlı panel.
      expect(r.contains('KategoriSecimPaneli(baslangic: _cats)'), isTrue);
      expect(r.contains('initial: _provDistricts'), isTrue);
      final w = read('lib/ui/ref_widgets.dart');
      expect(w.contains('_secili = {...widget.initial}'), isTrue);
    });

    test('zorunluluk kuralları korunur', () {
      // ⚠ METİNLER TEK KAYNAĞA TAŞINDI (`FormMesaj`). Kural aynı,
      // yazım artık ekranda gömülü değil.
      expect(r.contains('FormMesaj.kategoriSec'), isTrue);
      expect(r.contains('FormMesaj.bolgeSec'), isTrue);
    });
  });
}
