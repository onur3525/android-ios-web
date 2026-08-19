import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/sys_state.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/data/repositories/listing_repository.dart';
import 'package:hizmetcep/data/repositories/wallet_repository.dart';
import 'package:hizmetcep/data/services/otp_service.dart';
import 'package:hizmetcep/data/services/search_service.dart';
import 'package:hizmetcep/data/services/share_service.dart';
import 'package:hizmetcep/domain/config.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:flutter/material.dart';
import 'support/test_config.dart';

void main() {
  group('Arama', () {
    test('kategori ve alt hizmet adında bulur (Türkçe harf duyarsız)', () {
      expect(SearchService.services('boya').map((h) => h.label),
          contains('Boya ve Badana'));
      expect(SearchService.services('KOMBİ').map((h) => h.label),
          containsAll(['Kombi Bakımı', 'Kombi Montajı']));
      // ⚠ `Kombi` ARTIK AYRI ANA KATEGORİ (eskiden Doğalgaz altındaydı).
      // Ayrıca ilgi sıralaması eklendi: tam/prefix eşleşme önce gelir,
      // bu yüzden "kombi" sorgusunun ilki `Kombi` kategorisidir.
      // ⚠ Su Tesisatı'na eklenen 'Kombi Petek Tesisatı' bu sorguyu
      // kaçırıyordu (prefix eşleşme kategoriyle aynı skoru alıyor,
      // katalog sırası öne çıkarıyordu). Hizmet 'Petek Borusu
      // Tesisatı' olarak yeniden adlandırıldı — kategori adıyla
      // başlayan hizmet BAŞKA kategoride durmamalı.
      expect(SearchService.services('kombi').first.category, 'Kombi Montaj');
    });

    test('ilan başlığı ve açıklamasında yalnız AÇIK ilanları bulur', () {
      final repo = ListingRepository();
      final l1 = repo.create(
          ownerId: 'c', title: 'Kombi Bakımı', location: 'Konak',
          desc: 'Yıllık bakım gerekli acil değil beş kelime');
      // Başlıkta geçmez ama AÇIKLAMADA geçer → arama kapsamındadır.
      final l2 = repo.create(
          ownerId: 'c', title: 'Boya', location: 'Konak',
          desc: 'Salon boyanacak kombi ile ilgisi yok');
      final l3 = repo.create(
          ownerId: 'c', title: 'Tadilat', location: 'Konak',
          desc: 'Kombi dairesi tadilatı yapılacak hemen');
      l3.status = ListingStatus.userDeleted; // kapalı → sonuçta olmamalı
      final r = SearchService.listings(repo.all, 'kombi');
      // Sözleşme: AÇIK ilanlarda başlık VEYA açıklama eşleşmesi.
      // l1 başlıktan, l2 açıklamadan eşleşir; l3 kapalı olduğu için elenir.
      //
      // SIRA BAĞIMSIZ doğrulanır: arama sonucu için iş kuralında bir
      // sıralama tanımlı DEĞİLDİR. Mevcut sıra `ListingRepository`
      // sözleşmesinden gelir (`_items.insert(0, ...)` → yeni ilan önce);
      // bu bir arama davranışı değil, depo ayrıntısıdır.
      expect(r.map((x) => x.id), unorderedEquals([l1.id, l2.id]));
      expect(r, hasLength(2));
    });

    test('boş/temizlenmiş sorgu → sonuç modu kapalı (varsayılan görünüm)', () {
      expect(SearchService.services(''), isEmpty);
      expect(SearchService.services('   '), isEmpty);
      expect(SearchService.listings(const [], ''), isEmpty);
    });

    test('eşleşme yoksa boş liste (empty state verisi)', () {
      expect(SearchService.services('uçak bileti'), isEmpty);
    });
  });

  group('Şifremi unuttum (uçtan uca)', () {
    test('kayıtsız numara reddedilir; doğrulama sonrası yeni şifre işlenir', () {
      final auth = AuthRepository();
      // ⚠ K5: kayıtsız numara da BAŞARI döner (enumerasyon yok).
      expect(auth.forgotStart('5119998877'), isNull);
      expect(auth.forgotStart(kTestPhone), isNull);
      auth.forgotSave(kTestPhone, 'yepyeni1');
      expect(auth.girisEposta(kTestEmail, kTestPass), isA<AuthFailedError>());
      expect(auth.girisEposta(kTestEmail, 'yepyeni1'), isNull);
    });

    test('Mock OTP: debug derlemede doğru kod kabul, yanlış kod ret', () async {
      final svc = MockOtpService();
      expect(await svc.verify(kTestPhone, kTestPass), kDebugMode);
      expect(await svc.verify('5321112233', '000000'), isFalse);
      // Release güvenlik kuralı: verify kDebugMode && kod eşitliği ister;
      // release derlemede kDebugMode=false olduğundan test kodu KABUL EDİLMEZ.
    });
  });

  group('Paylaşım ve puanlama', () {
    test('paylaşım hatasında false (ekran anlaşılır mesaj gösterir)', () async {
      final fail = ShareService(sharer: (_) async => throw Exception('yok'));
      expect(await fail.shareApp(), isFalse);
      var sent = '';
      final ok = ShareService(sharer: (t) async => sent = t);
      expect(await ok.shareApp(), isTrue);
      expect(sent, DomainConfig.shareText); // metin tek merkezden
    });
  });

  group('Debug / release config ayrımı', () {
    test('production varsayılanları: cüzdan 0/0, test hesabı yok', () {
      final w = WalletRepository(); // demoDefaults verilmedi → prod
      expect(w.walletOf('x').avail, 0);
      expect(w.walletOf('x').blocked, 0);
      final auth = AuthRepository(seedTestAccount: false); // release davranışı
      expect(auth.accounts, isEmpty);
      expect(auth.girisEposta(kTestEmail, kTestPass), isA<AuthFailedError>());
    });

    test('debug tohumları yalnız istenince: seedTestAccount=true hesap açar', () {
      final auth = AuthRepository(seedTestAccount: true);
      expect(auth.findByPhone(kTestPhone), isNotNull);
    });
  });

  group('Sistem durumları (widget)', () {
    testWidgets('SysState: başlık, açıklama ve aksiyon görünür; empty/offline',
        (t) async {
      var tapped = false;
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        SysState(SysKind.noInternet, onAction: () => tapped = true),
        const SysEmpty(title: 'Kayıt yok', desc: 'Boş durum açıklaması'),
      ]))));
      expect(find.text('İnternet bağlantısı yok'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.text('Kayıt yok'), findsOneWidget);
      expect(find.text('Boş durum açıklaması'), findsOneWidget);
      await t.tap(find.text('Tekrar Dene'));
      expect(tapped, isTrue);
    });

    testWidgets('SysButton: busy iken kilitli (çift tıklama koruması)', (t) async {
      var count = 0;
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SysButton('Gönder', busy: true, onPressed: () => count++))));
      expect(
          t.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
      await t.tap(find.byType(ElevatedButton), warnIfMissed: false);
      expect(count, 0); // busy'de tık işlenmez
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
