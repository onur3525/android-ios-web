import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/wallet.dart';

/// Hizmet veren cüzdanları (providerId → Wallet).
/// Repository seviyesinde BÜTÜNLÜK korumaları vardır: negatif bakiye,
/// sıfır/negatif tutar ve karşılıksız tüketim/iade işlemleri reddedilir.
class WalletRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final Map<String, Wallet> _wallets = {};

  /// Demo modunda yeni cüzdanlar prototip bakiyesiyle açılır (950/150);
  /// production varsayılanı 0/0'dır.
  final bool demoDefaults;
  static const int demoAvail = 950;
  static const int demoBlocked = 150;

  WalletRepository({this.demoDefaults = false});

  Wallet walletOf(String providerId) => _wallets.putIfAbsent(
      providerId,
      () => demoDefaults
          ? Wallet(avail: demoAvail, blocked: demoBlocked)
          : Wallet());

  void _tx(String providerId, TxKind k, String title, String sub, int amount) {
    walletOf(providerId).txs.insert(0,
        WalletTx(id: _uuid.v4(), kind: k, title: title, sub: sub, amount: amount));
  }

  void _requirePositive(int amount) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Tutar pozitif olmalı');
    }
  }

  void topup(String providerId, int amount) {
    _requirePositive(amount);
    walletOf(providerId).avail += amount;
    _tx(providerId, TxKind.load, 'Bakiye Yükleme', 'Kredi Kartı ile yükleme', amount);
    notifyListeners();
  }

  /// Teklif blokesi: kullanılabilir → bloke. Karşılıksız bloke İMKANSIZ.
  void block(String providerId, int amount, {required String listingTitle}) {
    _requirePositive(amount);
    final w = walletOf(providerId);
    if (w.avail < amount) {
      throw StateError('Bütünlük ihlali: kullanılabilir bakiye ($providerId) '
          '${w.avail} < bloke $amount');
    }
    w.avail -= amount;
    w.blocked += amount;
    _tx(providerId, TxKind.block, 'Teklif Blokesi', 'İlan: $listingTitle', -amount);
    notifyListeners();
  }

  /// İletişim tüketimi: bloke düşer, kullanılabilir SABİT kalır.
  void consume(String providerId, int amount) {
    _requirePositive(amount);
    final w = walletOf(providerId);
    if (w.blocked < amount) {
      throw StateError('Bütünlük ihlali: bloke ($providerId) '
          '${w.blocked} < tüketim $amount');
    }
    w.blocked -= amount;
    _tx(providerId, TxKind.contact, 'İletişim Açma Ücreti',
        'Teklif blokesinden tüketildi', -amount);
    notifyListeners();
  }

  /// İade: bloke → kullanılabilir. Karşılıksız iade İMKANSIZ.
  void refund(String providerId, int amount, {required String reason}) {
    _requirePositive(amount);
    final w = walletOf(providerId);
    if (w.blocked < amount) {
      throw StateError('Bütünlük ihlali: bloke ($providerId) '
          '${w.blocked} < iade $amount');
    }
    w.blocked -= amount;
    w.avail += amount;
    _tx(providerId, TxKind.refund, 'Bloke İadesi', reason, amount);
    notifyListeners();
  }
}
