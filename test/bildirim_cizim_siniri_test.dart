// BİLDİRİM ÇİZİM SINIRI (28 Eki, kullanıcı kararı):
// "Bildirimler en fazla 2 ekranlık çizilsin; 2. ekrandan sonrası, eskide
// kalanlar çizilmesin." Sayı ve "Tümünü Okundu Yap" TAM listede kalır.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/screens/notifications_screen.dart';

String _kod(String yol) => File(yol).readAsStringSync();

/// Verilen ekran boyutunda `cizilecekEnFazla` sonucunu döner.
Future<int> _sinir(WidgetTester t, Size boyut) async {
  late int sonuc;
  await t.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: boyut),
      child: Builder(builder: (context) {
        sonuc = NotificationsScreen.cizilecekEnFazla(context);
        return const SizedBox.shrink();
      }),
    ),
  );
  return sonuc;
}

void main() {
  group('sınır hesabı (≈ 2 ekran)', () {
    testWidgets('telefon: 2 × yükseklik / tahmini kart yüksekliği', (t) async {
      // 2 × 800 / 94 = 17,02 → 17
      expect(await _sinir(t, const Size(390, 800)), 17);
      // 2 × 932 / 94 = 19,83 → 19 (aşağı yuvarlanır: 2 ekranı aşmaz)
      expect(await _sinir(t, const Size(430, 932)), 19);
    });

    testWidgets('masaüstü web penceresi', (t) async {
      // 2 × 1000 / 94 = 21,27 → 21
      expect(await _sinir(t, const Size(1440, 1000)), 21);
    });

    testWidgets('çok kısa pencerede alt sınır', (t) async {
      expect(await _sinir(t, const Size(800, 300)),
          NotificationsScreen.kEnAzCizilenBildirim);
      expect(await _sinir(t, Size.zero), NotificationsScreen.kEnAzCizilenBildirim);
    });

    test('tahmini kart yüksekliği kart ölçüleriyle uyumlu', () {
      // 13 + (14,5 başlık ≈ 17) + 3 + 2 × 12,5 × 1,5 + 13 ≈ 84; + 10 boşluk.
      expect(NotificationsScreen.kTahminiKartYuksekligi, inInclusiveRange(84, 100));
    });
  });

  group('ekran kodu', () {
    final k = _kod('lib/screens/notifications_screen.dart');

    test('kartlar yalnız SINIRLI listeden çizilir', () {
      expect(k.contains('for (final n in cizilecek) ...['), isTrue);
      expect(k.contains('for (final n in liste) ...['), isFalse,
          reason: 'tam liste kart olarak çizilmemeli');
      expect(
          k.contains('liste.take(NotificationsScreen.cizilecekEnFazla(context))'),
          isTrue);
    });

    test('okunmamış sayısı ve "Tümünü Okundu Yap" TAM listede kalır', () {
      expect(k.contains('final okunmamis = liste.where((n) => !n.read).length;'),
          isTrue);
      expect(k.contains('for (final n in liste.where((n) => !n.read)) {'), isTrue);
    });

    test('kart dokunuşu aynı yönlendirmeyi kullanır', () {
      expect(k.contains('NotificationsScreen.hedefeGit(context, n.type, n.refId)'),
          isTrue);
    });
  });
}
