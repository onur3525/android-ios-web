import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// ARAMA ÖLÇÜM İZİ — GEÇİCİ TEŞHİS ARACI (TEK KAYNAK)
///
/// ⚠ YALNIZ `--dart-define=ARAMA_IZ=true` İLE ETKİN.
///
/// Bayrak verilmezse `kAramaIzi` derleme sabiti `false` olur:
///   · `aramaIzi()` ilk satırda döner, hiçbir şey yazmaz/biriktirmez,
///   · ekran şeridi (`AramaIziSeridi`) ağaca HİÇ eklenmez (çağıranlar
///     `if (kAramaIzi)` koleksiyon koşuluyla ekler),
///   · sayfa dinleyicisi (`aramaIziSayfaDinleyicisi`) çocuğu OLDUĞU
///     GİBİ döndürür.
/// Yani normal/release derlemede davranış ve widget ağacı değişmez.
///
/// ⚠ DAVRANIŞA DOKUNMAZ: bu dosyadaki hiçbir şey seçim, kapanma,
/// kaydırma ya da yönlendirme kararı vermez; yalnız olanı yazar.
///
/// ⚠ ÇIKTI İKİ YERE: tarayıcı konsolu (`debugPrint` → release'te de
/// `console.log`) ve arama kutusunun altındaki son 12 kayıtlık şerit.
///
/// ⚠ ÖLÇÜM BİTİNCE bu dosya ve çağrı noktaları kaldırılacak.
/// ═══════════════════════════════════════════════════════════════
const bool kAramaIzi = bool.fromEnvironment('ARAMA_IZ');

/// Şeritte gösterilen kayıt sayısı.
const int _kSeritKayit = 12;

final List<String> _kayitlar = <String>[];
final Stopwatch _saat = Stopwatch();
bool _bildirimBekliyor = false;

/// Şeridin dinlediği kayıtlar (en yeni en üstte).
final ValueNotifier<List<String>> aramaIziKayitlari =
    ValueNotifier<List<String>>(const <String>[]);

/// Bir ölçüm kaydı yazar. Bayrak kapalıysa hiçbir şey yapmaz.
///
/// ⚠ Şerit güncellemesi MİKROGÖREVE ertelenir: kayıt bir `initState`
/// ya da çizim evresinin içinden gelebilir (ör. SEARCH_LISTING_OPEN);
/// o anda başka bir widget'a setState tetiklemek derleme evresinde
/// hata verirdi. Mikrogörev, çalışan kare bittikten sonra koşar.
void aramaIzi(String olay, [String ayrinti = '']) {
  if (!kAramaIzi) {
    return;
  }
  if (!_saat.isRunning) {
    _saat.start();
  }
  final ms = _saat.elapsedMilliseconds.toString().padLeft(6);
  final satir = ayrinti.isEmpty ? '$ms $olay' : '$ms $olay $ayrinti';
  debugPrint('[ARAMA_IZ] $satir');
  _kayitlar.insert(0, satir);
  if (_kayitlar.length > _kSeritKayit) {
    _kayitlar.removeRange(_kSeritKayit, _kayitlar.length);
  }
  if (_bildirimBekliyor) {
    return;
  }
  _bildirimBekliyor = true;
  scheduleMicrotask(() {
    _bildirimBekliyor = false;
    aramaIziKayitlari.value = List<String>.unmodifiable(_kayitlar);
  });
}

/// Ekrandaki genel konumu kısa yazar: (x,y).
String izNokta(Offset o) =>
    '(${o.dx.toStringAsFixed(1)},${o.dy.toStringAsFixed(1)})';

/// Genel dikdörtgeni kısa yazar: [sol,üst → sağ,alt].
String izRect(Rect? r) => r == null
    ? '[yok]'
    : '[${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)}'
        '→${r.right.toStringAsFixed(1)},${r.bottom.toStringAsFixed(1)}]';

/// Bir `BuildContext`in çizilmiş kutusunun GENEL dikdörtgeni
/// (ekran koordinatı). Bağlam yoksa ya da henüz çizilmemişse null.
Rect? izGenelRect(BuildContext? c) {
  final ro = c?.findRenderObject();
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) {
    return null;
  }
  final sol = ro.localToGlobal(Offset.zero);
  return sol & ro.size;
}

/// ── SAYFA DİNLEYİCİSİ: Flutter'a ulaşan GERÇEK işaretçi koordinatı ──
///
/// Uygulamanın en dışına (MaterialApp `builder`) konur. Geçirgen
/// `Listener`: isabet testini DEĞİŞTİRMEZ (kendini yalnız ek girdi
/// olarak ekler, çocuk isabetini aynen döndürür), olay tüketmez.
///
/// ⚠ Bayrak kapalıysa çocuk OLDUĞU GİBİ döner — ağaca düğüm eklenmez.
Widget aramaIziSayfaDinleyicisi(Widget cocuk) {
  if (!kAramaIzi) {
    return cocuk;
  }
  String yaz(PointerEvent e) => 'id=${e.pointer} tur=${e.kind.name} '
      'genel=${izNokta(e.position)}';
  return Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) => aramaIzi('SEARCH_PAGE_POINTER', 'DOWN ${yaz(e)}'),
    onPointerUp: (e) => aramaIzi('SEARCH_PAGE_POINTER', 'UP ${yaz(e)}'),
    onPointerCancel: (e) =>
        aramaIzi('SEARCH_PAGE_POINTER', 'CANCEL ${yaz(e)}'),
    child: cocuk,
  );
}

/// ── EKRAN ŞERİDİ: son 12 kayıt ──
///
/// Küçük, yarı saydam, dokunuşa KAPALI (`IgnorePointer`): altındaki
/// hiçbir şeyin dokunma davranışını değiştirmez. Semantik ağacına da
/// girmez.
class AramaIziSeridi extends StatelessWidget {
  const AramaIziSeridi({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ValueListenableBuilder<List<String>>(
          valueListenable: aramaIziKayitlari,
          builder: (_, kayitlar, __) => Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            color: const Color(0xE6101828),
            child: Text(
              kayitlar.isEmpty ? 'ARAMA_IZ açık — kayıt yok' : kayitlar.join('\n'),
              style: const TextStyle(
                fontSize: 8.5,
                height: 1.25,
                color: Color(0xFFE4E7EC),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
