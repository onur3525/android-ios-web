// KAYIT — ZORUNLU SÖZLEŞMELER (16 Eki, kullanıcı kararı + örnek görsel)
//   · İki ayrı zorunlu onay: Kullanım Sözleşmesi ve (4 Kas) yurt dışında
//     işlemeye açık rıza; Aydınlatma Metni kutusuz bağlantı; ticari ileti
//     isteğe bağlı kutu.
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
    expect(o.contains("'HizmetCep’i kullanırken geçerli olan kuralları, hak ve '\n                'sorumluluklarımı içerir.'"), isTrue);
    expect(o.contains("static const String kGizlilik = 'Gizlilik Politikası';"), isTrue);
    expect(o.contains("arguments: {'slug': 'privacy', 'title': kGizlilik}"), isTrue);
    // ── 4 Kas (kullanıcı kararı, örnek ekran) ──
    // Aydınlatma bir BİLGİLENDİRMEDİR: kutusuz, "Aydınlatma Metnini
    // Görüntüle" bağlantısı. Yurt dışında işlemeye açık rıza AYRI, zorunlu
    // kutu (Gizlilik Politikası bağlantılı); "yurt dışı sunucu" ifadesi
    // açıkça geçer. Ticari ileti kutusu isteğe bağlıdır, yıldızsız.
    expect(o.contains("'Aydınlatma Metnini Görüntüle'"), isTrue);
    expect(o.contains("arguments: {'slug': 'kvkk', 'title': kAydinlatma}"), isTrue);
    expect(o.contains("'amacıyla yurt dışındaki sunucularda işlenmesine yasal '"), isTrue);
    expect(o.contains("'haklarım saklı kalmak kaydıyla AÇIK RIZA veriyorum.'"), isTrue);
    expect(o.contains('’ni okudum; kişisel verilerimin'), isFalse,
        reason: 'aydınlatma artık onay kutusunda değil');
    // ⚠ 22 Eki (KVKK): aydınlatma için "kabul / izin" denmez.
    expect(o.contains('izin veriyorum'), isFalse);
    expect(o.contains("'ileti almak istiyorum. (İsteğe bağlı)'"), isTrue);
    expect(o.contains('zorunlu: false,'), isTrue);
    expect(o.contains('if (zorunlu)'), isTrue);
    // Web'de çerez bilgilendirmesi (onay istemez).
    expect(o.contains("arguments: {'slug': 'cookies', 'title': kCerez}"), isTrue);
    expect(o.contains("text: '  *'"), isTrue);
    expect(o.contains("arguments: {'slug': 'terms', 'title': kBaslik}"), isTrue);
  });

  test('ticari ileti izni üç kayıt ekranında da sunucuya gider (varsayılan kapalı)', () {
    for (final f in const [
      'lib/screens/register_screen.dart',
      'lib/screens/widgets/ilan_kayit_adimi.dart',
      'lib/screens/sosyal_kayit_screen.dart',
    ]) {
      expect(_oku(f).contains('onTicariIleti:'), isTrue, reason: f);
    }
    expect(_oku('lib/screens/register_screen.dart').contains('bool _ticariIleti = false;'), isTrue);
    expect(_oku('lib/screens/create_listing_screen.dart').contains('ticariIleti: _kayit.ticariIleti,'), isTrue);
    final api = _oku('lib/data/remote/api/auth_api.dart');
    expect("'marketingConsent': marketingConsent,".allMatches(api).length, 2);
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
    // 23 Eki: aydınlatma bilgilendirmesi sunucuda da ZORUNLU; kayıt
    // sözleşme + aydınlatma metnine yazılır (eski tek onaylı yol kaldırıldı).
    final k = _oku('backend/src/routes/kullanici.js');
    expect(k.contains("if (ctx.body.aydinlatmaAccepted !== true) throw new ApiHatasi(400, 'AYDINLATMA_REQUIRED'"), isTrue);
    expect(k.contains("const onaylananlar = ['terms', 'kvkk', 'privacy'];"), isTrue);
  });
}
