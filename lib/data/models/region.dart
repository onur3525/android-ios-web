/// BÖLGE VERİSİ — şehir / ilçe / mahalle
///
/// TEK GERÇEK KAYNAK VERİTABANIDIR. Bu model `GET /regions/tree` cevabını
/// temsil eder. Uygulama içindeki sabit İzmir dosyaları artık karar
/// kaynağı DEĞİLDİR (yalnız test fixture / seed üretimi için durur).
///
/// Sunucu yalnız AKTİF kayıtları döner; pasifleştirilmiş şehir, ilçe ve
/// mahalleler kullanıcıya hiç gösterilmez.
library;

class Neighborhood {
  final String id;
  final String name;
  const Neighborhood({required this.id, required this.name});

  factory Neighborhood.fromJson(Map<String, dynamic> j) => Neighborhood(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
      );
}

class District {
  final String id;
  final String name;

  /// "Tüm ilçelere hizmet veriyorum" seçeneğinin desteklenip
  /// desteklenmediği BACKEND SÖZLEŞMESİNDEN gelir.
  final bool allDistrictsSupported;

  final List<Neighborhood> neighborhoods;

  const District({
    required this.id,
    required this.name,
    required this.allDistrictsSupported,
    required this.neighborhoods,
  });

  factory District.fromJson(Map<String, dynamic> j) => District(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        allDistrictsSupported: j['allDistrictsSupported'] as bool? ?? false,
        neighborhoods: ((j['neighborhoods'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Neighborhood.fromJson)
            .toList(growable: false),
      );

  List<String> get neighborhoodNames =>
      neighborhoods.map((n) => n.name).toList(growable: false);
}

class City {
  final String id;
  final String name;
  final List<District> districts;

  const City({
    required this.id,
    required this.name,
    required this.districts,
  });

  factory City.fromJson(Map<String, dynamic> j) => City(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        districts: ((j['districts'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(District.fromJson)
            .toList(growable: false),
      );

  List<String> get districtNames =>
      districts.map((d) => d.name).toList(growable: false);

  District? districtByName(String name) {
    for (final d in districts) {
      if (d.name == name) {
        return d;
      }
    }
    return null;
  }
}

class RegionTree {
  final List<City> cities;
  const RegionTree(this.cities);

  static const empty = RegionTree(<City>[]);

  bool get isEmpty => cities.isEmpty;

  factory RegionTree.fromJson(Map<String, dynamic> j) => RegionTree(
        ((j['cities'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(City.fromJson)
            .toList(growable: false),
      );

  /// Varsayılan şehir — platform şu an tek şehirle çalışıyor.
  City? get primaryCity => cities.isEmpty ? null : cities.first;

  City? cityByName(String name) {
    for (final c in cities) {
      if (c.name == name) {
        return c;
      }
    }
    return null;
  }

  /// Verilen ilçenin mahalleleri (bilinmeyen ilçede boş liste).
  List<String> neighborhoodsOf(String district, {String? city}) {
    final c = city == null ? primaryCity : cityByName(city);
    return c?.districtByName(district)?.neighborhoodNames ?? const [];
  }
}
