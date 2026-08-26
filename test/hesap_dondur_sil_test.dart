// HESABI DONDUR / HESABI SİL — AKIŞ VE METİN SÖZLEŞMESİ
//
// GENEL PRENSİP: dondurma GEÇİCİ, silme KALICIDIR; biri ötekinin
// yerine kullanılamaz. Silme tek dokunuşla gerçekleşmez.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR —
// yasak ifadeler açıklamalarda gerekçe olarak geçiyor.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

void main() {
  final a = _kod('lib/screens/account_settings_screen.dart');

  group('KARTLAR', () {
    test('adlar ve alt açıklamalar', () {
      expect(a.contains("baslik: 'Hesabı Dondur'"), isTrue);
      expect(a.contains('Hesabınızı geçici olarak kullanıma kapatın.'), isTrue);
      expect(a.contains("baslik: 'Hesabı Sil'"), isTrue);
      expect(a.contains('Hesabınızı ve silinebilecek kişisel '), isTrue);
    });

    test('"Hesap Silme Talebi" adı kullanıcıya GÖSTERİLMEZ', () {
      expect(a.contains('Hesap Silme Talebi'), isFalse);
    });

    test('ana ekranda uzun hukuki metin YOK', () {
      // Uzun açıklamalar yalnız karta dokununca açılan panelde.
      expect(a.contains('Mevzuat gereği saklanması zorunlu kayıtlar, ilgili'),
          isTrue);
      final i = a.indexOf('_SatirKart(');
      final govde = a.substring(i, i + 900);
      expect(govde.contains('Mevzuat'), isFalse);
    });
  });

  group('DONDURMA AKIŞI', () {
    test('panel metni: SİLMEZ ifadesi açık', () {
      // ⚠ Metin kaynakta satırlara bölünmüştür; parçalar aranır.
      expect(a.contains('hesabınızı veya kişisel verilerinizi silmez.'),
          isTrue);
      expect(a.contains('yeniden etkinleştirene kadar HizmetCep '), isTrue);
    });

    test('iki düğme: Vazgeç / Hesabı Dondur', () {
      expect(a.contains("onayMetni: 'Hesabı Dondur'"), isTrue);
      expect(a.contains("child: Text('Vazgeç'"), isTrue);
    });

    test('ÜST ÜSTE İKİ ONAY YOK — eski onay ekranı kaldırıldı', () {
      expect(a.contains('refOnaySayfasi'), isFalse);
      expect(a.contains("onayMetni: 'Evet, Dondur'"), isFalse);
    });

    test('dondurma sonrası oturum kapanır', () {
      final i = a.indexOf('Future<void> _freeze() async {');
      expect(i, greaterThan(-1));
      final govde = a.substring(i, i + 1600);
      expect(govde.contains('auth.logout()'), isTrue);
      expect(govde.contains("pushNamedAndRemoveUntil('/home'"), isTrue);
    });

    test('engel varsa SUNUCUNUN GEREKÇESİ gösterilir', () {
      expect(a.contains('String? _sunucuGerekcesi(Object e)'), isTrue);
      expect(a.contains('_sunucuGerekcesi(e) ??'), isTrue);
    });
  });

  group('SİLME AKIŞI — ÜÇ AŞAMA', () {
    test('1. aşama: açıklama + Vazgeç / Devam Et', () {
      expect(
          a.contains('Hesabınızın silinmesi için işlem başlatılacaktır.'),
          isTrue);
      expect(a.contains("onayMetni: 'Devam Et'"), isTrue);
    });

    test('2. aşama: ŞİFRE DOĞRULAMASI', () {
      expect(a.contains('final dogrulandi = await _sifreDogrula();'), isTrue);
      expect(a.contains('Future<bool> _sifreDogrula() async {'), isTrue);
      expect(a.contains('.verifyPassword(ctl.text)'), isTrue);
      expect(a.contains('obscureText: true'), isTrue);
    });

    test('3. aşama: son kesin onay', () {
      expect(a.contains('Hesabınızı silmek istediğinize emin misiniz?'),
          isTrue);
      expect(a.contains('Bu işlem hesabınızı kalıcı olarak kapatır ve geri '),
          isTrue);
      expect(a.contains("onayMetni: 'Hesabımı Sil'"), isTrue);
    });

    test('SIRA DOĞRU: doğrulama son onaydan ÖNCE', () {
      final iDogrula = a.indexOf('final dogrulandi = await _sifreDogrula();');
      final iKesin = a.indexOf("onayMetni: 'Hesabımı Sil'");
      final iSil = a.indexOf('await _requestDeletion();');
      expect(iDogrula, greaterThan(-1));
      expect(iKesin, greaterThan(iDogrula));
      expect(iSil, greaterThan(iKesin));
    });

    test('"Devam Et" hesabı SİLMEZ', () {
      // Silme çağrısı yalnız son onaydan sonra.
      expect('await _requestDeletion();'.allMatches(a).length, 1);
    });
  });

  group('YASAK İFADELER', () {
    test('bakiye cümlesi HİÇBİR YERDE yok', () {
      for (final y in const [
        'Kalan bakiyeniz iade edilmez',
        'bakiye iade edilmez',
        'Jeton/bakiye iade edilmez',
      ]) {
        expect(a.contains(y), isFalse, reason: y);
      }
    });

    test('geçmiş ve anonimleştirme cümleleri yok', () {
      expect(a.contains('Teklif ve işlem geçmişiniz denetim'), isFalse);
      expect(a.contains('anonimleştirilir'), isFalse);
    });
  });

  group('SİLME SONRASI', () {
    test('⚠ SİLME SONRASI UYARI GÖSTERİLMEZ (ürün kararı)', () {
      // ── DEĞİŞEN KARAR ──
      //
      // Önce "Hesap silme işleminiz alındı… 30 gün içinde kalıcı
      // olarak silinecektir." uyarısı gösteriliyordu ve bu iki test
      // onun VARLIĞINI kilitliyordu.
      //
      // Yeni karar: uyarı GÖSTERİLMEZ. Kullanıcı üç aşamalı onaydan
      // geçiyor; işlem bitince oturum kapanıp giriş ekranına
      // dönülüyor ve sonucu oradan anlıyor.
      expect(a.contains('Hesap silme işleminiz alındı.'), isFalse,
          reason: 'kaldırılan uyarı geri gelmiş');
      expect(a.contains('30 gün içinde kalıcı olarak silinecektir.'), isFalse,
          reason: 'kaldırılan uyarı geri gelmiş');
      // ⚠ "Hesabınız silindi" iddiası HÂLÂ YASAK: backend yalnız
      // talep oluşturuyor, hesap o anda silinmiyor.
      expect(a.contains("sysToastOk(context, 'Hesabınız silindi"), isFalse);
    });

    test('⚠ SİLME AKIŞI BOZULMADI', () {
      // Kaldırılan yalnız EKRANDA BELİREN YAZI; işlemin kendisi aynı.
      expect(a.contains('requestDeletion()'), isTrue,
          reason: 'silme talebi çağrısı kalkmış');
      expect(a.contains('auth.logout()'), isTrue,
          reason: 'oturum kapatma kalkmış');
      expect(a.contains('OturumTercihi().temizle()'), isTrue);
    });

    test('tamamlanma bildirimi BU PAKETTE YOK — backend işi', () {
      // ⚠ Apple ikinci bir şart daha koşar: silme tamamlandığında
      // kullanıcıya ONAY verilmelidir. Bu bildirim SUNUCU tarafındadır
      // ve henüz yapılmamıştır. Burada yalnız gerçeğin kayda geçmesi
      // için duruyor: istemci sahte bir "tamamlandı" bildirimi
      // ÜRETMEZ.
      expect(a.contains('Hesabınız silindi ✓'), isFalse);
      expect(a.contains('silme tamamlandı'), isFalse);
    });

    test('oturum kapatılır ve ana ekrana dönülür', () {
      final i = a.indexOf('Future<void> _requestDeletion() async {');
      final govde = a.substring(i, i + 2000);
      expect(govde.contains('OturumTercihi().temizle()'), isTrue);
      expect(govde.contains('auth.logout()'), isTrue);
      expect(govde.contains("pushNamedAndRemoveUntil('/home'"), isTrue);
    });
  });

  group('MOCK MODDA AĞ ÇAĞRISI YOK', () {
    test('freeze ve deletion mod kontrolünden geçer', () {
      expect('if (ApiConfig.useRealApi) {'.allMatches(a).length,
          greaterThanOrEqualTo(2));
    });
  });

  group('ŞİFRE DOĞRULAMA SÖZLEŞMESİ', () {
    test('port ve controller ucu tanımlı', () {
      expect(
          _kod('lib/data/ports/repository_ports.dart')
              .contains('Future<DomainError?> verifyPassword(String password);'),
          isTrue);
      expect(
          _kod('lib/data/controllers/auth_controller.dart')
              .contains('verifyPassword(password)'),
          isTrue);
    });

    test('mock tarafı ŞİFREYİ DEĞİŞTİRMEZ, yalnız doğrular', () {
      final r = _kod('lib/data/repositories/auth_repository.dart');
      expect(r.contains('DomainError? sifreDogrula(String password)'), isTrue);
      final i = r.indexOf('DomainError? sifreDogrula(String password)');
      final govde = r.substring(i, i + 420);
      expect(govde.contains('_verify(acc, password)'), isTrue);
      expect(govde.contains('passwordHash ='), isFalse,
          reason: 'doğrulama şifreyi değiştirmemeli');
    });

    test('API ucu tanımlı (backend açacak)', () {
      expect(
          _kod('lib/data/remote/api/auth_api.dart')
              .contains("c.post('/auth/verify-password'"),
          isTrue);
    });
  });

  group('DONDURMA — DEVAM EDEN İŞ ENGELİ', () {
    final k = _kod('lib/screens/account_settings_screen.dart');

    test('panel açılmadan ÖNCE denetlenir', () {
      // Kullanıcı açıklamayı okuyup onaylayıp sonra reddedilmemeli.
      final i = k.indexOf('Future<void> _dondurPaneli() async {');
      expect(i, greaterThan(-1));
      final govde = k.substring(i, i + 900);
      final iDenetim = govde.indexOf('_devamEdenIsVar()');
      final iPanel = govde.indexOf('_onayPaneli(');
      expect(iDenetim, greaterThan(-1));
      expect(iPanel, greaterThan(-1));
      expect(iDenetim, lessThan(iPanel),
          reason: 'denetim panelden sonra çalışıyor');
    });

    test('gerekçe AÇIK yazılır', () {
      expect(
          k.contains('Hesabınızı dondurabilmek için devam eden '
              'işlemlerinizi '),
          isTrue);
    });

    test('CANLI kayıtlar sayılır, kapanmışlar sayılmaz', () {
      final i = k.indexOf('bool _devamEdenIsVar() {');
      expect(i, greaterThan(-1));
      final govde = k.substring(i, i + 900);
      for (final d in const [
        // ⚠ CANLI = YAŞAYAN (§24). Eski küme iş gidişatı durumlarını
        // da sayıyordu; onlar kalktı.
        'ListingStatus.active',
        'OfferStatus.active',
        'OfferStatus.selected',
      ]) {
        expect(govde.contains(d), isTrue, reason: d);
      }
      for (final d in const [
        'ListingStatus.userDeleted',
        'ListingStatus.expired',
        'OfferStatus.closed',
      ]) {
        expect(govde.contains(d), isFalse, reason: '$d engel olmamalı');
      }
    });

    test('SON SÖZ SUNUCUNUN — yerel denetim onun yerini almaz', () {
      // `_freeze` sunucu gerekçesini göstermeye devam eder.
      expect(k.contains('_sunucuGerekcesi(e) ??'), isTrue);
    });
  });

  group('MOCK AĞ KORUMASI — İSTİSNASIZ', () {
    test('talep geri çekme de mod kontrolünden geçer', () {
      final k = _kod('lib/screens/account_settings_screen.dart');
      final i = k.indexOf('Future<void> _cancelDeletion() async {');
      expect(i, greaterThan(-1));
      final govde = k.substring(i, i + 700);
      final iMod = govde.indexOf('if (ApiConfig.useRealApi) {');
      final iApi = govde.indexOf('AccountApi(context.read<ApiClient>())');
      expect(iMod, greaterThan(-1), reason: 'mod kontrolü yok');
      expect(iMod, lessThan(iApi), reason: 'API mod kontrolünden önce kurulmuş');
    });

    test('ekrandaki HER AccountApi kurulumu korumalı', () {
      final k = _kod('lib/screens/account_settings_screen.dart');
      final api = 'AccountApi(context.read<ApiClient>())'.allMatches(k).length;
      final mod = 'if (ApiConfig.useRealApi) {'.allMatches(k).length;
      final erken = 'if (!ApiConfig.useRealApi) {'.allMatches(k).length;
      expect(mod + erken, greaterThanOrEqualTo(api),
          reason: 'korumasız API kurulumu var');
    });
  });
}
