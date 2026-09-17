// ROL DEĞİŞTİR EKRANLARI — YERLEŞİM VE BİLGİLENDİRME KARARI
//
// KARARLAR:
//   1. Rol Değiştir ekranlarında BİLGİLENDİRME KUTUSU GÖSTERİLMEZ.
//      Geçiş kartı ve düğme zaten ne olacağını söylüyor.
//   2. Roller ALTLI ÜSTLÜ dizilir; aralarında geçiş oku vardır.
//   3. Geçilecek rol RENKLİ (mavi), şu anki rol koyu/gri kalır.
//   4. Tamamlanacak bilgi yoksa kart sayfanın DİKEY ORTASINDADIR.
//
// ⚠ İkon, ad ve etiketlere DOKUNULMADI; yalnız yerleşim değişti.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  final rs = _kod('lib/screens/role_switch_screen.dart');
  final rsel = _kod('lib/screens/role_select_screen.dart');

  group('BİLGİLENDİRME KUTUSU YOK', () {
    test('Rol Değiştir ekranında bilgi kutusu yok', () {
      expect(rs.contains('RefInfoBox'), isFalse);
      expect(rs.contains('profiline geçtiğinizde'), isFalse);
      expect(rs.contains('Hizmet veren profiliniz hazır'), isFalse);
    });

    test('Rol seçimi ekranının DEĞİŞTİR kipinde de yok', () {
      expect(rsel.contains('RefInfoBox'), isFalse);
      expect(rsel.contains('Aynı hesapla hem hizmet alabilir'), isFalse);
    });

    test('kayıt akışı BOZULMADI', () {
      // Bilgi kutusu yalnız `switching` dalındaydı; kayıt akışının
      // başlığı ve rol kartları yerinde kalmalı.
      expect(rsel.contains('Nasıl Başlamak İstersiniz?'), isTrue);
      expect(rsel.contains('startRegister(context, Role.customer)'), isTrue);
      expect(rsel.contains('startRegister(context, Role.provider)'), isTrue);
    });
  });

  group('ALTLI ÜSTLÜ YERLEŞİM', () {
    test('roller yan yana DEĞİL, alt alta', () {
      // Yatay dizilimin izi: iki `Expanded` içinde `_RolKutusu`.
      expect(rs.contains('child: _RolKutusu('), isFalse,
          reason: 'kutular hâlâ Expanded içinde yan yana');
      final govde = rs.substring(rs.indexOf('class _GecisKarti'));
      expect(govde.contains('Column('), isTrue);
    });

    test('geçiş oku KORUNDU ve dikey yöne çevrildi', () {
      expect(rs.contains('RotatedBox'), isTrue);
      expect(rs.contains("RefSvg('assets/svg/ic_pswap.svg'"), isTrue,
          reason: 'ok ikonu değiştirilmemeli');
    });

    test('ikon · ad · etiketler AYNEN duruyor', () {
      for (final s in [
        "etiket: 'Şu anki rolünüz'",
        "etiket: 'Geçilecek rol'",
        "'Hizmet Veren' : 'Hizmet Alan'",
        'assets/svg/ic_wrenchp.svg',
        'assets/svg/ic_pshield.svg',
      ]) {
        expect(rs.contains(s), isTrue, reason: s);
      }
    });
  });

  group('RENK KURALI', () {
    test('geçilecek rol RENKLİ, şu anki rol koyu/gri', () {
      // Vurgulu olan hedef roldür (`vurgulu: true` yalnız hedefte).
      expect(rs.contains("etiket: 'Geçilecek rol',\n              vurgulu: true"),
          isTrue);
      expect(
          rs.contains("etiket: 'Şu anki rolünüz',\n              vurgulu: false"),
          isTrue);
      // Renkler: vurguluysa mavi, değilse gri zemin + koyu yazı.
      expect(rs.contains('color: vurgulu ? RC.blue : const Color(0xFFF2F4F7)'),
          isTrue);
      expect(rs.contains('color: vurgulu ? RC.blue : RC.text'), isTrue);
    });
  });

  group('ORTALAMA', () {
    test('eksik bilgi yokken kart sayfanın ortasında', () {
      expect(rs.contains('if (!eksikVar)'), isTrue);
      expect(rs.contains('child: Center('), isTrue);
    });

    test('eksik bilgi varken liste düzeni korunur', () {
      expect(rs.contains('Tamamlanması Gerekenler'), isTrue);
      expect(rs.contains('onPressed: _hazir ?'), isTrue,
          reason: 'zorunlu bilgiler tamamlanmadan geçilemez');
    });
  });

  group('GEÇİŞ BLOĞU — ÇERÇEVESİZ VE BÜYÜK LOGO', () {
    test('gri çerçeve ve beyaz kutu KALDIRILDI', () {
      // Blok sayfayla bütün görünmeli; ayrı bir kart gibi
      // durmamalı.
      final i = rs.indexOf('class _GecisKarti');
      final govde = rs.substring(i, rs.indexOf('class _RolKutusu'));
      expect(govde.contains('Border.all(color: RC.border)'), isFalse,
          reason: 'çerçeve geri gelmiş');
      expect(govde.contains('color: RC.white'), isFalse,
          reason: 'kutu zemini geri gelmiş');
      expect(govde.contains('=> Padding('), isTrue);
    });

    test('rol logoları %30 büyütüldü', () {
      final i = rs.indexOf('class _RolKutusu');
      final govde = rs.substring(i);
      expect(govde.contains('width: 83'), isTrue);
      expect(govde.contains('height: 83'), isTrue);
      expect(govde.contains('size: 39'), isTrue);
      // Eski ölçüler geri gelmemeli.
      expect(govde.contains('width: 64'), isFalse);
      expect(govde.contains('size: 30,'), isFalse);
    });

    test('geçiş oku aynı oranda büyüdü', () {
      expect(rs.contains('size: 36, color: RC.greyLight'), isTrue);
      expect(rs.contains('size: 28, color: RC.greyLight'), isFalse);
    });

    test('YAZI ÖLÇÜLERİ DEĞİŞMEDİ', () {
      // İstenen yalnız logoların büyümesiydi.
      final i = rs.indexOf('class _RolKutusu');
      final govde = rs.substring(i);
      expect(govde.contains('size: RF.s18'), isTrue);
      expect(govde.contains('size: RF.s135'), isTrue);
    });

    test('içerik ve dizilim korundu', () {
      expect(rs.contains("etiket: 'Şu anki rolünüz'"), isTrue);
      expect(rs.contains("etiket: 'Geçilecek rol'"), isTrue);
      expect(rs.contains('RotatedBox'), isTrue);
    });
  });

  group('ROL SEÇİM KARTLARI EŞİT YÜKSEKLİKTE', () {
    test('ÖLÇEK PUNTOYA uygulanır, yüksekliğe DEĞİL', () {
      // ⚠ İKİ KEZ YANLIŞ YAPILDI:
      //   1. sabit 29 birim → yazı ölçeği hesaba katılmıyordu
      //   2. scale(29) → 29 bir YÜKSEKLİK, punto değil. Android 14+
      //      doğrusal olmayan ölçekleme uyguladığı için `scale()`
      //      büyük değere DAHA AZ çarpan verir; kutu gereken satır
      //      yüksekliğinden küçük kalır ve metin kırpılır.
      //
      // Doğrusu: ölçek PUNTOYA uygulanır, satır yüksekliği çarpanıyla
      // çarpılır, iki satır için ikiyle çoğaltılır.
      expect(rsel.contains('.scale(_kAciklamaPunto)'), isTrue);
      expect(rsel.contains('_kAciklamaSatirYuksekligi / _kAciklamaPunto'),
          isTrue);
      expect(rsel.contains('.scale(_kAciklamaSatirYuksekligi * 2)'), isFalse,
          reason: 'yüksekliği ölçekleme geri gelmiş');
      expect(rsel.contains('height: _kAciklamaSatirYuksekligi * 2,'), isFalse,
          reason: 'sabit yükseklik geri gelmiş');
    });

    test('PUNTO ve SATIR YÜKSEKLİĞİ tek yerde', () {
      // İkisi ayrı yerlerde yazılırsa hesap sessizce bozulur.
      expect(rsel.contains('const double _kAciklamaPunto = 11.6;'), isTrue);
      expect(rsel.contains('size: _kAciklamaPunto'), isTrue);
      expect(rsel.contains('size: 11.6,'), isFalse,
          reason: 'punto ikinci kez yazılmış');
    });

    test('açıklamaya iki satırlık SABİT alan ayrılmış', () {
      // ⚠ Kart yapısı ve dolgusu zaten aynıydı; fark açıklama
      // metninden geliyordu: biri tek satır, öteki iki satır sarıyor
      // ve turuncu kart yüksek görünüyordu.
      expect(rsel.contains('const double _kAciklamaSatirYuksekligi = 14.5;'),
          isTrue);
      // ⚠ Ölçek artık PUNTOYA uygulanıyor; kutu yüksekliği
      // punto × satır çarpanı × 2 olarak hesaplanıyor.
      expect(rsel.contains('_kAciklamaSatirYuksekligi / _kAciklamaPunto'),
          isTrue);
      expect(rsel.contains('.scale(_kAciklamaPunto)'), isTrue);
      expect(rsel.contains('maxLines: 2'), isTrue);
    });

    test('satır yüksekliği TEK KAYNAKTAN gelir', () {
      // Sabit hem kutu yüksekliğinde hem yazı `height` çarpanında
      // kullanılır; ikisi ayrışırsa kartlar yine kayar.
      expect(rsel.contains('_kAciklamaSatirYuksekligi / _kAciklamaPunto'),
          isTrue);
      expect(rsel.contains('const double _kAciklamaPunto = 11.6;'), isTrue);
      expect(rsel.contains('height: 14.5 / 11.6'), isFalse,
          reason: 'sabit yerine ham sayı geri gelmiş');
    });

    test('İKİ KART AYNI dolgu ve yapıyı kullanır', () {
      // Tek bir `_RolKarti` sınıfı iki kartı da çiziyor; ölçü farkı
      // ancak metinden doğabilir.
      expect(rsel.contains('class _RolKarti'), isTrue);
      expect('EdgeInsets.fromLTRB(16, 16, 16, 15)'.allMatches(rsel).length, 1);
    });

    test('METİNLER DEĞİŞMEDİ', () {
      expect(rsel.contains('Hizmet\\nAlmak İstiyorum'), isTrue);
      expect(rsel.contains('Hizmet\\nVermek İstiyorum'), isTrue);
      expect(rsel.contains('yeni işler kazanın.'), isTrue);
      expect(rsel.contains('teklif alın.'), isTrue);
    });
  });
}
