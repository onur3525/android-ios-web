// BAKIM DURUMU — UYGULAMA AÇIKKEN DE İZLENİR (22 Eki, kullanıcı kararı)
//
// Admin panelinden (Duyurular › Bakım modu) bakım açıldığında uygulamanın
// BÜTÜN ekranları bakım ekranıyla örtülür (`BakimKapisi`). Kaynak tektir:
// `GET /config/app` yanıtındaki `maintenance` alanı.
//
//   · açılışta splash ilk değeri verir ve izlemeyi başlatır,
//   · uygulama açıkken 60 sn'de bir ve uygulama öne gelince yeniden sorulur,
//   · sunucu bir isteğe "MAINTENANCE" (503) dönerse hemen sorulur.
//
// ⚠ Sorgu başarısız olursa durum DEĞİŞMEZ: ağ hatası bakım sayılmaz,
// bakım da ağ hatasıyla kendiliğinden kapanmaz.
import 'dart:async';

import 'package:flutter/widgets.dart';

class BakimDurumu extends ChangeNotifier with WidgetsBindingObserver {
  BakimDurumu._();

  static final BakimDurumu i = BakimDurumu._();

  bool _aktif = false;
  String? _mesaj;
  String? _bitis;
  Future<Map<String, dynamic>> Function()? _sorgu;
  Timer? _zamanlayici;
  VoidCallback? _bitince;
  bool _sorguda = false;

  bool get aktif => _aktif;
  String? get mesaj => _mesaj;
  String? get bitis => _bitis;

  /// `maintenance` nesnesini uygular (`{active, message, endAt}`).
  void uygula(Object? m) {
    final harita = m is Map ? m : const <String, Object?>{};
    final aktif = harita['active'] == true;
    final mesaj = harita['message'] is String ? harita['message'] as String : null;
    final bitis = harita['endAt'] is String ? harita['endAt'] as String : null;
    if (aktif == _aktif && mesaj == _mesaj && bitis == _bitis) {
      return;
    }
    final bitti = _aktif && !aktif;
    _aktif = aktif;
    _mesaj = mesaj;
    _bitis = bitis;
    notifyListeners();
    if (bitti) {
      final f = _bitince;
      _bitince = null;
      f?.call();
    }
  }

  /// Bakım bittiğinde BİR KEZ çalışacak iş (ör. açılışı baştan başlatmak).
  void bitinceCalistir(VoidCallback f) => _bitince = f;

  /// İzlemeyi başlatır (yalnız gerçek API modunda çağrılır).
  void baslat(Future<Map<String, dynamic>> Function() sorgu) {
    _sorgu = sorgu;
    _zamanlayici?.cancel();
    _zamanlayici =
        Timer.periodic(const Duration(seconds: 60), (_) => kontrolEt());
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Sunucuya şimdi sorar; hata olursa durum değişmez.
  Future<void> kontrolEt() async {
    final s = _sorgu;
    if (s == null || _sorguda) {
      return;
    }
    _sorguda = true;
    try {
      final j = await s();
      uygula(j['maintenance']);
    } catch (_) {
      // Ağ hatası bakım değildir; mevcut durum korunur.
    } finally {
      _sorguda = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(kontrolEt());
    }
  }

  /// Yalnız testler: başlangıç durumuna döner.
  @visibleForTesting
  void sifirla() {
    _zamanlayici?.cancel();
    _zamanlayici = null;
    _sorgu = null;
    _bitince = null;
    _aktif = false;
    _mesaj = null;
    _bitis = null;
  }
}
