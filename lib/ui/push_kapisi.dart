import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/push/push_platform.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/models/account.dart' show Role;
import '../data/controllers/notification_controller.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import '../data/remote/mappers.dart';
import '../domain/bildirim_rolu.dart';
import '../screens/notifications_screen.dart';
import 'gezgin.dart';

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

class _PushKapisiState extends State<PushKapisi> {
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
    final bekleyen = _bekleyenAcilis;
    if (bekleyen != null) {
      _bekleyenAcilis = null;
      _acildi(bekleyen);
    }
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
    final id = _auth?.currentAccount?.id;
    if (id == null || !mounted) {
      return;
    }
    final n = context.read<NotificationController>();
    unawaited(n.load(id));
    unawaited(n.refreshBadge(id));
    // ── ⚠ UYGULAMA AÇIKKEN EKRAN KENDİLİĞİNDEN TAZELENİR (15 Eki) ──
    // Yeni iş ilanı → hizmet verenin "Yeni işler" listesi; yeni teklif →
    // hizmet alanın ilanı ve teklifleri. Kullanıcı yenilemek zorunda kalmaz.
    final tur = veri['type'];
    final refId = veri['id'];
    final ilanlar = context.read<ListingController?>();
    if (tur == 'NEW_LISTING' && _auth?.activeRole == Role.provider) {
      unawaited(ilanlar?.loadAvailable());
    } else if (tur == 'NEW_OFFER' && refId is String && _kimlikDeseni.hasMatch(refId)) {
      unawaited(ilanlar?.loadOne(refId));
    }
  }

  void _acildi(Map<String, dynamic> veri) {
    // Oturum henüz yüklenmediyse (soğuk açılış) giriş sonrasına ertelenir.
    if (_auth?.currentAccount == null) {
      _bekleyenAcilis = veri;
      return;
    }
    // ⚠ TEK KAYNAK (14 Eki): uygulama içi bildirim kartıyla AYNI
    // yönlendirme (`NotificationsScreen.hedefeGit`) — tür + kimlikten
    // ilgili içerik (teklif bölümüne odaklanma, sohbet, doğru tarafın
    // ekranı). Orada gidilecek yer bulunamazsa (veri henüz yüklenmedi,
    // tür eşlenmedi) güvenli hedef tablosu (`pushRotasi`) kullanılır.
    final id = veri['id'];
    final hedef = veri['hedef'];
    final tur = Mappers.notifType(
        '${veri['type'] ?? ''}', hedef is String ? hedef : null);
    final baglam = gezginAnahtari.currentContext;
    final bildirimId = veri['bildirimId'];
    if (baglam != null && bildirimId is String && _kimlikDeseni.hasMatch(bildirimId)) {
      // Dokunulan bildirim okundu sayılır (kartla aynı davranış).
      unawaited(baglam.read<NotificationController>().markRead(bildirimId));
    }
    // ⚠ ROL: uygulama içi liste etkin role göre süzülür; push ise her
    // rolde gelebilir. Bildirimin rolü etkin rolden farklıysa ortak
    // yönlendirme KULLANILMAZ — rota tablosundaki RoleGuard devreye girer.
    final rol = bildirimRolu(tur);
    final rolUygun = rol == null || rol == _auth?.activeRole;
    if (baglam != null &&
        rolUygun &&
        id is String &&
        _kimlikDeseni.hasMatch(id) &&
        NotificationsScreen.hedefeGit(baglam, tur, id)) {
      return;
    }
    gezginAnahtari.currentState?.pushNamed(pushRotasi(veri));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
