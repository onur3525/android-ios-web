// ÇATILAR SUNUCUDAN (22 Eki, kullanıcı kararı)
//
// Çatının adı, açıklaması, fotoğrafı ve kategorileri admin panelinden
// gelir (`GET /categories` → `roofs`); gelmezse gömülü liste aynen kalır.
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/hizmet_alanlari.dart';

void main() {
  tearDown(sunucuAlanlariniSifirla);

  test('sunucu verisi yoksa gömülü liste aynen kullanılır', () {
    sunucuAlanlariniAyarla(null, apiKoku: 'https://api.ornek');
    expect(identical(kHizmetAlanlari, kGomuluHizmetAlanlari), isTrue);
    sunucuAlanlariniAyarla(const <Object>[], apiKoku: 'https://api.ornek');
    expect(identical(kHizmetAlanlari, kGomuluHizmetAlanlari), isTrue);
  });

  test('anahtar paket görselinin adıdır', () {
    expect(kGomuluHizmetAlanlari.first.anahtar, 'ev');
    expect(kGomuluHizmetAlanlari.map((a) => a.anahtar).toSet().length,
        kGomuluHizmetAlanlari.length);
  });

  test('ad, açıklama, kategoriler ve fotoğraf sunucudan; sıra ve görsel korunur', () {
    sunucuAlanlariniAyarla([
      {
        'key': 'insaat',
        'name': 'Yapı ve Dekorasyon',
        'description': 'Tadilat, Boya',
        'photoUrl':
            '/api/v1/categories/photo/katalog/kategori/12345678-1234-1234-1234-123456789abc.jpg',
        'categories': ['Boya ve Badana'],
      },
      {'key': 'bilinmeyen', 'name': 'Yok sayılır'},
    ], apiKoku: 'https://api.ornek');
    expect(kHizmetAlanlari.length, kGomuluHizmetAlanlari.length);
    final i = kHizmetAlanlari.firstWhere((a) => a.anahtar == 'insaat');
    expect(i.ad, 'Yapı ve Dekorasyon');
    expect(i.aciklama, 'Tadilat, Boya');
    expect(i.kategoriler, ['Boya ve Badana']);
    expect(i.gorsel, 'assets/alanlar/insaat.jpg');
    expect(i.fotoUrl,
        'https://api.ornek/api/v1/categories/photo/katalog/kategori/12345678-1234-1234-1234-123456789abc.jpg');
    expect(kKategoriAlani['Boya ve Badana'], 'Yapı ve Dekorasyon');
    // Sunucuda kaydı olmayan çatı gömülü hâliyle kalır.
    expect(kHizmetAlanlari.first.ad, 'Ev & Yaşam');
    expect(kHizmetAlanlari.first.fotoUrl, isNull);
  });

  test('başka adrese ya da kalıp dışı yola fotoğraf olarak izin verilmez', () {
    sunucuAlanlariniAyarla([
      {'key': 'ev', 'photoUrl': 'https://kotu.ornek/x.jpg'},
      {'key': 'arac', 'photoUrl': '/api/v1/categories/photo/../gizli.jpg'},
    ], apiKoku: 'https://api.ornek');
    expect(kHizmetAlanlari.firstWhere((a) => a.anahtar == 'ev').fotoUrl, isNull);
    expect(kHizmetAlanlari.firstWhere((a) => a.anahtar == 'arac').fotoUrl, isNull);
  });

  test('hizmet istisnası yeniden adlandırılan çatıyı anahtarla bulur', () {
    sunucuAlanlariniAyarla([
      {'key': 'arac', 'name': 'Araç & Oto'},
    ], apiKoku: 'https://api.ornek');
    expect(hizmetAlani('Koltuk ve Döşeme Yıkama', 'Araç Döşeme Yıkama'),
        'Araç & Oto');
  });

  test('gömülü kapsam denetimi sunucu verisinden etkilenmez', () {
    sunucuAlanlariniAyarla([
      {'key': 'ev', 'categories': <String>[]},
    ], apiKoku: 'https://api.ornek');
    expect(alanKapsamiTam(), isTrue);
  });
}
