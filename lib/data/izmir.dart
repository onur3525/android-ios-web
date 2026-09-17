import 'category_tree.dart';

/// İl kuralı: yalnızca İZMİR seçilebilir (HTML iş kuralı).
const String kCity = 'İzmir';

/// İzmir'in 30 ilçesi (resmî liste).
const List<String> kIzmirDistricts = [
  'Aliağa', 'Balçova', 'Bayındır', 'Bayraklı', 'Bergama', 'Beydağ', 'Bornova',
  'Buca', 'Çeşme', 'Çiğli', 'Dikili', 'Foça', 'Gaziemir', 'Güzelbahçe',
  'Karabağlar', 'Karaburun', 'Karşıyaka', 'Kemalpaşa', 'Kınık', 'Kiraz',
  'Konak', 'Menderes', 'Menemen', 'Narlıdere', 'Ödemiş', 'Seferihisar',
  'Selçuk', 'Tire', 'Torbalı', 'Urla',
];

// ═══════════════════════════════════════════════════════════════
// KATEGORİ VERİSİ — TEK KAYNAK: `category_tree.dart`
//

/// Ana kategoriler — referans ağacın tamamı.
List<String> get kHomeCategories => kTreeCategories;

/// Ana kategori → alt hizmetler.
Map<String, List<String>> get kSubServices => kCategoryTree;
