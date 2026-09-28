// TEKLİF TALEBİ — HANGİ LİSTEDE GÖRÜNÜR (KİLİT)
//
// ⚠ KULLANICI KURALI (9 Eyl): "Hizmet alan teklifi seçtikten sonra
// ilgili kart Bul'da görünmemeli, tamamlanan işlere taşınmalı. Aynı
// zamanda hizmet verenin teklif isteklerindeki ilgili kart kazandığım
// işlere taşınmalı."
//
// ⚠ ÖLÇÜLEN SAPMA — DÖRT LİSTE, DÖRT AYRI SÜZGEÇ:
//   • "Bul" içindeki gönderilen talepler → süzgeç YOKTU.
//   • "Teklif İstekleri" → `!= secildi`; oysa seçim anında akış
//     `secToVer` ardından `tamamla` çağırıyor, durum `tamamlandi`
//     oluyordu ve kart listede KALIYORDU.
//   • "Kazandığım" → YALNIZ `secildi`; aynı sebeple kazanılan iş
//     oraya HİÇ DÜŞMÜYORDU.
//   • "Tamamlanan işler" → `secildi || tamamlandi`; tek doğru olan.
//
// Yani kart eski listeden çıkmıyor, yenisine de girmiyordu. Bir
// listeyi tek başına düzeltmek dördünü tutarlı yapmaz.
//
// ⚠ EN KRİTİK İDDİA: iki küme AYRIK ve BİRLİKTE tüm akışı kapsar —
// bir talep aynı anda iki listede görünemez, hiçbir listede
// görünmeden de kaybolamaz.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/teklif_talebi.dart';
import 'package:hizmetcep/domain/teklif_talebi_asamasi.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('1 — AŞAMA KURALI', () {
    test('süren: beklemede ve teklif geldi', () {
      expect(talepSurenMi(TeklifTalebiDurumu.beklemede), isTrue);
      expect(talepSurenMi(TeklifTalebiDurumu.teklifGeldi), isTrue);
    });

    test('kazanıldı: seçildi VE tamamlandı', () {
      // ⚠ İKİSİ BİRDEN: "Bul" akışında ayrı bir "işi tamamla" adımı
      // yok; seçim anında `tamamla` da çağrılıyor. Yalnız `secildi`
      // aranırsa kazanılan iş listeye hiç düşmez — yaşanan hata buydu.
      expect(talepKazanildiMi(TeklifTalebiDurumu.secildi), isTrue);
      expect(talepKazanildiMi(TeklifTalebiDurumu.tamamlandi), isTrue);
    });

    test('⚠ İKİ KÜME AYRIK', () {
      // Bir talep aynı anda hem eski hem yeni listede görünemez.
      for (final d in TeklifTalebiDurumu.values) {
        expect(talepSurenMi(d) && talepKazanildiMi(d), isFalse,
            reason: '$d iki listede birden görünüyor');
      }
    });

    test('⚠ HİÇBİR DURUM KAPSAM DIŞI KALMAZ', () {
      // Süren + kazanıldı + sonlandı, tüm durumları kapsamalı.
      // Kapsanmayan bir durum, kartın hiçbir listede görünmemesi
      // demektir — sessiz kayıp.
      for (final d in TeklifTalebiDurumu.values) {
        expect(talepSurenMi(d) || talepKazanildiMi(d) || talepSonlandiMi(d),
            isTrue,
            reason: '$d hiçbir aşamaya girmiyor');
      }
    });
  });

  group('2 — SÜZME YARDIMCILARI', () {
    TeklifTalebi t(TeklifTalebiDurumu d) => TeklifTalebi(
          talepNo: '10458231',
          id: 't-${d.name}',
          hizmetAlanId: 'a1',
          saglayiciId: 'v1',
          saglayiciAdi: 'Usta',
          kategori: 'Doğalgaz',
          hizmet: 'Doğalgaz Tesisatı',
          aciklama: 'iş var',
          iletisimTercihi: IletisimTercihi.telefonGoster,
          // ⚠ `createdAt` ZORUNLU alan — modelde varsayılanı yok.
          createdAt: DateTime(2026, 9, 9),
          durum: d,
        );

    final hepsi = [for (final d in TeklifTalebiDurumu.values) t(d)];

    test('süren listesi yalnız süren durumları taşır', () {
      final d = surenTalepler(hepsi).map((x) => x.durum).toSet();
      expect(d, {
        TeklifTalebiDurumu.beklemede,
        TeklifTalebiDurumu.teklifGeldi,
      });
    });

    test('kazanılan listesi yalnız kazanılan durumları taşır', () {
      final d = kazanilanTalepler(hepsi).map((x) => x.durum).toSet();
      expect(d, {
        TeklifTalebiDurumu.secildi,
        TeklifTalebiDurumu.tamamlandi,
      });
    });
  });

  group('3 — DÖRT LİSTE DE TEK KAYNAKTAN OKUR', () {
    test('"Bul" gönderilen talepler → süren', () {
      final k = _kodu('lib/screens/teklif_istediklerim_screen.dart');
      expect(k.contains('surenTalepler('), isTrue);
    });

    test('hizmet verenin "Teklif İstekleri" → süren', () {
      final k = _kodu('lib/screens/teklif_istekleri_screen.dart');
      expect(k.contains('talepSurenMi(t.durum)'), isTrue);
      // ⚠ Tek durumu dışlayan eski süzgeç geri gelmemeli.
      expect(k.contains('!= TeklifTalebiDurumu.secildi'), isFalse,
          reason: 'tek durum dışlanıyor — `tamamlandi` listede kalır');
    });

    test('hizmet verenin "Kazandığım" → kazanılan', () {
      final k = _kodu('lib/screens/jobs_screen.dart');
      expect(k.contains('talepKazanildiMi(t.durum)'), isTrue);
      expect(k.contains('== TeklifTalebiDurumu.secildi'), isFalse,
          reason: 'yalnız `secildi` aranıyor — kazanılan iş düşmez');
    });

    test('hizmet alanın "Tamamlanan işler" → kazanılan', () {
      final k = _kodu('lib/screens/my_listings_screen.dart');
      expect(k.contains('talepKazanildiMi(t.durum)'), isTrue);
    });
  });
}
