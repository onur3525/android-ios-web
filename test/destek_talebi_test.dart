// DESTEK MERKEZİ › TALEP GÖNDER
//
// Kilitlenenler:
//   · istemci doğrulaması = sunucu doğrulaması (sınırlar backend'den okunur)
//   · Android ve web panelleri AYNI form bileşenini çizer (parite)
//   · mock/demo derlemesinde form yok, oturumsuz kullanıcıya form yok
//   · gönderim: tek istek (çift tıklama yok), başarıda temizlik ve talep
//     numarası, hatada anlaşılır metin, yeniden denemede AYNI anahtar
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/theme.dart';
import 'package:hizmetcep/domain/destek_talebi.dart';
import 'package:hizmetcep/domain/form_mesajlari.dart';
import 'package:hizmetcep/ui/destek_talebi_formu.dart';

String _kod(String yol) => const LineSplitter()
    .convert(File(yol).readAsStringSync())
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('DOĞRULAMA — sunucuyla aynı', () {
    test('boş ve yalnız boşluk içeren değer kabul edilmez', () {
      for (final v in [null, '', '   ', '\n\t ']) {
        expect(destekKonuHatasi(v), FormMesaj.zorunlu, reason: '$v');
        expect(destekMesajHatasi(v), FormMesaj.zorunlu, reason: '$v');
      }
    });

    test('alt/üst sınırlar (boşluklar sayılmaz)', () {
      expect(destekKonuHatasi('ab'), FormMesaj.destekKonuKisa);
      expect(destekKonuHatasi('  abc  '), isNull);
      expect(destekKonuHatasi('a' * kDestekKonuEnFazla), isNull);
      expect(destekKonuHatasi('a' * (kDestekKonuEnFazla + 1)),
          FormMesaj.destekKonuUzun);
      expect(destekMesajHatasi('123456789'), FormMesaj.destekMesajKisa);
      expect(destekMesajHatasi('  1234567890  '), isNull);
      expect(destekMesajHatasi('a' * kDestekMesajEnFazla), isNull);
      expect(destekMesajHatasi('a' * (kDestekMesajEnFazla + 1)),
          FormMesaj.destekMesajUzun);
    });

    test('sınırlar backend doğrulamasıyla AYNI', () {
      final b = File('backend/src/routes/destek.js').readAsStringSync();
      expect(
          b.contains(
              "metin(ctx.body.subject, 'Konu', $kDestekKonuEnAz, $kDestekKonuEnFazla)"),
          isTrue);
      expect(
          b.contains(
              "metin(ctx.body.message, 'Mesaj', $kDestekMesajEnAz, $kDestekMesajEnFazla)"),
          isTrue);
    });

    test('uyarı dili: nokta yok, "Lütfen" ile başlamaz, parantez yok', () {
      for (final m in const [
        FormMesaj.destekKonuKisa,
        FormMesaj.destekKonuUzun,
        FormMesaj.destekMesajKisa,
        FormMesaj.destekMesajUzun,
      ]) {
        expect(m.endsWith('.'), isFalse, reason: m);
        expect(m.startsWith('Lütfen'), isFalse, reason: m);
        expect(m.contains('('), isFalse, reason: m);
      }
    });
  });

  group('YERLEŞİM — Android ve web AYNI form', () {
    test('iki panel de ortak bileşeni çizer, e-posta kutusu korunur', () {
      for (final yol in [
        'lib/screens/profile_screen.dart',
        'lib/ui/web_destek_paneli.dart',
      ]) {
        final k = _kod(yol);
        expect(k.contains('const DestekTalebiFormu(),'), isTrue, reason: yol);
        expect(k.contains("Uri(scheme: 'mailto', path: adres)"), isTrue,
            reason: '$yol: e-posta kutusu kaldırılmamalı');
      }
    });

    test('mock/demo derlemesinde ve oturumsuz kullanıcıda form çizilmez', () {
      final k = _kod('lib/ui/destek_talebi_formu.dart');
      expect(k.contains('if (!ApiConfig.useRealApi) {'), isTrue);
      expect(k.contains('if (hesap == null) {'), isTrue);
      expect(k.contains('return const SizedBox.shrink();'), isTrue);
    });

    test('mevcut ApiClient ile POST /support/tickets + Idempotency-Key', () {
      final a = _kod('lib/data/remote/api/destek_api.dart');
      expect(a.contains("c.post('/support/tickets',"), isTrue);
      expect(a.contains('idempotencyKey: idempotencyKey'), isTrue);
      final f = _kod('lib/ui/destek_talebi_formu.dart');
      expect(f.contains('context.read<ApiClient>()'), isTrue);
      expect(f.contains('on ApiFailure catch (e)'), isTrue);
      expect(f.contains('e.error.message'), isTrue,
          reason: 'kullanıcıya yalnız eşlenmiş Türkçe metin gösterilir');
    });
  });

  group('DAVRANIŞ', () {
    late List<(String, String, String)> cagrilar;
    late Completer<DestekGonderimSonucu> bekleyen;

    Future<void> kur(WidgetTester t, {bool hemenBitir = true}) async {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      cagrilar = [];
      bekleyen = Completer();
      await t.pumpWidget(MaterialApp(
        theme: HC.theme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DestekTalebiFormu(
              epostaDogrulanmis: true,
              gonderici: (k, m, a) {
                cagrilar.add((k, m, a));
                return bekleyen.future;
              },
            ),
          ),
        ),
      ));
    }

    Finder alan(Key k) =>
        find.descendant(of: find.byKey(k), matching: find.byType(EditableText));

    testWidgets('boş/boşluk içerikle istek GİTMEZ, uyarılar görünür',
        (t) async {
      await kur(t);
      await t.enterText(alan(DestekTalebiFormu.konuAnahtari), '   ');
      await t.tap(find.byKey(DestekTalebiFormu.gonderAnahtari));
      await t.pump();
      expect(cagrilar, isEmpty);
      expect(find.text(FormMesaj.zorunlu), findsNWidgets(2));
    });

    testWidgets('gönderim sürerken ikinci dokunuş İKİNCİ istek üretmez; '
        'başarıda alanlar temizlenir ve talep numarası gösterilir', (t) async {
      await kur(t);
      await t.enterText(alan(DestekTalebiFormu.konuAnahtari), '  İlanım görünmüyor ');
      await t.enterText(
          alan(DestekTalebiFormu.mesajAnahtari), 'Dün verdiğim ilan listede yok.');
      await t.tap(find.byKey(DestekTalebiFormu.gonderAnahtari));
      await t.pump();
      await t.tap(find.byKey(DestekTalebiFormu.gonderAnahtari));
      await t.pump();
      expect(cagrilar.length, 1);
      expect(cagrilar.single.$1, 'İlanım görünmüyor', reason: 'boşluklar kırpılır');
      bekleyen.complete((talepNo: '30458231', hata: null));
      await t.pumpAndSettle();
      expect(
          find.text(FormMesaj.destekGonderildi('30458231', epostaDogrulanmis: true)),
          findsOneWidget);
      expect(t.widget<EditableText>(alan(DestekTalebiFormu.konuAnahtari)).controller.text,
          isEmpty);
      expect(t.widget<EditableText>(alan(DestekTalebiFormu.mesajAnahtari)).controller.text,
          isEmpty);
    });

    testWidgets('hata anlaşılır metinle gösterilir; aynı içerikle yeniden '
        'denemede AYNI anahtar gider', (t) async {
      await kur(t);
      await t.enterText(alan(DestekTalebiFormu.konuAnahtari), 'Bildirim gelmiyor');
      await t.enterText(
          alan(DestekTalebiFormu.mesajAnahtari), 'Telefonuma bildirim düşmüyor.');
      await t.tap(find.byKey(DestekTalebiFormu.gonderAnahtari));
      await t.pump();
      bekleyen.complete((talepNo: null, hata: 'Sunucuya ulaşılamıyor'));
      await t.pumpAndSettle();
      expect(find.text('Sunucuya ulaşılamıyor'), findsOneWidget);
      expect(t.widget<EditableText>(alan(DestekTalebiFormu.konuAnahtari)).controller.text,
          'Bildirim gelmiyor', reason: 'hatada kullanıcının yazdığı kaybolmaz');
      bekleyen = Completer();
      await t.tap(find.byKey(DestekTalebiFormu.gonderAnahtari));
      await t.pump();
      expect(cagrilar.length, 2);
      expect(cagrilar[1].$3, cagrilar[0].$3,
          reason: 'aynı içerik → aynı Idempotency-Key (ikinci kayıt açılmaz)');
      bekleyen.complete((talepNo: '30458232', hata: null));
      await t.pumpAndSettle();
    });
  });
}
