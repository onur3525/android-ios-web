import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/controllers/chat_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/notification_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/account.dart' show Role;
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import '../data/remote/ws_client.dart';
import 'katalog_tazeleme.dart';

/// Haber türüne göre yapılacak tazeleme işleri.
enum TazelemeIsi {
  /// Bildirim listesi ve rozet (her haberde).
  bildirimler,

  /// Hizmet verenin "Yeni işler" listesi.
  yeniIsler,

  /// Hizmet verenin kendi teklifleri (ve teklif verdiği ilanlar).
  tekliflerim,

  /// Hizmet alanın ilanları ve gelen teklifleri.
  ilanlarim,

  /// Doğrudan teklif talepleri (iki taraf).
  talepler,

  /// İlan sohbetlerinin okunmamış mesaj sayıları (kartlardaki "yeni
  /// mesaj" işareti; 29 Eki).
  sohbetler,
}

/// ═══════════════════════════════════════════════════════════════
/// ANLIK TAZELEME — TEK KAYNAK (28 Eki, kullanıcı kararı)
///
/// "Ekran 30 saniyede bir yenilenmesin; yeni teklif veya ilan gelince
/// yenilensin." Ekranlardaki 30 sn'lik zamanlayıcılar kaldırıldı. Veri
/// yalnız şu durumlarda, SESSİZCE (yükleniyor göstergesi olmadan) ve
/// YALNIZ İLGİLİ KISMI tazelenir:
///
///   · Sunucudan anlık haber gelince (açık bağlantı, `notification.new`)
///   · Uygulama açıkken push bildirimi gelince (`PushKapisi`)
///   · Uygulama/sekme arka plandan öne gelince
///   · Kopan anlık bağlantı yeniden kurulunca (kaçan haber olabilir)
///
/// Aynı anda gelen haberler (ör. push + anlık bağlantı aynı olay için)
/// kısa bir bekleme içinde BİRLEŞTİRİLİR; her iş bir kez yapılır. Veri
/// değişmediyse depolar haber vermez, ekran yeniden çizilmez.
/// ═══════════════════════════════════════════════════════════════
class AnlikTazeleme {
  AnlikTazeleme._();

  static const Duration birlestirme = Duration(milliseconds: 400);

  /// Haber türü → yapılacak işler (etkin role göre). Bilinmeyen tür
  /// yalnız bildirimleri tazeler.
  static Set<TazelemeIsi> isler(String? tur, Role rol) {
    // 29 Eki: karşı taraf mesajı aldı/okudu → yalnız talepler (tikler);
    // bildirim listesi değişmedi.
    if (tur == 'TALEP_DURUM') {
      return {TazelemeIsi.talepler};
    }
    final saglayici = rol == Role.provider;
    final s = {TazelemeIsi.bildirimler};
    switch (tur) {
      case 'NEW_LISTING':
        if (saglayici) s.add(TazelemeIsi.yeniIsler);
      case 'NEW_OFFER':
      case 'OFFER_SELECTED':
      case 'CONTACT_OPENED':
      case 'LISTING_EXPIRED':
        s.add(saglayici ? TazelemeIsi.tekliflerim : TazelemeIsi.ilanlarim);
      case 'NEW_MESSAGE':
        s.add(TazelemeIsi.sohbetler);
      case 'TALEP_REQUEST':
      case 'TALEP_OFFER':
      case 'TALEP_ACCEPTED':
      case 'TALEP_DECLINED':
      case 'TALEP_MESSAGE':
        s.add(TazelemeIsi.talepler);
    }
    return s;
  }

  /// Öne gelme / yeniden bağlanma: etkin rolün bütün listeleri.
  static Set<TazelemeIsi> hepsi(Role rol) => {
        TazelemeIsi.bildirimler,
        TazelemeIsi.talepler,
        TazelemeIsi.sohbetler,
        if (rol == Role.provider) ...[TazelemeIsi.tekliflerim, TazelemeIsi.yeniIsler]
        else TazelemeIsi.ilanlarim,
      };

  static final Set<TazelemeIsi> _bekleyen = {};
  static final Set<String> _bekleyenIlanlar = {};
  static Timer? _zamanlayici;
  static BuildContext? _baglam;

  /// Haber geldi (anlık bağlantı ya da push). [ilanId] varsa (push) o ilan
  /// ayrıca tek başına tazelenir.
  static void habereGore(BuildContext context, String? tur, {String? ilanId}) {
    final rol = context.read<AuthController?>()?.activeRole;
    if (rol == null) {
      return;
    }
    if (tur == 'NEW_OFFER' && ilanId != null && rol == Role.customer) {
      _bekleyenIlanlar.add(ilanId);
    }
    _planla(context, isler(tur, rol));
  }

  /// Uygulama öne geldi / bağlantı yeniden kuruldu.
  static void hepsiniTazele(BuildContext context) {
    final rol = context.read<AuthController?>()?.activeRole;
    if (rol == null) {
      return;
    }
    _planla(context, hepsi(rol));
  }

  static void _planla(BuildContext context, Set<TazelemeIsi> isler) {
    _bekleyen.addAll(isler);
    _baglam = context;
    _zamanlayici ??= Timer(birlestirme, _calistir);
  }

  static Future<void> _calistir() async {
    _zamanlayici = null;
    final context = _baglam;
    final isler = {..._bekleyen};
    final ilanlar = {..._bekleyenIlanlar};
    _bekleyen.clear();
    _bekleyenIlanlar.clear();
    if (context == null || !context.mounted) {
      return;
    }
    final me = context.read<AuthController?>()?.currentAccount;
    if (me == null) {
      return;
    }
    final bildirim = context.read<NotificationController?>();
    final ilan = context.read<ListingController?>();
    final teklif = context.read<OfferController?>();
    final talep = context.read<TeklifTalebiController?>();
    final sohbet = context.read<ChatController?>();
    final islerListesi = <Future<void>>[
      if (isler.contains(TazelemeIsi.sohbetler) && sohbet != null)
        sohbet.okunmamislariTazele(me.id),
      if (isler.contains(TazelemeIsi.bildirimler) && bildirim != null) ...[
        bildirim.load(me.id, sessiz: true),
        bildirim.refreshBadge(me.id),
      ],
      if (isler.contains(TazelemeIsi.talepler) && talep != null) talep.yenile(),
      if (isler.contains(TazelemeIsi.ilanlarim) && ilan != null)
        ilan.loadMine(me.id, sessiz: true)
      else
        for (final id in ilanlar)
          if (ilan != null) ilan.loadOne(id, sessiz: true),
      // ⚠ Önce tekliflerim, sonra yeni işler: "Yeni işler" teklif verilen
      // ilanları teklif listesine bakarak gizler (bkz. JobsScreen._refresh).
      _saglayici(isler, teklif, ilan),
    ];
    try {
      await Future.wait(islerListesi);
    } catch (_) {
      // Arka plan tazelemesi: hata ekranı kesmez; bir sonraki haberde yeniden.
    }
  }

  static Future<void> _saglayici(
      Set<TazelemeIsi> isler, OfferController? teklif, ListingController? ilan) async {
    if (isler.contains(TazelemeIsi.tekliflerim) && teklif != null) {
      await teklif.loadMine(sessiz: true);
    }
    if (isler.contains(TazelemeIsi.yeniIsler) && ilan != null) {
      await ilan.loadAvailable(sessiz: true);
    }
  }
}

/// ═══════════════════════════════════════════════════════════════
/// ANLIK TAZELEME KAPISI — anlık bağlantının ve öne gelme olayının
/// uygulama genelindeki tek dinleyicisi.
///
///   · Giriş yapılınca anlık bağlantı kurulur (yalnız sohbet açılınca
///     değil); çıkışta kapanır. Mock modda bağlantı yoktur.
///   · `notification.new` → `AnlikTazeleme.habereGore`
///   · Kopan bağlantı yeniden kurulunca ve uygulama öne gelince →
///     `AnlikTazeleme.hepsiniTazele` (en sık 10 sn'de bir).
///   · Oturum sahibi değişince talep önbelleği bırakılır.
///   · Öne gelmede katalog da (kategori, hizmet, çatı) denetlenir
///     (`KatalogTazeleme`, en sık 5 dk'da bir).
/// ═══════════════════════════════════════════════════════════════
class AnlikTazelemeKapisi extends StatefulWidget {
  const AnlikTazelemeKapisi({super.key, required this.child});

  final Widget child;

  /// Öne gelmede tam tazeleme arası (web'de odak değişimi sık tetikler).
  static const Duration enAzOneGelmeAraligi = Duration(seconds: 10);

  @override
  State<AnlikTazelemeKapisi> createState() => _AnlikTazelemeKapisiState();
}

class _AnlikTazelemeKapisiState extends State<AnlikTazelemeKapisi>
    with WidgetsBindingObserver {
  AuthController? _auth;
  WsClient? _ws;
  String? _kullanici;
  bool _ilkBaglanti = true;
  DateTime? _sonTamTazeleme;
  final List<StreamSubscription<dynamic>> _abonelikler = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_auth != null) {
      return;
    }
    // Sağlayıcı yoksa (yalıtılmış widget testleri) kapı devre dışı kalır.
    final auth = context.read<AuthController?>();
    if (auth == null) {
      return;
    }
    _ws = context.read<WsClient?>();
    final ws = _ws;
    if (ws != null) {
      _abonelikler
        ..add(ws.onNotificationNew.listen((d) {
          final tur = d['type'];
          if (mounted && tur is String) {
            AnlikTazeleme.habereGore(context, tur);
          }
        }))
        ..add(ws.onConnectionChange.listen((bagli) {
          if (!bagli || !mounted) {
            return;
          }
          // İlk bağlantıda ekranlar verisini zaten yüklüyor; yalnız
          // KOPUP YENİDEN bağlanınca kaçan haberler için tazelenir.
          if (_ilkBaglanti) {
            _ilkBaglanti = false;
            return;
          }
          _tamTazele();
        }));
    }
    _auth = auth..addListener(_oturumDegisti);
    _oturumDegisti();
  }

  void _oturumDegisti() {
    final id = _auth?.currentAccount?.id;
    if (id == _kullanici) {
      return;
    }
    final onceki = _kullanici;
    _kullanici = id;
    if (onceki != null) {
      context.read<TeklifTalebiController?>()?.oturumDegisti();
      unawaited(_ws?.disconnect());
    }
    if (id != null) {
      _ilkBaglanti = true;
      unawaited(_ws?.connect());
      // 29 Eki: kartlardaki "yeni mesaj" sayıları açılışta da gelsin
      // (yalnız API modunda; zamanlayıcısız, doğrudan ve sessiz).
      if (ApiConfig.useRealApi) {
        final sohbet = context.read<ChatController?>();
        if (sohbet != null) {
          unawaited(sohbet.okunmamislariTazele(id));
        }
      }
    }
  }

  void _tamTazele() {
    final son = _sonTamTazeleme;
    final simdi = DateTime.now();
    if (son != null && simdi.difference(son) < AnlikTazelemeKapisi.enAzOneGelmeAraligi) {
      return;
    }
    _sonTamTazeleme = simdi;
    AnlikTazeleme.hepsiniTazele(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    // Katalog herkese açıktır (oturumsuz da): admin değişikliği uygulama
    // kapanıp açılmadan gelir; en sık 5 dk'da bir, değişmediyse 304.
    if (ApiConfig.useRealApi) {
      final client = context.read<ApiClient?>();
      if (client != null) {
        unawaited(KatalogTazeleme.gerekirseTazele(client));
      }
    }
    if (_kullanici != null) {
      _tamTazele();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final a in _abonelikler) {
      unawaited(a.cancel());
    }
    _auth?.removeListener(_oturumDegisti);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
