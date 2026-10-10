import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WEB KENAR ÇUBUĞU — DESTEK MERKEZİ PANELİ + ÇİZGİ İKONLAR
///
/// ⚠ ANDROID KİLİTLİ: `profile_screen.dart` bu turda DEĞİŞMEDİ. Destek
/// paneli web için ayrı dosyada (`lib/ui/web_destek_paneli.dart`)
/// tanımlı; iki tanımın ayrışmaması aşağıdaki PARİTE testleriyle
/// kilitli.
void main() {
  String oku(String p) => File(p).readAsStringSync();

  group('DESTEK MERKEZİ — Profil sayfasına gitmez, panel açar', () {
    test('kenar çubuğu eylemi paneli doğrudan açar', () {
      final r = oku('lib/ui/ref_widgets.dart');
      final i = r.indexOf('case ProfilEylemi.destek:');
      expect(i, greaterThan(0));
      final son = r.indexOf('\n    }', i);
      final govde = r.substring(i, son);
      expect(govde.contains('webDestekPaneliniAc('), isTrue);
      expect(govde.contains("pushNamed('/profile')"), isFalse,
          reason: 'alakasız Profil sayfasına yönlendirme geri gelmiş');
    });

    test('PARİTE: web paneli Android paneliyle BİREBİR aynı içerik', () {
      final android = oku('lib/screens/profile_screen.dart');
      final web = oku('lib/ui/web_destek_paneli.dart');
      const ortak = <String>[
        "title: 'Destek Merkezi'",
        "ikon: 'assets/svg/ic_phead.svg'",
        'ikonZemin: const Color(0xFFF3E9FD)',
        "baslik: 'Size nasıl yardımcı olabiliriz?'",
        'aciklama: bilgi.description',
        "RefSvg('assets/svg/ic_mail.svg'",
        'Color(0xFF7C3AED)',
        "LegalApi(c.read<ApiClient>()).one('support')",
        'SupportInfo.fallback',
        "Uri(scheme: 'mailto', path: adres)",
        "'E-posta uygulaması bulunamadı: \$adres'",
        "'E-posta uygulaması açılamadı: \$adres'",
      ];
      for (final parca in ortak) {
        expect(android.contains(parca), isTrue,
            reason: 'Android panelinde yok: $parca');
        expect(web.contains(parca), isTrue,
            reason: 'web paneli Android panelinden ayrışmış: $parca');
      }
    });

    test('Android profil ekranı kendi panelini açmaya devam eder', () {
      final p = oku('lib/screens/profile_screen.dart');
      expect(p.contains('onTap: () => _destekSheet(c)'), isTrue);
      expect(p.contains('webDestekPaneliniAc'), isFalse);
    });
  });

  group('KENAR ÇUBUĞU İKONLARI — tek renge boyanınca leke olmaz', () {
    test('menü dolgulu Android ikonlarını kullanmaz', () {
      final m = oku('lib/domain/profil_menusu.dart');
      expect(m.contains("ikon: 'assets/svg/ic_ppin.svg'"), isFalse);
      expect(m.contains("ikon: 'assets/svg/ic_pdoc.svg'"), isFalse);
      expect("ikon: 'assets/svg/ic_pin.svg'".allMatches(m).length, 2,
          reason: 'Adreslerim + Hizmet Bölgelerim');
      expect(m.contains("ikon: 'assets/svg/ic_doc_cizgi.svg'"), isTrue);
    });

    test('yeni belge ikonu çizgi biçiminde (dolgu yok)', () {
      final s = oku('assets/svg/ic_doc_cizgi.svg');
      expect(s.contains('fill="none"'), isTrue);
      expect(RegExp(r'fill="#').hasMatch(s), isFalse,
          reason: 'dolgulu şekil tek renge boyanınca yine leke olur');
      expect(s.contains('stroke="currentColor"'), isTrue);
    });

    test('Android profil ekranı dolgulu ikonlarını KORUR', () {
      final p = oku('lib/screens/profile_screen.dart');
      expect(p.contains("'assets/svg/ic_ppin.svg'"), isTrue);
      expect(p.contains("'assets/svg/ic_pdoc.svg'"), isTrue);
    });
  });
}
