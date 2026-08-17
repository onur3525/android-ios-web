import '../../domain/config.dart';
import '../../domain/failures.dart';
import '../models/payment.dart';
import '../models/token_package.dart';
import '../models/wallet.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// Cüzdan ve hareketler (ledger). Bakiye YALNIZ kaynağın kesin cevabından
/// sonra güncellenir; istemci tarafında iyimser güncelleme YAPILMAZ.
class WalletController extends BaseController {
  final WalletPort _wallets;
  final AuthPort _auth;
  WalletController(this._wallets, this._auth) : super([_wallets, _auth]);

  Wallet? get myWallet {
    final acc = _auth.currentAccount;
    return acc == null ? null : _wallets.walletOf(acc.id);
  }

  List<WalletTx> get ledger => myWallet?.txs ?? const [];


  Future<DomainError?> load() async {
    final acc = _auth.currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum bulunamadı');
    }
    return runLoad(() => _wallets.load(acc.id));
  }

  /// ÖDEME ADIM 1 — oturum aç.
  ///
  /// KART BİLGİSİ ALINMAZ: kullanıcı kartını sağlayıcının kendi sayfasında
  /// girer. Idempotency anahtarı BİR KEZ üretilir ve aynı yükleme denemesi
  /// boyunca korunur — tekrar denemede ikinci tahsilat oluşmaz.
  String? _idemKey;
  PaymentSession? _session;
  PaymentSession? get session => _session;

  bool get topupInFlight => isBusy('wallet:topup');
  bool get confirmInFlight => isBusy('wallet:confirm');

  // ── JETON PAKETLERİ ────────────────────────────────────────────────
  //
  // Durumlar: initial → loading → loaded | empty | error, ve refreshing.
  // Önceki başarılı liste yenileme sırasında KAYBOLMAZ.

  List<TokenPackage>? _packages;
  DomainError? _packagesError;
  bool _packagesLoading = false;
  DateTime? _packagesAt;

  /// Son başarılı liste kısa süre taze sayılır (fiyat OTORİTESİ DEĞİL;
  /// ödeme başlatılırken sunucu paketi yeniden okur).
  static const _cacheTtl = Duration(minutes: 5);

  List<TokenPackage> get packages => _packages ?? const [];
  DomainError? get packagesError => _packagesError;

  /// Hiç yüklenmemiş.
  bool get packagesInitial => _packages == null && !_packagesLoading
      && _packagesError == null;

  /// İlk yükleme (elde veri yok).
  bool get packagesLoading => _packagesLoading && _packages == null;

  /// Yenileme (elde eski veri VAR, ekran boşalmaz).
  bool get packagesRefreshing => _packagesLoading && _packages != null;

  bool get packagesLoaded => _packages != null && _packages!.isNotEmpty;
  bool get packagesEmpty =>
      _packages != null && _packages!.isEmpty && !_packagesLoading;

  /// Çevrimdışı/eski liste gösteriliyor mu? (kullanıcı bilgilendirilir)
  bool get packagesStale =>
      _packagesError != null && _packages != null && _packages!.isNotEmpty;

  /// Paketleri yükler. [force] false ise taze önbellek varsa ağ çağrısı
  /// YAPILMAZ. Aynı anda ikinci fetch başlamaz.
  Future<void> loadPackages({bool force = false}) async {
    // ÇİFT FETCH ENGELİ.
    if (_packagesLoading) {
      return;
    }

    if (!force && _packages != null && _packagesAt != null
        && DateTime.now().difference(_packagesAt!) < _cacheTtl) {
      return;
    }

    _packagesLoading = true;
    _packagesError = null;
    notifyListeners();

    final (list, err) = await _wallets.tokenPackages();
    if (err != null) {
      _packagesError = err;
      // Eski liste KORUNUR; ekran boşalmaz, kullanıcı uyarılır.
    } else {
      _packages = list ?? const [];
      _packagesAt = DateTime.now();
    }
    _packagesLoading = false;
    notifyListeners();
  }

  /// Hata ekranındaki "Tekrar Dene".
  Future<void> retryPackages() => loadPackages(force: true);

  /// Paket geçersizleştiğinde (pasif/gizli/süre) listeyi tazeler ve
  /// seçimi temizler; sahte başarı GÖSTERİLMEZ.
  Future<void> invalidatePackages() async {
    _packages = null;
    _packagesAt = null;
    await loadPackages(force: true);
  }

  /// ÖDEME ADIM 1 — paketli veya serbest tutarlı oturum açar.
  ///
  /// [packageId] verildiğinde fiyat/jeton İSTEMCİDEN GÖNDERİLMEZ; sunucu
  /// paketi kendisi okur. Böylece istemci daha düşük tutar ödeyemez.
  Future<(PaymentSession?, DomainError?)> startTopup({
    String? packageId,
    int? amount,
    /// Kayıtlı kart tokenı (varsa). Sunucu kartı sağlayıcıda doğrular;
    /// istemci ham kart verisi GÖNDERMEZ.
    String? savedCardToken,
  }) async {
    final acc = _auth.currentAccount;
    if (acc == null) return (null, const UnauthorizedError('Oturum bulunamadı'));
    if (packageId == null) {
      if (amount == null) {
        return (null, const ValidationError('Paket seçiniz'));
      }
      if (amount < DomainConfig.minTopup) {
        return (null, ValidationError(
            "Minimum yükleme tutarı ${DomainConfig.minTopup} TL'dir"));
      }
    }
    // Aynı deneme için anahtar korunur (yeniden dene → çift tahsilat YOK).
    _idemKey ??= '${acc.id}-${DateTime.now().millisecondsSinceEpoch}';

    setBusy('wallet:topup', true);
    final (s, err) = await _wallets.startTopup(
      userId: acc.id, packageId: packageId, amountTl: amount,
      savedCardToken: savedCardToken,
      idempotencyKey: _idemKey!,
    );
    setBusy('wallet:topup', false);
    if (err != null) {
      return (null, err);
    }
    _session = s;
    notifyListeners();
    return (s, null);
  }

  /// ÖDEME ADIM 2 — sonucu SUNUCUDAN doğrula.
  /// Yalnız sunucu SUCCEEDED derse bakiye artmış sayılır.
  Future<(PaymentStatus?, DomainError?)> confirmTopup() async {
    final s = _session;
    if (s == null) return (null, const NotFoundError('Ödeme oturumu yok'));
    setBusy('wallet:confirm', true);
    final (status, err) = await _wallets.confirmTopup(s.sessionId);
    setBusy('wallet:confirm', false);
    if (err != null) {
      return (null, err);
    }
    if (status == PaymentStatus.succeeded) {
      // Başarılı ödeme sonrası yeni deneme yeni anahtar alır.
      _idemKey = null;
      _session = null;
      await load();
    }
    notifyListeners();
    return (status, null);
  }

  /// Kullanıcı vazgeçti veya ekrandan çıktı — oturum temizlenir,
  /// ancak idempotency anahtarı KORUNUR (aynı tutarda tekrar denerse
  /// sunucu aynı oturumu döndürür, ikinci tahsilat olmaz).
  void resetSession() {
    _session = null;
    notifyListeners();
  }
}
