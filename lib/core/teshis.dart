import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';


/// TEŞHİS BAYRAKLARI — YALNIZ HATA ARAMA İÇİN
///
/// ⚠ ÜRETİM DAVRANIŞI DEĞİŞMEZ.
/// Hepsi `--dart-define` ile açılır; verilmezse `false` kalır ve
/// üretim kodu bugünkü davranışını aynen sürdürür.
///
///   E1  --dart-define=FOCUS_LOG=true
///   E2  --dart-define=FOCUS_LOG=true --dart-define=NO_ONCHANGED=true
///   E3  --dart-define=FOCUS_LOG=true --dart-define=STATIC_REGION=true
abstract final class Teshis {
  /// E1 — odak + klavye inset değişimlerini kaydeder ve ekranda gösterir.
  /// ── ⚠ RELEASE'TE TEŞHİS KAPALIDIR ──
  ///
  /// Bayraklar derleme zamanında verilir. Sürüm alırken yanlışlıkla
  /// `--dart-define=FOCUS_LOG=true` geçilirse teşhis paneli ve odak
  /// günlüğü GERÇEK KULLANICIDA açılırdı: ekranda log rozeti çıkar,
  /// alan adları ve gezinme yolu okunur hâle gelir.
  ///
  /// Bayrak artık `kReleaseMode` ile AND'lenir; sürüm paketinde
  /// hiçbir define kombinasyonu teşhisi açamaz.
  static const bool _focusLogTanim = bool.fromEnvironment('FOCUS_LOG');
  static const bool focusLog = _focusLogTanim && !kReleaseMode;

  /// E2 — kayıt alanlarındaki `onChanged: setState` ETKİSİZ olur.
  static const bool _noOnChangedTanim = bool.fromEnvironment('NO_ONCHANGED');
  /// ⚠ Release'te KAPALI (bkz. `focusLog`).
  static const bool noOnChanged = _noOnChangedTanim && !kReleaseMode;

  /// E3 — `context.watch<RegionController>()` tek okumaya çevrilir.
  static const bool _staticRegionTanim = bool.fromEnvironment('STATIC_REGION');
  /// ⚠ Release'te KAPALI (bkz. `focusLog`).
  static const bool staticRegion = _staticRegionTanim && !kReleaseMode;
}

/// ODAK + KLAVYE İZLEYİCİ
///
/// Üç durumu birbirinden AYIRMAK için tasarlandı:
///   1) hasFocus true→false ve primary null/başka  → gerçek odak kaybı
///   2) hasFocus true kalır ama inset→0            → IME kapanıyor, odak duruyor
///   3) ikisi de normal, yalnız yavaş              → renderer/layout
///
/// ⚠ `Teshis.focusLog` kapalıyken HİÇBİR ŞEY yapmaz.
abstract final class FocusIzle with WidgetsBindingObserver {
  static final _adlar = <FocusNode, String>{};
  static final satirlar = ValueNotifier<List<String>>([]);
  static bool _kurulu = false;
  static String? _oncekiBirincil;
  static _Gozlemci? _gozlemci;

  /// Ekran adı — `kaydet` çağıran ekran tarafından set edilir.
  static String? aktifRoute;

  static String get _saat {
    final t = DateTime.now();
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.$ms';
  }

  static String get _birincilAd {
    final p = FocusManager.instance.primaryFocus;
    if (p == null) {
      return 'NULL';
    }
    return _adlar[p] ?? p.debugLabel ?? 'diğer';
  }

  /// Anlık klavye yüksekliği (mantıksal piksel).
  static int get _inset {
    final v = WidgetsBinding.instance.platformDispatcher.views.first;
    return (v.viewInsets.bottom / v.devicePixelRatio).round();
  }

  static void _yaz(String s) {
    final satir = 'FOCUS_LOG $_saat $s';
    debugPrint(satir);
    // Ekranda gösterilecek tampon — son 300 satır.
    final l = [...satirlar.value, satir];
    satirlar.value = l.length > 300 ? l.sublist(l.length - 300) : l;
  }

  /// Alanı izlemeye alır.
  static void kaydet(FocusNode node, String ad) {
    if (!Teshis.focusLog || _adlar.containsKey(node)) {
      return;
    }
    _adlar[node] = ad;
    node.addListener(() {
      _yaz('field=$ad hasFocus=${node.hasFocus} '
          'primary=$_birincilAd inset=$_inset');
      _birincilKontrol();
    });
    _kur();
  }

  static void _kur() {
    if (_kurulu) {
      return;
    }
    _kurulu = true;
    FocusManager.instance.addListener(_birincilKontrol);
    _gozlemci = _Gozlemci();
    WidgetsBinding.instance.addObserver(_gozlemci!);
    _yaz('BASLADI inset=$_inset primary=$_birincilAd');
  }

  static void _birincilKontrol() {
    final ad = _birincilAd;
    if (ad == _oncekiBirincil) {
      return;
    }
    _oncekiBirincil = ad;
    _yaz('PRIMARY primary=$ad inset=$_inset');
  }

  // ── KLAVYE SÜRE TELEMETRİSİ ──
  //
  // ⚠ Her AKIŞ AYRI ölçülür; route etiketiyle kaydedilir ve
  // sonuçlar birbirine karıştırılmaz.
  static int _oncekiInset = 0;
  static DateTime? _acilisBasi;
  static DateTime? _kapanisBasi;

  /// Klavye/inset değişimi — `didChangeMetrics` tetikler.
  static void metrics(String? route) {
    final i = _inset;
    final r = route ?? '?';
    _yaz('METRICS primary=$_birincilAd inset=$i route=$r');

    final simdi = DateTime.now();
    if (_oncekiInset == 0 && i > 0) {
      // Açılış BAŞLADI.
      _acilisBasi = simdi;
      _yaz('KEYBOARD_OPEN_START route=$r');
    } else if (_acilisBasi != null && i > _oncekiInset) {
      // Yükseliyor — sürüyor.
    } else if (_acilisBasi != null && i > 0 && i == _oncekiInset) {
      final ms = simdi.difference(_acilisBasi!).inMilliseconds;
      _yaz('KEYBOARD_OPEN_END route=$r sure=${ms}ms');
      _acilisBasi = null;
    }

    if (_oncekiInset > 0 && i < _oncekiInset && _kapanisBasi == null) {
      _kapanisBasi = simdi;
      _yaz('KEYBOARD_CLOSE_START route=$r');
    }
    if (_kapanisBasi != null && i == 0) {
      final ms = simdi.difference(_kapanisBasi!).inMilliseconds;
      _yaz('KEYBOARD_CLOSE_END route=$r sure=${ms}ms');
      _kapanisBasi = null;
    }
    _oncekiInset = i;
  }

  static void yasam(AppLifecycleState d) {
    _yaz('LIFECYCLE state=${d.name} primary=$_birincilAd inset=$_inset');
  }

  static void temizle() {
    if (!Teshis.focusLog) {
      return;
    }
    _adlar.clear();
    if (_kurulu) {
      FocusManager.instance.removeListener(_birincilKontrol);
      if (_gozlemci != null) {
        WidgetsBinding.instance.removeObserver(_gozlemci!);
        _gozlemci = null;
      }
      _kurulu = false;
    }
    _oncekiBirincil = null;
  }
}

class _Gozlemci with WidgetsBindingObserver {
  @override
  void didChangeMetrics() => FocusIzle.metrics(FocusIzle.aktifRoute);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      FocusIzle.yasam(state);
}

/// TEŞHİS PANELİ — logları TELEFONDAN okumak için.
///
/// ⚠ Yalnız `Teshis.focusLog` açıkken çizilir; kapalıyken
/// `SizedBox.shrink()` döner ve hiçbir maliyeti yoktur.
///
/// `adb` erişimi olmadan test edilebilsin diye eklendi.
class TeshisPaneli extends StatelessWidget {
  const TeshisPaneli({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Teshis.focusLog) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: 8,
      bottom: 8,
      child: SafeArea(
        child: Material(
          color: const Color(0xCC16233D),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _ac(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('LOG',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }

  void _ac(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        builder: (_, kaydir) => ValueListenableBuilder<List<String>>(
          valueListenable: FocusIzle.satirlar,
          builder: (c, l, __) => Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Text('FOCUS_LOG (${l.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: l.join('\n')));
                    ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                        content: Text('Log panoya kopyalandı')));
                  },
                  child: const Text('Kopyala'),
                ),
                TextButton(
                  onPressed: () => FocusIzle.satirlar.value = [],
                  child: const Text('Temizle'),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: kaydir,
                itemCount: l.length,
                itemBuilder: (_, i) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  child: SelectableText(
                    l[i],
                    style: const TextStyle(
                        fontSize: 11.5, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
