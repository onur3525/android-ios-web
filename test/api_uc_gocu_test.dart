import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PAKET 3 — UÇ ADLARI, IDEMPOTENCY, HATA KODLARI, PAGINATION
///
/// ⚠ Bu dosya UÇ SÖZLEŞMESİNİ kilitler. Uçlar sessizce eski adlarına
/// dönerse ya da idempotency başlığı düşerse burada yakalanır.
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

/// Flutter'ın GERÇEKTEN çağırdığı uçlar (normalize edilmiş).
///
/// ⚠ SADECE STRING ARAMASI YAPILMAZ: `/users/$id`, `/users/${id}` ve
/// `/users/{id}` AYNI uçtur; `/reviews/provider/{id}` ile
/// `/providers/{id}/reviews` ise FARKLI uçlardır.
Set<String> _flutterUclari() {
  final klasor = Directory('lib/data/remote/api');
  final desen = RegExp(r"c\.(get|getList|getOrNull|post|put|patch|delete)\('([^']+)'");
  final sonuc = <String>{};
  for (final f in klasor.listSync().whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    for (final m in desen.allMatches(_kodu(f.path))) {
      final yon = switch (m.group(1)) {
        'getList' || 'getOrNull' => 'GET',
        final v => v!.toUpperCase(),
      };
      sonuc.add('$yon ${_normalize(m.group(2)!)}');
    }
  }
  return sonuc;
}

String _normalize(String yol) => yol
    .replaceAll(RegExp(r'\$\{\w+\}'), '{}')
    .replaceAll(RegExp(r'\$\w+'), '{}')
    .replaceAll(RegExp(r'\{[^}]*\}'), '{}');

/// OpenAPI'deki yollar — ham YAML'dan okunur (paket bağımlılığı yok).
Set<String> _sozlesmeUclari() {
  final satirlar = File('docs/openapi.yaml').readAsLinesSync();
  final sonuc = <String>{};
  String? yol;
  for (final l in satirlar) {
    final y = RegExp(r"^  (/[^:]*):\s*\$").firstMatch(l);
    if (y != null) {
      yol = _normalize(y.group(1)!);
      continue;
    }
    final m = RegExp(r'^    (get|post|put|patch|delete):\s*\$').firstMatch(l);
    if (m != null && yol != null) {
      sonuc.add('${m.group(1)!.toUpperCase()} $yol');
    }
  }
  return sonuc;
}

void main() {
  group('0 — SÖZLEŞME KAPSAMI', () {
    test('⚠ FLUTTER\'IN ÇAĞIRDIĞI HER UÇ SÖZLEŞMEDE TANIMLI', () {
      // Sözleşmede tanımsız bir uç, backend ekibinin görmediği bir
      // istektir: sunucu onu hiç yazmayabilir.
      final eksik = _flutterUclari().difference(_sozlesmeUclari());
      expect(eksik, isEmpty, reason: 'OpenAPI\'de tanımsız uç: $eksik');
    });

    test('⚠ ESKİ UÇLAR SÖZLEŞMEDE DE YOK', () {
      final s = _sozlesmeUclari();
      for (final eski in const [
        'POST /contact/open',
        'POST /offers/{}/select',
        'POST /reviews',
        'GET /reviews/me',
        'GET /reviews/provider/{}',
        'POST /offers/{}/withdraw',
        'POST /listings/{}/start',
        'POST /listings/{}/complete',
      ]) {
        expect(s.contains(eski), isFalse, reason: 'sözleşmede kalmış: $eski');
      }
    });

    test('DUPLICATE UÇ YOK — aynı iş için tek yol', () {
      final s = _sozlesmeUclari();
      // Yorum listesi tek kanonik uçtan gelir.
      final yorumListeleri =
          s.where((u) => u.contains('reviews') && u.startsWith('GET')).toList();
      expect(yorumListeleri, ['GET /providers/{}/reviews']);
    });
  });

  group('1 — NİHAİ UÇ ADLARI', () {
    test('iletişim açma: POST /offers/{offerId}/communication', () {
      final k = _kodu('lib/data/remote/api/contact_api.dart');
      expect(k.contains("/offers/\$offerId/communication"), isTrue);
      expect(k.contains("'/contact/open'"), isFalse,
          reason: 'eski uç geri gelmiş');
    });

    test('teklif seçme: PUT /listings/{listingId}/selected-offer', () {
      final k = _kodu('lib/data/remote/api/offer_api.dart');
      expect(k.contains("c.put('/listings/\$listingId/selected-offer'"), isTrue);
      // ⚠ Eski uç `POST /offers/{offerId}/select` idi. "select"
      // kelimesi yeni yolda da geçtiği için TAM YOL aranır.
      expect(k.contains("/select'"), isFalse, reason: 'eski uç geri gelmiş');
    });

    test('yorum: POST /listings/{listingId}/review', () {
      final k = _kodu('lib/data/remote/api/review_api.dart');
      expect(k.contains("/listings/\$listingId/review"), isTrue);
      expect(k.contains("c.post('/reviews'"), isFalse,
          reason: 'eski uç geri gelmiş');
    });

    test('⚠ PAKET 1 ve 2\'de kaldırılan uçlar GERİ GELMEDİ', () {
      for (final yol in const [
        'lib/data/remote/api/offer_api.dart',
        'lib/data/remote/api/listing_api.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains('/withdraw'), isFalse, reason: '$yol');
      }
      final l = _kodu('lib/data/remote/api/listing_api.dart');
      expect(l.contains("/start'"), isFalse);
      expect(l.contains("/complete'"), isFalse);
    });
  });

  group('2 — IDEMPOTENCY-KEY', () {
    test('durum değiştiren uçlar anahtar alır', () {
      // ⚠ Anahtar REQUEST HEADER olarak gider (§30); gövdeye koymak
      // yetmez. `ApiClient.post/put` başlığa yazar.
      final contact = _kodu('lib/data/remote/api/contact_api.dart');
      final offer = _kodu('lib/data/remote/api/offer_api.dart');
      final review = _kodu('lib/data/remote/api/review_api.dart');
      for (final k in [contact, offer, review]) {
        expect(k.contains('idempotencyKey'), isTrue);
      }
    });

    test('PUT da anahtar taşıyabilir', () {
      // Teklif seçme PUT'tur ve sözleşmede anahtar ZORUNLUDUR.
      final k = _kodu('lib/data/remote/api_client.dart');
      final i = k.indexOf('Future<Map<String, dynamic>> put(');
      expect(i, greaterThan(0));
      expect(k.substring(i, i + 260).contains('idempotencyKey'), isTrue,
          reason: 'PUT anahtar almıyor — seçim tekrarında ikinci işlem olur');
    });

    test('yorum gönderiminde anahtar üretiliyor', () {
      final k = _kodu('lib/data/remote/repositories/api_chat_repositories.dart');
      expect(k.contains('idempotencyKey: ApiClient.newIdempotencyKey()'), isTrue,
          reason: 'çift tıklamada ikinci yorum oluşur');
    });
  });

  group('3 — HATA KODLARI', () {
    final k = _kodu('lib/data/remote/api_error_mapper.dart');

    test('nihai kodlar ele alınıyor', () {
      for (final kod in const [
        'FREE_RIGHTS_EXHAUSTED',
        'OFFER_ALREADY_EXISTS',
        'COMMUNICATION_ALREADY_OPEN',
        'LISTING_EXPIRED',
        'LISTING_REMOVED',
        'BUSINESS_RULE_VIOLATION',
        'RATE_LIMITED',
      ]) {
        expect(k.contains("'$kod'"), isTrue, reason: 'ele alınmayan kod: $kod');
      }
    });

    test('⚠ "iletişim zaten açık" HATA SAYILMAZ', () {
      // İdempotent sonuç: istenen durum zaten sağlanmıştır.
      expect(k.contains('IletisimZatenAcikError'), isTrue);
      final c = _kodu('lib/data/controllers/contact_controller.dart');
      expect(c.contains('is IletisimZatenAcikError'), isTrue,
          reason: 'controller bunu başarı gibi ele almıyor');
      expect(c.contains('return null;'), isTrue);
    });

    test('422 ve 409 iş kuralı ihlalidir, form hatası DEĞİL', () {
      expect(k.contains('status == 422 || status == 409'), isTrue);
    });
  });

  group('4 — CURSOR PAGINATION', () {
    test('sayfa numarası kullanılmıyor', () {
      final k = _kodu('lib/data/remote/api/review_api.dart');
      expect(k.contains("'cursor'"), isTrue);
      expect(k.contains("'skip'"), isFalse, reason: 'offset pagination kalmış');
    });

    test('⚠ /reviews/me AYRI UÇ AÇILMADI — kanonik uç kullanılıyor', () {
      // Ekranın istediği veri (hizmet verenin aldığı yorumlar,
      // ortalama, sayı, dağılım) `GET /providers/{providerId}/reviews`
      // ucunun döndürdüğü şeydir. "Kendi yorumlarım" ayrı bir VERİ
      // değil, aynı verinin `providerId = kendi kimliğim` hâlidir.
      // Sözleşme aynı anlam için alternatif uç açılmasını yasaklıyor.
      final k = _kodu('lib/data/remote/api/review_api.dart');
      expect(k.contains('/reviews/me'), isFalse,
          reason: 'sözleşmede olmayan uç geri gelmiş');
      expect(k.contains('/reviews/provider/'), isFalse,
          reason: 'eski yol geri gelmiş');
      expect("/providers/\$providerId/reviews".allMatches(k).length, 2,
          reason: 'mine() ve ofProvider() aynı kanonik ucu kullanmalı');
    });

    test('nextCursor null ise daha fazla istenmez', () {
      final k = _kodu('lib/screens/my_reviews_screen.dart');
      expect(k.contains("j['nextCursor']"), isTrue);
      expect(k.contains('_hasMore = _cursor != null'), isTrue);
    });
  });

  group('5 — ⚠ TAMAMLANAN İŞ REGRESYONU (§21, §22)', () {
    // Senaryo: ilan ACTIVE · teklif SELECTED · selectedOfferId dolu.
    // Bu durumda ESKİ AKSİYONLARIN HİÇBİRİ görünmemeli.
    test('seçilmiş teklifte İletişimi Aç ÇIKMAZ', () {
      final k = _kodu('lib/screens/offer_detail_screen.dart');
      // `open` bayrağı seçilmiş teklifte daima true olur.
      expect(k.contains('offer.status == OfferStatus.selected;'), isTrue);
      expect(k.contains('l.selectedOfferId == offer.id ||'), isTrue);
    });

    test('seçilmiş teklifte Teklifi Seç ÇIKMAZ', () {
      final k = _kodu('lib/screens/offer_detail_screen.dart');
      expect(k.contains('!l.isTamamlanmisIs &&'), isTrue,
          reason: 'ACTIVE + seçim varken düğme yine çizilir');
    });

    test('tamamlanmış ilana YENİ TEKLİF verilemez', () {
      final k = _kodu('lib/screens/job_detail_screen.dart');
      expect('!l.isTamamlanmisIs'.allMatches(k).length, greaterThanOrEqualTo(2),
          reason: 'teklif formu tamamlanmışlığı denetlemiyor');
    });

    test('eski aksiyonlar hiçbir ekranda YOK', () {
      for (final yol in const [
        'lib/screens/offer_detail_screen.dart',
        'lib/screens/job_detail_screen.dart',
        'lib/screens/listing_detail_screen.dart',
        'lib/screens/my_listings_screen.dart',
        'lib/screens/jobs_screen.dart',
      ]) {
        final k = _kodu(yol);
        for (final d in const [
          "'İşi Başlat'", "'İşi Tamamla'", "'Teklifi Geri Çek'"
        ]) {
          expect(k.contains(d), isFalse, reason: '$yol: $d');
        }
      }
    });
  });
}
