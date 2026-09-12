// SEKME SAYI ROZETİ — SEKMENİN SOL ÜST KÖŞESİ (KİLİT)
//
// ⚠ KULLANICI İSTEĞİ (12 Eyl): "Teklif istekleri butonunda yer alan
// sayı ok üzerinde duruyor; butonun sol köşesinde kırmızı daire
// içinde olsun."
//
// ── ⚠ İKİ TURLUK GEÇMİŞ ──
//
// 9 Eyl'de rozet `right: -7, top: -5` ile 20 px ikonun sağ üst
// köşesinin İÇİNE biniyordu; dışarı alındı (`right: -10, top: -8`).
// Ama konum hâlâ İKONA göreliydi: rozet ikona teğet duruyor ve uçuş
// ikonuyla görsel olarak karışmayı sürdürüyordu.
//
// 12 Eyl'de rozet ikondan tamamen koparıldı: artık SEKMENİN kendi
// sol üst köşesinde, sabit bir noktada. Hangi ikon kullanılırsa
// kullanılsın rozet aynı yerde durur.
//
// ⚠ KAYNAK OKUMAK YETMEZ: "kodda left: 6 yazıyor" demek rozetin
// ekranda nereye düştüğünü kanıtlamaz. Bu test rozeti, ikonu ve
// sekme kutusunu gerçekten pump edip ÖLÇER.
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

  testWidgets('⚠ ROZET SEKMENİN SOL ÜST KÖŞESİNDE', (t) async {
    await ciz(t, const [0, 0, 1]);
    await t.pump();

    expect(find.text('1'), findsOneWidget);

    final rozet = t.getRect(find.text('1'));
    final cubuk = t.getRect(find.byType(RefSegmentTabs));
    // Üçüncü sekmenin ikonu.
    final ikonlar = find.byType(RefSvg);
    expect(ikonlar, findsNWidgets(3));
    final ikon = t.getRect(ikonlar.at(2));

    // ── ⚠ SÖZLEŞME — ÜÇ ÖLÇÜ ──
    //
    //   1. Rozet İKONUN SOLUNDA. Eski hâlde sağ üst çeyrekteydi ve
    //      ikona teğetti; şikâyet buydu.
    expect(rozet.right, lessThan(ikon.left),
        reason: 'rozet hâlâ ikonun üstünde/sağında');

    //   2. Rozet SEKMENİN ÜST YARISINDA: köşe demek, orta demek
    //      değil.
    expect(rozet.center.dy, lessThan(cubuk.center.dy),
        reason: 'rozet sekmenin alt yarısına kaymış');

    //   3. İkonla HİÇ KESİŞMEZ. Merkez testi yetmez: rozetin kenarı
    //      ikona değiyorsa da örtüşme başlar.
    expect(rozet.overlaps(ikon), isFalse,
        reason: 'rozet ile ikon kesişiyor');
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
    // ⚠ ARTIK SOL KENAR RİSKLİ: rozet sola taşındığı için kırpılma
    // tehlikesi sağda değil SOLDA.
    expect(rozet.left, greaterThanOrEqualTo(cubuk.left),
        reason: 'rozet soldan kırpılıyor');
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
