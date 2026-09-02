import '../../domain/failures.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// İletişim açma. Bloke TEK KEZ tüketilir; çift tıklama engellenir ve
/// sonuç kesinleşmeden açık gösterilmez.
class ContactController extends BaseController {
  final ContactPort _contacts;

  /// ⚠ `OfferPort` ALAN OLARAK TUTULMAZ, yalnız MEŞGUL DURUMU için
  /// üst sınıfa verilir. Alan olarak saklandığında hiç okunmuyor ve
  ContactController(this._contacts, OfferPort offers)
      : super([_contacts, offers]);

  bool isOpen(String offerId) => _contacts.isOpen(offerId);

  Future<DomainError?> refresh(String offerId) =>
      runLoad(() => _contacts.refresh(offerId));

  /// İLETİŞİM AÇMA — idempotent.
  ///
  /// ⚠ "ZATEN AÇIK" HATA SAYILMAZ (§10). Sunucu ikinci istekte
  /// `COMMUNICATION_ALREADY_OPEN` dönebilir; istenen durum zaten
  /// sağlandığı için bunu BAŞARI gibi ele alırız. Aksi hâlde
  /// kullanıcı çift tıkladığında gereksiz kırmızı hata görürdü.
  Future<DomainError?> openShared(String offerId,
      {required String actorId}) async {
    final err = await runAction(
      'contact:open:$offerId',
      () => _contacts.openShared(offerId, actorId: actorId),
      onSuccess: () async {
        await _contacts.refresh(offerId);
      },
    );
    if (err is IletisimZatenAcikError) {
      // Durumu tazele ki ekran açık hâli çizsin.
      await _contacts.refresh(offerId);
      return null;
    }
    return err;
  }
}
