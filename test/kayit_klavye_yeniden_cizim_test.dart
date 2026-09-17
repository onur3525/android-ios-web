// KAYIT EKRANI — KLAVYE BAĞIMLILIĞI AĞAÇTAN AYRIK (KİLİT)
//
// ⚠ KULLANICI BULGUSU (9 Eyl): "Zorunlu alanları doldurmaya
// başladığımda klavye zor açılıp kapanıyor, kasmaya başlıyor. Ancak
// il-ilçe-mahalle bilgilerini diğer bilgilere hiç dokunmadan
// girdiğimde bu sorun yok."
//
// ⚠ BULGUNUN AÇIKLAMASI: alanlara dokunulmazsa klavye HİÇ AÇILMAZ.
// Dokunulunca, il satırına basıldığı an iki animasyon üst üste
// biner — klavye iniyor, seçim paneli çıkıyor.
//
// ⚠ ÖLÇÜLEN KÖK NEDEN: `MediaQuery.viewInsetsOf` doğrudan ekranın
// `build` metodunda okunuyordu. Bu değer klavye animasyonunun HER
// KARESİNDE değişir ve `MediaQuery`ye bağlanan eleman her karede
// yeniden çizilir — bağlanan eleman 613 satırlık formun TAMAMIYDI.
//
// ⚠ ÖNCEKİ DENEME YETMEDİ: doğrulayıcı desenlerinin önbelleğe
// alınması (`validators.dart`) tek başına farkı kapatmadı; kullanıcı
// aynı yavaşlığı bildirdi. Asıl yük yeniden çizilen AĞACIN
// BÜYÜKLÜĞÜYDÜ.
//
// ⚠ ÇÖZÜM AĞACI KÜÇÜLTMEK DEĞİL, BAĞIMLILIĞI AŞAĞI TAŞIMAK:
// `MediaQuery` okuması küçük bir sarmalayıcıya indi; `child` aynı
// widget örneği olarak geçtiği için altındaki ağaç yeniden
// KURULMUYOR.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final ham = File('lib/screens/register_screen.dart').readAsStringSync();
  final kod = ham
      .split('\n')
      .where((l) =>
          !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');

  test('⚠ ANA build KLAVYEYE BAĞLANMAZ', () {
    // Ekranın kendi `build` metodunda `MediaQuery` okuması kalmamalı;
    // kalırsa tüm form yeniden kare başına çizilir.
    final i = kod.indexOf('Widget build(BuildContext context)');
    final j = kod.indexOf('class _KlavyeDolgusu');
    expect(i, greaterThan(-1));
    expect(j, greaterThan(i), reason: 'sarmalayıcı bileşen yok');
    expect(kod.substring(i, j).contains('MediaQuery.'), isFalse,
        reason: 'klavye bağımlılığı ağacın köküne geri gelmiş');
  });

  test('okuma yalnız sarmalayıcıda', () {
    final j = kod.indexOf('class _KlavyeDolgusu');
    expect(kod.substring(j).contains('MediaQuery.viewInsetsOf(context)'),
        isTrue);
  });

  test('⚠ DOLGU FORMÜLÜ DEĞİŞMEDİ', () {
    // "Devam Et" düğmesinin klavye açıkken görünür alana
    // kaydırılabilmesi bu paya bağlı.
    expect(kod.contains('24 + MediaQuery.viewInsetsOf(context).bottom'),
        isTrue);
  });

  test('sarmalayıcı çocuğu OLDUĞU GİBİ geçirir', () {
    // Çocuğu yeniden kurarsa kazanç kaybolur.
    final j = kod.indexOf('class _KlavyeDolgusu');
    final govde = kod.substring(j);
    expect(govde.contains('final Widget child;'), isTrue);
    expect(govde.contains('child: child,'), isTrue);
  });

  test('⚠ DOĞRULAMA KİPİ DEĞİŞMEDİ', () {
    // Bu tur YALNIZ yeniden çizim alanını küçültür. Uyarıların ne
    // zaman göründüğü kuralına DOKUNULMADI; değişseydi hangi
    // düzeltmenin işe yaradığı ölçülemezdi.
    expect(kod.contains('AutovalidateMode.onUserInteraction'), isTrue);
  });
}
