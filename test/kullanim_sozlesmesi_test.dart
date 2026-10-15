// KULLANIM SÖZLEŞMESİ (16 Eki, kullanıcı isteği — belge Bölüm B)
//   · Kayıtta ayrı "18 yaş" kutusu YOK; yaş koşulu sözleşmenin 4. maddesinde.
//   · Ayrı "Kullanım Sözleşmesi'ni okudum ve kabul ediyorum" kabulü korunur;
//     kabul edilmeden kayıt tamamlanmaz (ekran + port + sunucu).
//   · İki kayıt ekranı aynı bileşeni kullanır; Gizlilik Politikası kabulün
//     yerine konmaz, bağlantısı ayrı durur.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String p) => File(p).readAsStringSync();

void main() {
  final o = _oku('lib/ui/kullanim_sozlesmesi_onayi.dart');

  test('kabul metni ve sözleşme bağlantısı', () {
    expect(o.contains("static const String kBaslik = 'Kullanım Sözleşmesi';"), isTrue);
    expect(o.contains("\"'ni okudum ve kabul ediyorum.\""), isTrue);
    expect(o.contains("arguments: {'slug': 'terms', 'title': kBaslik}"), isTrue);
    // Gizlilik ayrı bağlantı; kabul cümlesinde değil.
    expect(o.contains('gizlilik politikasını'), isFalse);
    expect(o.contains("'slug': 'privacy'"), isTrue);
  });

  test('iki kayıt ekranı tek bileşeni kullanır', () {
    for (final f in const [
      'lib/screens/register_screen.dart',
      'lib/screens/widgets/ilan_kayit_adimi.dart',
    ]) {
      final s = _oku(f);
      expect(s.contains('KullanimSozlesmesiOnayi('), isTrue, reason: f);
      expect(s.contains("' okudum, kabul ediyorum.'"), isFalse, reason: f);
    }
  });

  test('ayrı 18 yaş kutusu ve ona bağlı engel kaldırıldı', () {
    final r = _oku('lib/screens/register_screen.dart');
    expect(r.contains('18 yaşını doldurduğumu beyan ederim.'), isFalse);
    expect(r.contains('bool _yas'), isFalse);
    expect(r.contains('bool get _formTamam => _alanlarTamam && _agree;'), isTrue);
    for (final f in const [
      'lib/data/ports/api_ports.dart',
      'lib/data/ports/repository_ports.dart',
      'lib/data/remote/api/auth_api.dart',
      'lib/data/controllers/auth_controller.dart',
    ]) {
      expect(_oku(f).contains('ageConfirmed'), isFalse, reason: f);
    }
  });

  test('sözleşme onayı olmadan kayıt tamamlanmaz', () {
    expect(_oku('lib/data/ports/api_ports.dart').contains('if (!termsAccepted) {'), isTrue);
    expect(_oku('lib/data/repositories/auth_repository.dart').contains('if (!termsAccepted) {'), isTrue);
    expect(_oku('backend/src/routes/kullanici.js').contains("ctx.body.termsAccepted !== true"), isTrue);
  });
}
