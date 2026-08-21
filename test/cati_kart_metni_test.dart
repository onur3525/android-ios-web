import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/hizmet_alanlari.dart';
import 'package:hizmetcep/screens/home_screen.dart';

/// ÇATI KARTLARINDA METİN TAŞMASI
///
/// ── ⚠ NİÇİN VAR ──
///
/// Üç sütunda kart en dar cihazda ~97 dp; yan dolgu düşünce metne
/// ~85 dp kalıyor ve 12.5 puntoda satır başına ancak ~13 karakter
/// sığıyor. Başlık ve açıklama ikişer satırla sınırlı olduğu için
/// uzun metinler üç nokta ile KESİLİYORDU:
///
///   "Beyaz Eşya & Elektronik S…"   "Hukuk, Finans & Kur…"
///   "Hukuk, muhasebe, sig…"
///
/// ⚠ Bu test ÖLÇÜYÜ değil METNİ denetler: punto, kart yüksekliği ve
/// satır sayısı sabit kalır; sığmayan metin kısaltılır.
const int _kSatirSiniri = 13;
const int _kSatirSayisi = 2;

/// Metni kart genişliğine göre satırlara böler.
///
/// ⚠ Açık `\n` varsa ona uyulur — kırma noktası sabitlenmiş demektir.
List<String> _satirlar(String metin) {
  if (metin.contains('\n')) {
    return metin.split('\n');
  }
  final satir = <String>[];
  var buf = '';
  for (final k in metin.split(' ')) {
    final aday = buf.isEmpty ? k : '$buf $k';
    if (aday.length <= _kSatirSiniri) {
      buf = aday;
    } else {
      if (buf.isNotEmpty) satir.add(buf);
      buf = k;
    }
  }
  if (buf.isNotEmpty) satir.add(buf);
  return satir;
}

void main() {
  group('ÇATI KARTI METİNLERİ', () {
    test('⚠ HİÇBİR BAŞLIK TAŞMAZ', () {
      for (final a in kHizmetAlanlari) {
        final s = _satirlar(HizmetAlanlariPaneli.kartEtiketi(a.ad));
        expect(s.length, lessThanOrEqualTo(_kSatirSayisi),
            reason: '${a.ad}: ${s.length} satır — kesilir');
        for (final l in s) {
          expect(l.length, lessThanOrEqualTo(_kSatirSiniri),
              reason: '${a.ad}: "$l" (${l.length}) satıra sığmaz');
        }
      }
    });

    test('⚠ HİÇBİR AÇIKLAMA TAŞMAZ', () {
      for (final a in kHizmetAlanlari) {
        final s = _satirlar(a.aciklama);
        expect(s.length, lessThanOrEqualTo(_kSatirSayisi),
            reason: '${a.ad}: açıklama ${s.length} satır — kesilir');
      }
    });

    test('⚠ SÖZLÜKTEKİ HER ANAHTAR GERÇEK BİR ÇATI ADIDIR', () {
      // Paket A'da adlar değişince eski 'Mühendislik & Danışmanlık'
      // kaydı ÖLÜ kalmıştı: hiç eşleşmiyor, kimse fark etmiyordu.
      final adlar = kHizmetAlanlari.map((a) => a.ad).toSet();
      for (final k in HizmetAlanlariPaneli.kKartEtiketi.keys) {
        expect(adlar.contains(k), isTrue, reason: 'ölü kısaltma kaydı: $k');
      }
    });

    test('kısaltma en fazla iki satırdır', () {
      for (final e in HizmetAlanlariPaneli.kKartEtiketi.entries) {
        expect(e.value.split('\n').length, lessThanOrEqualTo(_kSatirSayisi),
            reason: e.key);
      }
    });

    test('⚠ PUNTO VE SATIR SAYISI DEĞİŞMEDİ', () {
      // Çözüm metni kısaltmaktı; kart ölçüsüne DOKUNULMADI.
      expect(HizmetAlanlariPaneli.kBaslikSatiri, 2);
      expect(HizmetAlanlariPaneli.kAciklamaSatiri, 2);
      expect(HizmetAlanlariPaneli.kSutun, 3);
    });
  });
}
