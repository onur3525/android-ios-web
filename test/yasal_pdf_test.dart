// YASAL BELGE PDF'İ (22 Eki): yalnız sunucunun verdiği kalıptaki göreli
// yol API kökenine çözülür; başka adres açılmaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/yasal_pdf_ac.dart';
import 'package:hizmetcep/data/legal_cache.dart';

void main() {
  test('kalıp dışı adres açılmaz', () {
    expect(yasalPdfAdresi(null), isNull);
    expect(yasalPdfAdresi('https://kotu.ornek/x.pdf'), isNull);
    expect(yasalPdfAdresi('/api/v1/legal/kvkk/pdf/../gizli'), isNull);
    expect(yasalPdfAdresi('/api/v1/legal/KVKK/pdf/3'), isNull);
  });

  test('geçerli göreli yol API kökenine çözülür', () {
    final u = yasalPdfAdresi('/api/v1/legal/kvkk/pdf/3');
    expect(u, isNotNull);
    expect(u!.path, '/api/v1/legal/kvkk/pdf/3');
  });

  test('LegalDoc özet ve PDF adresini taşır; yoksa null', () {
    final d = LegalDoc.fromJson({'slug': 'kvkk', 'title': 'KVKK', 'version': '3', 'effectiveDate': '2026-10-22', 'body': 'özet', 'summary': 'özet', 'pdfUrl': '/api/v1/legal/kvkk/pdf/3'});
    expect(d.summary, 'özet');
    expect(d.pdfUrl, '/api/v1/legal/kvkk/pdf/3');
    final e = LegalDoc.fromJson({'slug': 'terms', 'body': 'metin'});
    expect(e.summary, isNull);
    expect(e.pdfUrl, isNull);
  });
}
