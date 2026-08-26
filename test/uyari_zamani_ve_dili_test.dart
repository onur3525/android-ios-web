// KAYIT FORMU — UYARI ZAMANLAMASI VE ORTAK DİL
//
// KARARLAR:
//   1. Uyarı YAZARKEN gösterilmez. Alan ODAKTAYKEN — özellikle ilk
//      harfte — kırmızı uyarı çıkmaz.
//   2. Uyarı alan TERK EDİLİNCE görünür: kullanıcı bir satırı doldurup
//      alt satıra geçtiğinde, üstteki satır eksik veya hatalıysa
//      uyarısı o zaman belirir.
//   3. Kullanıcı düzeltmek için alana geri döndüğünde uyarı GİZLENİR;
//      tekrar çıkınca yeniden değerlendirilir.
//   4. Tüm uyarılar ORTAK DİLLE yazılır: parantez içi açıklama, örnek
//      ve tire ile bağlanmış ek cümle YOKTUR.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/validators.dart';

String _kod(String yol) {
  final f = File(yol);
  // ⚠ BURADA `expect` KULLANILMAZ.
  //
  // Bu yardımcı `group(...)` gövdesinde de çağrılıyor; `expect` bir
  // test gövdesi dışında çalışınca `OutsideTestException` atar ve
  // DOSYANIN TAMAMI yüklenemez ("Failed to load"). Eksik dosya
  // durumu düz bir istisnayla bildirilir.
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

void main() {
  // ── 1. ZAMANLAMA — KAYITLI KAYIT EKRANI ─────────────────────────
  group('KAYIT EKRANI — UYARI ZAMANI', () {
    final r = _kod('lib/screens/register_screen.dart');

    test('karar çerçeveye bırakılmaz, `_kural` içinde verilir', () {
      expect(r.contains('AutovalidateMode.always'), isTrue);
      expect(r.contains('AutovalidateMode.onUserInteraction'), isFalse);
    });

    test('ODAKTAKİ alanın uyarısı gösterilmez', () {
      expect(r.contains('if (f != null && f.hasFocus) {'), isTrue,
          reason: 'yazarken uyarı kapısı kalkmış');
      expect(r.contains('FocusNode? _odak(TextEditingController c)'), isTrue);
    });

    test('TERK EDİLMEMİŞ alan uyarılmaz', () {
      expect(r.contains('final Set<TextEditingController> _terkEdilen = {}'),
          isTrue);
      expect(r.contains('_terkEdilen.add(e.key)'), isTrue,
          reason: 'odaktan çıkışta kayıt yapılmıyor');
    });

    test('ATLANAN alan yine uyarılır', () {
      // Kullanıcı bir alana hiç uğramadan sonrakini doldurduysa,
      // üstteki eksik alan bildirilir.
      expect(r.contains('!_terkEdilen.contains(c) && !_sonrasiDolu(c)'), isTrue);
      expect(r.contains('bool _sonrasiDolu(TextEditingController c)'), isTrue);
      // ⚠ ATLANMIŞ ALAN ARTIK BOŞKEN UYARMAZ.
      //
      // `_sonrasiDolu` odak kapısında hâlâ kullanılıyor (dolu ama
      // geçersiz alanlar için), ancak BOŞ alan uyarısını yalnız
      // gönderim tetikler — yeni ürün kuralı.
      expect(
          r.contains(
              'bool _bosUyariGoster(TextEditingController c) => _gonderimAninda;'),
          isTrue);
    });

    test('gönderim denendiğinde TÜM alanlar denetlenir', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ: kalıcı `_gonderimDenendi` bayrağı, bir kez
      // gönderime basıldıktan sonra uyarıyı ekranda ASILI bırakıyordu.
      // Yerine `_gonderimAninda` geldi — yalnız `validate()` süresince
      // açık. Gönderimde tüm alanlar denetlenir, sonra odak kuralı
      // yeniden geçerlidir.
      expect(r.contains('if (!_gonderimAninda) {'), isTrue);
      expect(r.contains('_gonderimAninda = true;'), isTrue);
      expect(r.contains('_gonderimAninda = false;'), isTrue);
      expect(r.contains('_gonderimDenendi'), isFalse,
          reason: 'kalıcı bayrak geri gelmiş');
      // Gönderimde alanlar terk edilmiş sayılır.
      expect(r.contains('_terkEdilen.addAll(_siraliAlanlar);'), isTrue);
    });
  });

  // ── 2. ZAMANLAMA — KAYITSIZ İLAN AKIŞI ──────────────────────────
  group('KAYITSIZ KAYIT ADIMI — UYARI ZAMANI', () {
    final k = _kod('lib/screens/widgets/ilan_kayit_adimi.dart');

    test('odaktaki alanın uyarısı gizlenir', () {
      expect(k.contains('String? odaktakiAlan;'), isTrue);
      expect(k.contains('if (odaktakiAlan == id) {'), isTrue);
    });

    test('odağa girince gizlenir, çıkınca yeniden görünür', () {
      expect(k.contains('widget.veri.odaktakiAlan = id'), isTrue);
      expect(k.contains('widget.veri.odaktakiAlan = null'), isTrue);
      expect(k.contains('widget.veri.dokunulan.add(id)'), isTrue,
          reason: 'terk kaydı korunmalı');
    });
  });

  // ── 3. ORTAK DİL ────────────────────────────────────────────────
  group('UYARI METİNLERİ ORTAK DİLDE', () {
    final v = _kod('lib/core/validators.dart');

    test('PARANTEZ İÇİ AÇIKLAMA kalmadı', () {
      for (final eski in [
        '(5XX XXX XX XX)',
        '(en az \$min harf, gerçek bir \$label)',
        '(AA/YY)',
        '(örn. 123456, abcdef)',
      ]) {
        expect(v.contains(eski), isFalse, reason: eski);
      }
    });

    test('metinler tek biçimde bitiyor', () {
      expect(Validators.phone('123'), 'Geçerli bir telefon numarası giriniz');
      expect(Validators.email('a@b'), 'Geçerli bir e-posta adresi giriniz');
      expect(Validators.name('x'), 'Geçerli bir ad giriniz');
      expect(Validators.name('x', label: 'soyad'), 'Geçerli bir soyad giriniz');
    });

    test('boş alan mesajı TEK', () {
      expect(Validators.phone(''), kZorunluAlan);
      expect(Validators.email(''), kZorunluAlan);
      expect(Validators.name(''), kZorunluAlan);
      expect(Validators.password(''), kZorunluAlan);
      expect(Validators.passwordRepeat('', 'abc123'), kZorunluAlan);
    });

    test('şifre uyarıları "olmalıdır / kullanılamaz / seçiniz" kalıbında', () {
      // ⚠ SAYI TESTE GÖMÜLMEZ: sabitten okunur, yoksa kural her
      // değiştiğinde test de elle güncellenmek zorunda kalır.
      expect(Validators.password('abc'),
          'En az $kPasswordMinLength karakter olmalıdır');
      // ⚠ METİNLER KISALTILDI: uzun cümleler alanın içindeki hata
      // satırına sığmıyor, üç noktayla kesiliyordu.
      expect(Validators.password('12345678'), 'Ardışık karakter kullanılamaz');
      expect(Validators.password('11111111'), 'Aynı karakteri tekrar etmeyin');
      expect(Validators.password('qwerty12'), 'Bu şifre çok yaygın');
      expect(Validators.password('a' * 65),
          'En fazla $kPasswordMaxLength karakter olabilir');
      expect(Validators.passwordRepeat('abc124', 'abc123'),
          'Şifreler aynı olmalıdır');
    });

    test('tire ile bağlanmış ek cümle yok', () {
      // Uyarılar tek cümledir; "— daha zor bir şifre seçin" gibi
      // ekler kaldırıldı.
      for (final m in [
        Validators.password('qwerty'),
        Validators.password('abc'),
        Validators.phone('123'),
        Validators.name('x'),
      ]) {
        expect(m!.contains('—'), isFalse, reason: m);
        expect(m.contains('('), isFalse, reason: m);
      }
    });
  });

  group('PROFİL BİLGİLERİM — UYARI ZAMANI', () {
    final p = _kod('lib/screens/profile_info_screen.dart');

    test('başlık doğru yazılmış', () {
      expect(p.contains("RefPageTitle('Profil Bilgilerim')"), isTrue);
      expect(p.contains('Profil Bilgilerimi'), isFalse,
          reason: 'eski hatalı başlık geri gelmiş');
    });

    test('her tuşta doğrulama YOK', () {
      // Eski hâl `onChanged` içinde `validate()`/`reset()` çağırıyordu:
      // ilk harfte uyarı basıyor, alan boşalınca da düzenlemenin
      // ortasında alan durumunu sıfırlayıp silmeyi engelliyordu.
      for (final k in const ['_adKey', '_soyadKey', '_epostaKey', '_telefonKey']) {
        expect(p.contains('$k.currentState?.validate()'), isFalse, reason: k);
        expect(p.contains('$k.currentState?.reset()'), isFalse, reason: k);
      }
    });

    test('uyarı odak/terk kapısından geçer', () {
      expect(p.contains('AutovalidateMode.always'), isTrue);
      expect(p.contains('String? _kural('), isTrue);
      expect(p.contains('if (odak.hasFocus) {'), isTrue);
      expect(p.contains('!_terkEdilen.contains(alan)'), isTrue);
    });

    test('dört alan da kapıya bağlı ve odak düğümü var', () {
      for (final a in const [
        "_kural('ad', _fAd",
        "_kural('soyad', _fSoyad",
        "_kural('eposta', _fEposta",
        "_kural('telefon', _fTelefon",
      ]) {
        expect(p.contains(a), isTrue, reason: a);
      }
      for (final f in const ['_fEposta', '_fTelefon']) {
        expect(p.contains('final $f = FocusNode();'), isTrue, reason: f);
        expect(p.contains('$f.dispose();'), isTrue, reason: '$f dispose');
      }
    });

    test('kaydetmede tüm alanlar denetlenir', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ: kalıcı `_gonderimDenendi` bayrağı, bir kez
      // gönderime basıldıktan sonra uyarıyı ekranda ASILI bırakıyordu.
      // Yerine `_gonderimAninda` geldi — yalnız `validate()` süresince
      // açık. Gönderimde tüm alanlar denetlenir, sonra odak kuralı
      // yeniden geçerlidir.
      expect(p.contains('if (!_gonderimAninda) {'), isTrue);
      expect(p.contains('if (!_hepsiniDenetle()) {'), isTrue);
      expect(p.contains('_gonderimDenendi'), isFalse,
          reason: 'kalıcı bayrak geri gelmiş');
    });

    test('SAHTE GECİKME kaldırıldı', () {
      // Kaydetme 550ms boş bekliyordu; kullanıcı ekranın takıldığını
      // sanıyordu ve hiçbir işe yaramıyordu.
      expect(p.contains('Duration(milliseconds: 550)'), isFalse);
    });
  });

  group('ŞİFRE DEĞİŞTİR — UYARI ZAMANI', () {
    final c = _kod('lib/screens/change_password_screen.dart');

    test('bir alana yazmak DİĞER alanları kırmızıya boyamaz', () {
      // Eski hâl `onChanged` içinde ÜÇ ALANI birden doğruluyordu.
      for (final k in const ['_mevcutKey', '_yeniKey', '_tekrarKey']) {
        expect(c.contains('$k.currentState?.validate()'), isFalse, reason: k);
        expect(c.contains('$k.currentState?.reset()'), isFalse, reason: k);
      }
    });

    test('uyarı odak/terk kapısından geçer', () {
      expect(c.contains('AutovalidateMode.always'), isTrue);
      expect(c.contains('String? _kural('), isTrue);
      expect(c.contains('if (odak.hasFocus) {'), isTrue);
      expect(c.contains('!_terkEdilen.contains(alan)'), isTrue);
    });

    test('üç alan da kapıya bağlı', () {
      // ⚠ `yeni` alanının çağrısı çok satırlıdır; parçalar aranır.
      // ⚠ Çağrılar çok satırlı; alan ADI ile aranır.
      expect(c.contains("'mevcut', _f_cur"), isTrue);
      expect(c.contains("'yeni',"), isTrue);
      expect(c.contains("'tekrar',"), isTrue);
    });

    test('TEKRAR alanı yalnız EŞLEŞME sorar', () {
      // "Mevcut şifreden farklı olmalıdır" kuralı YENİ ŞİFRE alanının
      // işidir; tekrar satırında da gösterilince kullanıcı hangi alanın
      // sorunlu olduğunu anlayamıyordu.
      final i = c.indexOf("'tekrar',");
      expect(i, greaterThan(-1));
      final govde = c.substring(i, i + 300);
      expect(govde.contains('Validators.passwordRepeat'), isTrue);
      expect(govde.contains('mevcut şifrenizden farklı'), isFalse);
    });

    test('kural YENİ ŞİFRE alanında duruyor', () {
      expect(c.contains('Yeni şifreniz mevcut şifrenizden farklı '), isTrue);
    });

    test('güncellemede tüm alanlar denetlenir', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ: kalıcı `_gonderimDenendi` bayrağı, bir kez
      // gönderime basıldıktan sonra uyarıyı ekranda ASILI bırakıyordu.
      // Yerine `_gonderimAninda` geldi — yalnız `validate()` süresince
      // açık. Gönderimde tüm alanlar denetlenir, sonra odak kuralı
      // yeniden geçerlidir.
      expect(c.contains('if (!_gonderimAninda) {'), isTrue);
      expect(c.contains('if (!_hepsiniDenetle()) {'), isTrue);
      expect(c.contains('_gonderimDenendi'), isFalse,
          reason: 'kalıcı bayrak geri gelmiş');
    });
  });


  group('ŞİFRE ALANLARINDA BOŞALTMA UYARI ÜRETMEZ', () {
    // Kullanıcı bir şifre alanını doldurup SİLDİĞİNDE "Bu alan
    // zorunludur" beliriyordu. Silmek hata değildir; zorunluluk
    // gönderim anında denetlenir.
    // ⚠ ŞİFRE ALANLARI TAŞINDI.
    //
    // "Şifremi Unuttum" ekranı baştan yazıldı: ana yol e-posta oldu
    // ve yeni şifre alanları AYRI bir ekrana (`yeni_sifre_screen`)
    // taşındı. Kural aynı, yeri değişti.
    final f = _kod('lib/screens/yeni_sifre_screen.dart');
    final c = _kod('lib/screens/change_password_screen.dart');

    test('yeni şifre ekranı: boş alan yazım sürecinde uyarmaz', () {
      final i = f.indexOf('String? _kural(');
      final govde = f.substring(i, f.indexOf('\n  }', i));
      // ⚠ KAPI ARTIK TRIM EDER: düğme aktifliği `trim()` ile ölçülüyor;
      // kapı etmezse yalnız boşluk içeren alan "dolu" sayılıp uyarı
      // üretir ama düğme pasif kalır — iki ölçü ayrışırdı.
      expect(govde.contains("if ((v ?? '').trim().isEmpty) {"), isTrue);
      expect(govde.contains('return null;'), isTrue);
    });

    test('şifremi unuttum ekranında da aynı kapı var', () {
      // E-posta ve telefon alanları için de kural korunuyor.
      final u = _kod('lib/screens/forgot_password_screen.dart');
      final i = u.indexOf('String? _kural(');
      final govde = u.substring(i, u.indexOf('\n  }', i));
      expect(govde.contains("if ((v ?? '').trim().isEmpty) {"), isTrue);
    });

    test('şifre değiştir: aynı kural', () {
      final i = c.indexOf('String? _kural(');
      final govde = c.substring(i, c.indexOf('\n  }', i));
      expect(govde.contains("if ((v ?? '').trim().isEmpty) {"), isTrue);
    });

    test('boşluk denetimi KAPININ İÇİNDE — gönderimde uyarı ÇIKAR', () {
      // `_gonderimAninda` true iken kapı tamamen atlanır; boş alan
      // yine "Bu alan zorunludur" der ve form geçmez.
      for (final k in [f, c]) {
        final i = k.indexOf('if (!_gonderimAninda) {');
        final j = k.indexOf('return asil(v);', i);
        final govde = k.substring(i, j);
        expect(govde.contains("if ((v ?? '').trim().isEmpty) {"), isTrue,
            reason: 'boş denetimi kapının dışına çıkmış');
      }
    });

    test('DOLU ama GEÇERSİZ değer yine uyarır', () {
      // Boşluk kuralı yalnız BOŞ değeri kapsar; yanlış yazılmış satır
      // alandan çıkınca uyarısını verir.
      for (final k in [f, c]) {
        expect(k.contains("if ((v ?? '').isNotEmpty) {"), isFalse,
            reason: 'kural tersine çevrilmiş');
      }
      expect(f.contains('_hepsiniDenetle()'), isTrue);
      expect(c.contains('_hepsiniDenetle()'), isTrue);
      // Şifremi Unuttum ekranı kendi denetleyicisini kullanır.
      expect(_kod('lib/screens/forgot_password_screen.dart')
          .contains('bool _denetle()'), isTrue);
    });
  });
}
