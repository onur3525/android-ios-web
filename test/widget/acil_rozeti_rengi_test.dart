// "ACİL" ROZETİ KIRMIZI — RENK KİLİDİ (GERÇEK WIDGET TESTİ)
//
// ⚠ KULLANICI BULGUSU (9 Eyl): hizmet alan seçim ekranında "Acil"i
// KIRMIZI görüp ilanı gönderiyor; hizmet verene düşen önizleme
// kartında ve iş detayında AYNI bilgi MAVİ görünüyordu.
//
// ⚠ ÖLÇÜLEN KÖK NEDEN: `IsZamaniRozeti`, etiketin NE OLDUĞUNA hiç
// bakmadan `RC.blueSoft` + `RC.blue` çiziyordu. Kural yalnız
// seçicide (`IsZamaniSecici._secenek`) yazılıydı.
//
// ⚠ KAYNAK OKUMAK YETMEZ: "dosyada RC.danger geçiyor" demek rengin
// EKRANA çıktığını kanıtlamaz — seçici de aynı dosyada ve o zaten
// kırmızı kullanıyordu. Bu yüzden rozet gerçekten pump edilir ve
// rengi `BoxDecoration`dan OKUNUR.
//
// ⚠ ROZET İKİ YERDE ÇİZİLİR: `jobs_screen` (önizleme kartı) ve
// `job_detail_screen` (detay). İkisi de AYNI bileşeni kullandığı
// için tek bileşeni kilitlemek iki yüzeyi birden korur; kopya
// rozet yazılmadı.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/screens/widgets/is_zamani_secici.dart';
import 'package:hizmetcep/ui/ref_tokens.dart';

void main() {
  Future<void> ciz(WidgetTester t, IsZamani? z) => t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: IsZamaniRozeti(z)),
          ),
        ),
      );

  /// Rozetin KENDİ kutusunun zemin rengi.
  ///
  /// ⚠ `Scaffold`/`MaterialApp` de `Container` üretebilir; bu yüzden
  /// arama `IsZamaniRozeti`in ALTINA sınırlanır ve İLK kutu alınır.
  Color? zemin(WidgetTester t) {
    final f = find
        .descendant(
            of: find.byType(IsZamaniRozeti), matching: find.byType(Container))
        .first;
    final d = t.widget<Container>(f).decoration;
    if (d is! BoxDecoration) {
      throw StateError('rozetin dekorasyonu BoxDecoration değil');
    }
    return d.color;
  }

  Color? yazi(WidgetTester t, String etiket) =>
      t.widget<Text>(find.text(etiket)).style?.color;

  testWidgets('ACİL → zemin kırmızı, yazı beyaz', (t) async {
    await ciz(t, IsZamani.hemen);
    expect(find.text('Acil'), findsOneWidget);
    expect(zemin(t), RC.danger, reason: 'Acil rozeti kırmızı değil');
    // ⚠ Kırmızı zeminde kırmızı/mavi yazı okunmaz.
    expect(yazi(t, 'Acil'), RC.white);
  });

  testWidgets('BU HAFTA → mavi kalır (değişmedi)', (t) async {
    await ciz(t, IsZamani.buHafta);
    expect(zemin(t), RC.blueSoft);
    expect(yazi(t, 'Bu hafta'), RC.blue);
  });

  testWidgets('ESNEK ZAMAN → mavi kalır (değişmedi)', (t) async {
    await ciz(t, IsZamani.esnek);
    expect(zemin(t), RC.blueSoft);
    expect(yazi(t, 'Esnek zaman'), RC.blue);
  });

  testWidgets('SEÇİM YOKSA hiçbir şey çizilmez', (t) async {
    // ⚠ `null` normal bir durumdur — "belirtilmemiş" yer tutucusu
    // GÖSTERİLMEZ. Bu kural düzeltmeyle birlikte bozulmamalı.
    await ciz(t, null);
    expect(
        find.descendant(
            of: find.byType(IsZamaniRozeti), matching: find.byType(Container)),
        findsNothing);
    expect(find.text('Acil'), findsNothing);
  });

  testWidgets('⚠ ETİKET METNİ TEK KAYNAKTAN GELİR', (t) async {
    // Rozet kendi metnini yazmaz; `IsZamani.etiket` okunur. Metin
    // orada değişirse rozet de değişmeli.
    await ciz(t, IsZamani.hemen);
    expect(find.text(IsZamani.hemen.etiket), findsOneWidget);
  });
}
