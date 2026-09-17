import '../../domain/failures.dart';
import '../models/account.dart';
import '../models/provider_approval.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// Profil, adresler, kategoriler ve hizmet bölgeleri.
class ProfileController extends BaseController {
  final AuthPort _auth;
  ProfileController(this._auth) : super([_auth]);

  Account? get me => _auth.currentAccount;
  /// Hizmet veren platform onay durumu (yüklenene kadar null).
  ProviderApprovalState? _approval;
  ProviderApprovalState? get approval => _approval;

  /// Onaysızken teklif verilemez — ekranlar bunu kullanır.
  bool get canPlaceOffer => _approval?.canPlaceOffer ?? false;

  Future<void> loadApproval() async {
    _approval = await _auth.providerApproval();
    notifyListeners();
  }

  /// TEK adres (kayıt yoksa null).
  Address? get address => me?.address;
  Set<String> get categories => me?.categories ?? const {};
  Set<String> get districts => me?.serviceDistricts ?? const {};

  Future<DomainError?> updateProfile({String? name, String? photoPath}) =>
      runAction('profile:update',
          () => _auth.updateProfile(name: name, photoPath: photoPath));

  /// E-POSTA DEĞİŞİMİ — yeni adrese doğrulama bağlantısı yollanır.
  ///
  /// ⚠ Hesabın e-postası bu çağrıyla DEĞİŞMEZ (iş kuralları §4).
  Future<DomainError?> epostaDegisimiBaslat(String yeniEposta) =>
      runAction('profile:email-change',
          () => _auth.epostaDegisimiBaslat(yeniEposta));

  /// TEK ADRES — güncelleme. Ekleme/silme YOKTUR.
  Future<DomainError?> saveAddress({
    required String district,
    required String neighborhood,
    required String city,
  }) =>
      runAction('address:save',
          () => _auth.saveAddress(
              district: district, neighborhood: neighborhood, city: city));


  Future<DomainError?> setCategories(Set<String> categories) =>
      runAction('prefs:categories', () => _auth.setProviderPrefs(categories: categories));

  Future<DomainError?> setDistricts(Set<String> districts) =>
      runAction('prefs:districts', () => _auth.setProviderPrefs(districts: districts));
}
