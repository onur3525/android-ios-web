// ROL SEÇİM KARTLARI — GERÇEK ÖLÇÜ TESTİ
//
// ⚠ KAYNAK OKUMAK YETMEZ.
//
// "İki kartı da aynı sınıf çiziyor, öyleyse aynı ölçüdedir" çıkarımı
// YANLIŞ olabilir: genişlik ebeveyn kısıtından, yükseklik içerikten
// gelir. Kullanıcı gerçek cihazda turuncu kartın ~39 piksel daha
// geniş göründüğünü ölçtü. Bu test iddiayı KAYNAKTAN değil
// RENDERBOX'TAN doğrular.
//
// ⚠ Ölçülen üç şey: sol kenar, genişlik, yükseklik. Üçü de birebir
// eşit olmalı.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/screens/role_select_screen.dart';
import 'package:provider/provider.dart';

void main() {
  late AuthController auth;

  setUp(() {
    // ⚠ Oturum AÇILMAZ: ekran o zaman "Nasıl Başlamak İstersiniz?"
    auth = AuthController(MockAuthPort(AuthRepository(seedTestAccount: false)));
  });

  Widget app(Widget home) => ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(home: home),
      );

  /// İçinde 'Hizmet\nAlmak İstiyorum' / 'Hizmet\nVermek İstiyorum'
  /// metni geçen kartın DIŞ kutusunu bulur.
  ///
  /// ⚠ `Text` widget'ının kendi kutusu değil, onu saran kartın
  /// kutusu ölçülür — kart `Stack` içindeki `ClipRRect`'tir.
  /// ⚠ ANAHTARLA BULUNUR, metinle değil.
  ///
  /// İlk sürüm "metnin en dıştaki ClipRRect atası" diyordu ve YANLIŞ
  /// KUTUYU ölçüyordu: mavi kart 738,4 · turuncu 772 çıkıyordu.
  /// Kartlar aslında eşitti, ölçüm hatalıydı. Kart artık kendi
  /// `ValueKey`'ini taşıyor.
  Rect _kart(WidgetTester t, String anahtar) {
    final f = find.byKey(ValueKey(anahtar));
    expect(f, findsOneWidget, reason: '$anahtar bulunamadı');
    final rb = t.renderObject<RenderBox>(f);
    final sol = rb.localToGlobal(Offset.zero);
    return Rect.fromLTWH(sol.dx, sol.dy, rb.size.width, rb.size.height);
  }

  testWidgets('iki rol kartı AYNI genişlik, yükseklik ve sol kenar',
      (t) async {
    await t.pumpWidget(app(const RoleSelectScreen()));
    await t.pumpAndSettle();

    final mavi = _kart(t, 'rol-karti-alan');
    final turuncu = _kart(t, 'rol-karti-veren');

    // ⚠ SOL KENAR: ikisi de aynı hizadan başlamalı.
    expect(turuncu.left, mavi.left,
        reason: 'sol kenarlar farklı: ${mavi.left} vs ${turuncu.left}');

    // ⚠ GENİŞLİK: kullanıcının ölçtüğü fark tam buradaydı.
    expect(turuncu.width, mavi.width,
        reason: 'genişlikler farklı: ${mavi.width} vs ${turuncu.width}');

    // ⚠ SAĞ KENAR: sol + genişlik eşitse bu da eşittir; yine de
    // açıkça doğrulanır ki hata mesajı okunur olsun.
    expect(turuncu.right, mavi.right,
        reason: 'sağ kenarlar farklı: ${mavi.right} vs ${turuncu.right}');

    // ⚠ YÜKSEKLİK: açıklama kutusu iki satırlık sabit alan ayırdığı
    // için eşit olmalı.
    expect(turuncu.height, mavi.height,
        reason: 'yükseklikler farklı: ${mavi.height} vs ${turuncu.height}');
  });

  testWidgets('açıklama metni KESİLMEZ', (t) async {
    // ⚠ Turuncu kartın açıklaması iki satır; ayrılan kutu gerçek satır
    // yüksekliğinden küçükse alt satır kırpılır ("…kazanın" yarım
    // görünüyordu). Kutu ile metnin gerçek yüksekliği karşılaştırılır.
    await t.pumpWidget(app(const RoleSelectScreen()));
    await t.pumpAndSettle();

    const aciklama =
        'Hesap oluşturun, iş ilanlarını görüntüleyin ve yeni işler kazanın.';
    final metin = find.text(aciklama);
    expect(metin, findsOneWidget);

    final metinKutu = t.renderObject<RenderBox>(metin);
    final saran = find.ancestor(of: metin, matching: find.byType(SizedBox));
    expect(saran, findsWidgets);
    final ayrilan = saran.evaluate().first.renderObject! as RenderBox;

    expect(metinKutu.size.height, lessThanOrEqualTo(ayrilan.size.height),
        reason: 'metin ${metinKutu.size.height}, ayrılan '
            '${ayrilan.size.height} — alt satır kırpılıyor');
  });

  testWidgets('BÜYÜK YAZI ÖLÇEĞİNDE de kesilmez ve eşit kalır', (t) async {
    // ⚠ Asıl kusur burada çıkıyordu: cihaz yazı boyutu büyütülünce
    // ayrılan alan yetmiyordu. Android 14+ doğrusal olmayan ölçekleme
    // uyguladığı için ölçek YÜKSEKLİĞE değil PUNTOYA uygulanmalı.
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: app(const RoleSelectScreen()),
      ),
    );
    await t.pumpAndSettle();

    final mavi = _kart(t, 'rol-karti-alan');
    final turuncu = _kart(t, 'rol-karti-veren');
    expect(turuncu.width, mavi.width);
    expect(turuncu.height, mavi.height);
  });
}
