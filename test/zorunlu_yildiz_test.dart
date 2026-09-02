import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/theme.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';

/// ZORUNLU ALAN YILDIZI — `RefTextField`
///
/// ⚠ SORUN NEYDİ: yıldız üç yerde birden kayboluyordu.
///   · `RefFieldLabel` yıldızı bastırıyordu.
///   · `RefFormField` yıldızı alanın SOLUNDA çiziyordu.
///   · `RefTextField` ise HİÇ çizmiyordu.
/// Sonuç: Profil Bilgilerim ve Şifre Değiştir ekranlarında zorunlu
/// alanlar hiçbir yerde işaretlenmiyordu.
///
/// ⚠ ÇÖZÜM 16 AĞUSTOS'TA DEĞİŞTİ.
///
/// Yıldız önce etikete, sonra alanın soluna (`prefixIcon`) konmuştu.
/// İkisi de bırakıldı: yıldız artık YER TUTUCUNUN SONUNDA çiziliyor
/// (kayıt ekranının kurulu deseni) ve kutu dışında hiç etiket
/// kalmıyor. Tek kaynak `refYerTutucu`.
///
/// ⚠ KİLİT: yıldız eklenince ALAN YÜKSEKLİĞİ DEĞİŞMEMELİ. Yer tutucu
/// tek satır ve `ellipsis`'lidir; metinler 320 dp genişlikte %130
/// yazı ölçeğinde bile sığacak şekilde kısa seçilmiştir.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: HC.theme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 340, child: child),
          ),
        ),
      );

  Future<double> yukseklik(WidgetTester t, Widget alan) async {
    await t.pumpWidget(host(alan));
    await t.pump();
    return t.getSize(find.byType(TextFormField)).height;
  }

  group('1 — Yıldızın görünürlüğü', () {
    testWidgets('zorunlu: false → yıldız YOK', (t) async {
      await t.pumpWidget(host(RefTextField(
        controller: TextEditingController(),
        hint: 'Ad',
      )));
      await t.pump();
      // ⚠ Yıldız yer tutucunun İÇİNDE çizilir (RichText); isteğe bağlı
      // alanda hiç eklenmez.
      expect(find.textContaining('*', findRichText: true), findsNothing,
          reason: 'isteğe bağlı alanda yıldız çıkmış');
    });

    testWidgets('zorunlu: true → yıldız VAR', (t) async {
      await t.pumpWidget(host(RefTextField(
        controller: TextEditingController(),
        hint: 'Ad',
        zorunlu: true,
      )));
      await t.pump();
      expect(find.textContaining('*', findRichText: true), findsOneWidget,
          reason: 'zorunlu alanda yıldız çizilmemiş');
    });

    testWidgets('varsayılan değer FALSE', (t) async {
      // ⚠ `RefFormField`'ın varsayılanı `true`dur; `RefTextField`'ınki
      // BİLEREK farklıdır. Varsayılan `true` olsaydı değerlendirme
      // yorumu, puanlama metni, arama kutusu ve ilan açıklamasında da
      // yanlışlıkla yıldız çıkardı.
      await t.pumpWidget(host(RefTextField(
        controller: TextEditingController(),
        hint: 'Ad',
      )));
      await t.pump();
      expect(find.textContaining('*', findRichText: true), findsNothing);
    });
  });

  group('2 — ⚠ YÜKSEKLİK DEĞİŞMİYOR', () {
    testWidgets('yıldızlı ve yıldızsız alan AYNI yükseklikte', (t) async {
      final yildizsiz =
          await yukseklik(t, RefTextField(controller: TextEditingController(), hint: 'Ad'));
      final yildizli = await yukseklik(
          t,
          RefTextField(
              controller: TextEditingController(),
              hint: 'Ad',
              zorunlu: true));
      expect(yildizli, yildizsiz,
          reason: 'yıldız alan yüksekliğini değiştirmiş — '
              'prefixIconConstraints eksik ya da yanlış');
    });

    testWidgets('şifre alanı (suffix göz düğmesi) yüksekliği değişmiyor',
        (t) async {
      Widget sifre({required bool zorunlu}) => RefTextField(
            controller: TextEditingController(),
            obscureText: true,
            hint: 'Yeni şifre',
            zorunlu: zorunlu,
            suffix: const Icon(Icons.visibility_outlined, size: 20),
          );
      final yildizsiz = await yukseklik(t, sifre(zorunlu: false));
      final yildizli = await yukseklik(t, sifre(zorunlu: true));
      expect(yildizli, yildizsiz,
          reason: 'göz düğmeli alanda yıldız yüksekliği bozmuş');
    });

    testWidgets('çok satırlı alanda da yükseklik korunur', (t) async {
      // Bu alanlar bugün `zorunlu: false` kalıyor; yine de yıldız
      // eklenirse kutunun büyümediği kilitlensin.
      Widget uzun({required bool zorunlu}) => RefTextField(
            controller: TextEditingController(),
            maxLines: 5,
            hint: 'Açıklama',
            zorunlu: zorunlu,
          );
      final yildizsiz = await yukseklik(t, uzun(zorunlu: false));
      final yildizli = await yukseklik(t, uzun(zorunlu: true));
      expect(yildizli, yildizsiz);
    });
  });

  group('3 — Suffix düzeni bozulmadı', () {
    testWidgets('yıldız varken göz düğmesi hâlâ çiziliyor', (t) async {
      await t.pumpWidget(host(RefTextField(
        controller: TextEditingController(),
        hint: 'Yeni şifre',
        zorunlu: true,
        suffix: const Icon(Icons.visibility_outlined, size: 20),
      )));
      await t.pump();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.textContaining('*', findRichText: true), findsOneWidget);
    });
  });

  group('4 — Kaynak sözleşmesi', () {
    String kod(String p) => File(p)
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    test('yıldız RefFormField ile AYNI tokenları kullanır', () {
      final r = kod('lib/ui/ref_widgets.dart');
      // İki bileşende de aynı dört token geçmeli.
      for (final t in ['RC.requiredStar', 'RF.s15', 'RF.w700', 'RF.lh100']) {
        expect(r.contains(t), isTrue, reason: '$t kullanılmıyor');
      }
      expect(r.contains('prefixIconConstraints'), isTrue,
          reason: 'yükseklik kısıtı kaldırılmış');
    });

    /// Bir dosyada `zorunlu: true` verilen `RefTextField` sayısı.
    ///
    /// ⚠ DÜZ SAYIM YANILTIR: `RefFieldLabel` çağrıları da
    /// `zorunlu: true` içerir. Bu yüzden yalnız `RefTextField`
    /// bloklarının içine bakılır.
    int zorunluAlanSayisi(String kaynak) => kaynak
        .split('RefTextField(')
        .skip(1)
        .where((blok) =>
            blok.length > 200 ? blok.substring(0, 200).contains('zorunlu: true')
                : blok.contains('zorunlu: true'))
        .length;

    test('7 zorunlu alan işaretli', () {
      // ⚠ SAYI KİLİTLİ: yeni bir alan zorunlu yapılırsa bu test
      // düşer ve karar bilinçli olarak gözden geçirilir.
      expect(zorunluAlanSayisi(kod('lib/screens/profile_info_screen.dart')), 4,
          reason: 'Profil Bilgilerim: Ad, Soyad, E-posta, Telefon');
      expect(
          zorunluAlanSayisi(kod('lib/screens/change_password_screen.dart')), 3,
          reason: 'Şifre Değiştir: mevcut, yeni, tekrar');
    });

    test('isteğe bağlı alanlara DOKUNULMADI', () {
      // ⚠ Bu dört ekran RefTextField kullanıyor ama alanları zorunlu
      // DEĞİL; yıldız çıkmamalı.
      for (final yol in [
        'lib/screens/review_screen.dart',
        'lib/screens/app_rate_screen.dart',
        'lib/screens/hizmet_alani_screen.dart',
        'lib/screens/create_listing_screen.dart',
      ]) {
        expect(zorunluAlanSayisi(kod(yol)), 0,
            reason: '$yol: isteğe bağlı alana yıldız eklenmiş');
      }
    });

    test('İKİ BİLEŞEN DE ORTAK YER TUTUCUYU kullanır', () {
      // ⚠ 16 Ağu: yıldız yer tutucunun sonuna taşındı. `RefFormField`
      // içindeki ayrı yıldız bileşeni ve `RefTextField` içindeki
      final r = kod('lib/ui/ref_widgets.dart');
      expect(r.contains('Widget refYerTutucu('), isTrue);
      expect(r.contains('prefixIcon: zorunlu'), isFalse,
          reason: 'önek yıldızı geri gelmiş');
      // Etiket bileşeni duruyor ama artık hiçbir ekran kullanmıyor.
      expect(r.contains('class RefFieldLabel'), isTrue);
    });
  });
}

