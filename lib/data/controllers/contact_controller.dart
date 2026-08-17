import '../../domain/failures.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// İletişim açma. Bloke TEK KEZ tüketilir; çift tıklama engellenir ve
/// sonuç kesinleşmeden açık gösterilmez.
class ContactController extends BaseController {
  final ContactPort _contacts;
  final WalletPort _wallets;

  /// ⚠ `OfferPort` ALAN OLARAK TUTULMAZ, yalnız MEŞGUL DURUMU için
  /// üst sınıfa verilir. Alan olarak saklandığında hiç okunmuyor ve
  /// analyzer `unused_field` uyarısı üretiyordu; kaldırıldı, ama
  /// `super` listesinden ÇIKARILMADI — iletişim açılırken teklif
  /// portu da meşgulse düğme yine pasif kalmalıdır.
  ContactController(this._contacts, OfferPort offers, this._wallets)
      : super([_contacts, offers, _wallets]);

  bool isOpen(String offerId) => _contacts.isOpen(offerId);

  Future<DomainError?> refresh(String offerId) =>
      runLoad(() => _contacts.refresh(offerId));

  Future<DomainError?> openShared(String offerId, {required String actorId}) =>
      runAction(
        'contact:open:$offerId',
        () => _contacts.openShared(offerId, actorId: actorId),
        onSuccess: () async {
          await _contacts.refresh(offerId);
          await _wallets.load(actorId); // tüketim sonrası bakiye sunucudan
        },
      );
}
