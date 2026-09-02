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
// ⚠ Eski elle yazılmış 7 kategori / 30 alt hizmet listesi KALDIRILDI.
// Kategori ve alt hizmet adları `category_tree.dart` içindeki
// `kCategoryTree` sabitinden gelir (63 kategori, 640 alt hizmet).
//
// ⚠ KAYNAK HTML DEĞİLDİR: katalog bir tur referans HTML ağacından
// (34/165) türetilmişti, artık ondan BAĞIMSIZDIR ve ürün kararıyla
// büyür. HTML yalnız UI/UX referansı olmaya devam eder.
//
// Böylece ana sayfa, arama, ilan oluşturma ve hizmet sağlayıcı
// kategori seçimi AYNI veriyi kullanır; admin/backend yeni kategori
// eklediğinde tek dosya güncellenir.
// ═══════════════════════════════════════════════════════════════

/// Ana kategoriler — referans ağacın tamamı.
List<String> get kHomeCategories => kTreeCategories;

/// Ana kategori → alt hizmetler.
Map<String, List<String>> get kSubServices => kCategoryTree;
