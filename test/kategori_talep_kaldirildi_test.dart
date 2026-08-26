// KATEGORİ TALEP ETME — KULLANICI TARAFINDA YOK
//
// İŞ KURALI: yeni ana kategori / alt hizmet TANIMLAMA yetkisi YALNIZ
// ADMİNDEDİR. Hizmet veren uygulamadan kategori öneremez; "Yeni Hizmet
// Ekle" kartı (Kategori Seç + Alt Kategori Adı + Kategori Talep Et)
// Hizmet Kategorilerim ekranından tamamen kaldırılmıştır.
//
// ⚠ Bu dosya KAYNAK METNİ denetler ve YORUM SATIRLARINI ELER; aksi
// hâlde silme gerekçesini anlatan açıklamalar yanlış alarm verir.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';

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

/// Kategori seçimi yapılan TÜM kullanıcı ekranları.
const _secimEkranlari = [
  'lib/screens/my_categories_screen.dart',
  'lib/screens/role_switch_screen.dart',
  'lib/screens/register_screen.dart',
  'lib/screens/widgets/kategori_secim_paneli.dart',
];

void main() {
  group('HİZMET KATEGORİLERİM — TALEP KUTUSU YOK', () {
    final k = _kod('lib/screens/my_categories_screen.dart');

    test('"Yeni Hizmet Ekle" başlığı yok', () {
      expect(k.contains('Yeni Hizmet Ekle'), isFalse);
      expect(k.contains('Sistemde bulunmayan bir alt kategori'), isFalse);
    });

    test('"Alt Kategori Adı" alanı ve sayacı yok', () {
      expect(k.contains('Alt Kategori Adı'), isFalse);
      expect(k.contains('Alt kategori adını yazın'), isFalse);
      expect(k.contains('buildCounter'), isFalse);
    });

    test('"Kategori Seç" açılır listesi yok', () {
      expect(k.contains('RefRegDropdown'), isFalse);
      expect(k.contains("title: 'Kategori Seç'"), isFalse);
    });

    test('"Kategori Talep Et" düğmesi ve gönderimi yok', () {
      expect(k.contains('Kategori Talep Et'), isFalse);
      expect(k.contains('Talebiniz alındı'), isFalse);
      expect(k.contains('_talepGonder'), isFalse);
      expect(k.contains('_yeniHizmetKutusu'), isFalse);
    });

    test('talep formunun durum alanları kalmadı', () {
      for (final alan in ['_yeniAd', '_yeniAna', '_yeniHata', '_yeniGonderiliyor']) {
        expect(k.contains(alan), isFalse, reason: alan);
      }
    });

    test('yanlış bilgi veren mavi kutu kalmadı', () {
      // Talep gönderilemediği için "kontrol edilip eklenecektir"
      // cümlesi artık doğru değildi.
      expect(k.contains('kontrol edilip uygun olması halinde'), isFalse);
      expect(k.contains('RefInfoBox'), isFalse);
    });

    test('alt başlık yeni kategori ekleme VAAT ETMEZ', () {
      expect(k.contains('yeni bir alt kategori ekleyin'), isFalse);
      expect(k.contains('Hizmet verdiğiniz hizmet kategorilerini seçin.'),
          isTrue);
    });

    test('"Hizmet Taleplerim" listesi de yok', () {
      expect(k.contains('Hizmet Taleplerim'), isFalse);
      expect(k.contains('_requestsBlock'), isFalse);
      expect(k.contains('_requests'), isFalse);
      expect(k.contains('Değerlendirmede'), isFalse);
      expect(k.contains('requestedName'), isFalse);
    });

    test('ekran HİÇ ağ çağrısı yapmaz', () {
      // Talep uçları gidince bu ekranın tek veri kaynağı
      // `ProfileController` kaldı; doğrudan HTTP kurulumu yok.
      expect(k.contains('ApiClient'), isFalse);
      expect(k.contains('ApiConfig'), isFalse);
      expect(k.contains('CategoryRequestApi'), isFalse);
    });

    test('ölü `_KategoriCipi` sınıfı da silindi', () {
      expect(k.contains('class _KategoriCipi'), isFalse);
    });

    test('SEÇİM işlevi bozulmadı', () {
      // Silinen yalnız TALEP akışıdır; arama, seçim ve kaydetme durur.
      expect(k.contains('out.length >= 6'), isTrue, reason: 'arama kayboldu');
      expect(k.contains('setCategories(_selected)'), isTrue,
          reason: 'kaydetme kayboldu');
      // ⚠ METİN TEK KAYNAĞA TAŞINDI (`FormMesaj.kategoriSec`).
      // Aynı kural üç ekranda üç farklı cümleyle yazılıyordu; uyarının
      // VARLIĞI korunuyor, yazımı standartlaştı.
      expect(k.contains('FormMesaj.kategoriSec'), isTrue);
      expect(k.contains('Seçili Hizmetlerim'), isTrue);
    });
  });

  group('HİÇBİR KULLANICI EKRANINDA TALEP GÖNDERİMİ YOK', () {
    for (final yol in _secimEkranlari) {
      test('${yol.split('/').last} talep OLUŞTURMAZ', () {
        final s = _kod(yol);
        expect(s.contains('.create(requestedName'), isFalse, reason: yol);
        expect(s.contains('requestedName:'), isFalse, reason: yol);
        expect(s.contains('Kategori Talep Et'), isFalse, reason: yol);
      });
    }

    test('talep API dosyası SİLİNDİ', () {
      // ⚠ Uç tanımı bile bırakılmadı: çağrılmayan `*Api` sınıfı ölü
      // koddur ve ileride yanlışlıkla yeniden bağlanmaya davetiyedir.
      expect(File('lib/data/remote/api/category_request_api.dart').existsSync(),
          isFalse);
    });

    test('lib/ içinde talep ucuna DEĞEN dosya yok', () {
      final degenler = <String>[];
      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) {
          continue;
        }
        final s = _kod(e.path);
        if (s.contains('categories/requests') ||
            s.contains('CategoryRequestApi')) {
          degenler.add(e.path);
        }
      }
      expect(degenler, isEmpty, reason: 'talep ucuna değen dosya: $degenler');
    });
  });

  group('SEÇİM DAVRANIŞI — PANEL İLE AYNI', () {
    final k = _kod('lib/screens/my_categories_screen.dart');
    final p = _kod('lib/screens/widgets/kategori_secim_paneli.dart');

    test('eklemeden sonra arama TEMİZLENİR', () {
      // ⚠ Panel bunu yapıyordu, profil ekranı yapmıyordu: arama
      // metni kalınca öneri listesi ekranı kaplıyor ve kullanıcı
      // seçtiği hizmeti göremiyordu.
      expect(p.contains('_ara.clear();'), isTrue, reason: 'panel bozulmuş');

      final i = k.indexOf('void _toggle(String name)');
      expect(i, greaterThan(0));
      final govde = k.substring(i, k.indexOf('\n  }', i));
      expect(govde.contains('_search.clear();'), isTrue,
          reason: 'ekleme sonrası arama temizlenmiyor');
    });

    test('KALDIRMADA arama temizlenmez', () {
      // Çipteki X'e basınca kullanıcı arama yapmıyor olabilir;
      // yazdığı metni silmek yanlış olur.
      final i = k.indexOf('void _toggle(String name)');
      final govde = k.substring(i, k.indexOf('\n  }', i));
      final iKaldir = govde.indexOf('_selected.remove(name);');
      final iEkle = govde.indexOf('_selected.add(name);');
      final iClear = govde.indexOf('_search.clear();');
      expect(iKaldir, greaterThan(-1));
      expect(iClear, greaterThan(iEkle),
          reason: 'temizleme ekleme dalında olmalı');
      expect(iClear, greaterThan(iKaldir));
    });

    test('seçilenler AYNI ekranda çip olarak görünür', () {
      // Kullanıcı ekrandan çıkmadan seçtiklerini görebilmeli.
      expect(k.contains("Seçili Hizmetlerim (\${_selected.length})"), isTrue);
      expect(k.contains('for (final c in _selected)'), isTrue);
      // Çipten kaldırma da aynı ekranda.
      expect(k.contains('onTap: _saving ? null : () => _toggle(c)'), isTrue);
    });

    test('boş seçimde kaydet PASİF', () {
      expect(k.contains('onPressed: _selected.isEmpty ? null : _save'), isTrue);
    });
  });

  group('SON HİZMET KORUNUR (iş kuralı)', () {
    test('depo BOŞ küme kabul etmez', () {
      final auth = AuthRepository(seedTestAccount: false);
      final r = auth.register(
        phone: '5551110000',
        pass: 'abc123',
        email: 'usta@example.com',
        role: Role.provider,
        otpVerified: true,
        termsAccepted: true,
        categories: {'Temizlik Hizmetleri'},
        serviceDistricts: {'Karşıyaka'},
      );
      expect(r.error, isNull);
      final acc = r.account!;

      // ⚠ Boş küme REDDEDİLİR ve mevcut seçim BOZULMAZ.
      expect(auth.setProviderPrefs(categories: {}), isNotNull);
      expect(acc.categories, {'Temizlik Hizmetleri'});
      expect(auth.setProviderPrefs(districts: {}), isNotNull);
      expect(acc.serviceDistricts, {'Karşıyaka'});

      // Dolu küme geçer.
      expect(auth.setProviderPrefs(categories: {'Su Tesisatı'}), isNull);
      expect(acc.categories, {'Su Tesisatı'});
    });

    test('DEĞİŞTİRME yolu kapanmaz: önce ekle, sonra kaldır', () {
      final auth = AuthRepository(seedTestAccount: false);
      final r = auth.register(
        phone: '5551110001',
        pass: 'abc123',
        email: 'usta2@example.com',
        role: Role.provider,
        otpVerified: true,
        termsAccepted: true,
        categories: {'Temizlik Hizmetleri'},
        serviceDistricts: {'Karşıyaka'},
      );
      final acc = r.account!;
      // İki hizmetle kaydet…
      expect(
          auth.setProviderPrefs(
              categories: {'Temizlik Hizmetleri', 'Su Tesisatı'}),
          isNull);
      // …sonra eskisini bırak.
      expect(auth.setProviderPrefs(categories: {'Su Tesisatı'}), isNull);
      expect(acc.categories, {'Su Tesisatı'});
    });

    test('EKRANLAR son çipin kaldırılmasını engeller', () {
      // İki seçim ekranı da aynı kuralı ve AYNI metni kullanır.
      for (final f in const [
        'lib/screens/my_categories_screen.dart',
        'lib/screens/widgets/kategori_secim_paneli.dart',
      ]) {
        final k = _kod(f);
        expect(k.contains('En az bir hizmet kategorisi seçili olmalıdır.'),
            isTrue,
            reason: f);
        expect(k.contains('length == 1'), isTrue, reason: f);
      }
    });

    test('KURAL BİLDİRİMİ hata gibi sunulmaz', () {
      // ⚠ "Bir sorun oluştu — …" öneki kullanıcıya ARIZA varmış gibi
      // geliyordu; oysa uygulama doğru çalışıyor, kural izin vermiyor.
      final c = _kod('lib/core/sys_state.dart');
      expect(c.contains('void sysToastKural('), isTrue);

      for (final f in const [
        'lib/screens/my_categories_screen.dart',
        'lib/screens/widgets/kategori_secim_paneli.dart',
      ]) {
        final k = _kod(f);
        expect(k.contains('sysToastKural('), isTrue, reason: f);
        expect(k.contains('SysKind.genericError'), isFalse,
            reason: '$f: kural hatası genel hata olarak gösteriliyor');
      }
    });
  });
}
