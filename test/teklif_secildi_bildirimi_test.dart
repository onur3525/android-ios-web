// TEKLİF SEÇİLDİ BİLDİRİMİ — İKİ AKIŞTA TEK METİN (KİLİT)
//
// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): "Teklif seçildiğinde, Bul ile
// veya ilan oluşturmayla farketmeksizin 'Teklifiniz seçildi 🎉'
// olarak bildirim gelmeli. 'Teklifiniz kabul edildi' kabul
// etmiyorum."
//
// ⚠ ÖNCEKİ DURUM: aynı olay iki portta ayrı ayrı yazılmıştı.
//   · `mock_ports`        → "Teklifiniz seçildi 🎉"
//   · `teklif_talebi_port` → "Teklifiniz kabul edildi"
//
// Hizmet veren için olay AYNI: verdiği teklif kabul edildi, iş
// başladı. Bildirim listesinde iki başlık alt alta düşünce iki farklı
// şey olmuş izlenimi veriyordu.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/bildirim_metinleri.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('1 — ⚠ METİN TEK KAYNAKTA', () {
    test('başlık ve gövde domain katmanında', () {
      expect(kTeklifSecildiBaslik, 'Teklifiniz seçildi 🎉');
      expect(teklifSecildiGovde('Doğalgaz Kaçak Tespiti'),
          '"Doğalgaz Kaçak Tespiti" işinde hizmet alan sizinle '
          'çalışmak istiyor.');
    });

    test('⚠ EMOJİ BAŞLIĞIN PARÇASI', () {
      // Kutlama tonu ürün kararıdır, süs değil. Ayrı bir "emoji ekle"
      // adımı yoktur.
      expect(kTeklifSecildiBaslik.contains('🎉'), isTrue);
    });
  });

  group('2 — ⚠ PORTLAR KENDİ METNİNİ YAZMAZ', () {
    const portlar = <String>[
      'lib/data/ports/mock_ports.dart',
      'lib/data/ports/teklif_talebi_port.dart',
    ];

    test('ikisi de ortak sabiti kullanır', () {
      for (final yol in portlar) {
        final k = _kod(yol);
        expect(k.contains('title: kTeklifSecildiBaslik'), isTrue, reason: yol);
        expect(k.contains('body: teklifSecildiGovde('), isTrue, reason: yol);
      }
    });

    test('⚠ ELLE YAZILMIŞ SEÇİLDİ METNİ KALMADI', () {
      // ⚠ KAPSAM DAR TUTULUR: `teklif_talebi_port` içinde
      // "Teklifiniz geldi" adlı BAŞKA bir bildirim var (hizmet alana,
      // teklif verildiğinde). Geniş bir "title: 'Teklifiniz" araması
      // onu da yakalar ve ilgisiz bir kuralı kilitlerdi.
      for (final yol in portlar) {
        final k = _kod(yol);
        expect(k.contains("title: 'Teklifiniz seçildi"), isFalse,
            reason: '$yol: başlık yine elle yazılmış');
      }
    });

    test('⚠ "kabul edildi" VARYANTI GERİ GELMEZ', () {
      // Kullanıcı bu ifadeyi açıkça reddetti.
      for (final yol in portlar) {
        expect(_kod(yol).contains('Teklifiniz kabul edildi'), isFalse,
            reason: yol);
      }
    });
  });

  group('3 — ⚠ İKİ AKIŞ AYNI OLAYI AYNI ANLATIR', () {
    test('ilan akışı ilan başlığını, Bul akışı hizmet adını geçirir', () {
      // İki alan farklı ama kullanıcı için ikisi de "iş"tir.
      final m = _kod('lib/data/ports/mock_ports.dart');
      final t = _kod('lib/data/ports/teklif_talebi_port.dart');
      expect(m.contains('teklifSecildiGovde(l.title)'), isTrue);
      expect(t.contains('teklifSecildiGovde(t.hizmet)'), isTrue);
    });

    test('bildirim türü her iki akışta da korunur', () {
      // Tür ROTALAMA için kullanılır; metin eşitlendi diye tür
      // birleştirilmedi — iki akış farklı ekrana gider.
      final m = _kod('lib/data/ports/mock_ports.dart');
      final t = _kod('lib/data/ports/teklif_talebi_port.dart');
      expect(m.contains('NotifType.offerSelected'), isTrue);
      expect(t.contains('NotifType.teklifSecildi'), isTrue);
    });
  });
}
