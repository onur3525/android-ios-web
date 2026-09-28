import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/remote/api_config.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/models/review.dart';
import '../data/remote/api/review_api.dart';
import '../data/remote/api_client.dart';
import '../ui/ref_widgets.dart';
import 'widgets/puan_dagilim_satiri.dart';
// ⚠ Yorum kartı ORTAK — kopya çizim yok.
import 'provider_reviews_screen.dart' show YorumKartiGovde;
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
    // ── ⚠ YENİ YORUM ANINDA GÖRÜNSÜN ──
    //
    // Ekran veriyi YALNIZ açılışta okuyordu. Hizmet alan yorum
    // yazdığında liste, ortalama ve toplam sayı ancak ekran yeniden
    // açılınca güncelleniyordu.
    //
    // ⚠ Depoya abone olunur; yorum eklenince liste BAŞTAN kurulur.
    // Böylece yeni yorum eskilerin ÜZERİNE YAZILMAZ, aynı yorum iki
    // kez eklenmez ve ortalama yeniden hesaplanır.
    _yorumlar = context.read<ReviewController>()..addListener(_yorumDegisti);
  }

  ReviewController? _yorumlar;

  void _yorumDegisti() {
    if (!mounted) {
      return;
    }
    // ⚠ `reset: true`: liste sıfırdan kurulur, tekrar oluşmaz.
    _load(reset: true);
  }

  @override
  void dispose() {
    _yorumlar?.removeListener(_yorumDegisti);
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
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── ⚠ BAŞLIK EKLENDİ (16 Eyl, kullanıcı isteği) ──
              //
              // "Müşteri yorumları sayfasında hiç başlık yok, ekle."
              //
              // Ekranda yalnız geri oku vardı; kullanıcı hangi sayfada
              // olduğunu anlamıyordu. Başlık, profil menüsündeki
              // satırın adıyla AYNI tutuldu ("Müşteri Yorumları") —
              // farklı olsaydı aynı yere iki ad verilmiş olurdu.
              //
              // ⚠ ORTAK BİLEŞEN: `RefDetailHeader` geri okunu da
              // kendisi çizer, bu yüzden buradaki ayrı `RefBackButton`
              // KALDIRILDI — iki ok üst üste görünürdü.
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: RefDetailHeader(title: 'Müşteri Yorumları'),
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
                // ⚠ "Değerlendirme" DEĞİL "yorum" (16 Eyl, kullanıcı
                // kararı). Sayı ne olursa olsun tekil yazılır —
                // Türkçede sayıdan sonra çoğul eki gelmez:
                // "1 yorum", "2 yorum", "3 yorum".
                Text(
                    _count == 0
                        ? '(Yorum yok)'
                        : '($_count yorum)',
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
  /// ⚠ ORTAK BİLEŞENE DELEGE EDİLDİ (10 Eyl): dağılım satırı artık
  /// `widgets/puan_dagilim_satiri.dart` içinde TEK yerde. Teklif
  /// detayındaki kopya yüzde yazıyor ve çubuğu hiç doldurmuyordu;
  /// iki grafik aynı olmalı.
  Widget _distRow(String star, int n) => PuanDagilimSatiri(
        yildiz: int.parse(star),
        adet: n,
        toplam: _count,
      );




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
  /// ⚠ İKİ KAYNAK: normal ilan (`listingId`) YA DA "Bul" üzerinden
  /// doğrudan teklif (`talepId`) — Review artık ikisinden birini
  /// taşıyabilir (bkz. model notu). Hangisi doluysa o gösterilir.
  Map<String, dynamic> _mockSatir(Review r) {
    final yazar = context.read<AuthController>().accountById(r.authorId);
    final ilan = r.listingId == null
        ? null
        : context.read<ListingController>().byId(r.listingId!);
    final talep = r.talepId == null
        ? null
        : context.read<TeklifTalebiController>().byId(r.talepId!);
    final baslik = ilan?.title ?? talep?.hizmet ?? '';
    return {
      'stars': r.stars,
      'text': r.text,
      'createdAt': r.createdAt.toIso8601String(),
      'author': {'name': yazar?.name ?? ''},
      'listing': {'title': baslik, 'category': baslik},
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

    // ── ⚠ KOPYA KART KALDIRILDI (kullanıcı kuralları, 9 Eyl) ──
    //
    // Bu ekran yorum kartını KENDİ çiziyordu ve o yüzden yeni
    // kurallardan hiçbirini almamıştı: profil fotoğrafı hâlâ
    // vardı, ad TAM SOYADIYLA yazıyordu ("Gönül Bütün"), uzun
    // yorumda aç/kapa yoktu.
    //
    // ⚠ MODEL DÖNÜŞTÜRÜLMEDİ: bu ekran sunucudan gelen HAM MAP ile
    // çalışıyor, elinde `Review` nesnesi yok. Bu yüzden çizim
    // `YorumKartiGovde`ye taşındı; `Review` tutan ekranlar
    // `YorumKarti` sarmalayıcısını, bu ekran doğrudan gövdeyi
    // kullanıyor. Tek çizim, iki giriş.
    //
    // ⚠ TAM AD GEÇİRİLİR: kısaltma bileşenin içinde yapılır
    // (`kisaYazarAdi`). Burada kısaltsaydım iki ekran ayrışabilirdi.
    //
    // ⚠ HİZMET ADI TEKRARI GİDERİLDİ: veri `title` ve `category`
    // alanlarını AYNI değerle döndürebiliyor ve kart
    // "Doğalgaz Tesisatı · Doğalgaz Tesisatı" yazıyordu. Aynıysa
    // tek kez yazılır.
    final hizmet = (title == null || title.isEmpty)
        ? null
        : ((category == null || category.isEmpty || category == title)
            ? title
            : '$title · $category');

    return Padding(
      padding: const EdgeInsets.only(bottom: 11), // .mr-list{gap:11px}
      child: YorumKartiGovde(
        adTam: author,
        hizmet: hizmet,
        tarih: _date(r['createdAt']),
        yildiz: stars,
        metin: text,
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
