// ANA SAYFA ÇATI PANELİ — GERÇEK ÖLÇÜ TESTİ
//
// ⚠ KAYNAK OKUMAK YETMEZ. "Değişken adında 3 yazıyor" panelin
// gerçekten üç satır gösterdiğini KANITLAMAZ. Bu dosya ekranı
// çizer ve kartların `RenderBox` ölçülerini okur.
//
// Ölçülenler: aynı anda görünen kart sayısı, sütun ve satır sayısı,
// kart genişlik/yükseklik eşitliği, fotoğraf alanı eşitliği ve
// 10-11-12. çatılara panel içinden ulaşılabilirliği.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/hizmet_alanlari.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/screens/home_screen.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';
import 'package:provider/provider.dart';

void main() {
  late AuthController auth;

  setUp(() {
    auth = AuthController(MockAuthPort(AuthRepository(seedTestAccount: false)));
  });

  /// ── ⚠ TELEFON BOYUTLU GÖRÜNTÜ ALANI ──
  ///
  /// Varsayılan test yüzeyi 800×600. Ana sayfa panele gelmeden önce
  /// başlık, arama kutusu ve rol kartlarını çiziyor; panel 600'ün
  /// ALTINDA kalıyor ve `drag` çağrısı ekran dışına düşüyordu:
  ///   "Offset(400.0, 1209.2) is outside the bounds of the root of
  ///    the render tree, Size(800.0, 600.0)"
  ///
  /// Yüzey gerçek bir telefona yakın kurulur ki panel görünür olsun.
  void _telefonYuzeyi(WidgetTester t) {
    t.view.physicalSize = const Size(400, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Widget app() => ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: const MaterialApp(home: HomeScreen()),
      );

  /// Panelin görünen penceresi (kırpma kutusu).
  /// ⚠ `Scrollbar` KALDIRILDI (görünür çubuk istenmiyor); pencere
  /// artık panelin kendi `ListView`'ü.
  Rect _pencere(WidgetTester t) {
    final f = find.byType(ListView).last;
    expect(f, findsOneWidget, reason: 'panel listesi yok');
    final rb = t.renderObject<RenderBox>(f);
    final sol = rb.localToGlobal(Offset.zero);
    return Rect.fromLTWH(sol.dx, sol.dy, rb.size.width, rb.size.height);
  }

  /// Pencerenin İÇİNDE tamamen görünen çatı kartları.
  List<({String ad, Rect kutu})> _gorunen(WidgetTester t) {
    final pen = _pencere(t);
    final out = <({String ad, Rect kutu})>[];
    for (final a in kHizmetAlanlari) {
      // ⚠ ANAHTARLA ölçülür: kart içinde başka `ClipRRect`'ler de
      // olabilir ve atadan bulmak yanlış kutuyu yakalar (rol
      // kartlarında tam bu hata yaşandı).
      final kartF = find.byKey(ValueKey('cati-karti-${a.ad}'));
      if (kartF.evaluate().isEmpty) {
        continue;
      }
      final rb = t.renderObject<RenderBox>(kartF);
      final sol = rb.localToGlobal(Offset.zero);
      final kutu =
          Rect.fromLTWH(sol.dx, sol.dy, rb.size.width, rb.size.height);
      // ⚠ TAMAMEN görünüyor mu — yarısı kırpılmış kart sayılmaz.
      if (kutu.top >= pen.top - 0.5 && kutu.bottom <= pen.bottom + 0.5) {
        out.add((ad: a.ad, kutu: kutu));
      }
    }
    return out;
  }

  testWidgets('12 KARTIN TAMAMI AYNI ANDA GÖRÜNÜR — 3 sütun', (t) async {
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();

    // ⚠ PANEL KAYMIYOR: 12 kartın hepsi çizili olmalı.
    final g = _gorunen(t);
    expect(g.length, 12, reason: 'görünen kart: ${g.length}');

    // ⚠ Sütun/satır sayısı KOORDİNATTAN çıkarılır, koddan değil.
    final sutunlar = g.map((e) => e.kutu.left.roundToDouble()).toSet();
    final satirlar = g.map((e) => e.kutu.top.roundToDouble()).toSet();
    expect(sutunlar.length, 3, reason: 'sütun x konumları: $sutunlar');
    expect(satirlar.length, 4, reason: 'satır y konumları: $satirlar');
  });

  testWidgets('12 KARTIN ÖLÇÜLERİ EŞİT', (t) async {
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();

    final olculer = <String, Size>{};
    for (final e in _gorunen(t)) {
      olculer[e.ad] = e.kutu.size;
    }

    expect(olculer.length, 12,
        reason: 'ölçülemeyen çatı: '
            '${kHizmetAlanlari.map((a) => a.ad).where((a) => !olculer.containsKey(a))}');

    final ilk = olculer.values.first;
    for (final e in olculer.entries) {
      expect(e.value.width, closeTo(ilk.width, 0.5), reason: '${e.key} genişlik');
      expect(e.value.height, closeTo(ilk.height, 0.5),
          reason: '${e.key} yükseklik');
    }
  });

  testWidgets('10-11-12. ÇATILAR da BAŞTAN GÖRÜNÜR', (t) async {
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();

    final sonUc = kHizmetAlanlari.skip(9).map((a) => a.ad).toList();
    expect(sonUc.length, 3);

    // ⚠ Kaydırma kalktı: son üç çatı da ilk çizimde görünür.


    final gorunen = _gorunen(t).map((e) => e.ad).toSet();
    for (final ad in sonUc) {
      expect(gorunen.contains(ad), isTrue, reason: '$ad çizilmemiş');
    }
  });

  testWidgets('PANEL KENDİ İÇİNDE KAYMAZ', (t) async {
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();

    final baslik = find.text('Hizmet Kategorileri');
    // ⚠ MUTLAK KONUM DEĞİL, ARADAKİ MESAFE ölçülür.
    //
    // Panel içi kaydırma kapalı olduğu için sürükleme dıştaki SAYFAYA
    // geçer ve sayfa kayar — bu beklenen davranıştır. Kaymaması
    // gereken şey panelin İÇİ: başlık ile ilk kart arasındaki mesafe
    // sabit kalmalı.
    final onceFark = _gorunen(t).first.kutu.top - t.getTopLeft(baslik).dy;

    await t.drag(find.byType(ListView).last, const Offset(0, -300));
    await t.pumpAndSettle();

    final sonraFark = _gorunen(t).first.kutu.top - t.getTopLeft(baslik).dy;
    expect(sonraFark, closeTo(onceFark, 0.5),
        reason: 'panel içi kaydı — kaydırma kapalı olmalı');
  });

  testWidgets('FOTOĞRAF ALANLARI EŞİT ve ESNETİLMEMİŞ', (t) async {
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();

    final oranlar = <double>{};
    final boyutlar = <Size>[];
    for (final e in _gorunen(t)) {
      final f = find.descendant(
          of: find.byKey(ValueKey('cati-karti-${e.ad}')),
          matching: find.byType(AspectRatio));
      final w = t.widget<AspectRatio>(f.first);
      oranlar.add(w.aspectRatio);
      boyutlar.add(t.renderObject<RenderBox>(f.first).size);
    }
    expect(oranlar.length, 1, reason: 'farklı en-boy oranları: $oranlar');
    for (final b in boyutlar) {
      expect(b.width, closeTo(boyutlar.first.width, 0.5));
      expect(b.height, closeTo(boyutlar.first.height, 0.5));
    }
  });

  testWidgets('BÜYÜK YAZI ÖLÇEĞİNDE de 12 kart tam görünür', (t) async {
    // ⚠ Panel yüksekliği puntodan hesaplanıyor; ölçek büyüyünce
    // pencere de büyümeli, üçüncü satır kırpılmamalı.
    _telefonYuzeyi(t);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: app(),
      ),
    );
    await t.pumpAndSettle();

    final g = _gorunen(t);
    expect(g.length, 12, reason: 'ölçek 1.3\'te görünen: ${g.length}');
    expect(g.map((e) => e.kutu.top.roundToDouble()).toSet().length, 4);
  });


  testWidgets('KARTTA İKON YOK — hiyerarşi fotoğraf → başlık → açıklama',
      (t) async {
    // ⚠ KESİN KARAR (15 Ağu): çatı kartında renkli ikon çizilmez.
    // Alev, 1-9 sayacı ve yön okları zaten yoktu; ikon da kalktı.
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();

    for (final e in _gorunen(t)) {
      final kart = find.byKey(ValueKey('cati-karti-${e.ad}'));
      // Kartın içinde HİÇ SVG olmamalı.
      expect(find.descendant(of: kart, matching: find.byType(RefSvg)),
          findsNothing,
          reason: '${e.ad} kartında ikon çizilmiş');
      // Fotoğraf ve iki metin yerinde.
      expect(find.descendant(of: kart, matching: find.byType(AspectRatio)),
          findsOneWidget);
      expect(find.descendant(of: kart, matching: find.byType(Text)),
          findsNWidgets(2),
          reason: '${e.ad}: başlık + açıklama dışında metin var');
    }
  });

  testWidgets('İKONSUZ KART ile HESAPLANAN yükseklik örtüşüyor', (t) async {
    // ⚠ İkon varken başlık satırı bir `Row` içindeydi ve 18 birimlik
    // ikon satırı yükseltiyordu; hesap ise punto × çarpan sayıyordu.
    // Kart gerçekte hesaptan uzundu. İkon kalkınca ikisi eşitlendi —
    // bu test o eşitliği koruyor.
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();

    final g = _gorunen(t);
    expect(g, isNotEmpty);
    final olculen = g.first.kutu;
    final beklenen = HizmetAlanlariPaneli.kartYuksekligi(
        olculen.width, TextScaler.noScaling);
    expect(olculen.height, closeTo(beklenen, 1.0),
        reason: 'ölçülen ${olculen.height}, hesaplanan $beklenen');
  });


  testWidgets('GÖRÜNÜR KAYDIRMA ÇUBUĞU YOK', (t) async {
    // ⚠ ÜRÜN KARARI: panel parmakla kayar, gri çubuk çizilmez.
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(find.byType(Scrollbar), findsNothing,
        reason: 'kaydırma çubuğu geri gelmiş');
  });

  testWidgets('UZUN ÇATI ADI ÜÇ NOKTA ile KESİLMİYOR', (t) async {
    // ⚠ "Kişisel Hizmet" tek satıra sığmıyordu ve "Kişisel Hizm…"
    // görünüyordu. Ad KISALTILMADI; kart başlığa iki satır ayırıyor.
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();

    for (final ad in const [
      'Kişisel Hizmet',
      'İnşaat & Dekorasyon',
      'Mühendislik & Danışmanlık',
    ]) {
      final f = find.text(ad);
      if (f.evaluate().isEmpty) {
        continue; // panelde henüz görünmüyorsa atla
      }
      final w = t.widget<Text>(f);
      expect(w.maxLines, 2, reason: '$ad tek satıra sıkışmış');
      // Metnin kendisi TAM; kısaltılmış bir sürüm çizilmiyor.
      expect(w.data, ad);
    }
  });

  testWidgets('BAŞLIK ve AÇIKLAMA alanları TÜM KARTLARDA eşit', (t) async {
    _telefonYuzeyi(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();

    final baslik = <double>{};
    final aciklama = <double>{};
    for (final e in _gorunen(t)) {
      final kart = find.byKey(ValueKey('cati-karti-${e.ad}'));
      final kutular = find.descendant(of: kart, matching: find.byType(Text));
      expect(kutular, findsNWidgets(2));
      final b = t.renderObject<RenderBox>(
          find.ancestor(of: kutular.first, matching: find.byType(SizedBox))
              .first);
      final a = t.renderObject<RenderBox>(
          find.ancestor(of: kutular.last, matching: find.byType(SizedBox))
              .first);
      baslik.add(b.size.height);
      aciklama.add(a.size.height);
    }
    expect(baslik.length, 1, reason: 'farklı başlık alanları: $baslik');
    expect(aciklama.length, 1, reason: 'farklı açıklama alanları: $aciklama');
  });
}
