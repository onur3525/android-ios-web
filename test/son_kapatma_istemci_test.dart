// SON KAPATMA TURU — istemci tarafı
//   · "Bul": sunucu yanıtı → kart kaydı (gizli alan yok, bozuk satır atlanır)
//   · Profil fotoğrafı: sunucudaki imzalı adresler hesaba rol bazlı okunur
//   · API modunda Bul / talep değerlendirmesi / profil fotoğrafı / ilan
//     idempotency bağlantıları kaynakta kilitlenir
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/remote/mappers.dart';
import 'package:hizmetcep/screens/sonuclar_screen.dart';

String _kod(String yol) => const LineSplitter()
    .convert(File(yol).readAsStringSync())
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('BUL — sunucu yanıtı', () {
    test('alanlar çevrilir; sıralama ilçesi hizmet bölgesinden, gösterilen konum adresten', () {
      final l = saglayicilariSunucudanCevir([
        {
          'id': 'u1', 'name': 'Ali Usta',
          'address': {'city': 'İzmir', 'district': 'Bornova'},
          'serviceDistricts': ['Konak', 'Bornova'],
          'rating': 4.5, 'reviewCount': 2, 'completedJobs': 3,
          'photoUrl': 'https://depo/x.jpg?X-Amz-Signature=1',
        },
        {'id': 'u2', 'name': 'Veli', 'address': null, 'serviceDistricts': []},
        {'id': 5, 'name': 'bozuk'},
        'bozuk',
      ], musteriIlcesi: 'Konak');
      expect(l.length, 2, reason: 'bozuk satırlar atlanır, çökme yok');
      expect(l[0].gercek, isTrue);
      expect(l[0].ilce, 'Konak');
      expect(l[0].adresIlcesi, 'Bornova');
      expect(l[0].puan, 4.5);
      expect(l[0].yorumSayisi, 2);
      expect(l[0].tamamlananIs, 3);
      expect(l[0].fotoUrl, startsWith('https://'));
      expect(l[1].adresIlcesi, isNull, reason: 'adres yoksa konum uydurulmaz');
      expect(l[1].yorumSayisi, 0);
      expect(l[1].fotoUrl, isEmpty);
    });

    test('API modunda sunucudan çekilir; yükleniyor/hata ayrı çizilir', () {
      final k = _kod('lib/screens/sonuclar_screen.dart');
      expect(k.contains('if (ApiConfig.useRealApi) {'), isTrue);
      expect(k.contains('SaglayiciApi(context.read<ApiClient>())'), isTrue);
      expect(k.contains('if (_yukleniyor)'), isTrue);
      expect(k.contains('else if (_hata != null)'), isTrue);
      expect(_kod('lib/data/remote/api/saglayici_api.dart')
          .contains("c.getList('/providers/search'"), isTrue);
    });
  });

  group('PROFİL FOTOĞRAFI', () {
    test('sunucudaki imzalı adresler role göre hesaba yazılır', () {
      final a = Mappers.account({
        'id': 'u1', 'name': 'T', 'email': '', 'phone': '5321112233',
        'roles': ['CUSTOMER', 'PROVIDER'], 'activeRole': 'PROVIDER',
        'photos': {'customer': null, 'provider': 'https://depo/p.jpg'},
      });
      expect(a.fotografi(Role.provider), 'https://depo/p.jpg');
      expect(a.fotografi(Role.customer), isEmpty);
    });

    test('API modunda yerel yol sunucuya referans diye GİTMEZ; yüklenir', () {
      final p = _kod('lib/data/ports/api_ports.dart');
      expect(p.contains('repo.profilFotografiniKaydet(photoPath, acc.activeRole)'),
          isTrue);
      // 29 Eki: yükleme tek kaynakta (`fotograf_yukleyici.dart`; sohbet
      // fotoğraflarıyla aynı yol). Profil bu yolu `profile-photo` ile çağırır.
      final r = _kod('lib/data/remote/repositories/api_repositories.dart');
      expect(r.contains("FotografYukleyici.yukle(_client, yol, tur: 'profile-photo')"), isTrue);
      final y = _kod('lib/data/remote/fotograf_yukleyici.dart');
      expect(y.contains('s.uploadBytes('), isTrue);
      expect(y.contains('s.discardPending('), isTrue,
          reason: 'yarım yükleme temizlenir');
      expect(_kod('lib/data/remote/api/profile_api.dart')
          .contains("{'photoRef': ref, 'photoRole': role}"), isTrue);
    });

    test('uzak (https) adres mobilde ağdan çizilir', () {
      final k = _kod('lib/core/platform/yerel_gorsel_io.dart');
      expect(k.contains("yol.startsWith('https://')"), isTrue);
      // 28 Eki: ağdan çizim kalıcı önbellekli ortak bileşenle (agGorseli).
      expect(k.contains('agGorseli('), isTrue);
    });
  });

  group('API BAĞLANTILARI', () {
    test('talep değerlendirmesi gerçek uca gider; "desteklenmiyor" kalmadı', () {
      final p = _kod('lib/data/ports/api_ports.dart');
      expect(p.contains('desteklenmiyor'), isFalse);
      expect(p.contains('repo.submitTalep(talepId: talepId'), isTrue);
      expect(_kod('lib/data/remote/api/review_api.dart')
          .contains("c.post('/teklif-talepleri/\$talepId/review'"), isTrue);
    });

    test('ilan, teklif talebi ve talep mesajı Idempotency-Key taşır', () {
      expect(_kod('lib/data/remote/api/listing_api.dart')
          .contains("c.post('/listings', idempotencyKey:"), isTrue);
      final t = _kod('lib/data/remote/api_teklif_talebi_port.dart');
      expect(t.contains("_c.post('/teklif-talepleri', idempotencyKey:"), isTrue);
      expect(t.contains("_c.post('/teklif-talepleri/\$id/mesajlar', idempotencyKey:"),
          isTrue);
    });
  });
}
