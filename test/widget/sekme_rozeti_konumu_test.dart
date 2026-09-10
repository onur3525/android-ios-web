// SEKME SAYI ROZETİ — İKONU ÖRTMEZ (KİLİT)
//
// ⚠ KULLANICI İSTEĞİ (9 Eyl): "Teklif istekleri butonu üzerinde
// bulunan sayı, ikonun TAM ÜSTÜNDE kalmasın, daha kaliteli olsun."
//
// ÖNCEDEN rozet `right: -7, top: -5` ile 20 px ikonun sağ üst
// köşesinin İÇİNE biniyordu; "Yeni işler" ikonu (kâğıt uçak) görsel
// ağırlığını zaten sağ üstte taşıdığı için sayı ikonu örtüyordu.
//
// ⚠ KAYNAK OKUMAK YETMEZ: "kodda -10 yazıyor" demek rozetin ekranda
// nereye düştüğünü kanıtlamaz. Bu test rozeti ve ikonu gerçekten
// pump edip KUTULARINI ölçer.
//
// ⚠ ROZET ORTAK BİLEŞENDE (`RefSegmentTabs`): düzeltme, bu sekme
// çubuğunu kullanan tüm ekranları birden kapsar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/ref_tokens.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';

void main() {
  const ogeler = <({String asset, String label})>[
    (asset: 'assets/svg/ic_send.svg', label: 'Yeni işler'),
    (asset: 'assets/svg/ic_checkc.svg', label: 'Teklif verdiklerim'),
    (asset: 'assets/svg/ic_send.svg', label: 'Teklif istekleri'),
  ];

  Future<void> ciz(WidgetTester t, List<int> sayilar, {int secili = 0}) =>
      t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: RefSegmentTabs(
              items: ogeler,
              selected: secili,
              onChanged: (_) {},
              badges: sayilar,
            ),
          ),
        ),
      ));

  testWidgets('rozet ikonun DIŞINA taşar — gövdesini örtmez', (t) async {
    await ciz(t, const [0, 0, 1]);
    await t.pump();

    expect(find.text('1'), findsOneWidget);

    final rozet = t.getRect(find.text('1'));
    // Rozetin ait olduğu sekmenin ikonu: üçüncü sekmedeki `RefSvg`.
    final ikonlar = find.byType(RefSvg);
    expect(ikonlar, findsNWidgets(3));
    final ikon = t.getRect(ikonlar.at(2));

    // ⚠ ASIL SÖZLEŞME — ÜÇ ÖLÇÜ:
    //
    //   1. Rozetin MERKEZİ ikon kutusunun DIŞINDA olmalı. İçinde
    //      olsaydı sayı ikonun üstünde otururdu — şikâyet buydu.
    expect(ikon.contains(rozet.center), isFalse,
        reason: 'rozetin merkezi ikonun içinde — sayı ikonu örtüyor');

    //   2. Rozet SAĞ ÜST çeyrekte kalmalı: sol kenarı ikonun yatay
    //      ortasından solda olamaz.
    expect(rozet.left, greaterThanOrEqualTo(ikon.center.dx),
        reason: 'rozet ikonun ortasına doğru kaymış');

    //   3. Alt kenarı ikonun dikey ortasından aşağı inemez.
    expect(rozet.bottom, lessThanOrEqualTo(ikon.center.dy),
        reason: 'rozet ikonun gövdesine iniyor');
  });

  testWidgets('rozet KIRPILMAZ — sekme çubuğunun içinde kalır', (t) async {
    // ⚠ Dışarı almanın riski budur: fazla taşarsa kök `ClipRRect`
    // rozeti keser. Ölçülerek kilitlenir.
    await ciz(t, const [0, 0, 9]);
    await t.pump();

    final cubuk = t.getRect(find.byType(RefSegmentTabs));
    final rozet = t.getRect(find.text('9'));
    expect(rozet.top, greaterThanOrEqualTo(cubuk.top),
        reason: 'rozet üstten kırpılıyor');
    expect(rozet.right, lessThanOrEqualTo(cubuk.right),
        reason: 'rozet sağdan kırpılıyor');
  });

  testWidgets('⚠ SAYI YOKKEN ROZET ÇİZİLMEZ', (t) async {
    await ciz(t, const [0, 0, 0]);
    await t.pump();
    expect(find.text('0'), findsNothing,
        reason: 'sıfır için boş rozet çiziliyor');
  });

  testWidgets('99 üstü kısaltılır', (t) async {
    await ciz(t, const [0, 0, 150]);
    await t.pump();
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('⚠ ALT BAR ROZETİ AYNI BİLEŞENDİR', (t) async {
    // KULLANICI BULGUSU (9 Eyl): "Bul" ikonundaki "!" rozeti
    // hatalıydı; gelen teklifi gösteren SAYI rozeti olmalı. İki
    // rozet ayrı ayrı çizildiği sürece ölçü ve konum ayrışıyordu
    // (alt barda 15 px + "!", sekmede 17 px + sayı).
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: RefSayiRozeti(sayi: 3, halkaRengi: RC.white),
        ),
      ),
    ));
    await t.pump();
    expect(find.text('3'), findsOneWidget);
    // "!" bir UYARI anlatır; gelen teklif iyi bir haberdir.
    expect(find.text('!'), findsNothing);
  });

  testWidgets('halka rengi seçili sekmede zemine uyar', (t) async {
    // Seçili sekmede zemin mavi, seçilmemişte beyaz; halka zemine
    // uymazsa rozet yamalı görünür.
    await ciz(t, const [0, 0, 1], secili: 2);
    await t.pump();
    final kutu = t.widget<Container>(find
        .ancestor(of: find.text('1'), matching: find.byType(Container))
        .first);
    final d = kutu.decoration! as BoxDecoration;
    expect(d.color, RC.danger);
    expect(d.border!.top.color, RC.blue);
    expect(d.border!.top.width, 2);
  });
}
