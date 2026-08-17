import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/theme.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/controllers/region_controller.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/screens/register_screen.dart';
import 'package:provider/provider.dart';

/// NEXT ZİNCİRİ — GERÇEK WIDGET DAVRANIŞI
///
/// ⚠ Kaynak-metin testi DEĞİL: ekran gerçekten pump edilir,
/// `testTextInput.receiveAction(TextInputAction.next)` gönderilir ve
/// odağın gerçekten bir sonraki alana geçtiği doğrulanır.
///
/// Sözleşme: `onEditingComplete` verildiği için Flutter'ın varsayılan
/// `unfocus()` yolu çalışmaz — klavye geçiş sırasında KAPANMAZ.
void main() {
  Widget app() {
    final repo = AuthRepository();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthController(MockAuthPort(repo))),
        ChangeNotifierProvider(create: (_) => RegionController(MockRegionPort())),
      ],
      child: MaterialApp(
        theme: HC.theme(),
        home: const RegisterScreen(role: Role.customer),
      ),
    );
  }

  /// Ekrandaki TextFormField'ları sırayla döndürür.
  List<EditableText> alanlar(WidgetTester t) =>
      t.widgetList<EditableText>(find.byType(EditableText)).toList();

  testWidgets('ilk alan odaklanır ve metin girilir', (t) async {
    await t.pumpWidget(app());
    await t.pump();

    final ilk = find.byType(TextFormField).first;
    await t.tap(ilk);
    await t.pump();
    await t.enterText(ilk, 'Onur');
    await t.pump();

    expect(find.text('Onur'), findsOneWidget);
  });

  testWidgets('NEXT zinciri: her ara alan bir sonrakine geçer', (t) async {
    await t.pumpWidget(app());
    await t.pump();

    final sahalar = find.byType(TextFormField);
    final adet = sahalar.evaluate().length;
    expect(adet, greaterThanOrEqualTo(6),
        reason: 'kayıt formunda en az 6 metin alanı olmalı');

    // Ad → Soyad → Telefon → E-posta → Şifre → Şifre Tekrar
    const degerler = ['Onur', 'Butun', '05551112233', 'a@b.com', '123456'];

    for (var i = 0; i < degerler.length; i++) {
      final o = sahalar.at(i);
      // ⚠ YALNIZ TEST HARNESS DÜZELTMESİ.
      // Test penceresi 800×600'dür; alttaki alanlar görünür alanın
      // dışında kalıp `tap()` hedefi ıskalayabiliyor. Alan önce
      // görünür kılınır. `warnIfMissed: false` KULLANILMAZ ve
      // production'a hiçbir kaydırma sarmalayıcısı eklenmez.
      await t.ensureVisible(o);
      await t.pump();
      await t.tap(o);
      await t.pump();
      await t.enterText(o, degerler[i]);
      await t.pump();

      // Gerçek IME eylemi gönderilir.
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pumpAndSettle();

      final hepsi = alanlar(t);
      // Bir sonraki alan odak ALMALI.
      expect(hepsi[i + 1].focusNode.hasFocus, isTrue,
          reason: '${i + 1}. alan odak almalı');
      // Önceki alan odağı BIRAKMALI.
      expect(hepsi[i].focusNode.hasFocus, isFalse,
          reason: '$i. alan odağı bırakmalı');
    }
  });

  testWidgets('son alanda DONE — zincir devam etmez', (t) async {
    await t.pumpWidget(app());
    await t.pump();

    final sahalar = find.byType(TextFormField);
    final son = sahalar.at(5);
    // ⚠ YALNIZ TEST HARNESS DÜZELTMESİ — bkz. yukarıdaki not.
    // Logda hedef Offset(400,805), pencere Size(800,600) idi.
    await t.ensureVisible(son);
    await t.pump();
    await t.tap(son);
    await t.pump();
    await t.enterText(son, '123456');
    await t.pump();

    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    // Son alandan sonra başka alana geçilmez.
    final hepsi = alanlar(t);
    for (var i = 0; i < 5; i++) {
      expect(hepsi[i].focusNode.hasFocus, isFalse,
          reason: 'done sonrası önceki alanlar odak almamalı');
    }
  });

  testWidgets('yazarken odak DÜŞMEZ', (t) async {
    await t.pumpWidget(app());
    await t.pump();

    final ilk = find.byType(TextFormField).first;
    await t.tap(ilk);
    await t.pump();

    // Harf harf yazılır; her adımda odak korunmalı.
    for (final s in ['O', 'On', 'Onu', 'Onur']) {
      await t.enterText(ilk, s);
      await t.pump();
      expect(alanlar(t).first.focusNode.hasFocus, isTrue,
          reason: '"$s" yazıldıktan sonra odak düşmemeli');
    }
  });

  testWidgets('NEXT olay sırası — odak ARA DURUMA düşüyor mu?', (t) async {
    await t.pumpWidget(app());
    await t.pump();

    // ⚠ Bu test bir İDDİAYI DOĞRULAMAK için değil, gerçek sırayı
    // ÖLÇMEK için yazıldı. `primaryFocus` geçişi kare kare izlenir.
    final olaylar = <String>[];
    void kaydet(String e) => olaylar.add(e);

    String primaryAd() {
      final p = FocusManager.instance.primaryFocus;
      if (p == null) {
        return 'NULL';
      }
      final hepsi = alanlar(t);
      for (var i = 0; i < hepsi.length; i++) {
        if (hepsi[i].focusNode == p) {
          return 'alan$i';
        }
      }
      return 'diger';
    }

    final sahalar = find.byType(TextFormField);
    await t.tap(sahalar.first);
    await t.pump();
    await t.enterText(sahalar.first, 'Onur');
    await t.pump();
    kaydet('ONCE primary=${primaryAd()}');

    await t.testTextInput.receiveAction(TextInputAction.next);

    // Tek tek kare ilerletilir; ara durum varsa yakalanır.
    for (var k = 0; k < 4; k++) {
      await t.pump(const Duration(milliseconds: 16));
      kaydet('kare$k primary=${primaryAd()}');
    }
    await t.pumpAndSettle();
    kaydet('SONRA primary=${primaryAd()}');

    // Ölçüm çıktısı — CI logunda görünür.
    // ignore: avoid_print
    print('NEXT_OLAY_SIRASI: ${olaylar.join(" | ")}');

    // Sözleşme: geçiş TAMAMLANDIĞINDA ikinci alan odaklı olmalı.
    expect(alanlar(t)[1].focusNode.hasFocus, isTrue);

    // ⚠ Ara karelerde `NULL` görülüp görülmediği RAPORLANIR;
    // testi kırmaz — gerçek davranışı öğrenmek için ölçüyoruz.
    final nullGoruldu =
        olaylar.where((e) => e.startsWith('kare')).any((e) => e.contains('NULL'));
    // ignore: avoid_print
    print('NEXT_ARA_DURUM_NULL: $nullGoruldu');
  });
}
