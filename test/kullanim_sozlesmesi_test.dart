// KAYIT — ZORUNLU SÖZLEŞMELER (16 Eki, kullanıcı kararı + örnek görsel)
//   · İki ayrı zorunlu onay, metinler görseldeki gibi: Kullanım Sözleşmesi
//     ve Aydınlatma Metni (kırmızı yıldız + gri açıklama).
//   · İkisi de işaretlenmeden kayıt tamamlanmaz (iki kayıt ekranı).
//   · Ayrı 18 yaş kutusu YOK; yaş koşulu sözleşmenin 4. maddesinde.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String p) => File(p).readAsStringSync();

void main() {
  final o = _oku('lib/ui/kullanim_sozlesmesi_onayi.dart');

  test('metinler görseldeki gibi', () {
    expect(o.contains("static const String kBaslik = 'Kullanım Sözleşmesi';"), isTrue);
    expect(o.contains("static const String kAydinlatma = 'Aydınlatma Metni';"), isTrue);
    expect(o.contains("(text: '’ni okudum ve kabul ediyorum.', onTap: null)"), isTrue);
    expect(o.contains("'Kişisel verilerimin işlenmesi ve aktarılmasına ilişkin '"), isTrue);
    expect(o.contains("'HizmetCep’i kullanırken geçerli olan kuralları, hak ve '\n                'sorumluluklarımı içerir.'"), isTrue);
    // ⚠ 22 Eki (KVKK): aydınlatma bilgilendirmedir — "kabul / izin" denmez.
    expect(o.contains("(text: '’ni okudum, bilgilendirildim.', onTap: null)"), isTrue);
    expect(o.contains('izin veriyorum'), isFalse, reason: 'aydınlatma açık rızayla karıştırılmış');
    expect(o.contains("'Hangi kişisel verilerimin, hangi amaçla ve hangi '\n                'hukuki sebeple işlendiğini ve haklarımı anlatır.'"), isTrue);
    // Web'de çerez bilgilendirmesi (onay istemez).
    expect(o.contains("arguments: {'slug': 'cookies', 'title': kCerez}"), isTrue);
    expect(o.contains("text: '  *'"), isTrue);
    expect(o.contains("arguments: {'slug': 'terms', 'title': kBaslik}"), isTrue);
    expect(o.contains("arguments: {'slug': 'kvkk', 'title': kAydinlatma}"), isTrue);
  });

  test('iki kayıt ekranı tek bileşeni kullanır; iki onay da zorunlu', () {
    final r = _oku('lib/screens/register_screen.dart');
    expect(r.contains('KullanimSozlesmesiOnayi('), isTrue);
    expect(r.contains('bool get _formTamam => _alanlarTamam && _agree && _aydinlatma;'), isTrue);
    expect(r.contains('termsAccepted: _agree && _aydinlatma);'), isTrue);
    final i = _oku('lib/screens/widgets/ilan_kayit_adimi.dart');
    expect(i.contains('KullanimSozlesmesiOnayi('), isTrue);
    expect(i.contains('bool get tamam => alanlarGecerli && sozlesme && aydinlatma;'), isTrue);
    expect(_oku('lib/screens/create_listing_screen.dart')
        .contains('termsAccepted: _kayit.sozlesme && _kayit.aydinlatma,'), isTrue);
  });

  test('ayrı 18 yaş kutusu ve ona bağlı engel yok', () {
    final r = _oku('lib/screens/register_screen.dart');
    expect(r.contains('18 yaşını doldurduğumu beyan ederim.'), isFalse);
    expect(r.contains('bool _yas'), isFalse);
    for (final f in const [
      'lib/data/ports/api_ports.dart',
      'lib/data/ports/repository_ports.dart',
      'lib/data/remote/api/auth_api.dart',
      'lib/data/controllers/auth_controller.dart',
    ]) {
      expect(_oku(f).contains('ageConfirmed'), isFalse, reason: f);
    }
  });

  test('onay olmadan kayıt tamamlanmaz (port + sunucu)', () {
    expect(_oku('lib/data/ports/api_ports.dart').contains('if (!termsAccepted) {'), isTrue);
    expect(_oku('lib/data/repositories/auth_repository.dart').contains('if (!termsAccepted) {'), isTrue);
    expect(_oku('backend/src/routes/kullanici.js').contains("ctx.body.termsAccepted !== true"), isTrue);
    // İki onay sunucuya bildirilir; onay kaydı sözleşme + aydınlatma metnine yazılır.
    expect(_oku('lib/data/remote/api/auth_api.dart').contains("'aydinlatmaAccepted': termsAccepted,"), isTrue);
    expect(_oku('backend/src/routes/kullanici.js').contains("ctx.body.aydinlatmaAccepted === true ? ['terms', 'kvkk'] : ['terms', 'privacy']"), isTrue);
  });
}
