// TEKLİF İSTE — HİZMET ZAMANI (Acil / Bu hafta / Esnek zaman)
//
// ⚠ KULLANICI İSTEĞİ (9 Eyl): "İlan Ver" ekranındaki hizmet zamanı
// düğmeleri, AYNI ölçü, AYNI renk ve AYNI çalışma mantığıyla "Teklif
// İste" ekranında da olsun.
//
// Bu dosya iki şeyi ayrı ayrı kilitler:
//   1. VERİ ZİNCİRİ — seçim gerçekten talebe yazılıyor mu (birim
//      testi; ekran kurulumu gerekmez, gerçek repository+port koşar).
//   2. EKRAN SÖZLEŞMESİ — ekran KOPYA düğme çizmiyor, ortak bileşeni
//      kullanıyor ve seçimi gönderime iletiyor (kaynak metni).
//
// ⚠ "AYNI ölçü ve renk" iddiası burada AYRICA ölçülmez: ekran
// `IsZamaniSecici` bileşeninin KENDİSİNİ kullandığı için ölçü/renk
// tanım gereği aynıdır. Rengin doğruluğu `acil_rozeti_rengi_test`
// ve seçicinin kendi kuralları tarafından korunur.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/teklif_talebi.dart';
import 'package:hizmetcep/data/ports/teklif_talebi_port.dart';
import 'package:hizmetcep/data/repositories/teklif_talebi_repository.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('1 — VERİ ZİNCİRİ (ekran → controller → port → repo → model)', () {
    late TeklifTalebiRepository repo;
    late MockTeklifTalebiPort port;

    setUp(() {
      repo = TeklifTalebiRepository();
      port = MockTeklifTalebiPort(repo);
    });

    Future<TeklifTalebi> gonder(IsZamani? z) async {
      final err = await port.gonder(
        hizmetAlanId: 'alan-1',
        saglayiciId: 'veren-1',
        saglayiciAdi: 'Onur Bilgin',
        kategori: 'Doğalgaz',
        hizmet: 'Doğalgaz Tesisatı',
        aciklama: 'Kombi bağlantısı yapılacak',
        iletisimTercihi: IletisimTercihi.telefonGoster,
        isZamani: z,
      );
      if (err != null) {
        throw StateError('gönderim başarısız: ${err.message}');
      }
      final liste = port.byHizmetAlan('alan-1');
      if (liste.length != 1) {
        throw StateError('beklenen 1 talep, gelen ${liste.length}');
      }
      return liste.first;
    }

    test('ACİL seçilirse talebe ACİL olarak yazılır', () async {
      final t = await gonder(IsZamani.hemen);
      expect(t.isZamani, IsZamani.hemen);
      // ⚠ Etiket tek kaynaktan gelir — ekran kendi metnini yazmaz.
      expect(t.isZamani!.etiket, 'Acil');
    });

    test('BU HAFTA ve ESNEK ZAMAN da aynen taşınır', () async {
      expect((await gonder(IsZamani.buHafta)).isZamani, IsZamani.buHafta);
      repo = TeklifTalebiRepository();
      port = MockTeklifTalebiPort(repo);
      expect((await gonder(IsZamani.esnek)).isZamani, IsZamani.esnek);
    });

    test('⚠ SEÇİM YOKSA null KALIR — varsayılana ÇEVRİLMEZ', () async {
      // "İlan Ver"deki kuralla aynı: alan isteğe bağlıdır, seçim
      // yapılmadan talep gönderilebilir ve hiçbir zaman bilgisi
      // uydurulmaz.
      final t = await gonder(null);
      expect(t.isZamani, isNull);
    });

    test('zaman seçilmemesi gönderimi ENGELLEMEZ', () async {
      final t = await gonder(null);
      expect(t.durum, TeklifTalebiDurumu.beklemede);
    });
  });

  group('2 — EKRAN SÖZLEŞMESİ', () {
    final k = _kodu('lib/screens/teklif_iste_screen.dart');

    test('ORTAK bileşen kullanılır, kopya düğme çizilmez', () {
      expect(k.contains('IsZamaniSecici('), isTrue,
          reason: 'ortak seçici bileşeni ekranda yok');
      // ⚠ Kopya çizim işareti: ekran kendi seçenek listesini
      // yazıyorsa ölçü/renk seçiciden AYRILABİLİR.
      expect(k.contains('IsZamani.values'), isFalse,
          reason: 'ekran kendi seçenek listesini yazıyor — '
              'seçenekler `IsZamaniSecici` içinden gelmeli');
    });

    test('seçim gönderime iletilir', () {
      expect(k.contains('isZamani: _isZamani'), isTrue,
          reason: 'seçilen değer `gonder()` çağrısına geçmiyor — '
              'seçici yalnız görsel kalır');
    });

    test('⚠ ZORUNLU DEĞİL: doğrulama/uyarı eklenmemiş', () {
      // Alan isteğe bağlıdır; "İlan Ver"de de hiçbir doğrulama yok.
      // Gönderim kapısı yalnız açıklama kurallarına bakmalı.
      expect(k.contains('_isZamani == null'), isFalse,
          reason: 'hizmet zamanı zorunlu hâle getirilmiş');
    });
  });

  group('3 — HİZMET VEREN TARAFI GÖRÜR', () {
    test('⚠ BÖLÜM SIRASI: Hizmet Zamanı → Açıklama → Fotoğraflar', () {
      // KULLANICI KARARI (9 Eyl): fotoğraflar açıklamanın İÇİNDE
      // değil, kendi başlıklı bölümünde ve en altta olmalı.
      final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      final iZaman = k.indexOf("Text('Hizmet Zamanı'");
      final iAciklama = k.indexOf("Text('Açıklama'");
      final iFoto = k.indexOf("Text('Fotoğraflar'");
      expect(iZaman, greaterThan(-1), reason: 'Hizmet Zamanı başlığı yok');
      expect(iAciklama, greaterThan(iZaman),
          reason: 'Açıklama, Hizmet Zamanı bölümünden önce geliyor');
      expect(iFoto, greaterThan(iAciklama),
          reason: 'Fotoğraflar bölümü açıklamadan önce ya da '
              'açıklamanın içinde çiziliyor');
    });

    test('talep detayında rozet çizilir', () {
      // ⚠ Karşı taraf görmezse seçici gönderende kalan ölü bir alan
      // olurdu. Rozet ORTAK bileşendir (`IsZamaniRozeti`), ilan
      // akışıyla aynı ölçü ve renk.
      final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('IsZamaniRozeti(t.isZamani)'), isTrue);
      expect(k.contains('if (t.isZamani != null)'), isTrue,
          reason: 'seçim yokken yer tutucu çizilmemeli');
    });
  });
}
