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

/// `maintenance` nesnesi bu cihaz için bakım ekranı gerektiriyor mu?
///
/// ⚠ TEK KAYNAK (açılış kararı + uygulama açıkken izleme). Sunucu, istek
/// admin'in "Bakımda erişebilecek hesaplar" listesindeki bir hesabın
/// oturumuyla geldiyse `bypass: true` ekler (032): o kişi uygulamayı
/// normal kullanır, diğer herkes bakım ekranını görür.
bool bakimEtkinMi(Object? m) =>
    m is Map && m['active'] == true && m['bypass'] != true;

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
  bool _girisAcik = false;
  bool _testCihazi = false;

  bool get aktif => _aktif;

  /// Bu cihaz admin listesindeki bir hesabın TANINMIŞ cihazı mı? (sunucu
  /// `testerDevice`). Bakım ekranındaki gizli giriş kapısı yalnız o zaman
  /// vardır; diğer cihazlarda logoya basmak hiçbir şey yapmaz.
  bool get testCihazi => _testCihazi;

  /// Bakım ekranındaki gizli giriş kapısından (logoya 2 sn basılı tutma)
  /// giriş ekranı açıkken bakım örtüsü kalkar. Giriş ekranı kapanınca
  /// durum sunucuya yeniden sorulur: listedeki hesapla giriş yapıldıysa
  /// sunucu `bypass` der ve örtü gelmez; yapılmadıysa örtü geri gelir.
  bool get girisAcik => _girisAcik;

  void girisAc() {
    _girisAcik = true;
    notifyListeners();
  }

  Future<void> girisKapat() async {
    await kontrolEt();
    _girisAcik = false;
    notifyListeners();
  }
  String? get mesaj => _mesaj;
  String? get bitis => _bitis;

  /// `maintenance` nesnesini uygular (`{active, message, endAt}`).
  void uygula(Object? m) {
    final harita = m is Map ? m : const <String, Object?>{};
    final aktif = bakimEtkinMi(harita);
    final mesaj = harita['message'] is String ? harita['message'] as String : null;
    final bitis = harita['endAt'] is String ? harita['endAt'] as String : null;
    final testCihazi = aktif && harita['testerDevice'] == true;
    if (aktif == _aktif && mesaj == _mesaj && bitis == _bitis && testCihazi == _testCihazi) {
      return;
    }
    _testCihazi = testCihazi;
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
    _girisAcik = false;
    _testCihazi = false;
    _mesaj = null;
    _bitis = null;
  }
}
