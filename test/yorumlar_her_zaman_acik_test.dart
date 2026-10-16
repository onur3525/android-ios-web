// HİZMET VERENİN YORUMLARI HER ZAMAN AÇIK (16 Eki, kullanıcı kuralı):
// hizmet alan, iletişimi açmamış olsa da teklif verenin yorumlarını ve
// puanını görür. Yorumlar okunduğu an sunucudan yüklenir (tek kaynak).
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/review_controller.dart';
import 'package:hizmetcep/data/ports/repository_ports.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/data/models/review.dart';

class _SahteYorumDeposu extends Fake implements ReviewPort {
  final istekler = <String>[];
  final List<void Function()> _dinleyiciler = [];
  @override
  List<Review> byProvider(String providerId) => const [];
  @override
  double? averageOf(String providerId) => null;
  @override
  Future<DomainError?> loadForProvider(String providerId) async {
    istekler.add(providerId);
    return null;
  }
  @override
  void addListener(void Function() l) => _dinleyiciler.add(l);
  @override
  void removeListener(void Function() l) => _dinleyiciler.remove(l);
}

void main() {
  test('okunan hizmet verenin yorumları yüklenir; kısa sürede tekrar istenmez', () async {
    final d = _SahteYorumDeposu();
    final c = ReviewController(d);
    c.byProvider('p1');
    c.averageOf('p1');
    c.byProvider('p2');
    expect(d.istekler, isEmpty, reason: 'çizim sırasında değil, sonra yüklenir');
    await Future<void>.delayed(Duration.zero);
    expect(d.istekler, ['p1', 'p2']);
    c.byProvider('p1');
    await Future<void>.delayed(Duration.zero);
    expect(d.istekler, ['p1', 'p2']);
  });
}
