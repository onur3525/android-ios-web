import 'package:hizmetcep/data/controllers/chat_controller.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/notification_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/controllers/review_controller.dart';
import 'package:hizmetcep/data/controllers/wallet_controller.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/data/repositories/chat_repository.dart';
import 'package:hizmetcep/data/repositories/contact_repository.dart';
import 'package:hizmetcep/data/repositories/listing_repository.dart';
import 'package:hizmetcep/data/repositories/notification_repository.dart';
import 'package:hizmetcep/data/repositories/offer_repository.dart';
import 'package:hizmetcep/data/repositories/review_repository.dart';
import 'package:hizmetcep/data/repositories/wallet_repository.dart';

/// Bellek içi (mock) kurulum — testler somut repository'leri kurar,
/// controller'lar port üzerinden bağlanır. Uygulamadaki DI ile aynı
/// bileşimi kullanır; iş kuralları değişmeden çalışır.
class MockWiring {
  final AuthRepository authRepo;
  final WalletRepository wallets;
  final ListingRepository listings;
  final OfferRepository offers;
  final ContactRepository contacts;
  final ChatRepository chats;
  final ReviewRepository reviews;
  final NotificationRepository notifs;

  late final MockOfferPort offerPort;
  late final MockListingPort listingPort;
  late final MockWalletPort walletPort;
  late final MockContactPort contactPort;
  late final MockAuthPort authPort;
  late final MockChatPort chatPort;
  late final MockReviewPort reviewPort;
  late final MockNotificationPort notifPort;

  late final AuthController authCtl;
  late final OfferController offerCtl;
  late final ListingController listingCtl;
  late final ContactController contactCtl;
  late final WalletController walletCtl;
  late final ChatController chatCtl;
  late final ReviewController reviewCtl;
  late final NotificationController notifCtl;

  MockWiring({bool demoWallets = true, bool seedTestAccount = false})
      : authRepo = AuthRepository(seedTestAccount: seedTestAccount),
        wallets = WalletRepository(demoDefaults: demoWallets),
        listings = ListingRepository(),
        offers = OfferRepository(),
        contacts = ContactRepository(),
        chats = ChatRepository(),
        reviews = ReviewRepository(),
        notifs = NotificationRepository() {
    offerPort = MockOfferPort(offers, listings, wallets, notifs: notifs);
    listingPort = MockListingPort(listings, offers, contacts, chats, offerPort);
    walletPort = MockWalletPort(wallets);
    contactPort =
        MockContactPort(contacts, offers, wallets, listings, notifs: notifs);
    authPort = MockAuthPort(authRepo);
    chatPort = MockChatPort(chats, offers, listings,
        contacts: contacts, notifs: notifs);
    reviewPort = MockReviewPort(reviews, listings, offers, wallets, contacts);
    notifPort = MockNotificationPort(notifs);

    authCtl = AuthController(authPort);
    offerCtl = OfferController(offerPort, listingPort, walletPort);
    listingCtl = ListingController(listingPort);
    contactCtl = ContactController(contactPort, offerPort, walletPort);
    walletCtl = WalletController(walletPort, authPort);
    chatCtl = ChatController(chatPort);
    reviewCtl = ReviewController(reviewPort);
    notifCtl = NotificationController(notifPort);
  }
}
