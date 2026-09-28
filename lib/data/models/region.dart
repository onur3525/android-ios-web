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

  /// ⚠ AD OLDUĞU GİBİ KORUNUR: "Ağaçkonak Köyü" gibi köy kayıtları da
  /// bu listede, kendi adlarıyla durur. Ayrı bir "köy seçimi" YOKTUR;
  /// hiyerarşi yalnız İl → İlçe → Mahalle'dir.
  final String name;

  /// Posta kodu — veri kaynağında varsa korunur.
  final String? postaKodu;

  /// ── ⚠ HİZMETE AÇIK MI ──
  ///
  /// Verinin VAR OLMASI ile HİZMETE AÇIK olması ayrı şeylerdir. Bu
  /// alan yalnız hizmet durumunu tutar; pasif yapmak veriyi SİLMEZ.
  ///
  /// ⚠ VARSAYILAN `true`: sunucu alanı göndermezse mevcut davranış
  /// bozulmaz (geriye dönük uyumluluk).
  final bool aktif;

  const Neighborhood({
    required this.id,
    required this.name,
    this.postaKodu,
    this.aktif = true,
  });

  factory Neighborhood.fromJson(Map<String, dynamic> j) => Neighborhood(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        postaKodu: j['postalCode'] as String?,
        aktif: j['active'] as bool? ?? true,
      );
}

class District {
  final String id;
  final String name;

  /// "Tüm ilçelere hizmet veriyorum" seçeneğinin desteklenip
  /// desteklenmediği BACKEND SÖZLEŞMESİNDEN gelir.
  final bool allDistrictsSupported;

  /// ⚠ İLÇE BAĞIMSIZ AÇILIP KAPANABİLİR: il aktif olsa bile bir ilçe
  /// pasif olabilir (ör. İzmir açık, Bergama kapalı).
  final bool aktif;

  final List<Neighborhood> neighborhoods;

  const District({
    required this.id,
    required this.name,
    required this.allDistrictsSupported,
    this.aktif = true,
    required this.neighborhoods,
  });

  factory District.fromJson(Map<String, dynamic> j) => District(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        allDistrictsSupported: j['allDistrictsSupported'] as bool? ?? false,
        aktif: j['active'] as bool? ?? true,
        neighborhoods: ((j['neighborhoods'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Neighborhood.fromJson)
            .toList(growable: false),
      );

  /// ⚠ YALNIZ HİZMETE AÇIK MAHALLELER.
  ///
  /// Kullanıcı pasif bir mahalleyi hizmet bölgesi olarak seçemez.
  /// Veri yerinde durur, yalnız listede görünmez.
  List<String> get neighborhoodNames => neighborhoods
      .where((n) => n.aktif)
      .map((n) => n.name)
      .toList(growable: false);

  /// ⚠ TÜM mahalleler — aktiflik gözetmeksizin.
  /// Admin görünümü ve geçmiş adres çözümlemesi için.
  List<String> get tumMahalleAdlari =>
      neighborhoods.map((n) => n.name).toList(growable: false);
}

class City {
  final String id;
  final String name;

  /// ── ⚠ ŞEHİR HİZMETE AÇIK MI ──
  ///
  /// Başlangıçta yalnız İzmir `true`; Türkiye'nin öteki 80 ili
  /// listede GÖRÜNÜR ama `false`tur ("Yakında HizmetCep'te").
  ///
  /// ⚠ PASİF ŞEHRİN VERİSİ SİLİNMEZ: ilçeleri ve mahalleleri yerinde
  /// durur. Şehir sonradan açıldığında yeniden veri yüklemek ya da
  /// APK güncellemek GEREKMEZ — yalnız bu alan değişir.
  final bool aktif;

  final List<District> districts;

  const City({
    required this.id,
    required this.name,
    this.aktif = true,
    required this.districts,
  });

  factory City.fromJson(Map<String, dynamic> j) => City(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        // ⚠ Alan gelmezse `true`: mevcut tek şehirli davranış bozulmaz.
        aktif: j['active'] as bool? ?? true,
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

  /// ── ⚠ HİZMETE AÇIK ŞEHİRLER ──
  ///
  /// Sıralama: önce AKTİF şehirler, sonra pasifler — ikisi de kendi
  /// içinde alfabetik. Başlangıçta tek aktif şehir İzmir olduğu için
  /// listenin başında görünür.
  List<City> get siraliSehirler {
    final aktifler = cities.where((c) => c.aktif).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final pasifler = cities.where((c) => !c.aktif).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [...aktifler, ...pasifler];
  }

  /// ── ⚠ ETKİN AKTİFLİK — ÜST SEVİYE KAPALIYSA ALT DA KAPALIDIR ──
  ///
  /// Kural: **il aktif VE ilçe aktif VE mahalle aktif**.
  ///
  /// Admin üst seviyeyi kapatarak bütün altını tek işlemle devre dışı
  /// bırakabilir; alt kayıtları tek tek değiştirmesi GEREKMEZ.
  ///
  /// ⚠ EKRANLAR KENDİ KURALINI YAZMAZ: aktiflik sorusu buradan
  /// sorulur, üç ekran üç farklı sonuç üretmesin.
  bool hizmeteAcik({
    required String sehir,
    String? ilce,
    String? mahalle,
  }) {
    final c = cityByName(sehir);
    if (c == null || !c.aktif) {
      return false;
    }
    if (ilce == null) {
      return true;
    }
    final d = c.districtByName(ilce);
    if (d == null || !d.aktif) {
      return false;
    }
    if (mahalle == null) {
      return true;
    }
    for (final n in d.neighborhoods) {
      if (n.name == mahalle) {
        return n.aktif;
      }
    }
    return false;
  }

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
