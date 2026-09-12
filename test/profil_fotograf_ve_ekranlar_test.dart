// PROFİL FOTOĞRAFI · SİLME ONAYI · ROL KARTI · DESTEK METNİ
//
// Bu tur cihazda bulunan yedi kusurun sözleşmesi.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';

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
  group('İLAN SİLME', () {
    final l = _kod('lib/screens/listing_detail_screen.dart');

    test('"Hizmeti aldım" gerekçesi KALDIRILDI', () {
      // Tamamlanan iş silinmez: değerlendirme ve fatura ona bağlıdır.
      expect(l.contains('Hizmeti aldım'), isFalse);
    });

    test('kalan beş gerekçe duruyor', () {
      for (final g in const [
        'İhtiyacım kalmadı / vazgeçtim',
        'Dışarıdan biri ile anlaştım',
        'Yanlış ilan oluşturdum',
        'Gelen teklifler uygun değildi',
        'Diğer',
      ]) {
        expect(l.contains(g), isTrue, reason: g);
      }
    });

    test('onay penceresi SADE — açıklama yok', () {
      expect(l.contains('_silOnayi(context, acik: acik)'), isTrue);
      expect(l.contains('Gerekçe: '), isFalse);
      expect(l.contains('Bu işlem geri alınamaz'), isFalse);
      expect(l.contains('blokeleri hizmet verenlere iade edilir'), isFalse);
    });

    test('onayda yalnız iki düğme var', () {
      final i = l.indexOf('Future<bool> _silOnayi(');
      expect(i, greaterThan(-1));
      final govde = l.substring(i, i + 1200);
      expect(govde.contains("Text('Vazgeç')"), isTrue);
      expect(govde.contains("acik ? 'Sil' : 'İptal Et'"), isTrue);
      expect(govde.contains('content:'), isFalse,
          reason: 'açıklama gövdesi geri gelmiş');
    });
  });

  group('ROL DEĞİŞTİR KARTI BÜYÜTÜLDÜ', () {
    final r = _kod('lib/screens/role_switch_screen.dart');

    test('daire ve ikon büyüdü', () {
      // ⚠ ÖLÇÜLER BİR KEZ DAHA BÜYÜDÜ (%30): 64→83, 30→39.
      // Kural aynı — logolar büyük olacak; sayılar güncellendi.
      expect(r.contains('width: 83,'), isTrue);
      expect(r.contains('height: 83,'), isTrue);
      expect(r.contains('size: 39, color: vurgulu'), isTrue);
      expect(r.contains('width: 46,'), isFalse, reason: 'eski ölçü kalmış');
      expect(r.contains('width: 64,'), isFalse, reason: 'ara ölçü kalmış');
    });

    test('yazılar büyüdü ama METİN AYNI', () {
      expect(r.contains('size: RF.s18,'), isTrue);
      expect(r.contains('size: RF.s135, weight: RF.w400, color: RC.textSoft'),
          isTrue);
      expect(r.contains("'Şu anki rolünüz'"), isTrue);
      expect(r.contains("'Geçilecek rol'"), isTrue);
      expect(r.contains("'Hizmet Veren'"), isTrue);
      expect(r.contains("'Hizmet Alan'"), isTrue);
    });

    test('geçiş oku da büyüdü, ikon dosyası AYNI', () {
      // Ok, rol logolarıyla aynı oranda büyüdü: 28 → 36.
      expect(r.contains("RefSvg('assets/svg/ic_pswap.svg',\n"
          "                  size: 36, color: RC.greyLight)"), isTrue);
    });
  });

  group('DESTEK MERKEZİ', () {
    test('yanıt süresi taahhüdü KALDIRILDI', () {
      final d = _kod('lib/data/models/support_info.dart');
      expect(d.contains('1 iş günüdür'), isFalse);
      expect(d.contains('Yanıt süresi'), isFalse);
      // Asıl davet cümlesi duruyor.
      expect(d.contains('destek ekibimize yazın.'), isTrue);
      expect(d.contains('destek@hizmetcep.com'), isTrue);
    });
  });

  group('PROFİL BİLGİLERİM — FOTOĞRAF YOK', () {
    final p = _kod('lib/screens/profile_info_screen.dart');

    test('avatar bileşeni ve fotoğraf seçme kaldırıldı', () {
      expect(p.contains('_AvatarSecici'), isFalse);
      expect(p.contains('_pickPhoto'), isFalse);
      expect(p.contains('ImagePicker'), isFalse);
      expect(p.contains('image_picker'), isFalse);
    });

    test('dört alan yerinde kaldı', () {
      for (final a in const ['Ad', 'Soyad', 'E-posta']) {
        expect(p.contains("hint: '$a'"), isTrue, reason: a);
      }
      expect(p.contains("hint: '5XX XXX XX XX'"), isTrue, reason: 'Telefon');
      expect(p.contains('RefFieldLabel('), isFalse,
          reason: 'kutu dışında etiket kalmış');
    });
  });

  group('PROFİL EKRANI — FOTOĞRAF SEÇENEKLERİ', () {
    final s = _kod('lib/screens/profile_screen.dart');

    test('avatara dokununca PANEL açılır, doğrudan galeri DEĞİL', () {
      expect(s.contains('Future<void> _fotoMenusu(BuildContext context)'),
          isTrue);
      expect(s.contains('onTap: () => _fotoMenusu(context)'), isTrue);
    });

    test('üç seçenek de var', () {
      expect(s.contains("baslik: 'Fotoğraf Çek'"), isTrue);
      expect(s.contains("baslik: 'Galeriden Yükle'"), isTrue);
      expect(s.contains("baslik: 'Fotoğrafı Kaldır'"), isTrue);
    });

    test('kaldırma seçeneği YALNIZ fotoğraf varken görünür', () {
      expect(s.contains("if (fotoYolu.trim().isNotEmpty)"), isTrue);
    });

    test('kamera ve galeri AYRI kaynaklardır', () {
      expect(s.contains('ImageSource.camera : ImageSource.gallery'), isTrue);
    });

    test('kaldırma BOŞ yol yazar', () {
      expect(s.contains("_fotoYaz(context, '', 'Profil fotoğrafı kaldırıldı')"),
          isTrue);
    });
  });

  group('⚠ KARŞI TARAFIN FOTOĞRAFI GÖRÜNÜR', () {
    // ── ⚠ KULLANICI BULGUSU (12 Eyl) ──
    //
    // "Kullanıcılar birbirlerinin profil fotoğraflarını yüklemiş
    // olsalar bile kurallara göre iletişim açıldığında veya teklif
    // istenip teklif verildikten sonra görebilmeliler. Şu anda
    // sadece kendi fotoğraflarını kendileri görebiliyorlar."
    //
    // KÖK NEDEN: fotoğraf çizen TEK yer profil ekranındaki `_Avatar`
    // sınıfıydı ve o dosyaya ÖZELDİ. Ortak avatar bileşeni
    // (`RefBasHarfAvatar`) yalnız baş harf çiziyordu. Veri vardı,
    // gösterim yoktu.

    test('ortak avatar fotoğraf çizebilir', () {
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(w.contains('class RefBasHarfAvatar'), isTrue);
      expect(w.contains('this.fotoYolu'), isTrue,
          reason: 'ortak avatar yine yalnız baş harf çiziyor');
      expect(w.contains('Image.file('), isTrue);
      // ⚠ Dosya okunamazsa çökmez, baş harfe düşer.
      expect(w.contains('errorBuilder: (_, __, ___) => basHarf'), isTrue);
    });

    test('⚠ MASKELİYKEN FOTOĞRAF OKUNMAZ', () {
      // Fotoğraf maskelemenin parçasıdır, ayrı bir kural değildir:
      // kimlik açılmadan önce karşı tarafın fotoğrafı GÖSTERİLMEZ.
      final ilan = _kod('lib/screens/job_detail_screen.dart');
      final bul = _kod('lib/screens/teklif_talebi_detay_screen.dart');
      expect(ilan.contains('fotoYolu: iletisimAcik'), isTrue,
          reason: 'ilan akışında fotoğraf iletişim kuralına bağlı değil');
      expect(bul.contains("acik ? (hesap?.fotografi(Role.customer) ?? '') : ''"),
          isTrue,
          reason: 'bul akışında fotoğraf teklif kuralına bağlı değil');
    });

    test('⚠ ROL BAZLI OKUNUR', () {
      // Çift rollü hesapta yanlış rolün fotoğrafı yanlış kimliği
      // gösterirdi: kişisel profil ile iş profili ayrı fotoğraflar.
      final ilan = _kod('lib/screens/job_detail_screen.dart');
      final bul = _kod('lib/screens/teklif_talebi_detay_screen.dart');
      final ozet = _kod('lib/domain/saglayici_ozeti.dart');
      // Karşı taraf ilan/talep sahibidir → hizmet alan rolü.
      expect(ilan.contains('fotografi(Role.customer)'), isTrue);
      expect(bul.contains('fotografi(Role.customer)'), isTrue);
      // Sağlayıcı özetinde karşı taraf hizmet verendir.
      expect(ozet.contains('fotografi(Role.provider)'), isTrue);
    });

    test('sağlayıcı özet satırı fotoğrafı geçirir', () {
      final satir = _kod('lib/screens/widgets/saglayici_ozet_satiri.dart');
      expect(satir.contains('fotoYolu: ozet.fotoYolu'), isTrue);
      // Maskeliyken hâlâ kilitli avatar çizilmeli.
      expect(satir.contains("ic_avlock"), isTrue);
    });

    test('sahip kartı fotoğrafı geçirir', () {
      final parca = _kod('lib/screens/widgets/detay_karti_parcalari.dart');
      expect(parca.contains('this.fotoYolu'), isTrue);
      expect(parca.contains('RefBasHarfAvatar('), isTrue);
    });
  });

  group('FOTOĞRAF ROL BAZLIDIR', () {
    Account hesap({Role rol = Role.customer}) => Account(
          id: 'a1',
          phone: '5321112233',
          passwordHash: 'h',
          salt: 's',
          roles: {Role.customer, Role.provider},
          activeRole: rol,
        );

    test('iki rolün fotoğrafı BAĞIMSIZ', () {
      final a = hesap();
      a.fotografAta(Role.customer, '/foto/alan.jpg');
      expect(a.fotografi(Role.customer), '/foto/alan.jpg');
      expect(a.fotografi(Role.provider), '',
          reason: 'öteki role sızmış');

      a.fotografAta(Role.provider, '/foto/veren.jpg');
      expect(a.fotografi(Role.customer), '/foto/alan.jpg');
      expect(a.fotografi(Role.provider), '/foto/veren.jpg');
    });

    test('photoPath AKTİF ROLÜN fotoğrafıdır', () {
      final a = hesap();
      a.photoPath = '/foto/alan.jpg';
      expect(a.fotografi(Role.customer), '/foto/alan.jpg');
      expect(a.fotografi(Role.provider), '');

      a.activeRole = Role.provider;
      expect(a.photoPath, '', reason: 'rol değişince öteki fotoğraf görünmeli');
      a.photoPath = '/foto/veren.jpg';
      expect(a.fotografi(Role.provider), '/foto/veren.jpg');
      expect(a.fotografi(Role.customer), '/foto/alan.jpg');
    });

    test('silme YALNIZ o rolü etkiler', () {
      final a = hesap();
      a.fotografAta(Role.customer, '/foto/alan.jpg');
      a.fotografAta(Role.provider, '/foto/veren.jpg');
      a.photoPath = '';
      expect(a.fotografi(Role.customer), '');
      expect(a.fotografi(Role.provider), '/foto/veren.jpg');
    });

    test('kurucudaki fotoğraf yalnız AKTİF role yazılır', () {
      final a = Account(
        id: 'a2',
        phone: '5321112234',
        passwordHash: 'h',
        salt: 's',
        photoPath: '/foto/ilk.jpg',
        roles: {Role.customer, Role.provider},
        activeRole: Role.provider,
      );
      expect(a.fotografi(Role.provider), '/foto/ilk.jpg');
      expect(a.fotografi(Role.customer), '');
    });
  });
}
