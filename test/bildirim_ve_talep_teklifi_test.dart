// BİLDİRİMDEN AÇILAN SAYFA BİLDİRİMİN ANLATTIĞINI GÖSTERİR (11 Eki)
//
// KULLANICI BULGUSU: yeni açılmış gibi görünen hizmet alan hesabında
// "Yeni teklif aldınız — 7 dk" bildirimi vardı; dokununca açılan talep
// sayfasında fiyat yoktu, yalnız "Teklifin süresi doldu" yazıyordu ve
// fotoğraf yerinde ham hata metni ("HTTP request failed…") vardı.
//
// ÖLÇÜLEN KÖK NEDENLER:
//   1. Bildirim zamanı hiç saklanmıyor/okunmuyordu — her bildirim
//      yüklendiği an gelmiş gibi görünüyordu (teklif aslında 30+ saat
//      önceydi).
//   2. Süresi dolan teklifte sayfa fiyatı ve notu GİZLİYORDU; liste de
//      bu talebi göstermiyordu, başlık boş kalıyordu.
//   3. Talep, cihazdaki dosya yolunu (web'de geçici `blob:` adresi)
//      taşıyordu; açılamayan görselde yedek tanımlı değildi.
//
// KULLANICI KARARLARI: süresi dolan teklifte telefon ve mesajlaşma
// KİLİTLENİR; hizmet verenin profil yorumlarının başlığı netleşir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/notification.dart';
import 'package:hizmetcep/data/models/teklif_talebi.dart';
import 'package:hizmetcep/data/remote/mappers.dart';
import 'package:hizmetcep/data/repositories/sekme_anligi.dart';
import 'package:hizmetcep/domain/teklif_talebi_asamasi.dart';

String _kodu(String yol) => File(yol).readAsStringSync();

TeklifTalebi _t(TeklifTalebiDurumu d, {DateTime? teklifTarihi}) => TeklifTalebi(
      talepNo: '10458231',
      id: 't-${d.name}',
      hizmetAlanId: 'a1',
      saglayiciId: 'v1',
      saglayiciAdi: 'Usta',
      kategori: 'Doğalgaz',
      hizmet: 'Doğalgaz Tesisatı',
      aciklama: 'iş var',
      iletisimTercihi: IletisimTercihi.telefonGoster,
      createdAt: DateTime(2026, 10, 2),
      durum: d,
      teklifTarihi: teklifTarihi,
    );

void main() {
  group('1 — BİLDİRİM ZAMANI GERÇEK', () {
    test('sunucunun createdAt alanı okunur', () {
      final n = Mappers.notification({
        'id': 'n1', 'userId': 'u1', 'type': 'NEW_OFFER', 'title': 'Yeni teklif',
        'body': 'x', 'refId': 'l1', 'readAt': null,
        'createdAt': '2026-10-02T09:00:00.000Z',
      });
      expect(n.createdAt.toUtc(), DateTime.utc(2026, 10, 2, 9));
    });

    test('createdAt yoksa (eski sunucu) "şimdi" kullanılır', () {
      final once = DateTime.now();
      final n = Mappers.notification({
        'id': 'n1', 'userId': 'u1', 'type': 'NEW_OFFER', 'title': 't', 'body': 'b',
      });
      expect(n.createdAt.isBefore(once), isFalse);
    });

    test('web deneme deposu zamanı saklar ve geri okur', () {
      final zaman = DateTime(2026, 10, 2, 12, 30);
      final n = AppNotification(
          id: 'n1', userId: 'u1', type: NotifType.teklifVerildi,
          title: 't', body: 'b', refId: 'r1', createdAt: zaman);
      final geri = bildirimCoz(bildirimJson(n))!;
      expect(geri.createdAt, zaman);
    });
  });

  group('2 — SONLANAN TALEP LİSTEDE KALIR, BAŞLIK BOŞ KALMAZ', () {
    final hepsi = [for (final d in TeklifTalebiDurumu.values) _t(d)];

    test('süren üstte, sonlanan altta; kazanılan YOK', () {
      final d = teklifIstediklerimTalepleri(hepsi).map((x) => x.durum).toList();
      expect(d, [
        TeklifTalebiDurumu.beklemede,
        TeklifTalebiDurumu.teklifGeldi,
        TeklifTalebiDurumu.reddedildi,
        TeklifTalebiDurumu.suresiDoldu,
      ]);
    });

    test('Bul başlığı listeyle AYNI kuralı kullanır', () {
      final k = _kodu('lib/screens/find_provider_screen.dart');
      expect(k.contains('return teklifIstediklerimTalepleri('), isTrue,
          reason: 'başlık başka süzgeçle karar veriyor — boş başlık geri gelir');
    });
  });

  group('3 — SÜRESİ DOLAN TEKLİF GÖRÜNÜR, İLETİŞİM KİLİTLİ', () {
    test('iletişim: teklif gelince açık, süre dolunca kapalı', () {
      final simdi = DateTime.now();
      expect(talepIletisimAcikMi(_t(TeklifTalebiDurumu.beklemede)), isFalse);
      expect(
          talepIletisimAcikMi(
              _t(TeklifTalebiDurumu.teklifGeldi, teklifTarihi: simdi)),
          isTrue);
      expect(
          talepIletisimAcikMi(
              _t(TeklifTalebiDurumu.suresiDoldu, teklifTarihi: simdi)),
          isFalse);
      expect(
          talepIletisimAcikMi(
              _t(TeklifTalebiDurumu.tamamlandi, teklifTarihi: simdi)),
          isTrue);
    });

    final detay = _kodu('lib/screens/teklif_talebi_detay_screen.dart');

    test('sonlanan teklifte fiyat ve not salt okunur çizilir', () {
      expect(detay.contains('return _SonlananTeklif('), isTrue);
      expect(RegExp(r'return _SonlananTeklif\(').allMatches(detay).length, 2,
          reason: 'reddedilen ve süresi dolan teklif aynı görünümü kullanmalı');
      expect(detay.contains('_GelenTeklif(talep: talep)'), isTrue);
    });

    test('iletişim kutuları ortak kuralı okur', () {
      expect(detay.contains('final iletisim = talepIletisimAcikMi(talep);'),
          isTrue);
      expect(detay.contains('kilitli: !iletisim'), isTrue);
      final sohbet = _kodu('lib/screens/teklif_talebi_sohbet_screen.dart');
      expect(sohbet.contains('talepIletisimAcikMi(talep)'), isTrue,
          reason: 'sohbet ekranı süresi dolan teklifte mesaj yazdırıyor');
      final depo = _kodu('lib/data/repositories/teklif_talebi_repository.dart');
      expect(depo.contains('t.durum == TeklifTalebiDurumu.suresiDoldu'), isTrue);
    });

    test('profil yorumlarının başlığı netleşti', () {
      expect(detay.contains("Text('Hizmet Verenin Yorumları',"), isTrue);
      expect(detay.contains("Text('Yorumlar',"), isFalse);
    });
  });

  group('4 — BİLDİRİM SAYFAYI TEKLİF BÖLÜMÜNE AÇAR', () {
    test('teklif/karar bildirimleri teklif bölümüne odaklanır', () {
      final k = _kodu('lib/screens/notifications_screen.dart');
      expect(
          k.contains('teklifeOdaklan: t != NotifType.teklifTalebiGeldi'), isTrue);
      final d = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      expect(d.contains('Scrollable.ensureVisible('), isTrue);
      expect(d.contains('key: _teklifBolumu'), isTrue);
    });
  });

  group('5 — FOTOĞRAF', () {
    test('talep yüklenmiş fotoğrafın referansını taşır, cihaz yolunu değil', () {
      final k = _kodu('lib/screens/teklif_iste_screen.dart');
      expect(k.contains('fotograflar: _photos.map((p) => p.storageRef!)'), isTrue);
      expect(k.contains('_photos.map((p) => p.localPath)'), isFalse);
      expect(k.contains('uploadEnabled: true'), isTrue);
    });

    test('açılamayan görselde ham hata yerine yer tutucu', () {
      for (final yol in [
        'lib/core/platform/yerel_gorsel_io.dart',
        'lib/core/platform/yerel_gorsel_web.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains('(hataYedegi ?? varsayilanGorselYedegi)(context)'),
            isTrue, reason: yol);
        expect(k.contains('errorBuilder: hataYedegi == null'), isFalse,
            reason: '$yol: yedeksiz görsel ham hata çizer');
      }
    });
  });

  group('6 — MASAÜSTÜ GÖRÜNÜM VE SAYFA YENİLEME (14 Eki)', () {
    // KULLANICI BULGUSU: telefonun tarayıcısında "Masaüstü sitesi"
    // seçilince (1) talep fotoğrafı "HTTP request failed … blob:" hatası
    // verdi — sayfa yeniden yüklendiği için `blob:` adresi ölmüştü;
    // (2) dar yan sütunda "Mesajlaşma" kelimesi ortadan bölündü.

    test('deneme modunda seçilen fotoğraf kalıcı biçime çevrilir', () {
      final secici = _kodu('lib/screens/widgets/photo_picker.dart');
      expect(
          secici.contains(
              'yerel = await kaliciYerelYol(p.localPath, tur: p.contentType);'),
          isTrue);
      expect(secici.contains('p.storageRef = yerel;'), isTrue);
      expect(secici.contains('p.storageRef = p.localPath;'), isFalse,
          reason: 'web\'de sayfayla ölen blob adresi kayda yazılıyor');
      final sohbet = _kodu('lib/screens/widgets/sohbet_fotograf_akisi.dart');
      expect(sohbet.contains('kaliciYerelYol(yol)'), isTrue);
    });

    test('web köprüsü data: adresini çizer; mobil yol aynen kalır', () {
      final web = _kodu('lib/core/platform/yerel_gorsel_web.dart');
      expect(web.contains("yol.startsWith('data:')"), isTrue);
      expect(web.contains('Image.memory('), isTrue);
      expect(web.contains("base64Encode(b)"), isTrue);
      final io = _kodu('lib/core/platform/yerel_gorsel_io.dart');
      expect(
          io.contains(
              'Future<String> kaliciYerelYol(String yol, {String? tur}) async => yol;'),
          isTrue);
    });

    test('dar alanda iletişim kutuları alt alta, etiket bölünmez', () {
      final d = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      expect(RegExp(r'_IletisimCifti\(').allMatches(d).length, 3,
          reason: 'iki çağrı + sınıf kurucusu');
      expect(d.contains('kutu.maxWidth >= _yanYanaEnAz'), isTrue);
      final k = _kodu('lib/screens/widgets/detay_karti_parcalari.dart');
      expect(k.contains('fit: BoxFit.scaleDown'), isTrue);
      expect(k.contains('softWrap: false'), isTrue);
    });
  });

  group('7 — DETAY EKRANLARI MASAÜSTÜNDE DE TEK SÜTUN (14 Eki)', () {
    test('düzen yan yana çizmez; masaüstünde ortalı tek sütun', () {
      // ⚠ KULLANICI KARARI: "Masaüstü görünümde yan yana olmamalı —
      // sayfa tek sütun olsun." Kural ortak widget'ta; iki detay ekranı
      // (ilan ve Bul akışı) birlikte uyar.
      final k = _kodu('lib/ui/masaustu_detay.dart');
      expect(k.contains('Row('), isFalse, reason: 'iki kolon geri gelmiş');
      expect(k.contains('maxWidth: IcerikGenisligi.liste'), isTrue);
      expect(k.contains('children: [ana, SizedBox(height: aralik), yan]'),
          isTrue);
      for (final yol in [
        'lib/screens/job_detail_screen.dart',
        'lib/screens/teklif_talebi_detay_screen.dart',
      ]) {
        expect(_kodu(yol).contains('MasaustuDetay('), isTrue, reason: yol);
      }
    });
  });
}
