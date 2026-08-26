import '../../domain/failures.dart';
import '../models/region.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// BÖLGE VERİSİ DURUMU
///
/// Şehir/ilçe/mahalle verisi SUNUCUDAN gelir; sabit dosyalar karar
/// kaynağı değildir.
///
/// Ele alınan durumlar: yükleniyor, boş, hata, tekrar dene ve
/// ÇEVRİMDIŞI YEDEK (son başarılı cevap bellekte tutulur).
class RegionController extends BaseController {
  final RegionPort _regions;
  /// `RegionPort` bir `Listenable` DEĞİLDİR (salt okuma sözleşmesi),
  /// bu yüzden bağımlılık listesi boştur.
  RegionController(this._regions) : super(const []);

  RegionTree? _tree;
  DomainError? _error;

  /// Son başarılı cevap — ağ koptuğunda kullanıcının ekranı boş kalmasın.
  RegionTree? _cache;

  RegionTree get tree => _tree ?? _cache ?? RegionTree.empty;
  DomainError? get error => _error;

  bool get hasData => tree.cities.isNotEmpty;

  /// Veri yok, hata da yok → gerçekten boş sonuç.
  bool get isEmpty => !isBusy('regions') && _error == null && !hasData;

  /// Hata var ama çevrimdışı yedek gösteriliyor.
  bool get showingCache => _error != null && _cache != null;

  // ═══════════════════════════════════════════════════════════════
  // ŞEHİR ZİNCİRİ — İl → İlçe → Mahalle
  //
  // ⚠ İL HARD-CODE DEĞİLDİR. Aktif il listesi SUNUCUDAN gelir
  // (`RegionTree.cities`). Bugün mock veride yalnız İzmir bulunur;
  // admin/backend yeni bir il aktif ettiğinde aynı yapı onu
  // KENDİLİĞİNDEN gösterir — ekran veya doğrulama kodu değişmez.
  // ═══════════════════════════════════════════════════════════════

  /// Seçilebilir il adları (sunucudan gelen aktif iller).
  List<String> get cityNames =>
      tree.cities.map((c) => c.name).toList(growable: false);

  /// Tek il varsa onu döndürür; birden çok il varsa `null`
  /// (kullanıcı seçmelidir).
  String? get soleCityName =>
      tree.cities.length == 1 ? tree.cities.first.name : null;

  /// Geriye dönük uyumluluk: varsayılan/ilk il adı.
  ///
  /// ⚠ Yeni kodda `cityNames` + kullanıcı seçimi kullanılmalıdır.
  String? get cityName => tree.primaryCity?.name;

  bool isKnownCity(String name) => tree.cityByName(name) != null;

  /// Verilen ilin ilçeleri. [city] verilmezse varsayılan il kullanılır.
  List<String> districtsOf(String? city) {
    if (city == null || city.isEmpty) {
      return tree.primaryCity?.districtNames ?? const [];
    }
    return tree.cityByName(city)?.districtNames ?? const [];
  }

  /// Varsayılan ilin ilçeleri (geriye dönük uyumluluk).
  List<String> get districts => districtsOf(null);

  /// Verilen ilçenin mahalleleri. [city] verilirse o ilin içinde aranır.
  List<String> neighborhoodsOf(String district, {String? city}) =>
      tree.neighborhoodsOf(district, city: city);

  /// Bu ilçe "tüm ilçeler" seçeneğini destekliyor mu? (backend sözleşmesi)
  bool allDistrictsSupported() {
    final ds = tree.primaryCity?.districts ?? const <District>[];
    return ds.isNotEmpty && ds.every((d) => d.allDistrictsSupported);
  }

  /// Seçili kayıt sunucuda pasifleştirilmiş olabilir: listede yoksa
  /// çağıran ekran kontrollü uyarı gösterir.
  bool isKnownDistrict(String name, {String? city}) =>
      districtsOf(city).contains(name);

  bool isKnownNeighborhood(String district, String name, {String? city}) =>
      neighborhoodsOf(district, city: city).contains(name);

  /// Veriyi yükler. Zaten yüklenmişse ve [force] false ise tekrar çekmez.
  Future<void> load({bool force = false}) async {
    if (!force && _tree != null) {
      return;
    }
    if (!setBusy('regions', true)) {
      return;
    }
    _error = null;
    notifyListeners();

    final (data, err) = await _regions.regionTree();
    if (err != null) {
      _error = err;
      // Yedek varsa korunur; yoksa ekran hata durumunu gösterir.
    } else {
      _tree = data;
      _cache = data;
    }
    setBusy('regions', false);
  }

  /// Hata ekranındaki "Tekrar Dene".
  Future<void> retry() => load(force: true);
}
