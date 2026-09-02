// İLAN NUMARASI (ilanNo) — SÖZLEŞME
//
// ⚠ İKİ KİMLİK BİRBİRİNE KARIŞMAZ:
//   id     → teknik UUID; teklif/mesaj/ödeme/şikâyet ilişkileri
//   ilanNo → kullanıcıya gösterilen okunabilir referans
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/repositories/listing_repository.dart';
import 'package:hizmetcep/data/repositories/offer_repository.dart';

String _kod(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) =>
          !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

Listing _ilan(ListingRepository r, {String baslik = 'Boya işi'}) => r.create(
      ownerId: 'musteri-1',
      title: baslik,
      location: 'Karşıyaka',
      desc: 'Açıklama metni buraya',
    );

void main() {
  group('ÜRETİM VE BENZERSİZLİK', () {
    test('iki ilan FARKLI numara alır', () {
      final r = ListingRepository();
      final a = _ilan(r);
      final b = _ilan(r, baslik: 'Tesisat');
      expect(a.ilanNo, isNotEmpty);
      expect(b.ilanNo, isNotEmpty);
      expect(a.ilanNo, isNot(b.ilanNo));
    });

    test('numara DETERMİNİSTİK başlar — rastgelelik yok', () {
      // Testler kararsız numaralarla çalışmamalı.
      // ⚠ TEST HATASIYDI: `_ilan(r1)` iki kez çağrılınca İKİNCİ
      // ilan üretiliyor ve numara bir artıyordu. İlk ilanlar bir kez
      // üretilip karşılaştırılır.
      final ilk1 = _ilan(ListingRepository());
      final ilk2 = _ilan(ListingRepository());
      expect(ilk1.ilanNo, ilk2.ilanNo);
      expect(ilk1.ilanNo, '10458231');
    });

    test('çok sayıda ilanda TEKRAR YOK', () {
      final r = ListingRepository();
      final nolar = <String>{};
      for (var i = 0; i < 200; i++) {
        nolar.add(_ilan(r, baslik: 'İş $i').ilanNo);
      }
      expect(nolar.length, 200);
    });

    test('numara KISA ve okunabilir — UUID DEĞİL', () {
      final r = ListingRepository();
      final l = _ilan(r);
      expect(l.ilanNo.length, lessThanOrEqualTo(10));
      expect(l.ilanNo.contains('-'), isFalse, reason: 'UUID biçimi');
      expect(RegExp(r'^\d+$').hasMatch(l.ilanNo), isTrue);
      // Teknik kimlik ise UUID olarak KALIR.
      expect(l.id.length, greaterThan(20));
      expect(l.id.contains('-'), isTrue);
    });
  });

  group('DEĞİŞMEZLİK', () {
    test('düzenleme numarayı DEĞİŞTİRMEZ', () {
      final r = ListingRepository();
      final l = _ilan(r);
      final no = l.ilanNo;
      l.title = 'Yeni başlık';
      l.location = 'Bornova';
      l.desc = 'Değiştirilmiş açıklama';
      l.photoPaths.add('/tmp/a.jpg');
      expect(l.ilanNo, no);
      expect(r.byId(l.id)!.ilanNo, no);
    });

    test('kapatma ve geçmişe taşıma numarayı DEĞİŞTİRMEZ', () {
      final r = ListingRepository();
      final l = _ilan(r);
      final no = l.ilanNo;
      for (final d in ListingStatus.values) {
        r.setStatus(l.id, d);
        expect(r.byId(l.id)!.ilanNo, no, reason: '$d');
      }
    });

    test('teklif seçimi numarayı DEĞİŞTİRMEZ', () {
      final r = ListingRepository();
      final l = _ilan(r);
      final no = l.ilanNo;
      l.selectedOfferId = 'teklif-1';
      expect(l.ilanNo, no);
    });
  });

  group('NUMARA YENİDEN KULLANILMAZ', () {
    test('silinen ilanın numarası yeni ilana verilmez', () {
      final r = ListingRepository();
      final ilk = _ilan(r);
      final silinen = ilk.ilanNo;
      r.remove(ilk.id);
      // Depo boşaldı; yine de sayaç geri gitmez.
      expect(r.all, isEmpty);
      final yeni = _ilan(r, baslik: 'Başka iş');
      expect(yeni.ilanNo, isNot(silinen));
    });

    test('kapanmış ilanın numarası yeni ilana verilmez', () {
      // ⚠ NİHAİ DURUMLAR (§24): kapanış `userDeleted`, `adminRemoved`
      // veya `expired`tır. Numara sayacı durumdan bağımsız artar.
      final r = ListingRepository();
      final ilk = _ilan(r);
      r.setStatus(ilk.id, ListingStatus.userDeleted);
      final yeni = _ilan(r, baslik: 'Başka iş');
      expect(yeni.ilanNo, isNot(ilk.ilanNo));
    });

    test('AYNI numara iki ilanda bulunmaz', () {
      final r = ListingRepository();
      for (var i = 0; i < 50; i++) {
        _ilan(r, baslik: 'İş $i');
        if (i.isEven) {
          r.remove(r.all.first.id);
        }
      }
      final nolar = r.all.map((l) => l.ilanNo).toList();
      expect(nolar.toSet().length, nolar.length);
    });
  });

  group('ARAMA', () {
    test('tam numara doğru ilanı bulur', () {
      final r = ListingRepository();
      final a = _ilan(r);
      final b = _ilan(r, baslik: 'Tesisat');
      expect(r.byIlanNo(a.ilanNo)!.id, a.id);
      expect(r.byIlanNo(b.ilanNo)!.id, b.id);
      // Boşluklu yazım da çalışır.
      expect(r.byIlanNo(' ${a.ilanNo} ')!.id, a.id);
    });

    test('olmayan numara null döner', () {
      final r = ListingRepository();
      _ilan(r);
      expect(r.byIlanNo('99999999'), isNull);
      expect(r.byIlanNo(''), isNull);
      expect(r.byIlanNo('   '), isNull);
    });

    test('numara araması UUID ile karışmaz', () {
      final r = ListingRepository();
      final l = _ilan(r);
      // UUID yazılırsa numara araması bulmaz — ayrı alanlar.
      expect(r.byIlanNo(l.id), isNull);
    });
  });

  group('İLİŞKİLER UUID ÜZERİNDEN KALIR', () {
    test('teklif ilanı UUID ile bağlar', () {
      final r = ListingRepository();
      final offers = OfferRepository();
      final l = _ilan(r);
      final o = offers.create(
        listingId: l.id,
        providerId: 'usta-1',
        amount: 500,
        note: 'Beş kelimelik açıklama buraya',
      );
      expect(o.listingId, l.id);
      expect(o.listingId, isNot(l.ilanNo));
      expect(offers.forListing(l.id).length, 1);
      // Numarayla ilişki KURULMAZ.
      expect(offers.forListing(l.ilanNo), isEmpty);
    });

    test('kaynakta ilanNo foreign key olarak KULLANILMIYOR', () {
      // Teklif/mesaj/ödeme/şikâyet depoları numarayı görmemeli.
      for (final f in const [
        'lib/data/repositories/offer_repository.dart',
        'lib/data/repositories/chat_repository.dart',
        'lib/data/repositories/contact_repository.dart',
      ]) {
        expect(_kod(f).contains('ilanNo'), isFalse, reason: f);
      }
    });
  });

  group('GÖRÜNÜRLÜK', () {
    test('etiket biçimi TEK KAYNAKTAN gelir', () {
      final r = ListingRepository();
      final l = _ilan(r);
      expect(l.ilanNoEtiketi, 'İlan No: ${l.ilanNo}');
    });

    test('⚠ YALNIZ DETAY EKRANLARI ETİKETİ GÖSTERİR', () {
      // ── ÜRÜN KURALI (değişti) ──
      //
      // Numara ÖNİZLEME kartlarında GÖSTERİLMEZ: liste kartında yer
      // kaplıyor ve kullanıcı kartları BAŞLIĞA göre tarıyor. Numara
      // karta girince gerekli.
      for (final f in const [
        'lib/screens/listing_detail_screen.dart', // müşteri detayı
        'lib/screens/job_detail_screen.dart', // hizmet veren detayı
      ]) {
        expect(_kod(f).contains('IlanNoEtiketi('), isTrue, reason: f);
      }
      for (final f in const [
        'lib/screens/my_listings_screen.dart', // müşteri listesi
        'lib/screens/jobs_screen.dart', // hizmet veren listesi
      ]) {
        expect(_kod(f).contains('IlanNoEtiketi('), isFalse,
            reason: '$f: önizleme kartında numara gösteriliyor');
      }
    });

    test('⚠ SAĞ ÜST KÖŞE — KURAL BİLEŞENDE SABİT', () {
      // ⚠ Hizalama ve alt boşluk `IlanNoEtiketi` içinde tanımlıdır;
      // ekranlar kendi hizalamasını YAZMAZ. Böylece YENİ ilan detay
      // ekranları da bileşeni çağırmakla aynı kurala uyar.
      final w = _kod('lib/screens/widgets/ilan_no_etiketi.dart');
      expect(w.contains('Alignment.centerRight'), isTrue,
          reason: 'sağa yaslama bileşende değil');
      expect(w.contains('EdgeInsets.only(bottom: 4)'), isTrue,
          reason: 'başlıkla arasındaki boşluk bileşende değil');
      // Eski sola yaslama geri gelmemeli.
      expect(w.contains('Alignment.centerLeft'), isFalse);
    });

    test('⚠ NUMARA BAŞLIĞIN ÜSTÜNDE ÇİZİLİR', () {
      // Etiket, kategori/başlık satırlarından ÖNCE gelmeli.
      for (final f in const [
        'lib/screens/listing_detail_screen.dart',
        'lib/screens/job_detail_screen.dart',
      ]) {
        final k = _kod(f);
        final numara = k.indexOf('IlanNoEtiketi(l)');
        final baslik = k.indexOf('kategoriAdi(l.title) != null');
        expect(numara, greaterThan(0), reason: f);
        expect(numara, lessThan(baslik),
            reason: '$f: numara başlıktan SONRA çiziliyor');
      }
    });

    test('ekranlar UUID GÖSTERMEZ', () {
      // Kullanıcıya teknik kimlik çizilmez.
      for (final f in const [
        'lib/screens/my_listings_screen.dart',
        'lib/screens/jobs_screen.dart',
        'lib/screens/listing_detail_screen.dart',
        'lib/screens/job_detail_screen.dart',
      ]) {
        final k = _kod(f);
        expect(k.contains('Text(l.id'), isFalse, reason: f);
        expect(k.contains('Text(listing.id'), isFalse, reason: f);
      }
    });

    test('numara BOŞSA hiçbir şey çizilmez', () {
      final w = _kod('lib/screens/widgets/ilan_no_etiketi.dart');
      expect(w.contains('SizedBox.shrink()'), isTrue);
      expect(w.contains('listing.ilanNo.trim().isEmpty'), isTrue);
    });

    test('etiket İKİNCİL ölçüde — başlığın önüne geçmez', () {
      final w = _kod('lib/screens/widgets/ilan_no_etiketi.dart');
      expect(w.contains('size: RF.s12'), isTrue);
      expect(w.contains('weight: RF.w400'), isTrue);
      expect(w.contains('color: RC.textSoft'), isTrue);
    });
  });

  group('FORM İLAN NUMARASI SORMAZ', () {
    test('ilan oluşturma ve düzenleme ekranında alan YOK', () {
      final c = _kod('lib/screens/create_listing_screen.dart');
      expect(c.contains('ilanNo'), isFalse,
          reason: 'kullanıcıdan numara isteniyor');
    });

    test('numara DEPODA üretilir', () {
      final r = _kod('lib/data/repositories/listing_repository.dart');
      expect(r.contains('ilanNo: _ilanNoUret()'), isTrue);
      expect(r.contains('String _ilanNoUret()'), isTrue);
    });

    test('API modunda numara SUNUCUDAN gelir, uydurulmaz', () {
      final m = _kod('lib/data/remote/mappers.dart');
      expect(m.contains("j['ilanNo']"), isTrue);
      // İstemci tarafı üretim yok.
      expect(m.contains('_ilanNoUret'), isFalse);
    });
  });
}
