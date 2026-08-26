import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/payment.dart';
import 'package:hizmetcep/data/controllers/wallet_controller.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/data/repositories/wallet_repository.dart';
import 'package:hizmetcep/domain/config.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'support/test_config.dart';

void main() {
  group('Wallet repository bütünlük korumaları (O4)', () {
    late WalletRepository wallets;
    setUp(() => wallets = WalletRepository());

    test('production varsayılanı 0/0; demo modunda 950/150', () {
      expect(wallets.walletOf('x').avail, 0);
      expect(wallets.walletOf('x').blocked, 0);
      final demo = WalletRepository(demoDefaults: true);
      expect(demo.walletOf('y').avail, WalletRepository.demoAvail);
      expect(demo.walletOf('y').blocked, WalletRepository.demoBlocked);
    });

    test('karşılıksız bloke İMKANSIZ (negatif bakiye koruması)', () {
      wallets.topup('p', 600);
      expect(() => wallets.block('p', 700, listingTitle: 't'), throwsStateError);
      expect(wallets.walletOf('p').avail, 600); // değişmedi
    });

    test('karşılıksız tüketim ve iade İMKANSIZ', () {
      expect(() => wallets.consume('p', 10), throwsStateError);
      expect(() => wallets.refund('p', 10, reason: 'r'), throwsStateError);
      expect(wallets.walletOf('p').blocked, 0);
    });

    test('sıfır/negatif tutarlar reddedilir', () {
      expect(() => wallets.topup('p', 0), throwsArgumentError);
      expect(() => wallets.block('p', -5, listingTitle: 't'), throwsArgumentError);
    });
  });

  group('WalletController.topup (O2)', () {
    late AuthRepository auth;
    late WalletRepository wallets;
    late WalletController ctl;
    setUp(() {
      auth = AuthRepository();
      wallets = WalletRepository();
      // Controller'lar port üzerinden bağlanır; kural aynıdır.
      ctl = WalletController(MockWalletPort(wallets), MockAuthPort(auth));
    });

    test('oturum yokken ödeme oturumu AÇILAMAZ', () async {
      final (session, err) = await ctl.startTopup(amount: 600);
      expect(session, isNull);
      expect(err, isA<UnauthorizedError>());
    });

    test('minimum tutar DomainConfig.minTopup üzerinden denetlenir', () async {
      auth.girisEposta(kTestEmail, kTestPass);
      final (s1, e1) = await ctl.startTopup(amount: DomainConfig.minTopup - 1);
      expect(s1, isNull);
      expect(e1, isA<ValidationError>());
    });

    test('BAKİYE ancak backend confirm SUCCEEDED derse artar', () async {
      auth.girisEposta(kTestEmail, kTestPass);
      // ADIM 1 — oturum açılır; bakiye HENÜZ ARTMAZ.
      final (session, err) = await ctl.startTopup(amount: DomainConfig.minTopup);
      expect(err, isNull);
      expect(session, isNotNull);
      expect(session!.status, PaymentStatus.pending);
      expect(ctl.myWallet?.avail ?? 0, 0, reason: 'onaysız bakiye artmamalı');

      // ADIM 2 — sunucu doğrulaması başarılı olunca bakiye artar.
      final (status, cerr) = await ctl.confirmTopup();
      expect(cerr, isNull);
      expect(status, PaymentStatus.succeeded);
      expect(ctl.myWallet!.avail, DomainConfig.minTopup);
    });

    test('oturum yokken confirm çağrısı hata verir', () async {
      auth.girisEposta(kTestEmail, kTestPass);
      final (status, err) = await ctl.confirmTopup();
      expect(status, isNull);
      expect(err, isA<NotFoundError>());
    });
  });

  test('yeni cüzdanda usta yeterli bakiyeyi YÜKLEmeden teklif veremez (0/0 + akış)', () {
    // production cüzdanıyla uçtan uca: 0 bakiye → topup → bloke mümkün
    final wallets = WalletRepository();
    wallets.topup('p1', DomainConfig.minTopup);
    wallets.block('p1', DomainConfig.contactFee, listingTitle: 'İlan');
    expect(wallets.walletOf('p1').avail, DomainConfig.minTopup - DomainConfig.contactFee);
    expect(wallets.walletOf('p1').blocked, DomainConfig.contactFee);
  });

  test('kTestOtp yalnız test ortamında tanımlıdır', () {
    expect(kTestOtp, '123456'); // lib/ altında bu sabit YOKTUR
  });
}
