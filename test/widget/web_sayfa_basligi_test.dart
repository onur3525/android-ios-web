import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WEB — SAĞ ALANDAKİ BÜTÜN SAYFALARDA STANDART BAŞLIK
///
/// Kullanıcı kararı: hizmet alanın kenar çubuğundan açılan her sayfada
/// başlık OLMALI ve hepsi AYNI ölçüde olmalı. Tek kaynak `RefPageTitle`
/// (25 / w700 / ortalı); `RefDetailHeader` aynı ölçüyü kullanır.
///
/// ⚠ MOBİL KİLİTLİ: aşağıdaki başlıklar yalnız `kIsWeb` dalında
/// eklenir; Android/iOS ağaçları değişmez.
void main() {
  String oku(String p) => File(p).readAsStringSync();

  // Ekran → web dalında beklenen standart başlık satırı.
  const webBasliklari = <String, String>{
    'lib/screens/find_provider_screen.dart':
        "const RefPageTitle('Hizmet Veren Bul')",
    'lib/screens/my_listings_screen.dart':
        "RefPageTitle(saglayici ? 'İşlerim' : 'İlanlarım',",
    'lib/screens/notifications_screen.dart':
        "const RefPageTitle('Bildirimler', geriDugmesi: false)",
    'lib/screens/profile_screen.dart':
        "const RefPageTitle('Profil', geriDugmesi: false)",
    'lib/screens/account_settings_screen.dart':
        "const RefPageTitle('Hesap Ayarları')",
    'lib/screens/legal_screen.dart':
        'RefPageTitle(d?.title ?? widget.title)',
  };

  test('web dalında her sayfa başlığı RefPageTitle ile çizer', () {
    webBasliklari.forEach((yol, satir) {
      final k = oku(yol);
      final i = k.indexOf(satir);
      expect(i, greaterThan(0), reason: '$yol: web başlığı yok');
      // Başlık bir `kIsWeb` koşulunun hemen ardında olmalı.
      final once = k.substring(i - 400 < 0 ? 0 : i - 400, i);
      expect(once.contains('kIsWeb'), isTrue,
          reason: '$yol: başlık web koşuluna bağlı değil (mobil etkilenir)');
    });
  });

  test('zaten standart olanlar yerinde', () {
    for (final e in {
      'lib/screens/profile_info_screen.dart': "RefPageTitle('Profil Bilgilerim')",
      'lib/screens/addresses_screen.dart': "RefPageTitle('Adreslerim')",
      'lib/screens/app_rate_screen.dart': "RefPageTitle('Uygulamayı Puanla')",
      'lib/screens/change_password_screen.dart': "RefPageTitle('Şifre Değiştir')",
      'lib/screens/role_switch_screen.dart': "RefDetailHeader(title: 'Rol Değiştir')",
    }.entries) {
      expect(oku(e.key).contains(e.value), isTrue, reason: e.key);
    }
  });

  test('tek ölçü: RefPageTitle ve RefDetailHeader 25 / w700', () {
    final w = oku('lib/ui/ref_widgets.dart');
    for (final sinif in ['class RefPageTitle', 'class RefDetailHeader']) {
      final i = w.indexOf(sinif);
      expect(i, greaterThan(0));
      final govde = w.substring(i, w.indexOf('\n}\n', i));
      expect(govde.contains('size: RF.s25'), isTrue, reason: sinif);
      expect(govde.contains('weight: RF.w700'), isTrue, reason: sinif);
    }
  });

  test('web: hukuki metinde AppBar çizilmez, Bul vitrini çizilmez', () {
    final l = oku('lib/screens/legal_screen.dart');
    expect(l.contains('appBar: kIsWeb\n          ? null'), isTrue);
    final b = oku('lib/screens/find_provider_screen.dart');
    final i = b.indexOf("const RefPageTitle('Hizmet Veren Bul')");
    final e = b.indexOf('else ...[', i);
    final vitrin = b.indexOf("'assets/art/bul_character.png'", i);
    expect(e, greaterThan(i));
    expect(vitrin, greaterThan(e),
        reason: 'vitrin görseli yalnız mobil (else) dalında kalmalı');
  });

  test('Bildirimler: "Tümünü Okundu Yap" TEK tanım', () {
    final k = oku('lib/screens/notifications_screen.dart');
    expect("'Tümünü Okundu Yap'".allMatches(k).length, 1);
    expect(k.contains('final Widget? tumunuOkundu'), isTrue);
  });

  test('Bildirimler: boş durum web\'de kalan alanın ortasında, mobil aynen',
      () {
    final k = oku('lib/screens/notifications_screen.dart');
    expect("'Henüz bildiriminiz yok.'".allMatches(k).length, 1,
        reason: 'boş metin TEK tanım');
    expect(k.contains('else if (liste.isEmpty && kIsWeb)\n'
            '            KalanAlandaOrtala(child: bosMetin)'),
        isTrue);
    expect(k.contains('padding: const EdgeInsets.symmetric(vertical: 40),\n'
            '              child: bosMetin,'),
        isTrue,
        reason: 'mobil düzen değişmiş');
  });

  test('Sonuçlar: bilgilendirme web\'de kalan alanın ortasında, mobil aynen',
      () {
    final k = oku('lib/screens/sonuclar_screen.dart');
    expect("'hizmet veren bulunmuyor. İlan vererek '".allMatches(k).length, 1,
        reason: 'açıklama TEK tanım');
    expect(k.contains('if (_sonuclar.isEmpty && kIsWeb)\n'
            '                    KalanAlandaOrtala(altBosluk: 20, child: bosAciklama)'),
        isTrue);
    expect(k.contains('padding: const EdgeInsets.symmetric(vertical: 32),\n'
            '                      child: bosAciklama,'),
        isTrue,
        reason: 'mobil düzen değişmiş');
  });

  test('ortalama TEK kaynakta: ekranlar kendi kopyasını yazmaz', () {
    for (final yol in [
      'lib/screens/notifications_screen.dart',
      'lib/screens/sonuclar_screen.dart',
      'lib/screens/my_listings_screen.dart',
      'lib/screens/my_reviews_screen.dart',
    ]) {
      final k = oku(yol);
      expect(k.contains("import '../ui/kalan_alanda_ortala.dart';"), isTrue,
          reason: yol);
      expect(k.contains('class _KalanAlandaOrtala'), isFalse, reason: yol);
    }
  });

  test('İlanlarım ve Müşteri Yorumları: boş durum web\'de ortada, mobil aynen',
      () {
    final l = oku('lib/screens/my_listings_screen.dart');
    expect(l.contains('return KalanAlandaOrtala(altBosluk: 24, child: metin);'),
        isTrue);
    expect(l.contains('padding: const EdgeInsets.symmetric(vertical: 40),\n'
            '      child: metin,'),
        isTrue);
    final r = oku('lib/screens/my_reviews_screen.dart');
    expect(
        r.contains(
            'const KalanAlandaOrtala(altBosluk: 24, child: _bosDegerlendirme)'),
        isTrue);
    expect(r.contains('padding: EdgeInsets.only(top: 26),\n'
            '                child: _bosDegerlendirme,'),
        isTrue);
  });

  test('zaten ortalı olanlar ortalı kalır (İşlerim/Kazandığım, teklif listeleri)',
      () {
    final j = oku('lib/screens/jobs_screen.dart');
    expect(j.contains('child: Center(child: child),'), isTrue,
        reason: '_pullable boş durumu tam yükseklikte ortalar');
    for (final yol in [
      'lib/screens/teklif_istediklerim_screen.dart',
      'lib/screens/teklif_istekleri_screen.dart',
    ]) {
      expect(oku(yol).contains('Center(\n'), isTrue, reason: yol);
    }
  });
}
