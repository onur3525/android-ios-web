// BOŞ ALAN UYARI YASAĞI + DÜĞME AKTİFLİK KURALI
//
// ⚠ ÜÇ KURAL, UYGULAMA GENELİNDE:
//
//   1. Satırlar boşken KATİYEN uyarı görünmez. Kullanıcı bilgi girip
//      sonra sildiğinde de uyarı KALMAZ.
//   2. Zorunlu alanlardan biri eksikken onay/giriş/ileri düğmeleri
//      AKTİF OLMAZ. Hepsi dolunca aktifleşir.
//   3. Yanlış girilmiş değer varsa uyarı YALNIZ o satırda çıkar;
//      öteki satırlar temiz kalır.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/validators.dart';

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

/// Metin alanı içeren ekranlar ve her birinin düğme kuralı.
const _formlar = <String, String>{
  'lib/screens/login_screen.dart': '_zorunlularDolu',
  'lib/screens/forgot_password_screen.dart': '_zorunluDolu',
  'lib/screens/yeni_sifre_screen.dart': '_zorunlularDolu',
  'lib/screens/job_detail_screen.dart': '_zorunlularDolu',
};

void main() {
  group('1 — BOŞ ALANDA UYARI YOK', () {
    test('kapılı formlarda boş değer erken döner', () {
      for (final p in const [
        'lib/screens/login_screen.dart',
        'lib/screens/forgot_password_screen.dart',
        'lib/screens/yeni_sifre_screen.dart',
        'lib/screens/change_password_screen.dart',
      ]) {
        final k = _kod(p);
        final i = k.indexOf('String? _kural(');
        expect(i, greaterThan(0), reason: '$p: ortak kapı yok');
        final govde = k.substring(i, k.indexOf('\n  }', i));
        expect(govde.contains("(v ?? '')"), isTrue,
            reason: '$p: boş değer denetimi yok');
        expect(govde.contains('return null;'), isTrue, reason: p);
      }
    });

    test('giriş ekranında boş alan HİÇBİR KOŞULDA uyarmaz', () {
      // ⚠ Burada `_gonderimAninda` KAPISI YOKTUR: düğme zaten boş
      // alanla aktif olmadığı için gönderim denenemiyor, dolayısıyla
      // "Bu alan zorunludur" uyarısının çıkacağı bir an yok.
      final l = _kod('lib/screens/login_screen.dart');
      final i = l.indexOf('String? _kural(');
      final govde = l.substring(i, l.indexOf('\n  }', i));
      expect(govde.contains("if ((v ?? '').trim().isEmpty) {"), isTrue);
    });

    test('odaktayken de uyarı yok', () {
      for (final p in _formlar.keys.where((p) => p.contains('login') ||
          p.contains('forgot') ||
          p.contains('yeni_sifre'))) {
        final k = _kod(p);
        final i = k.indexOf('String? _kural(');
        final govde = k.substring(i, k.indexOf('\n  }', i));
        expect(govde.contains('odak.hasFocus'), isTrue, reason: p);
      }
    });
  });

  group('2 — EKSİK ALANLA DÜĞME AKTİF DEĞİL', () {
    test('her formun düğmesi doluluk kuralına bağlı', () {
      _formlar.forEach((dosya, kural) {
        final k = _kod(dosya);
        expect(k.contains('bool get $kural'), isTrue,
            reason: '$dosya: $kural tanımlı değil');
        // Bağlanma biçimi ekrana göre değişir (`kural ? x : null`
        // ya da `(!kural) ? null : x`); önemli olan düğmenin
        // KURALA bağlı olması.
        expect(k.contains('$kural ?') || k.contains('!$kural'), isTrue,
            reason: '$dosya: düğme kurala bağlı değil');
      });
    });

    test('kayıt formu geçerlilik bildiricisine bağlı', () {
      // Kayıt ekranı ValueNotifier kullanır (form ağacı sabit kalsın
      // diye); kural aynı: geçersizken düğme pasif.
      final r = _kod('lib/screens/register_screen.dart');
      expect(r.contains('valueListenable: _formGecerli'), isTrue);
      expect(r.contains('onPressed: gecerli ? _next : null'), isTrue);
    });

    test('değer değişince düğme durumu TAZELENİR', () {
      // ⚠ Yalnız hata temizlemek yetmez: hata yokken setState
      // çağrılmazsa doluluk yeniden hesaplanmaz ve düğme pasif kalır.
      final l = _kod('lib/screens/login_screen.dart');
      expect(l.contains('void _degerDegisti()'), isTrue);
      expect('onChanged: (_) => _degerDegisti(),'.allMatches(l).length, 3);
    });

    test('bakiye ve kart formları da kurala bağlı', () {
      expect(_kod('lib/screens/topup_screen.dart').contains('_tutarGecerli'),
          isTrue);
      expect(
          _kod('lib/screens/widgets/saved_cards_section.dart')
              .contains('_formGecerli'),
          isTrue);
    });
  });

  group('3 — UYARI YALNIZ YANLIŞ SATIRDA', () {
    test('teklif formunda alanlar AYRI hata tutar', () {
      final j = _kod('lib/screens/job_detail_screen.dart');
      expect(j.contains('_amtError'), isTrue);
      expect(j.contains('_noteError'), isTrue);
      // Bir alan değişince YALNIZ kendi hatası düşer.
      expect(j.contains('onChanged: (_) => setState(() => _amtError = null)'),
          isTrue);
      expect(j.contains('onChanged: (_) => setState(() => _noteError = null)'),
          isTrue);
      // ⚠ ALAN BAŞINA TEK `onChanged`.
      //
      // İki ayrı `onChanged` verilince Dart derlemeyi durduruyordu
      // (`duplicate_named_argument`); ikinci callback sayacı ve
      // düğme durumunu tazeliyordu, o iş tek callback'e alındı.
      expect('onChanged:'.allMatches(j).length, 2,
          reason: 'alan başına tek onChanged olmalı (tutar + açıklama)');
    });

    test('kart formunda düğme TÜM alanlar geçerliyken aktif', () {
      // ⚠ Bu ekran alan-altı `errorText` KULLANMIYOR: dört alan da
      // geçerli olmadan düğme pasif kalıyor, dolayısıyla kullanıcı
      // hiç hata metniyle karşılaşmıyor. Kural aynı, uygulaması
      // farklı.
      final s = _kod('lib/screens/widgets/saved_cards_section.dart');
      expect(s.contains('bool get _formGecerli'), isTrue);
      expect(s.contains('_formGecerli'), isTrue);
    });

    test('şifre tekrar alanı yalnız EŞLEŞME sorar', () {
      // Aynı kuralı iki satırda birden söylemek hangi alanın sorunlu
      // olduğunu gizler.
      // ⚠ SÖZLEŞME GELİŞTİ: tekrar alanı eşleşmeyi yalnız REFERANS
      // GEÇERLİYKEN sorar. Bu yüzden validator'da `Validators.password`
      // ÇAĞRISI VAR — ama şifre kuralını bu alanda GÖSTERMEK için
      // değil, referansın geçerliliğini ölçmek için.
      final y = _kod('lib/screens/yeni_sifre_screen.dart');
      expect(y.contains('Validators.passwordRepeat'), isTrue);
      expect(y.contains('Validators.password(_yeni.text) != null'), isTrue);
      // Tekrar alanı şifre kuralını KENDİ hatası olarak döndürmez.
      final i = y.indexOf('Validators.passwordRepeat');
      final govde = y.substring(i - 260, i);
      expect(govde.contains('? null'), isTrue,
          reason: 'referans geçersizken null dönmeli');
    });
  });


  group('4 — REFERANS ALAN BOŞKEN EŞLEŞME SORULMAZ', () {
    // ⚠ KULLANICININ YAKALADIĞI KUSUR (14 Ağu):
    //
    // İki şifre alanı doldurulup ÜSTTEKİ silinince, alttaki alan hâlâ
    // dolu olduğu için "Şifreler aynı olmalıdır" uyarısı ekranda
    // KALIYORDU. Kural açık: bilgi girilip silindiğinde uyarı kalmaz.

    test('yeni şifre ekranı referansı denetler', () {
      // ⚠ DENETİM GENİŞLEDİ: referans yalnız BOŞ değil, KURALA
      // UYMUYORSA da eşleşme sorulmaz.
      //
      // Kullanıcı üst alana 3 haneli şifre yazıp alta 6 hane
      // girdiğinde ekranda tek uyarı çıkıyordu: "Şifreler aynı
      // olmalıdır". Asıl sorun eşleşme değil, üst alanın kurala
      // uymamasıydı — uyarı YANLIŞ ALANI işaret ediyordu.
      final y = _kod('lib/screens/yeni_sifre_screen.dart');
      expect(y.contains('Validators.password(_yeni.text) != null'), isTrue);
      expect(y.contains('? null'), isTrue,
          reason: 'referans geçersizken null dönmeli');
    });

    test('şifre değiştirme ekranı da denetler', () {
      final c = _kod('lib/screens/change_password_screen.dart');
      expect(c.contains('Validators.password(_new1.text) != null'), isTrue);
    });

    test('İKİSİ DE GEÇERLİ ama FARKLIYSA eşleşme uyarısı ÇIKAR', () {
      // Kural gevşetilmedi: referans kuralı geçtiği anda eşleşme
      // yeniden sorulur.
      // ⚠ Örnekler 8 haneye çıkarıldı (asgari 6 → 8).
      expect(Validators.password('abc12345'), isNull);
      expect(Validators.passwordRepeat('abc12346', 'abc12345'), isNotNull);
    });

    test('REFERANS KISAYSA kendi alanında uyarılır', () {
      // Uyarı doğru alana gider: üst alan odaktan çıkınca kendi
      // kuralını söyler.
      expect(Validators.password('abc'), isNotNull);
      // ⚠ Sayı teste gömülmez; sabitten okunur.
      expect(
          Validators.password('abc')!.contains('$kPasswordMinLength'), isTrue);
    });

    test('KAPI TRIM EDER — düğme ölçüsüyle aynı', () {
      // Düğme aktifliği `trim()` ile ölçülüyor; kapı etmezse yalnız
      // boşluk içeren alan "dolu" sayılıp uyarı üretir ama düğme
      // pasif kalır — iki ölçü ayrışır.
      for (final f in const [
        'lib/screens/yeni_sifre_screen.dart',
        'lib/screens/change_password_screen.dart',
        'lib/screens/forgot_password_screen.dart',
      ]) {
        final k = _kod(f);
        expect(k.contains("(v ?? '').trim().isEmpty"), isTrue, reason: f);
        expect(k.contains("if ((v ?? '').isEmpty) {"), isFalse, reason: f);
      }
    });
  });

  group('5 — ŞİFRE DOĞRULAMA PANELİ', () {
    // Hesap silmeden önceki şifre paneli standardın DIŞINDAYDI.
    final a = _kod('lib/screens/account_settings_screen.dart');

    test('değer değişince uyarı düşer', () {
      expect(a.contains('hataNot.value = null;'), isTrue);
    });

    test('boş alanda düğme PASİF — uyarı üretilmez', () {
      expect(a.contains('doluNot'), isTrue);
      expect(a.contains('onPressed: !dolu'), isTrue);
      expect(a.contains("hataNot.value = 'Şifrenizi giriniz'"), isFalse,
          reason: 'boş alan uyarısı geri gelmiş');
    });

    test('bildirici SERBEST BIRAKILIR', () {
      expect(a.contains('doluNot.dispose();'), isTrue);
    });
  });


  group('6 — DOĞRU/TAM GİRDİ OLMADAN DÜĞME AKTİF DEĞİL', () {
    test('OTP: kod 6 hane değilken "Doğrula" PASİF', () {
      // ⚠ Eskiden düğme her zaman aktifti; eksik kodla basılınca
      // "Lütfen 6 haneli kodu eksiksiz giriniz" uyarısı çıkıyordu.
      // Kural: eksik girdiyle düğme aktif olmaz, uyarı da üretilmez.
      final o = _kod('lib/screens/otp_screen.dart');
      expect(o.contains('onPressed: _kodUzunluk < 6'), isTrue);
      expect(o.contains('Lütfen 6 haneli kodu eksiksiz giriniz'), isFalse,
          reason: 'eksik kod uyarısı geri gelmiş');
    });

    test('OTP alanı HER DEĞİŞİMDE haber verir', () {
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(w.contains('final ValueChanged<String>? onDegisti;'), isTrue);
      expect(w.contains('widget.onDegisti?.call(code);'), isTrue);
    });

    test('kayıtsız ilan akışında da tam kod aranır', () {
      final c = _kod('lib/screens/create_listing_screen.dart');
      expect(c.contains('4 => !_otp.tamam'), isTrue);
    });
  });

  group('7 — ⚠ KAYITSIZ NUMARA UYARISI KALDIRILDI (enumeration)', () {
    // ⚠ ESKİ ÜRÜN KARARI GERİ ALINDI — GÜVENLİK GEREKÇESİYLE.
    //
    // Eskiden numara tamamlanınca kayıt denetleniyor, kayıtsızsa
    // "Sisteme kayıtlı bir numara giriniz." uyarısı çıkıp düğme
    // kilitleniyordu. Bu, HESAP SAYIMINA (enumeration) kapı
    // bırakıyordu: saldırgan numara deneyerek hangi numaraların
    // sistemde kayıtlı olduğunu öğrenebiliyordu. Telefon numaraları
    // tahmin edilebilir aralıkta olduğu için liste bulmaya bile
    // gerek yok, sırayla denemek yeterliydi.
    //
    // ⚠ UYARIYI ALAN ALTINA TAŞIMAK ÇÖZMEZ: sızdıran şey uyarının
    // YERİ değil, cevabın kayıtlı ve kayıtsız numarada FARKLI
    // olmasıdır.
    //
    // ⚠ TEST GEVŞETİLMEDİ, SÖZLEŞME DEĞİŞTİ. Aşağıdaki iddialar eski
    // davranışın GERİ GELMEDİĞİNİ kilitler.
    final f = _kod('lib/screens/forgot_password_screen.dart');

    test('ekran kayıt durumunu SORGULAMAZ', () {
      expect(f.contains('telefonKayitliMi('), isFalse,
          reason: 'kayıt sorgusu geri gelmiş — sızıntının kaynağı budur');
      expect(f.contains('_kayitsizNumaralar'), isFalse);
      expect(f.contains('_numaraKayitsiz'), isFalse);
    });

    test('düğme YALNIZ biçime bakar', () {
      expect(f.contains('&& _telefonTam && !_numaraKayitsiz'), isFalse,
          reason: 'kayıtsızlık düğmeye geri bağlanmış');
      expect(f.contains('(_phone.text.trim().isNotEmpty && _telefonTam)'),
          isTrue);
    });

    test('doğrulayıcı YALNIZ biçim denetler', () {
      expect(f.contains("_kural('telefon', _fPhone, v, Validators.phone)"),
          isTrue);
      expect(f.contains('FormMesaj.numaraKayitsiz'), isFalse,
          reason: 'kayıtsız numara mesajı geri gelmiş');
    });

    test('kayıtsız numarada da doğrulama adımına GEÇİLİR', () {
      // Durmanın kendisi evet/hayır cevabı vermekle aynı şeydir.
      expect(f.contains('_kayitsizNumaralar.add(telefonAnlik)'), isFalse);
      expect(f.contains('Navigator.push('), isTrue);
    });

    test('NÖTR KUTU YALNIZ E-POSTA YOLUNDA', () {
      // ⚠ 16 Ağu: telefon yolundan kaldırıldı. Kod istendiğinde
      // doğrulama ekranı zaten açılıyor; kutu hem gereksizdi hem de
      // geri dönülüp numara değiştirilince ekranda kalıp
      // YANILTIYORDU.
      expect(f.contains('if (_gonderildi && !_telefonYolu)'), isTrue,
          reason: 'kutu telefon yolunda da gösteriliyor');
      expect(f.contains('FormMesaj.sifirlamaGonderildi'), isTrue,
          reason: 'e-posta yolunda nötr metin yok');
      expect(f.contains('FormMesaj.kodGonderildiNotr'), isFalse,
          reason: 'kaldırılan sabit geri gelmiş');
    });

    test('ADRES DEĞİŞİNCE kutu kalkar', () {
      // Kutu eski adrese aitti; yeni adres yazılırken durması
      // "gönderildi" yanılgısı üretir.
      expect(f.contains('onChanged: (_) => setState(() => _gonderildi = false)'),
          isTrue);
    });

    test('nötr metin hesap durumu SÖYLEMEZ', () {
      final m = _kod('lib/domain/form_mesajlari.dart');
      expect(m.contains('Sisteme kayıtlı bir numara giriniz.'), isFalse,
          reason: 'kayıtsızlık mesajı geri gelmiş');
      // Metin KOŞULLU dille yazılır: "varsa".
      expect(m.contains('kayıtlı bir hesabınız varsa'), isTrue);
    });

    test('OTP ekranında nötr yönlendirme var', () {
      // ⚠ Cümle GİRİLEN NUMARA hakkında hiçbir şey söylemez; dört
      // akışta da (kayıt, giriş, telefon değişimi, kurtarma) geçerli.
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(w.contains('Numaranızın doğru olduğundan emin olun.'), isTrue);
      expect(w.contains('kayıtlı değil'), isFalse,
          reason: 'OTP ekranında hesap varlığı sızdırılıyor');
    });
  });

  group('8 — ŞİFRE DÜĞMESİ: DOLU YETMEZ, GEÇERLİ VE EŞİT OLMALI', () {
    // ⚠ KULLANICININ BULDUĞU KUSUR (14 Ağu):
    //
    // Yeni Şifre Belirle ekranında iki alan BİRBİRİNİ TUTMASA ve
    // şifre altı karakterden kısa OLSA bile "Şifremi Yenile" aktifti;
    // hata ancak basıldıktan sonra çıkıyordu.
    //
    // Kural: politika geçmeden VE iki alan aynı olmadan düğme aktif
    // olmaz.

    test('yeni şifre ekranı: politika + eşitlik', () {
      final y = _kod('lib/screens/yeni_sifre_screen.dart');
      expect(y.contains('Validators.password(_yeni.text) == null &&'), isTrue);
      expect(y.contains('_tekrar.text == _yeni.text'), isTrue);
      expect(
          y.contains(
              '_yeni.text.trim().isNotEmpty && _tekrar.text.trim().isNotEmpty'),
          isFalse,
          reason: 'yalnız doluluk denetimi geri gelmiş');
    });

    test('şifre değiştirme ekranı: mevcut + politika + eşitlik', () {
      // Bu ekranda düğmenin HİÇ kuralı yoktu, her zaman aktifti.
      final c = _kod('lib/screens/change_password_screen.dart');
      expect(c.contains('bool get _formGecerli'), isTrue);
      expect(c.contains('_cur.text.trim().isNotEmpty &&'), isTrue);
      expect(c.contains('Validators.password(_new1.text) == null &&'), isTrue);
      expect(c.contains('_new2.text == _new1.text'), isTrue);
      expect(c.contains('onPressed: _formGecerli ? _save : null'), isTrue);
      expect(c.contains('onPressed: _save,'), isFalse,
          reason: 'kuralsız düğme geri gelmiş');
    });

    test('POLİTİKA TEK KAYNAKTAN — ekran kendi kuralını yazmaz', () {
      // "en az 6" gibi sayılar ekrana gömülmemeli.
      for (final f in const [
        'lib/screens/yeni_sifre_screen.dart',
        'lib/screens/change_password_screen.dart',
      ]) {
        final k = _kod(f);
        expect(k.contains('.length < 6'), isFalse, reason: f);
        expect(k.contains('.length >= 6'), isFalse, reason: f);
      }
    });

    test('DOĞRULAYICI davranışı: kısa, yaygın, tekrarlı reddedilir', () {
      expect(Validators.password('abc12'), isNotNull, reason: '5 karakter');
      expect(Validators.password('abc12345'), isNull, reason: '8 karakter');
      expect(Validators.password('11111111'), isNotNull, reason: 'tekrar');
      expect(Validators.password('Abc123!x'), isNull, reason: 'geçerli');
    });
  });
}
