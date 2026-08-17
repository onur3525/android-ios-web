import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../support/kaynak_okuma.dart';

/// HTML ↔ FLUTTER KABUL KONTROLLERİ
///
/// Referans: `hizmetcep-v66-final__1_.html`
/// Talimat §7 "TEST VE KABUL" maddelerinin kaynak düzeyi karşılığı.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('HOME — kabul kontrolleri', () {
    final src = read('lib/screens/home_screen.dart');

    test('12 ÇATI paneli — eski hızlı kategoriler YOK', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ (15 Ağu): ana sayfadaki 12 sabit kategori
      // kısayolu yerini 12 ÇATIYA bıraktı. Çatı listesi
      // `hizmet_alanlari.dart` içinde; ana sayfa onu okur.
      expect(src.contains('kisa:'), isFalse,
          reason: 'eski hızlı kategori listesi geri gelmiş');
      expect(src.contains('kHizmetAlanlari'), isTrue);
      expect(src.contains('HizmetAlanlariPaneli'), isTrue);
    });

    test('ana sayfa ÇATI KARTI kullanır', () {
      // ⚠ `KategoriKarti` (kategori fotoğrafı) ana sayfada YOK; çatı
      // kartı ayrı bir bileşen ve kendi görselini çizer.
      expect(src.contains('KategoriKarti('), isFalse);
      expect(src.contains('class _AlanKarti'), isTrue);
      expect(src.contains('fit: BoxFit.cover'), isTrue);
    });

    test('profil / arama / rol kartı hedefleri doğru', () {
      expect(src.contains("pushNamed(context, '/login')"), isTrue);
      expect(src.contains('startRegister(context, Role.customer)'), isTrue);
      expect(src.contains('startRegister(context, Role.provider)'), isTrue);
    });

    // ⚠ ESKİ BEKLENTİ DEĞİŞTİ.
    //
    // Ana sayfadaki arama ve kategori ikonları AYRI BİR ARAMA
    // SAYFASI AÇMAZ. Arama kutusu yerinde açılır (`InlineSearchBox`),
    // kategori ikonu ise öneri seçimiyle AYNI yönlendiriciye girer.
    test('ana sayfa AYRI arama sayfası AÇMAZ', () {
      expect(src.contains('SearchScreen'), isFalse,
          reason: 'kategori ikonu ayrı arama sayfası açmamalı');
      expect(src.contains('InlineSearchBox('), isTrue);
      // ⚠ Çatı kartı ilan formu AÇMAZ; çatı ekranına gider.
      expect(src.contains('HizmetAlaniScreen(alan: alan)'), isTrue);
    });
  });

  group('HİZMET ALAN KAYIT — kabul kontrolleri', () {
    final src = read('lib/screens/register_screen.dart');

    test('başlık ROL ADIYLA yazılır', () {
      // ⚠ ÜRÜN KARARI: uygulamada tek bir rol sözlüğü kullanılır —
      // "Hizmet Alan" ve "Hizmet Veren". "Müşteri" ve "Hizmet
      // Sağlayıcı" ikinci bir kavram çifti yaratıyordu; kullanıcı
      // aynı şeyin iki adını öğrenmek zorunda kalıyordu.
      //
      // Test SİLİNMEDİ, yeni sözlüğe çevrildi ve ESKİ terimlerin
      // geri sızmadığı da denetlenir.
      expect(src.contains("'Hizmet Alan Kaydı'"), isTrue);
      expect(src.contains("'Hizmet Veren Kaydı'"), isTrue);
      expect(src.contains('Müşteri Kaydı'), isFalse,
          reason: 'eski rol adı geri gelmemeli');
      expect(src.contains('Hizmet Sağlayıcı Kaydı'), isFalse,
          reason: 'eski rol adı geri gelmemeli');

      // `.rg-sub` — kaynak kodda satır bölünmüş olabilir; boşluk
      // normalizasyonuyla aranır.
      final duz = src.replaceAll(RegExp(r"'\s*\n\s*'"), '');
      expect(
        duz.contains('Hizmet almak için hesabınızı oluşturun ve hemen '
            'başlayın.'),
        isTrue,
        reason: 'müşteri açıklaması yok',
      );
      expect(
        duz.contains('Hizmet vermek için hesabınızı oluşturun ve hemen '
            'başlayın.'),
        isTrue,
        reason: 'sağlayıcı açıklaması yok',
      );
    });

    test('başlık ORTALANMIŞ', () {
      // ⚠ Rol adı değişti: 'Hizmet Sağlayıcı Kaydı' → 'Hizmet Veren
      // Kaydı'. Test bu yüzden düşüyordu; kural DEĞİŞMEDİ, arama
      // terimi güncellendi.
      //
      // Test GÜÇLENDİRİLDİ: iki rolün başlığı da ayrı ayrı denetlenir,
      // biri ortalı diğeri değil kalamaz.
      for (final baslik in ["'Hizmet Veren Kaydı'", "'Hizmet Alan Kaydı'"]) {
        final i = src.indexOf(baslik);
        expect(i, greaterThan(0), reason: '$baslik bulunamadı');
        expect(src.pencere(i, 220).contains('TextAlign.center'), isTrue,
            reason: '.rg-title{text-align:center} — $baslik');
      }
    });

    test('CTA "Devam Et" — "Kod Gönder" DEĞİL', () {
      expect(src.contains("'Devam Et'"), isTrue);
      expect(src.contains('Kod Gönder'), isFalse,
          reason: 'adım 1 CTA metni HTML ile uyuşmuyor');
    });

    test('+90 ülke kodu kutusu YOK — numara yerel biçimde alınır', () {
      // ⚠ ÜRÜN KARARI: `+90` kutusu KALDIRILDI.
      //
      // Tek ülkede hizmet verildiği için seçim yoktu; dokunulunca
      // yalnız "şimdilik +90" mesajı veren işlevsiz bir açılır
      // kutuydu. Numara artık `0` ile başlayan YEREL biçimde alınır.
      //
      // Test SİLİNMEDİ, yeni kurala çevrildi: kutunun bulunmadığı ve
      // yerine ortak telefon biçimlendiricisinin geçtiği doğrulanır.
      expect(src.contains('RefCountryCodeDrop'), isFalse,
          reason: '+90 kutusu kaldırıldı');
      expect(src.contains('prefixText'), isFalse,
          reason: '+90 prefix olarak da eklenmez');
      expect(src.contains('TelefonBicimlendirici()'), isTrue,
          reason: 'numara ortak biçimlendiriciyle yerel biçimde alınır');
    });

    test('il/ilçe/mahalle aynı kutu ailesi ve seçimli', () {
      expect(src.contains('RefRegDropdown'), isTrue);
      expect(src.contains('RegionPickerSheet'), isTrue);
      // Alt çizgili Material dropdown YOK.
      expect(src.contains('DropdownButtonFormField'), isFalse);
    });

    test('gerçek onay kutusu + mavi yasal bağlantılar', () {
      expect(src.contains('RefAgreeRow'), isTrue);
      expect(src.contains("'slug': 'terms'"), isTrue);
      expect(src.contains("'slug': 'privacy'"), isTrue);
    });

    test('veya ayırıcı + Google ile Devam Et', () {
      expect(src.contains('RefOrDivider'), isTrue);
      expect(src.contains('Google ile Devam Et'), isTrue);
      // Yalnız görsel buton DEĞİL: gerçek akış bağlı.
      expect(src.contains('GoogleAuthService().signInIdToken()'), isTrue);
      expect(src.contains('googleLogin('), isTrue);
    });

    test('sözleşme kabul zorunluluğu korunur', () {
      expect(src.contains('if (!_agree)'), isTrue);
    });
  });

  group('LOGIN — kabul kontrolleri', () {
    final src = read('lib/screens/login_screen.dart');
    final w = read('lib/ui/ref_widgets.dart');

    test('kullanıcı ikonu RefSvg ile ve MAVİ', () {
      expect(src.contains("RefScreenIcon"), isTrue);
      expect(src.contains('ic_profile.svg'), isTrue);
      // .lg-ico{color:#1D6BE3} — varsayılan mavi.
      expect(w.contains('this.iconColor = RC.blue'), isTrue);
    });

    test('Google butonu ve şifremi unuttum var', () {
      expect(src.contains('Google ile Devam Et'), isTrue);
      expect(src.contains('Şifremi Unuttum'), isTrue);
    });

    test('Material AppBar / Icons kullanılmaz', () {
      expect(src.contains('AppBar('), isFalse);
      expect(src.contains('Icons.'), isFalse);
    });
  });
}
