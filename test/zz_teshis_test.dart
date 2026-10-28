// GEÇİCİ TEŞHİS — CI'da hangi adımın takıldığını bulmak için; sonra silinecek.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/platform/kalici_gorsel_io.dart';
import 'package:http/http.dart' as http;

Future<T> _adim<T>(List<String> g, String ad, Future<T> Function() f) async {
  g.add('$ad…');
  final v = await f().timeout(const Duration(seconds: 3),
      onTimeout: () => throw StateError('TAKILDI: $ad | ${g.join(' > ')}'));
  g.add('$ad ✓');
  return v;
}

void main() {
  test('teşhis adımları', () async {
    final g = <String>[];
    final d = await _adim(g, 'createTemp', () => Directory.systemTemp.createTemp('hc_teshis'));
    await _adim(g, 'create', () => d.create(recursive: true));
    final f = File('${d.path}/a');
    await _adim(g, 'stat', () => f.stat());
    await _adim(g, 'write', () => File('${f.path}.t').writeAsBytes([1, 2, 3], flush: true));
    await _adim(g, 'rename', () => File('${f.path}.t').rename(f.path));
    await _adim(g, 'read', () => f.readAsBytes());
    await _adim(g, 'delayed', () => Future<void>.delayed(const Duration(milliseconds: 10)));
    await _adim(g, 'timeoutluFuture', () => Future.value(1).timeout(const Duration(seconds: 30)));
    GorselOnbellegi.testSifirla();
    GorselOnbellegi.testKlasoru = d;
    GorselOnbellegi.testIndir = (u) async => http.Response.bytes(Uint8List.fromList([9, 9]), 200);
    await _adim(g, 'getir', () => GorselOnbellegi.getir('https://x.ornek/a.jpg'));
    await _adim(g, 'getir2', () => GorselOnbellegi.getir('https://x.ornek/a.jpg'));
    fail('HEPSİ GEÇTİ: ${g.join(' > ')}');
  });
}
