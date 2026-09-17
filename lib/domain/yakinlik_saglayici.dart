import 'dart:math' as math;

import '../data/ilce_koordinatlari.dart';

/// ── ⚠ YAKINLIK SAĞLAYICISI SOYUTLAMASI ──
///
/// "Bul" akışında hizmet verenler önce hizmet alanın İLÇESİNDE,
/// bulunamazsa YAKIN İLÇELERDE, hâlâ yoksa İL GENELİNDE aranır.
///
/// ⚠ GERÇEK KOORDİNAT VERİSİ ARTIK VAR — `ilce_koordinatlari.dart`
/// (bkz. o dosyadaki kaynak notu). `KoordinatTabanliYakinlikSaglayici`
/// gerçek enlem/boylamdan haversine mesafesiyle sıralar.
/// `IlBazliYakinlikSaglayici` yalnız koordinatı OLMAYAN bir il için
/// (ki şu an projede İzmir dışında hiçbiri "hizmete açık" değil)
/// GERİ DÜŞÜŞ (fallback) olarak tutulur — çağıran kod hangi
/// uygulamanın kullanıldığını BİLMEZ, yalnız `YakinlikSaglayici`
/// arayüzünü görür.
abstract class YakinlikSaglayici {
  /// Verilen il/ilçenin KENDİSİ HARİÇ, öteki ilçeleri — EN YAKINDAN
  /// EN UZAĞA sıralı.
  ///
  /// ⚠ `KoordinatTabanliYakinlikSaglayici`'de bu sıra GERÇEK coğrafi
  /// mesafeye dayanır (haversine). Koordinat yoksa
  /// `IlBazliYakinlikSaglayici`'ye düşülür; o durumda sıra yalnız
  /// "aynı ildeki öteki ilçeler" anlamına gelir, mesafe TAŞIMAZ.
  List<String> yakinIlceler(String il, String ilce);
}

/// ── ⚠ GERÇEK UYGULAMA — HAVERSINE MESAFESİYLE SIRALAR ──
///
/// Kullanıcının ilçesinden ötekilere gerçek küresel mesafe (km)
/// hesaplanır ve en yakından en uzağa sıralanır. `ilce`nin kendisi
/// bu listede YER ALMAZ — o zaten "Aşama 1: kendi ilçesi" olarak
/// ayrıca ele alınır (bkz. `mock_saglayici_dizini.dart`).
///
/// ⚠ Koordinatı olmayan bir ilçe (kendi ilçe dahil) için elde veri
/// yoksa `IlBazliYakinlikSaglayici`'ye SESSİZCE düşer — uygulama
/// çökmez, yalnız sıralama coğrafi anlamını kaybeder.
class KoordinatTabanliYakinlikSaglayici implements YakinlikSaglayici {
  const KoordinatTabanliYakinlikSaglayici(this._ilceleriGetir);

  final List<String> Function(String il) _ilceleriGetir;

  @override
  List<String> yakinIlceler(String il, String ilce) {
    final tumIlceler =
        _ilceleriGetir(il).where((i) => i != ilce).toList(growable: false);

    final merkez = kIlceKoordinatlari[ilce];
    if (merkez == null) {
      // ⚠ Kendi ilçemizin koordinatı yoksa mesafe hesaplanamaz —
      // dürüst geri düşüş.
      return IlBazliYakinlikSaglayici(_ilceleriGetir)
          .yakinIlceler(il, ilce);
    }

    final mesafeli = <({String ilce, double km})>[];
    final koordinatsiz = <String>[];
    for (final i in tumIlceler) {
      final nokta = kIlceKoordinatlari[i];
      if (nokta == null) {
        koordinatsiz.add(i);
        continue;
      }
      mesafeli.add((ilce: i, km: _haversineKm(merkez, nokta)));
    }
    mesafeli.sort((a, b) => a.km.compareTo(b.km));

    // ⚠ Koordinatı olmayan ilçeler EN SONA, kendi aralarında mevcut
    // sırayla eklenir — kaybolmazlar, yalnız sıralanamazlar.
    return [
      for (final m in mesafeli) m.ilce,
      ...koordinatsiz,
    ];
  }
}

/// Haversine formülü — Dünya küresi üzerinde iki nokta arası gerçek
/// mesafe (km). Standart, doğrulanabilir bir hesaplamadır; uydurma
/// bir yaklaşıklık DEĞİLDİR.
double _haversineKm(({double lat, double lng}) a, ({double lat, double lng}) b) {
  const yaricap = 6371.0; // km — Dünya ortalama yarıçapı
  final dLat = _radyan(b.lat - a.lat);
  final dLng = _radyan(b.lng - a.lng);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radyan(a.lat)) *
          math.cos(_radyan(b.lat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return yaricap * c;
}

double _radyan(double derece) => derece * math.pi / 180;

/// ── ⚠ GEÇİCİ UYGULAMA — İL/İLÇE HİYERARŞİSİNE DAYALI (GERİ DÜŞÜŞ) ──
///
/// Gerçek coğrafi mesafe hesaplayamaz. Yalnız aynı ildeki, verilen
/// ilçe dışındaki ilçeleri döndürür. `KoordinatTabanliYakinlikSaglayici`
/// koordinat bulamadığında bu sınıfa düşer.
class IlBazliYakinlikSaglayici implements YakinlikSaglayici {
  const IlBazliYakinlikSaglayici(this._ilceleriGetir);

  /// Bir ilin ilçe adlarını döndüren fonksiyon — çağıran taraf
  /// `RegionController.tree` üzerinden sağlar. Bu sınıf `RegionTree`
  /// tipine DOĞRUDAN bağımlı değildir; test edilebilirlik için.
  final List<String> Function(String il) _ilceleriGetir;

  @override
  List<String> yakinIlceler(String il, String ilce) {
    final tumIlceler = _ilceleriGetir(il);
    return tumIlceler.where((i) => i != ilce).toList(growable: false);
  }
}
