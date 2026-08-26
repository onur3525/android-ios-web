import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/remote/api_config.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/models/review.dart';
import '../data/remote/api/review_api.dart';
import '../data/remote/api_client.dart';
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';

/// HİZMET VEREN — DEĞERLENDİRMELERİM (HTML vMyRevs)
///
/// READ-ONLY: Hizmet veren aldığı değerlendirmeleri yalnız görüntüler;
/// düzenleyemez ve silemez. Bu ekranda hiçbir düzenleme/silme aksiyonu
/// bulunmaz (backend'de de hizmet verene ait böyle bir uç yoktur).
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});
  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];

  double? _average;
  int _count = 0;
  Map<String, int> _dist = const {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;

  /// ⚠ SON OKUNAN KAYDIN İMİ (§16). `null` iken ilk sayfa istenir.
  /// Sayfa numarası tutulmaz — araya kayıt girdiğinde kayma olurdu.
  String? _cursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 260) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _items.clear();
      });
    }
    try {
      // ⚠ MOCK MODDA API UCU YOKTUR.
      //
      // Ekran her iki modda da `ReviewApi` çağırıyordu; mock modda
      // sunucu bulunmadığı için istek düşüyor ve ekran "yüklenemedi"
      // diyordu. Yani hizmet verenin ALDIĞI değerlendirmeler demo
      // APK'da hiç görünmüyordu.
      //
      // Artık mock modda veri doğrudan depodan okunur; kart çizimi ve
      // sayfalama mantığı DEĞİŞMEZ — iki mod aynı kodu kullanır.
      if (!ApiConfig.useRealApi) {
        final me = context.read<AuthController>().currentAccount;
        final list = me == null
            ? const <Review>[]
            : context.read<ReviewController>().byProvider(me.id);
        if (!mounted) {
          return;
        }
        setState(() {
          // ⚠ `_items` FINAL bir listedir; yeniden atanamaz.
          // İçeriği değiştirilir — ekranın diğer yerleri aynı listeye
          // referans tuttuğu için bu doğru olan da budur.
          _items
            ..clear()
            ..addAll(list.map(_mockSatir));
          _count = list.length;
          _average = list.isEmpty
              ? null
              : list.fold<int>(0, (t, r) => t + r.stars) / list.length;
          _dist = {
            for (var y = 1; y <= 5; y++)
              '$y': list.where((r) => r.stars == y).length,
          };
          // Mock listesi tek seferde gelir; sayfalama yoktur.
          _hasMore = false;
          _loading = false;
        });
        return;
      }

      final api = ReviewApi(context.read<ApiClient>());
      // ⚠ Kanonik uç kimlik ister: "kendi yorumlarım" = kendi
      // kimliğimle sorgulanan hizmet veren yorumları.
      final benim = context.read<AuthController>().currentAccount;
      if (benim == null) {
        setState(() => _loading = false);
        return;
      }
      final j = await api.mine(benim.id, limit: _pageSize);
      if (!mounted) {
        return;
      }
      setState(() {
        _average = (j['average'] as num?)?.toDouble();
        _count = (j['count'] as num?)?.toInt() ?? 0;
        _dist = _parseDist(j['distribution']);
        _items
          ..clear()
          ..addAll(_parseItems(j['items']));
        // ⚠ CURSOR SÖZLEŞMESİ (§16): `nextCursor` null ise liste
        // bitmiştir; aynı cursor ile tekrar istek YAPILMAZ.
        _cursor = j['nextCursor'] as String?;
        _hasMore = _cursor != null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Değerlendirmeleriniz yüklenemedi.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final api = ReviewApi(context.read<ApiClient>());
      final benim = context.read<AuthController>().currentAccount;
      if (benim == null) {
        setState(() => _loadingMore = false);
        return;
      }
      final j = await api.mine(benim.id, cursor: _cursor, limit: _pageSize);
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(_parseItems(j['items']));
        // ⚠ CURSOR SÖZLEŞMESİ (§16): `nextCursor` null ise liste
        // bitmiştir; aynı cursor ile tekrar istek YAPILMAZ.
        _cursor = j['nextCursor'] as String?;
        _hasMore = _cursor != null;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      // Sayfalama hatası tüm listeyi düşürmez; kullanıcı tekrar deneyebilir.
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  Map<String, int> _parseDist(Object? raw) {
    final m = raw as Map<String, dynamic>? ?? const {};
    return {
      for (final k in ['5', '4', '3', '2', '1'])
        k: (m[k] as num?)?.toInt() ?? 0,
    };
  }

  List<Map<String, dynamic>> _parseItems(Object? raw) =>
      ((raw as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: HC.bg,
        // AppBar KALDIRILDI — referansta yok (başlık sayfa içinde).
        // ⚠ GERİ OKU HER PLATFORMDA VARDIR (nihai karar): gövde hangi
        // durumda olursa olsun (yükleniyor / hata / liste) ok üstte
        // sabit durur, kullanıcı ekranda kilitlenmez.
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RefBackButton(),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: SysState(SysKind.genericError,
            title: 'Yüklenemedi',
            desc: _error,
            action: 'Tekrar Dene',
            onAction: () => _load(reset: true)),
      );
    }
    // ⚠ ÖZET KARTI HER ZAMAN GÖRÜNÜR — hizmet alan tarafıyla AYNI kural.
    //
    // Önceden hiç değerlendirme yokken ekran tamamen boş bir duruma
    // düşüyordu. Artık kart SIFIR değerlerle çizilir: ortalama 0,0,
    // beş yıldız satırı da 0, çubuklar boş. İlk değerlendirme
    // geldiğinde aynı kart canlanır.
    if (_count == 0) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _summary(),
            const Padding(
              padding: EdgeInsets.only(top: 26),
              child: SysState(SysKind.empty,
                  title: 'Henüz değerlendirme yok',
                  desc: 'Tamamladığınız işlerden sonra hizmet alanlar sizi '
                      'değerlendirdiğinde burada görünecek ve yukarıdaki '
                      'puan ortalamanıza yansıyacak.'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length + 2, // özet + liste + alt gösterge
        itemBuilder: (_, i) {
          if (i == 0) {
            return _summary();
          }
          if (i <= _items.length) {
            return _reviewCard(_items[i - 1]);
          }
          return _footer();
        },
      ),
    );
  }

  // ── Özet: ortalama + toplam + yıldız dağılımı ─────────────────────────
  /// `.mr-sum` — genel puan + dağılım kartı.
  ///
  /// ```css
  /// .mr-sum{gap:13px;#fff;1px #ECEEF1;r15;padding:15px 13px}
  /// .mr-left{sağ kenarlık #EFF1F4;padding-right:12px;gap:5px}
  /// .mr-gl{13px/700}  .mr-score{37px/800;-1px}  .mr-cnt{11.5px #5B6472}
  /// .mr-right{gap:7px}
  /// ```
  ///
  /// ⚠ Zemin BEYAZDIR (#fff) — önceki gri (#F7F9FC) referansta yoktur.
  Widget _summary() {
    final avg = _average;
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 13),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: RC.border),
        borderRadius: BorderRadius.circular(RR.r15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // .mr-left
          Container(
            padding: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFFEFF1F4))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Genel Puanım',
                    style: refText(
                        size: RF.s13, weight: RF.w700, color: RC.text)),
                const SizedBox(height: 5),
                // ⚠ Sıfır durumda '—' DEĞİL '0,0': ortalama henüz
                // hesaplanmadı değil, GERÇEKTEN sıfırdır. Tire
                // "veri yok/yüklenmedi" izlenimi veriyordu.
                Text((avg ?? 0).toStringAsFixed(1).replaceAll('.', ','),
                    style: refText(
                        size: 37,
                        weight: RF.w800,
                        color: RC.text,
                        letterSpacing: -1)),
                const SizedBox(height: 5),
                _stars(avg ?? 0, size: 20),
                const SizedBox(height: 5),
                Text(
                    _count == 0
                        ? '(Değerlendirme yok)'
                        : '($_count Değerlendirme)',
                    style: refText(
                        size: RF.s115,
                        weight: RF.w400,
                        color: RC.textSoft)),
              ],
            ),
          ),
          const SizedBox(width: 13), // .mr-sum{gap:13px}
          // .mr-right
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final k in const ['5', '4', '3', '2', '1']) ...[
                  _distRow(k, _dist[k] ?? 0),
                  if (k != '1') const SizedBox(height: 7), // gap:7px
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `.mr-drow` — tek dağılım satırı.
  ///
  /// ```css
  /// .mr-dn{12px/700;width:8px;text-align:right}
  /// .pr-dbar{7px;r4;#EDF0F4}  dolgu: #F5A319 (turuncu — mavi DEĞİL)
  /// .mr-dc{12px/600;width:28px;text-align:right}   ← ADET, yüzde DEĞİL
  /// ```
  Widget _distRow(String star, int n) {
    final oran = _count == 0 ? 0.0 : n / _count;
    return Row(
      children: [
        SizedBox(
          width: 8, // .mr-dn
          child: Text(star,
              textAlign: TextAlign.right,
              style: refText(size: RF.s12, weight: RF.w700, color: RC.text)),
        ),
        const SizedBox(width: 6),
        const RefSvg('assets/svg/ic_starfill.svg',
            size: 13, color: Color(0xFFF5A319)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: [
                  const Positioned.fill(
                      child: ColoredBox(color: Color(0xFFEDF0F4))),
                  // ⚠ En az %3 genişlik: sıfır olsa bile çubuk görünür
                  // (referans `Math.max(3, ...)`).
                  FractionallySizedBox(
                    widthFactor: oran < 0.03 ? 0.03 : oran,
                    child: const ColoredBox(color: Color(0xFFF5A319)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28, // .mr-dc
          child: Text('$n',
              textAlign: TextAlign.right,
              style: refText(size: RF.s12, weight: RF.w600, color: RC.text)),
        ),
      ],
    );
  }


  Widget _stars(double v, {double size = 18}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = v >= i + 1;
          final half = !filled && v > i && v < i + 1;
          return RefSvg(
            half
                ? 'assets/svg/ic_starb.svg'
                : (filled
                    ? 'assets/svg/ic_starfill.svg'
                    : 'assets/svg/ic_starempty.svg'),
            size: size,
            color: const Color(0xFFF5A319), // referans yıldız rengi
          );
        }),
      );

  /// Mock `Review` kaydını kartın beklediği haritaya çevirir.
  ///
  /// ⚠ Kart kodu DEĞİŞTİRİLMEZ; iki mod aynı çizimi kullanır.
  Map<String, dynamic> _mockSatir(Review r) {
    final yazar = context.read<AuthController>().accountById(r.authorId);
    final ilan = context.read<ListingController>().byId(r.listingId);
    return {
      'stars': r.stars,
      'text': r.text,
      'createdAt': r.createdAt.toIso8601String(),
      'author': {'name': yazar?.name ?? ''},
      'listing': {'title': ilan?.title ?? '', 'category': ilan?.title ?? ''},
    };
  }

  // ── Tek yorum kartı ───────────────────────────────────────────────────
  Widget _reviewCard(Map<String, dynamic> r) {
    final author = (r['author'] as Map<String, dynamic>?)?['name'] as String?;
    final listing = r['listing'] as Map<String, dynamic>?;
    final title = listing?['title'] as String?;
    final category = listing?['category'] as String?;
    final stars = (r['stars'] as num?)?.toInt() ?? 0;
    final text = (r['text'] as String? ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 11), // .mr-list{gap:11px}
      padding: const EdgeInsets.all(13), // .mr-card{padding:13px}
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: RC.border),
        borderRadius: BorderRadius.circular(RR.r14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .mr-head{gap:11px}
          Row(
            children: [
              // .mr-av{44px daire;19px/700} — baş harf rozeti
              RefBasHarfAvatar(
                  ad: (author == null || author.isEmpty) ? 'Hizmet Alan' : author),
              const SizedBox(width: 11),
              // .mr-hx{gap:2px}
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (author == null || author.isEmpty) ? 'Hizmet Alan' : author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s145, weight: RF.w700, color: RC.text),
                    ),
                    // .mr-svc — hizmet adı
                    if (title != null && title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        category != null && category.isNotEmpty
                            ? '$title · $category'
                            : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s12,
                            weight: RF.w400,
                            color: RC.textSoft),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // .mr-date{11.5px;#8A94A6}
              Text(_date(r['createdAt']),
                  style: refText(
                      size: RF.s115,
                      weight: RF.w400,
                      color: RC.greyLight)),
            ],
          ),
          // .mr-card .mr-stars{margin-top:9px}
          const SizedBox(height: 9),
          _stars(stars.toDouble(), size: 16),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8), // .mr-txt{margin-top:8px}
            Text(text,
                style: refText(
                    size: 12.8,
                    weight: RF.w400,
                    color: const Color(0xFF3A4658),
                    height: RF.lh155)),
          ],
        ],
      ),
    );
  }

  Widget _footer() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: RefTextButton('Daha fazla göster', onPressed: _loadMore),
        ),
      );
    }
    return const SizedBox(height: 12);
  }

  String _date(Object? raw) {
    final s = raw?.toString();
    if (s == null || s.isEmpty) {
      return '';
    }
    final d = DateTime.tryParse(s);
    if (d == null) {
      return '';
    }
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.${l.year}';
  }
}
