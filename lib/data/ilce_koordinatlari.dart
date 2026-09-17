/// ── ⚠ İLÇE MERKEZİ KOORDİNATLARI — GERÇEK VERİ ──
///
/// `YakinlikSaglayici` soyutlamasının GERÇEK (koordinat tabanlı)
/// uygulaması bu dosyadaki verilere dayanır (bkz.
/// `domain/yakinlik_saglayici.dart` içindeki
/// `KoordinatTabanliYakinlikSaglayici`).
///
/// ── KAYNAK ──
///
/// Temel veri: Google Maps / Başarsoft — kamuya açık, yapılandırılmış
/// il/ilçe enlem-boylam tablosu.
///   https://gist.github.com/ismailbaskin/2492196
///
/// ⚠ İKİ KAYIT DÜZELTİLDİ: kaynaktaki "Karşıyaka" ve "Buca" satırları
/// İzmir il merkeziyle AYNI koordinatı taşıyordu (toplama sırasında
/// oluşmuş bir veri hatası — bu iki büyük ilçenin merkezi il
/// merkeziyle çakışamaz). Üç bağımsız kaynaktan (harita.gen.tr,
/// Yandex Haritalar, Wikipedia) çapraz doğrulanarak düzeltildi:
///   Karşıyaka → 38.4586, 27.1201
///   Buca      → 38.3868, 27.1747
///
/// ── KAPSAM ──
///
/// Yalnız İzmir'in 30 ilçesi var — projede şu an yalnız İzmir
/// "hizmete açık" (bkz. `kIzmirDistricts`, `data/izmir.dart`).
/// Başka bir il eklendiğinde bu dosyaya o ilin ilçe koordinatları
/// AYNI BİÇİMDE eklenir; `KoordinatTabanliYakinlikSaglayici` başka
/// hiçbir yerde değişikliğe gerek duymadan onları da kullanır.
///
/// ── DOĞRULUK SINIRI ──
///
/// Bunlar İLÇE MERKEZİ noktalarıdır, sınır/alan verisi DEĞİLDİR.
/// Büyükşehir ilçelerinde (İzmir'in tamamı büyükşehirdir) merkez
/// noktası ilçenin nüfus ağırlık merkezinden sapabilir — bu, "hangi
/// ilçe önce taranır" sıralamasını KABA olarak doğru verir, kesin
/// kilometre mesafesi olarak SUNULMAZ (zaten kullanıcıya km
/// gösterilmiyor, yalnız sıralama için kullanılıyor).
const Map<String, ({double lat, double lng})> kIlceKoordinatlari = {
  'Aliağa': (lat: 38.7950, lng: 26.9703),
  'Balçova': (lat: 38.3693, lng: 27.0934),
  'Bayındır': (lat: 38.2286, lng: 27.6465),
  'Bayraklı': (lat: 38.4622, lng: 27.1667),
  'Bergama': (lat: 39.1167, lng: 27.1833),
  'Beydağ': (lat: 38.0869, lng: 28.2088),
  'Bornova': (lat: 38.4627, lng: 27.2441),
  // ⚠ Düzeltilen kayıt — bkz. dosya başı not.
  'Buca': (lat: 38.3868, lng: 27.1747),
  'Çeşme': (lat: 38.3298, lng: 26.3149),
  'Çiğli': (lat: 38.4994, lng: 27.0382),
  'Dikili': (lat: 39.0721, lng: 26.8882),
  'Foça': (lat: 38.6675, lng: 26.7581),
  'Gaziemir': (lat: 38.3252, lng: 27.1225),
  'Güzelbahçe': (lat: 38.3620, lng: 26.9028),
  'Karabağlar': (lat: 38.3270, lng: 27.0441),
  'Karaburun': (lat: 38.6333, lng: 26.5167),
  // ⚠ Düzeltilen kayıt — bkz. dosya başı not.
  'Karşıyaka': (lat: 38.4586, lng: 27.1201),
  'Kemalpaşa': (lat: 38.4263, lng: 27.4231),
  'Kınık': (lat: 39.0884, lng: 27.3807),
  'Kiraz': (lat: 38.2306, lng: 28.2044),
  'Konak': (lat: 38.4145, lng: 27.1441),
  'Menderes': (lat: 38.2540, lng: 27.1340),
  'Menemen': (lat: 38.6000, lng: 27.0667),
  'Narlıdere': (lat: 38.3910, lng: 27.0029),
  'Ödemiş': (lat: 38.2306, lng: 27.9717),
  'Seferihisar': (lat: 38.1989, lng: 26.8373),
  'Selçuk': (lat: 37.9499, lng: 27.3701),
  'Tire': (lat: 38.0886, lng: 27.7335),
  'Torbalı': (lat: 38.1778, lng: 27.3533),
  'Urla': (lat: 38.3246, lng: 26.7619),
};
