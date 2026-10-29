import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/push/push_platform.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/notification_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/account.dart' show Role;
import '../data/models/notification.dart' show NotifType;
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import '../data/remote/mappers.dart';
import '../domain/bildirim_rolu.dart';
import '../screens/notifications_screen.dart';
import 'anlik_tazeleme.dart';
import 'gezgin.dart';
import 'global_web_kabugu.dart' show AktifRota;

/// ═══════════════════════════════════════════════════════════════
/// PUSH KAPISI — Firebase Cloud Messaging yaşam döngüsü (tek kaynak)
///
///   · Açılış: köprü başlatılır (ilk kareden SONRA; açılışı geciktirmez).
///   · Giriş: bildirim izni istenir (iOS / Android 13+ / tarayıcı sistem
///     penceresi), jeton alınır; API modunda sunucuya kaydedilir.
///     İzin YALNIZ oturum açmış kullanıcıya sorulur (gereksiz açılış
///     penceresi yok).
///   · Jeton yenilenirse yeniden kaydedilir.
///   · Çıkış: jeton sunucudan silinir ve cihazda geçersiz kılınır.
///   · Önde gelen bildirim: Bildirimler listesi ve rozet tazelenir
///     (iOS'ta sistem bildirimi de gösterilir).
///   · Bildirime dokunma: uygulama içi bildirim kartıyla AYNI yönlendirme
///     (`NotificationsScreen.hedefeGit`); olmazsa güvenli hedef tablosuyla
///     MEVCUT rotalara gidilir (rota korumaları — rol, taraf — aynen).
///
/// ⚠ JETON KALICI DEPOLAMAYA YAZILMAZ (yalnız bellekte). Firebase SDK'nın
/// kendi iç kaydı dışında uygulama jetonu saklamaz.
/// ⚠ Mock modda sunucu kaydı yapılmaz; push alımı (Firebase Console test
/// mesajı) yine çalışır. Arayüzde yeni ekran YOK.
/// ═══════════════════════════════════════════════════════════════
class PushKapisi extends StatefulWidget {
  const PushKapisi({super.key, required this.child});

  final Widget child;

  @override
  State<PushKapisi> createState() => _PushKapisiState();
}

/// Bildirim verisindeki hedef → mevcut rota. YALNIZ bu tablo; serbest
/// yol/URL kabul edilmez (dışarıdan gelen veriyle rastgele gezinme yok).
const Map<String, String> kPushHedefleri = {
  'ilan': '/ilan/',
  'is': '/is/',
  'teklif': '/teklif/',
  'talep': '/talep/',
  'mesaj': '/mesaj/',
};
final RegExp _kimlikDeseni = RegExp(r'^[A-Za-z0-9-]{1,64}$');

/// Bildirim verisinden güvenli rota üretir; uygun değilse Bildirimler.
String pushRotasi(Map<String, dynamic> veri) {
  final hedef = veri['hedef'];
  final id = veri['id'];
  final onek = hedef is String ? kPushHedefleri[hedef] : null;
  if (onek != null && id is String && _kimlikDeseni.hasMatch(id)) {
    return '$onek$id';
  }
  return '/notifications';
}

/// ── BİLDİRİMİN AÇACAĞI EKRANIN İSTEDİĞİ ROL (29 Eki, kullanıcı isteği) ──
///
/// "Bildirime dokununca uygulamada hangi ekran açık olursa olsun
/// bildirimin geldiği ekrana gidilmeli." Push her rolde gelir; ekranlar
/// ise role bağlıdır (RoleGuard / yanlış taraf kapısı). Etkin rol farklıysa
/// önce kullanıcının KENDİ rolleri arasında geçilir, sonra ekran açılır.
///
/// `null` = rol fark etmez (sohbet, duyuru). "İletişim açıldı" iki tarafa
/// da gider: okuyan ilan sahibiyse hizmet alan, değilse hizmet veren.
Role? pushGerekenRol(NotifType tur, {String? benId, String? ilanSahibiId}) {
  final r = bildirimRolu(tur);
  if (r != null) {
    return r;
  }
  if (tur == NotifType.contactOpened && benId != null && ilanSahibiId != null) {
    return ilanSahibiId == benId ? Role.customer : Role.provider;
  }
  return null;
}

/// AYNI BİLDİRİM İKİ KEZ AÇILMAZ: bazı cihazlarda aynı dokunuş hem
/// "kapalıyken açıldı" hem "arka plandan açıldı" olarak gelir; hedef
/// ekran üst üste iki kez açılıyordu. Kısa pencerede aynı bildirim
/// yok sayılır; sonra yeniden dokunmak yine açar.
class PushTekrarSuzgeci {
  PushTekrarSuzgeci({this.pencere = const Duration(seconds: 3), DateTime Function()? saat})
      : _saat = saat ?? DateTime.now;

  final Duration pencere;
  final DateTime Function() _saat;
  String? _son;
  DateTime? _zaman;

  bool tekrarMi(Map<String, dynamic> veri) {
    final a = '${veri['bildirimId'] ?? ''}|${veri['type'] ?? ''}|${veri['id'] ?? ''}';
    final t = _saat();
    final z = _zaman;
    if (a == _son && z != null && t.difference(z) < pencere) {
      return true;
    }
    _son = a;
    _zaman = t;
    return false;
  }
}

class _PushKapisiState extends State<PushKapisi> {
  final PushTekrarSuzgeci _tekrar = PushTekrarSuzgeci();

  AuthController? _auth;
  String? _kullanici;
  String? _token; // ⚠ yalnız bellekte
  bool _basladi = false;
  Map<String, dynamic>? _bekleyenAcilis;

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
    _auth = auth..addListener(_oturumDegisti);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_baslat()));
  }

  @override
  void dispose() {
    if (_rotaDinleniyor) {
      AktifRota.ad.removeListener(_bekleyeniIsle);
    }
    _auth?.removeListener(_oturumDegisti);
    super.dispose();
  }

  Future<void> _baslat() async {
    _basladi = await pushBaslat(
      onMesaj: _mesajGeldi,
      onAcildi: _acildi,
      onToken: (t) => unawaited(_tokenKaydet(t)),
    );
    if (_basladi) {
      _oturumDegisti();
    }
  }

  void _oturumDegisti() {
    final id = _auth?.currentAccount?.id;
    if (id == _kullanici) {
      return;
    }
    final onceki = _token;
    _kullanici = id;
    if (id == null) {
      _token = null;
      unawaited(_cikis(onceki));
      return;
    }
    if (_basladi) {
      unawaited(_giris());
    }
    _bekleyeniIsle();
  }

  // ── ⚠ SOĞUK AÇILIŞTA BİLDİRİM HEDEFİ (16 Eki, kullanıcı bulgusu) ──
  //
  // Uygulama kapalıyken gelen bildirime dokununca ilgili ekrana değil
  // ana panele düşülüyordu. Neden: dokunulan bildirim, oturum yüklenir
  // yüklenmez açılıyordu; ama o an açılış ekranı hâlâ ekrandaydı ve
  // ardından rol paneline `pushNamedAndRemoveUntil` ile geçerken açılan
  // hedef ekranı da siliyordu. Artık hedef, açılış/bağlanıyor ekranı
  // bitip ilk gerçek ekran (rol paneli) geldikten SONRA açılır.
  bool get _acilisTamam {
    final r = AktifRota.ad.value;
    return r != null && r != '/' && r != '/baglaniyor';
  }

  bool _rotaDinleniyor = false;

  void _bekleyeniIsle() {
    final bekleyen = _bekleyenAcilis;
    if (bekleyen == null || _auth?.currentAccount == null) {
      return;
    }
    if (!_acilisTamam) {
      if (!_rotaDinleniyor) {
        _rotaDinleniyor = true;
        AktifRota.ad.addListener(_bekleyeniIsle);
      }
      return;
    }
    _bekleyenAcilis = null;
    if (_rotaDinleniyor) {
      _rotaDinleniyor = false;
      AktifRota.ad.removeListener(_bekleyeniIsle);
    }
    // Rol paneli ilk karesini çizdikten sonra hedef üstüne açılır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _acildi(bekleyen);
      }
    });
  }

  Future<void> _giris() async {
    final t = await pushIzinIsteVeTokenAl();
    if (t != null) {
      await _tokenKaydet(t);
    }
  }

  Future<void> _tokenKaydet(String t) async {
    _token = t;
    if (!ApiConfig.useRealApi || _kullanici == null || !mounted) {
      return;
    }
    try {
      await context.read<ApiClient>().post('/devices/push-token', body: {
        'token': t,
        'platform': kIsWeb
            ? 'web'
            : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
      });
    } catch (_) {
      // Sunucuya ulaşılamazsa bir sonraki açılışta/yenilemede tekrar.
    }
  }

  Future<void> _cikis(String? token) async {
    if (token != null && ApiConfig.useRealApi && mounted) {
      try {
        await context.read<ApiClient>().delete('/devices/push-token', body: {'token': token});
      } catch (_) {}
    }
    await pushTokenSil();
  }

  void _mesajGeldi(Map<String, dynamic> veri) {
    if (_auth?.currentAccount == null || !mounted) {
      return;
    }
    // ── ⚠ UYGULAMA AÇIKKEN EKRAN KENDİLİĞİNDEN TAZELENİR (15 Eki) ──
    // ⚠ TEK KAYNAK (28 Eki): anlık bağlantıyla AYNI eşleme
    // (`AnlikTazeleme`); ikisi aynı olay için gelirse birleştirilir.
    final tur = veri['type'];
    final refId = veri['id'];
    AnlikTazeleme.habereGore(context, tur is String ? tur : null,
        ilanId: refId is String && _kimlikDeseni.hasMatch(refId) ? refId : null);
  }

  void _acildi(Map<String, dynamic> veri) {
    // Oturum henüz yüklenmediyse ya da açılış ekranı hâlâ duruyorsa
    // (soğuk açılış) ilk gerçek ekrandan sonraya ertelenir.
    if (_auth?.currentAccount == null || !_acilisTamam) {
      _bekleyenAcilis = veri;
      _bekleyeniIsle();
      return;
    }
    if (_tekrar.tekrarMi(veri)) {
      return;
    }
    unawaited(_yonlendir(veri));
  }

  // ── ⚠ HER DURUMDA BİLDİRİMİN EKRANINA (29 Eki, kullanıcı isteği) ──
  //
  // "Telefon kilitli, uygulama kapalı ya da arka plandayken bildirime
  // dokununca, uygulamada hangi ekran açık olursa olsun bildirimin
  // geldiği ekrana gidilmeli."
  //
  // Önceden iki yerde kalınıyordu:
  //   1. ROL: bildirim etkin rolden farklı roldeyse ortak yönlendirme
  //      atlanıyor, rota tablosuna düşülüyor, RoleGuard da ekranı
  //      engelliyordu. Artık kullanıcının KENDİ rolleri arasında geçilir
  //      (rol eklenmez), yeni rolün paneli kök olur, hedef üstüne açılır.
  //   2. VERİ: "iletişim açıldı" ve teklif talebi sohbeti, kaydı bellekte
  //      bulamayınca Bildirimler listesine düşüyordu (kapalıyken açılışta
  //      listeler henüz yüklenmemiş olur). Artık önce kayıt yüklenir.
  //
  // ⚠ GÜVENLİK AYNEN: hedef yalnız tür + kimlikten, sabit tablodan çözülür;
  // ekranların kendi taraf denetimleri ve sunucu yetkisi değişmedi.
  Future<void> _yonlendir(Map<String, dynamic> veri) async {
    final ham = veri['id'];
    final id = ham is String && _kimlikDeseni.hasMatch(ham) ? ham : null;
    final hedef = veri['hedef'];
    final tur = Mappers.notifType(
        '${veri['type'] ?? ''}', hedef is String ? hedef : null);
    final ilkBaglam = gezginAnahtari.currentContext;
    if (ilkBaglam == null) {
      return;
    }
    final bildirimId = veri['bildirimId'];
    if (bildirimId is String && _kimlikDeseni.hasMatch(bildirimId)) {
      // Dokunulan bildirim okundu sayılır (kartla aynı davranış).
      unawaited(ilkBaglam.read<NotificationController>().markRead(bildirimId));
    }
    final teklifler = ilkBaglam.read<OfferController>();
    final ilanlar = ilkBaglam.read<ListingController>();
    final talepler = ilkBaglam.read<TeklifTalebiController>();
    if (id != null) {
      await _veriyiHazirla(tur, id, teklifler, ilanlar, talepler);
    }
    final auth = _auth;
    final ben = auth?.currentAccount;
    if (!mounted || auth == null || ben == null) {
      return;
    }

    String? ilanSahibi;
    if (tur == NotifType.contactOpened && id != null) {
      final o = teklifler.byId(id);
      ilanSahibi = o == null ? null : ilanlar.byId(o.listingId)?.ownerId;
    }
    final rol = pushGerekenRol(tur, benId: ben.id, ilanSahibiId: ilanSahibi);
    if (rol != null && rol != auth.activeRole) {
      // Kullanıcının o rolü yoksa (ya da geçiş olmadıysa) ekran açılmaz;
      // Bildirimler listesi gösterilir.
      if (!ben.roles.contains(rol) || await auth.switchRole(rol) != null) {
        if (mounted) {
          gezginAnahtari.currentState?.pushNamed('/notifications');
        }
        return;
      }
      if (!mounted) {
        return;
      }
      // Yeni rolün paneli kök olur (geri tuşu panele döner).
      gezginAnahtari.currentState?.pushNamedAndRemoveUntil(
          rol == Role.provider ? '/provider/jobs' : '/customer/listings',
          (r) => false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
    }

    // ⚠ TEK KAYNAK (14 Eki): uygulama içi bildirim kartıyla AYNI
    // yönlendirme (`NotificationsScreen.hedefeGit`). Orada gidilecek yer
    // bulunamazsa (kayıt yok, tür eşlenmedi) güvenli hedef tablosu.
    final baglam = gezginAnahtari.currentContext;
    if (baglam != null &&
        id != null &&
        NotificationsScreen.hedefeGit(baglam, tur, id)) {
      return;
    }
    gezginAnahtari.currentState?.pushNamed(pushRotasi(veri));
  }

  /// Hedef ekranın yönlendirme kararı için gereken kayıt bellekte yoksa
  /// yüklenir (en çok birkaç saniye beklenir; ağ yoksa yine devam edilir).
  /// Ekranlar kendi verisini zaten yükleyenler için burada bir şey yapılmaz.
  Future<void> _veriyiHazirla(NotifType tur, String id, OfferController teklifler,
      ListingController ilanlar, TeklifTalebiController talepler) async {
    Future<void> bekle(Future<void> f) => f
        .timeout(const Duration(seconds: 6))
        .then((_) {}, onError: (Object _) {});
    final ben = _auth?.currentAccount;
    if (ben == null) {
      return;
    }
    switch (tur) {
      case NotifType.contactOpened:
        // `id` TEKLİF kimliğidir; ilan teklif üzerinden bulunur. Teklif
        // benim verdiğim (hizmet veren) ya da ilanıma gelen (hizmet alan)
        // olabilir: iki liste birlikte yüklenir.
        if (teklifler.byId(id) == null) {
          await Future.wait([
            bekle(teklifler.loadMine(sessiz: true)),
            bekle(ilanlar.loadMine(ben.id, sessiz: true)),
          ]);
        }
        final o = teklifler.byId(id);
        if (o != null && ilanlar.byId(o.listingId) == null) {
          await bekle(ilanlar.loadOne(o.listingId, sessiz: true));
        }
      case NotifType.teklifYeniMesaj:
        if (talepler.byId(id) == null) {
          await bekle(talepler.yenile());
        }
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
