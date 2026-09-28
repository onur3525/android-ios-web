// DURUM ROZETİ — ORANTILI VE BEKLERKEN CANLI (KİLİT)
//
// ⚠ KULLANICI İSTEĞİ (9 Eyl): "'Teklif bekleniyor' yazısı çok gelişi
// güzel konulmuş, daha orantılı olmalı. Ve teklif bekliyor canlı
// hissi vermeli — noktalar sırayla yanıp sönebilir."
//
// ⚠ NOKTALAR METNE EKLENMEZ, AYRI ÇİZİLİR: metnin sonuna nokta
// eklemek her karede metni yeniden ölçtürür ve rozetin genişliği
// oynar. Üç nokta SABİT yer kaplar, yalnız saydamlıkları değişir —
// rozet zıplamaz.
//
// ⚠ ANİMASYON YALNIZ BEKLEYEN DURUMDA: sonuçlanmış bir durumda
// ("Teklif geldi", "İş tamamlandı") sürekli oynayan bir öğe, bitmiş
// işi bitmemiş gibi gösterirdi. Ayrıca her kartta boşuna dönen bir
// denetleyici, uzun listelerde kare kaybı demektir.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/screens/widgets/durum_rozeti.dart';
import 'package:hizmetcep/ui/ref_tokens.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  Future<void> ciz(WidgetTester t, {required bool bekliyor}) => t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DurumRozeti(
                metin: bekliyor ? 'Teklif bekleniyor' : 'Teklif geldi',
                renk: RC.blue,
                bekliyor: bekliyor,
              ),
            ),
          ),
        ),
      );

  testWidgets('metin çizilir', (t) async {
    await ciz(t, bekliyor: true);
    expect(find.text('Teklif bekleniyor'), findsOneWidget);
  });

  testWidgets('⚠ BEKLERKEN ÜÇ NOKTA VAR', (t) async {
    await ciz(t, bekliyor: true);
    await t.pump(const Duration(milliseconds: 100));
    // Noktalar `Opacity` ile çizilir; üç tane olmalı.
    expect(find.byType(Opacity), findsNWidgets(3));
  });

  testWidgets('⚠ SONUÇLANMIŞ DURUMDA NOKTA YOK', (t) async {
    await ciz(t, bekliyor: false);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(Opacity), findsNothing,
        reason: 'bitmiş iş, sürüyormuş gibi gösteriliyor');
  });

  testWidgets('⚠ NOKTALAR ROZETTE DE SATIRIN ALTINDA', (t) async {
    // Kullanıcı isteği (10 Eyl): noktalar kelimenin ortasında değil,
    // "Teklif bekleniyor..." gibi altında olmalı. Talep detayındaki
    // geniş kutu ile AYNI kural.
    await ciz(t, bekliyor: true);
    await t.pump(const Duration(milliseconds: 100));

    final yazi = t.getRect(find.text('Teklif bekleniyor'));
    final nokta = t.getRect(find.byType(Opacity).first);
    // Noktanın merkezi, yazının dikey ORTASININ ALTINDA olmalı.
    expect(nokta.center.dy, greaterThan(yazi.center.dy),
        reason: 'noktalar hâlâ satırın ortasında');
  });

  testWidgets('⚠ ROZET GENİŞLİĞİ OYNAMAZ', (t) async {
    // Noktalar metne eklenseydi genişlik her karede değişirdi.
    await ciz(t, bekliyor: true);
    await t.pump(const Duration(milliseconds: 100));
    final ilk = t.getSize(find.byType(DurumRozeti));
    await t.pump(const Duration(milliseconds: 400));
    final sonra = t.getSize(find.byType(DurumRozeti));
    expect(sonra.width, ilk.width);
  });

  testWidgets('animasyon sonsuz döner ve testi kilitlemez', (t) async {
    // ⚠ `pumpAndSettle` KULLANILMAZ: sürekli tekrar eden animasyon
    // hiç durmaz, `pumpAndSettle` zaman aşımına düşerdi.
    await ciz(t, bekliyor: true);
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull);
  });

  group('⚠ DETAY EKRANI DA AYNI DİLDE', () {
    // KULLANICI SORUSU (9 Eyl): "Bu ekranda da aynı yazı ve işleyişle
    // uygulandı mı?" — uygulanmamıştı: metin ayrıydı ("Hizmet verenin
    // teklifi bekleniyor.") ve animasyon ayrıydı (nabız atan ikon).
    test('metin tek kaynaktan, noktalar ortak bileşenden', () {
      final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('kTeklifBekleniyorMetni'), isTrue);
      expect(k.contains('BekleyenNoktalar('), isTrue);
      expect(k.contains('Hizmet verenin teklifi bekleniyor'), isFalse,
          reason: 'ikinci cümle geri gelmiş');
    });

    test('⚠ İKİ ANİMASYON AYNI ANDA OYNAMAZ', () {
      // Nabız atan ikon + parlayan noktalar birlikte "canlı" değil
      // huzursuz görünürdü; hareket TEK yerde.
      final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('FadeTransition'), isFalse);
    });

    test('⚠ GÖNDERİ İKONU KALDIRILDI (10 Eyl)', () {
      // Kutu zaten mavi zeminli ve metin ne beklendiğini söylüyordu;
      // soldaki mavi daire fazladan görsel ağırlıktı.
      final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('ic_send.svg'), isFalse);
    });

    test('⚠ NOKTALAR SATIRIN ALTINDA, ORTASINDA DEĞİL', () {
      // Ortada duruyorlardı ve "Teklif bekleniyor..." izlenimi
      // vermiyorlardı. `end` hizası + 3 px alt dolgu, noktaları
      // yazının taban çizgisine oturtur.
      final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('CrossAxisAlignment.end'), isTrue);
      expect(k.contains('EdgeInsets.only(bottom: 3)'), isTrue);
    });
  });

  group('KART YERLEŞİMİ', () {
    test('⚠ ROZET KARTIN SAĞ ÜST KÖŞESİNDE', () {
      // Kullanıcı isteği (10 Eyl): "Teklif bekleniyor yazısı kartın
      // sağ üst köşesine konumlansın." Önceden özet satırının
      // sağındaydı, yani hizmet adının BİR SATIR ALTINDA
      // başlıyordu.
      final k = _kodu('lib/screens/teklif_istediklerim_screen.dart');
      final iBaslik = k.indexOf('Text(talep.hizmet');
      final iRozet = k.indexOf('DurumRozeti(');
      final iOzet = k.indexOf('SaglayiciOzetSatiri(');
      expect(iRozet, greaterThan(iBaslik));
      expect(iRozet, lessThan(iOzet),
          reason: 'rozet hâlâ özet satırının içinde/altında');
    });
  });

  group('İKİ LİSTE DE AYNI BİLEŞENİ KULLANIR', () {
    test('hizmet alan ve hizmet veren kartları', () {
      for (final yol in const [
        'lib/screens/teklif_istediklerim_screen.dart',
        'lib/screens/teklif_istekleri_screen.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains('DurumRozeti('), isTrue,
            reason: '$yol kendi rozetini çiziyor');
        expect(k.contains('bekliyor: talep.durum == TeklifTalebiDurumu.beklemede'),
            isTrue,
            reason: '$yol canlılık kuralını uygulamıyor');
      }
    });
  });
}
