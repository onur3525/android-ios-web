import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WEB KENAR ÇUBUĞU — DESTEK MERKEZİ PANELİ + ÇİZGİ İKONLAR
///
/// Destek paneli 15 Eki'den beri TEK KAYNAK (`destek_merkezi_paneli.dart`):
/// mobil profil ekranı ve web kenar çubuğu aynı paneli açar (kullanıcı
/// kararı: "Android'deki gibi görünmeli ve tepki vermeli").
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

    test('TEK KAYNAK: mobil ve web AYNI paneli açar; ikinci tanım yok', () {
      final p = oku('lib/screens/profile_screen.dart');
      expect(p.contains('onTap: () => _destekSheet(c)'), isTrue);
      expect(p.contains('destekMerkeziPaneliniAc(c)'), isTrue);
      expect(oku('lib/ui/web_destek_paneli.dart').contains('destekMerkeziPaneliniAc(c)'), isTrue);
      for (final yol in ['lib/screens/profile_screen.dart', 'lib/ui/web_destek_paneli.dart']) {
        final k = oku(yol);
        expect(k.contains('RefSheetBody('), isFalse, reason: '$yol: ikinci panel tanımı');
        expect(k.contains('DestekTalebiFormu'), isFalse, reason: yol);
      }
    });

    test('panel içeriği: başlık, açıklama, e-posta kutusu; talep formu yok', () {
      final d = oku('lib/ui/destek_merkezi_paneli.dart');
      for (final parca in const [
        "title: 'Destek Merkezi'",
        "ikon: 'assets/svg/ic_phead.svg'",
        'ikonZemin: const Color(0xFFF3E9FD)',
        "baslik: 'Size nasıl yardımcı olabiliriz?'",
        'aciklama: bilgi.description',
        "RefSvg('assets/svg/ic_mail.svg'",
        "LegalApi(c.read<ApiClient>()).one('support')",
        'SupportInfo.fallback',
        'onTap: () => epostaUygulamasiniAc(c, bilgi.email)',
      ]) {
        expect(d.contains(parca), isTrue, reason: parca);
      }
      expect(d.contains('DestekTalebiFormu'), isFalse);
    });

    test('e-posta: alıcısı dolu mailto, web\'de aynı sekmede (boş sekme yok)', () {
      final e = oku('lib/core/eposta_acma.dart');
      expect(e.contains("Uri(scheme: 'mailto', path: adres)"), isTrue);
      expect(e.contains("webOnlyWindowName: kIsWeb ? '_self' : null"), isTrue);
      expect(e.contains('mode: acilisModu()'), isTrue);
      expect(e.contains("'E-posta uygulaması bulunamadı: \$adres'"), isTrue);
      expect(e.contains("'E-posta uygulaması açılamadı: \$adres'"), isTrue);
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
