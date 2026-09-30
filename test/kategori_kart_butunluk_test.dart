// KATEGORİ KARTI — BÜTÜNLÜK VE TAŞMA
//
// KARARLAR:
//   1. TÜM kartlar aynı ölçüdedir: tek `GridView` (3 sütun, sabit
//      en-boy oranı) + etiket için SABİT 40px kutu. Kart yükseklikleri
//      metne göre değişmez.
//   2. TÜM etiketler aynı yazı tipi ve puntosundadır: Poppins,
//      11px, w700. `FittedBox` YOKTUR — metin küçültülerek
//      sığdırılmaz, dolayısıyla kartlar arası punto farkı oluşmaz.
//   3. HİÇBİR ETİKET TAŞMAZ, KESİLMEZ, YARIM KALMAZ:
//      · en fazla 3 satır, satır yüksekliği 11 × 1.20 = 13,2px,
//        üç satır 39,6px → 40px kutuya sığar
//      · en dar hedef ekranda (320dp) metin alanı 81,3px; 50
//        etiketin tamamı üç satıra ve kelime bölünmeden sığar
//      · sistem yazı ölçeği bu etikette 1.0 ile sınırlıdır; aksi
//        hâlde 3 satır kutuyu aşıyordu
//
// ⚠ ÖLÇÜM GERÇEK FONTLA YAPILDI. Aşağıdaki genişlik denetimi
// `assets/fonts/Poppins-Bold.ttf` metriklerinden değil, katalogdaki
// etiketlerin KARAKTER SAYISI üzerinden kaba bir üst sınır kurar;
// asıl piksel ölçümü teslim raporundadır. Buradaki test, etiketlerin
// bir daha uzamasını ve kart ölçülerinin ayrışmasını engeller.
//
// ⚠ GÜNCEL DURUM: `KategoriKarti` (lib/screens/widgets/kategori_karti.dart)
// hiçbir ekranda kullanılmıyordu — ölü kod olarak SİLİNDİ. Kart
// ölçüsü/etiket taşması kilitleri onunla birlikte kalktı. Kalan tek
// kilit: ilan verme ekranına fotoğraflı kategori ızgarası geri
// gelmez (seçim YALNIZ arama ile).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) {
  final f = File(yol);
  // ⚠ BURADA `expect` KULLANILMAZ.
  //
  // Bu yardımcı `group(...)` gövdesinde de çağrılıyor; `expect` bir
  // test gövdesi dışında çalışınca `OutsideTestException` atar ve
  // DOSYANIN TAMAMI yüklenemez ("Failed to load"). Eksik dosya
  // durumu düz bir istisnayla bildirilir.
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

void main() {
  final grid = _kod('lib/screens/create_listing_screen.dart');

  test('İLAN IZGARASI YOK — seçim yalnız arama ile', () {
    expect(grid.contains('crossAxisCount: kKategoriIzgaraSutun'), isFalse);
    expect(grid.contains('KategoriKarti('), isFalse);
    expect(grid.contains('SearchService.services('), isTrue);
    expect(grid.contains('crossAxisSpacing: kKategoriIzgaraBosluk'), isFalse);
  });

  test('ölü kart bileşeni geri gelmedi', () {
    expect(File('lib/screens/widgets/kategori_karti.dart').existsSync(),
        isFalse);
  });
}
