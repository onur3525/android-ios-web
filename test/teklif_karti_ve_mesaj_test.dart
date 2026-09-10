// TEKLİF TUTARI · GEÇİCİ ONAY · YENİ MESAJ (KİLİT)
//
// ⚠ KULLANICI İSTEKLERİ (9 Eyl):
//   • "Fiyat" yazan yer "Teklif" olsun; teklif yazısı ve tutar daha
//     belirgin olsun.
//   • Teklif gönderildiyse "gönderildi" yazısı görünsün, 2 sn sonra
//     kaybolsun.
//   • İki tarafta da kartlar üzerinde yeni mesaj geldiğini gösteren
//     bir şey olsun.
//
// ⚠ "GÖNDERİLDİ" ŞERİDİ EN İNCE NOKTA: önceden `teklifTarihi != null`
// koşuluna bağlıydı, yani KALICIYDI — ekran her açıldığında yeniden
// görünüyordu. Bu bir durum değil, bir EYLEM ONAYIDIR; durumu zaten
// teklif kartı söyler. Bu yüzden bayrak gönderim anında açılır ve
// zamanlayıcıyla söner.

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

TeklifMesaj _m(String gonderen, TeklifMesajDurumu d) => TeklifMesaj(
      id: 'm-$gonderen-${d.name}',
      gonderenId: gonderen,
      zaman: DateTime(2026, 9, 9),
      metin: 'merhaba',
      durum: d,
    );

TeklifTalebi _talep(List<TeklifMesaj> mesajlar) => TeklifTalebi(
      id: 't1',
      hizmetAlanId: 'alan',
      saglayiciId: 'veren',
      saglayiciAdi: 'Usta',
      kategori: 'Doğalgaz',
      hizmet: 'Doğalgaz Tesisatı',
      aciklama: 'iş var',
      iletisimTercihi: IletisimTercihi.telefonGoster,
      createdAt: DateTime(2026, 9, 9),
      mesajlar: mesajlar,
    );

void main() {
  final detay = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
  final kart = _kodu('lib/screens/widgets/teklif_tutar_karti.dart');

  group('1 — TEKLİF TUTARI KARTI', () {
    test('başlık "Teklif", "Fiyat" DEĞİL', () {
      expect(kart.contains("Text('Teklif'"), isTrue);
      expect(detay.contains("Text('Fiyat'"), isFalse,
          reason: 'eski "Fiyat" başlığı kalmış');
    });

    test('⚠ İKİ TARAF DA AYNI KARTI KULLANIR', () {
      // Hizmet verenin gönderdiği teklif ile hizmet alanın gördüğü
      // teklif ayrı ayrı çiziliyordu.
      expect(
          RegExp(r'TeklifTutarKarti\(').allMatches(detay).length,
          greaterThanOrEqualTo(2));
    });

    test('tutar biçimi ortak kaynaktan', () {
      expect(kart.contains('tutarMetni(tutar)'), isTrue);
    });
  });

  group('2 — "GÖNDERİLDİ" ONAYI GEÇİCİ', () {
    test('⚠ DURUMDAN TÜRETİLMEZ, BAYRAKTAN GELİR', () {
      expect(detay.contains('if (gonderimOnayi)'), isTrue,
          reason: 'şerit yine kalıcı duruma bağlanmış');
    });

    test('2 saniyelik zamanlayıcı kurulur', () {
      expect(detay.contains('Timer(const Duration(seconds: 2)'), isTrue);
      expect(detay.contains('_gonderimOnayi = false'), isTrue);
    });

    test('⚠ ZAMANLAYICI dispose EDİLİR', () {
      // Ekran 2 sn dolmadan kapanırsa ölü bir `setState` çağrılırdı.
      expect(detay.contains('_onayZamanlayici?.cancel()'), isTrue);
    });
  });

  group('3 — YENİ MESAJ SAYIMI', () {
    test('karşı tarafın okunmamış mesajları sayılır', () {
      final t = _talep([
        _m('veren', TeklifMesajDurumu.gonderildi),
        _m('veren', TeklifMesajDurumu.iletildi),
      ]);
      expect(okunmamisMesajSayisi(t, 'alan'), 2);
    });

    test('⚠ KENDİ MESAJIN "YENİ" SAYILMAZ', () {
      final t = _talep([_m('alan', TeklifMesajDurumu.gonderildi)]);
      expect(okunmamisMesajSayisi(t, 'alan'), 0);
    });

    test('okundu işaretli mesaj sayılmaz', () {
      final t = _talep([_m('veren', TeklifMesajDurumu.okundu)]);
      expect(okunmamisMesajSayisi(t, 'alan'), 0);
    });

    test('⚠ İKİ TARAF AYNI FONKSİYONU KULLANIR', () {
      final t = _talep([
        _m('veren', TeklifMesajDurumu.gonderildi),
        _m('alan', TeklifMesajDurumu.gonderildi),
      ]);
      expect(okunmamisMesajSayisi(t, 'alan'), 1);
      expect(okunmamisMesajSayisi(t, 'veren'), 1);
    });
  });

  group('4 — ÜÇ KART DA GÖSTERİR', () {
    test('hizmet alan ve hizmet veren listeleri', () {
      for (final yol in const [
        'lib/screens/teklif_istediklerim_screen.dart',
        'lib/screens/teklif_istekleri_screen.dart',
        'lib/screens/jobs_screen.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains('YeniMesajSeridi('), isTrue,
            reason: '$yol yeni mesajı göstermiyor');
        expect(k.contains('okunmamisMesajSayisi('), isTrue,
            reason: '$yol kendi sayımını yapıyor olabilir');
      }
    });

    test('⚠ SIFIRDA ŞERİT ÇİZİLMEZ', () {
      // ⚠ "> 0" METNİ ARANMAZ: karşılaştırma satır sonuna sarıldığında
      // ("...) >\n    0)") o metin kaynakta HİÇ geçmez ve test kural
      // bozulmadan düşerdi. Aranan şey, sayımın bir KOŞUL içinde
      // kullanılmış olmasıdır.
      for (final yol in const [
        'lib/screens/teklif_istediklerim_screen.dart',
        'lib/screens/teklif_istekleri_screen.dart',
        'lib/screens/jobs_screen.dart',
      ]) {
        expect(_kodu(yol).contains('if (okunmamisMesajSayisi('), isTrue,
            reason: '$yol sıfır mesajda boş şerit çizebilir');
      }
    });
  });
}
