// ALT NAVİGASYON — EŞİT ARALIK KİLİDİ (GERÇEK ÖLÇÜ TESTİ)
//
// ⚠ KAYNAK OKUMAK YETMEZ. "Hepsi `Expanded`, öyleyse aralıklar
// eşittir" çıkarımı YANLIŞTI: satırda dört eşit `Expanded` yuvanın
// arasına SABİT genişlikte (62 dp) bir boşluk konmuştu. Çentik bir
// yuvadan dar olduğu için çentiğe komşu öğelerin merkez mesafesi
// (yuva + çentik) / 2'ye düşüyor, kenardaki komşularda tam yuva
// kalıyordu.
//
// ⚠ KULLANICI ÖLÇÜMÜ (1080 px genişlikli cihaz, 480 dp): etiket
// merkezleri 123,5 · 354,5 · 540 · 725,5 · 955 px → aralıklar
// 231 · 185,5 · 185,5 · 229,5 px. Sol-sağ simetri BOZUK DEĞİLDİ;
// bozuk olan, ortadaki ikilinin butona doğru sıkışmasıydı.
//
// Bu test iddiayı KAYNAKTAN değil RENDERBOX'TAN doğrular: beş
// etiketin merkezi ölçülür ve dört aralığın da eşit olması istenir.
//
// ⚠ NEDEN İKİ GENİŞLİK: yuva payı ekran genişliğine bağlıdır. Eşitlik
// tek bir genişlikte tesadüfen sağlanmış olabilir; dar (360) ve geniş
// (480) ekranda ayrı ayrı ölçülür.
//
// ⚠ MERKEZ ÖLÇÜLÜR, KENAR DEĞİL: etiket genişlikleri çok farklıdır
// ("Bul" ile "Bildirimler"). Kenar boşluklarının eşitliği etiketler
// değişmeden mümkün değildir; sözleşme MERKEZ aralığıdır.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';

typedef NavOge = ({
  String key,
  String label,
  String asset,
  VoidCallback onTap,
  bool rozet,
  bool belirginRozet
});

NavOge _oge(String key, String label, String asset) => (
      key: key,
      label: label,
      asset: asset,
      onTap: () {},
      rozet: false,
      belirginRozet: false,
    );

/// Hizmet ALAN sekmeleri — `nav_actions.dart` ile AYNI sıra ve
/// AYNI asset yolları (sahte ad uydurulmadı).
final _musteri = <NavOge>[
  _oge('bul', 'Bul', 'assets/svg/ic_search.svg'),
  _oge('ilanlarim', 'İlanlarım', 'assets/svg/ic_clip.svg'),
  _oge('ilanver', 'İlan Ver', 'assets/svg/ic_addbox.svg'),
  _oge('bildirim', 'Bildirimler', 'assets/svg/ic_bell.svg'),
  _oge('profil', 'Profil', 'assets/svg/ic_profile.svg'),
];

/// Hizmet VEREN sekmeleri — `ilanver` YOKTUR, düz bar dalı çizilir.
final _saglayici = <NavOge>[
  _oge('ilanlarim', 'İşlerim', 'assets/svg/ic_clip.svg'),
  _oge('kazandigim', 'Kazandığım', 'assets/svg/ic_checkc.svg'),
  _oge('bildirim', 'Bildirimler', 'assets/svg/ic_bell.svg'),
  _oge('profil', 'Profil', 'assets/svg/ic_profile.svg'),
];

void main() {
  /// Barı verilen GENİŞLİKTE kurar.
  ///
  /// ⚠ Güvenli alan SIFIRLANIR: `safeBottom` yalnız dikey ölçüye
  /// girer, yatay yerleşimi etkilemez; yine de ölçümün cihaz
  /// çentiğinden bağımsız olması için sabitlenir.
  Widget bar(double genislik, List<NavOge> ogeler, String aktif) =>
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.zero),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: genislik,
              child: RefBottomNav(items: ogeler, activeKey: aktif),
            ),
          ),
        ),
      );

  /// Etiket metninin yatay merkezi.
  double _merkez(WidgetTester t, String etiket) {
    final f = find.text(etiket);
    if (f.evaluate().length != 1) {
      throw StateError('"$etiket" etiketi tek örnek bulunamadı');
    }
    return t.getCenter(f).dx;
  }

  for (final genislik in <double>[360, 392, 480]) {
    testWidgets('hizmet alan alt barı — beş merkez EŞİT aralıklı '
        '(${genislik.toInt()} dp)', (t) async {
      await t.pumpWidget(bar(genislik, _musteri, 'ilanlarim'));
      await t.pump();

      final m = <double>[
        _merkez(t, 'Bul'),
        _merkez(t, 'İlanlarım'),
        _merkez(t, 'İlan Ver'),
        _merkez(t, 'Bildirimler'),
        _merkez(t, 'Profil'),
      ];
      final aralik = <double>[
        for (var i = 0; i < m.length - 1; i++) m[i + 1] - m[i],
      ];

      // ⚠ Sıra korunmalı: merkezler soldan sağa ARTAN olmalı.
      for (final a in aralik) {
        expect(a, greaterThan(0),
            reason: 'sekme sırası bozulmuş: aralıklar $aralik');
      }

      // ⚠ ASIL SÖZLEŞME: dört aralığın dördü de birbirine eşit.
      // Tolerans yalnız kayan nokta yuvarlaması içindir (0,5 dp);
      // eski koddaki fark 480 dp'de ~20 dp idi, bu toleransa SIĞMAZ.
      for (final a in aralik) {
        expect((a - aralik.first).abs(), lessThan(0.5),
            reason: 'merkez aralıkları eşit değil: $aralik');
      }
    });

    testWidgets('"İlan Ver" butonu barın TAM ortasında '
        '(${genislik.toInt()} dp)', (t) async {
      await t.pumpWidget(bar(genislik, _musteri, 'ilanlarim'));
      await t.pump();

      // Barın kendisi ekranda ortalanmış olabilir; buton merkezi
      // BARIN merkeziyle karşılaştırılır, ekranınkiyle değil.
      final barMerkez = t.getCenter(find.byType(RefBottomNav)).dx;
      expect((_merkez(t, 'İlan Ver') - barMerkez).abs(), lessThan(0.5),
          reason: 'buton bar merkezinden kaymış');
    });

    testWidgets('hizmet veren düz barı — dört merkez EŞİT aralıklı '
        '(${genislik.toInt()} dp)', (t) async {
      // ⚠ REGRESYON KİLİDİ: düzeltme YALNIZ çentikli dalı ilgilendirir.
      // Sağlayıcı tarafı zaten eşitti ve DEĞİŞMEMELİ.
      await t.pumpWidget(bar(genislik, _saglayici, 'ilanlarim'));
      await t.pump();

      final m = <double>[
        _merkez(t, 'İşlerim'),
        _merkez(t, 'Kazandığım'),
        _merkez(t, 'Bildirimler'),
        _merkez(t, 'Profil'),
      ];
      final aralik = <double>[
        for (var i = 0; i < m.length - 1; i++) m[i + 1] - m[i],
      ];
      for (final a in aralik) {
        expect((a - aralik.first).abs(), lessThan(0.5),
            reason: 'düz bar aralıkları eşit değil: $aralik');
      }
    });
  }

  testWidgets('orta yuva çentikten DAR kalmamalı (en dar ekran)',
      (t) async {
    // ⚠ NEDEN: orta boşluk artık eşit paylı; yuva payı çentik
    // genişliğinin (62) altına düşerse buton ve çentik komşu
    // etiketlerin üstüne biner. 360 dp en dar hedef ekrandır.
    await t.pumpWidget(bar(360, _musteri, 'ilanlarim'));
    await t.pump();

    final solKomsu = _merkez(t, 'İlanlarım');
    final sagKomsu = _merkez(t, 'Bildirimler');
    expect(sagKomsu - solKomsu, greaterThan(62 * 2),
        reason: 'çentiğe komşu iki merkez arası çentiği taşıyamıyor');
  });
}
