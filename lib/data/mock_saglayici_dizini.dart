import '../domain/yakinlik_saglayici.dart';

/// ── ⚠ MOCK HİZMET VEREN DİZİNİ — GERÇEK BACKEND DEĞİL ──
///
/// Projede "belirli bir hizmeti veren hizmet verenleri il/ilçeye
/// göre bul" sorgusunu karşılayacak GERÇEK bir depo/repository
/// YOKTUR — bu, "Bul" akışının kendisiyle birlikte gelen YENİ bir
/// ihtiyaçtır.
///
/// Bu dosya yalnız GELİŞTİRME/GÖSTERİM amaçlıdır. Gerçek backend
/// bağlandığında bu dosyanın YERİNE bir `SaglayiciDizinPort`
/// (repository/port) geçecek; `SonuclarScreen` yalnız `List<MockSaglayici>`
/// tükettiği için o gün ekranın kendisi DEĞİŞMEYECEK.
class MockSaglayici {
  const MockSaglayici({
    required this.id,
    required this.adSoyad,
    required this.ilce,
    required this.puan,
    required this.yorumSayisi,
    required this.tamamlananIs,
    required this.aktiflikSkoru,
    this.gercek = false,
  });

  final String id;
  final String adSoyad;
  final String ilce;
  final double puan;
  final int yorumSayisi;
  final int tamamlananIs;

  /// ⚠ "AKTİFLİK" — uygulamanın o an açık olması DEĞİLDİR.
  ///
  /// Platformdaki gerçek kullanım/yanıt/iş aktivitesinin 0-1
  /// arası bir özeti olarak TASARLANMIŞTIR. Gerçek backend bu
  /// değeri yanıt süresi, son giriş, tamamlanma oranı gibi
  /// sinyallerden hesaplayacak — burada yalnız SABİT mock veridir.
  final double aktiflikSkoru;

  /// ⚠ `true` İSE bu kayıt KURGUSAL DEĞİL — gerçek kayıtlı bir
  /// hesaptan üretildi (`id` gerçek hesap id'sidir, "mock-saglayici-N"
  /// DEĞİL). "Teklif İste" bu id'yi kullanır; gerçek hizmet veren
  /// gerçekten kendi "Teklif İstekleri" sekmesinde talebi görür.
  final bool gercek;
}

/// Seçilen hizmet + kullanıcının il/ilçesi için hizmet veren
/// listesini, "yakınlık" bilgisiyle birlikte üretir.
///
/// ⚠ GERÇEK EŞLEŞME + MOCK DOLGU: `gercekSaglayicilar` — o hizmeti
/// GERÇEKTEN sunduğunu `MyCategoriesScreen`de kendi seçmiş, kayıtlı
/// hesaplardan üretilir (bkz. `sonuclar_screen.dart`). Mock havuz,
/// gerçek sonuç olsun ya da olmasın, listeyi DOLDURMAYA devam eder —
/// gerçek backend/dizin tam kurulana kadarki bilinen bir
/// sadeleştirmedir.
List<({MockSaglayici saglayici, int yakinlikSirasi})> mockSaglayicilariBul({
  required String il,
  required String ilce,
  required YakinlikSaglayici yakinlik,
  List<MockSaglayici> gercekSaglayicilar = const [],
}) {
  // ── ⚠ TAM SIRALI LİSTE — artık "yakın/uzak" gibi kaba İKİ grup
  // DEĞİL. `yakinlik.yakinIlceler` (kendi ilçesi hariç) EN YAKINDAN
  // EN UZAĞA sıralı gelir (bkz. `KoordinatTabanliYakinlikSaglayici`).
  // Bu sıradaki KONUM doğrudan `yakinlikSirasi` olur — ilk sırada
  // olan ilçe puan/aktiflik eşitliğinde önde çıkar.
  final siraliIlceler = yakinlik.yakinIlceler(il, ilce);
  final ilceSirasi = <String, int>{
    ilce: 0, // ⚠ KENDİ İLÇESİ HER ZAMAN 0 — "Aşama 1".
    for (var i = 0; i < siraliIlceler.length; i++) siraliIlceler[i]: i + 1,
  };

  int siraHesapla(String saglayiciIlcesi) =>
      ilceSirasi[saglayiciIlcesi] ?? (siraliIlceler.length + 1);

  // ── ⚠ KURGUSAL HAVUZ ARTIK LİSTEYE KARIŞMIYOR (9 Eyl) ──
  //
  // KULLANICI KARARI: "Buradaki bilgiler görüntü olarak kalmayacak,
  // gerçek bilgilerle doldurulacak."
  //
  // ÖNCEDEN `_havuz(...)` sonuçları gerçek hesapların ARDINA
  // ekleniyordu; ekran hep dolu görünsün diye. Sonuç: kullanıcı,
  // gerçek olmayan isim/puan/iş sayısı gören bir liste ile karşı
  // karşıya kalıyordu ve hangisinin gerçek olduğunu ayırt edemiyordu.
  //
  // ⚠ SONUÇ: o hizmeti gerçekten sunan kayıtlı hesap yoksa liste BOŞ
  // döner. Bu bilinçlidir — boş liste, sahte doluluktan dürüsttür.
  // Ekran boş durumu kendi gösterir.
  //
  // ⚠ `_havuz` SİLİNMEDİ: sıralama mantığının elle denenmesi için
  // duruyor, ama HİÇBİR ÜRÜN AKIŞINDAN çağrılmıyor.
  final sonuc = [
    for (final s in gercekSaglayicilar)
      (saglayici: s, yakinlikSirasi: siraHesapla(s.ilce)),
  ];

  // ── ⚠ SIRALAMA: önce İLÇE, sonra aktiflik → puan → yorum →
  // tamamlanan iş (ürün kararı, güncellendi) ──
  //
  // Mesafe burada `yakinlikSirasi`dir — gerçek haversine sırasına
  // göre 0 (kendi ilçe), 1 (en yakın), 2, 3... şeklinde artar.
  // Kullanıcıya GÖSTERİLMEZ — yalnız sıralama kriteridir.
  //
  // ÖNCEDEN mesafe EN SONDAKİ kıstastı: yeni başlayan, hiç yorumu
  // olmayan ama hizmet alanla AYNI ilçedeki bir usta, uzak ilçedeki
  // deneyimli ustaların GERİSİNE düşebiliyordu. Şimdi İLÇE YAKINLIĞI
  // birincil kıstas — önce "hangi ilçe" (kendi ilçesi → en yakın →
  // ... → en uzak), AYNI ilçe içinde eşitlik olursa aktiflik/puan/
  // yorum/tamamlanan iş belirler.
  sonuc.sort((a, b) {
    var c = a.yakinlikSirasi.compareTo(b.yakinlikSirasi);
    if (c != 0) return c;
    c = b.saglayici.aktiflikSkoru.compareTo(a.saglayici.aktiflikSkoru);
    if (c != 0) return c;
    c = b.saglayici.puan.compareTo(a.saglayici.puan);
    if (c != 0) return c;
    c = b.saglayici.yorumSayisi.compareTo(a.saglayici.yorumSayisi);
    if (c != 0) return c;
    return b.saglayici.tamamlananIs.compareTo(a.saglayici.tamamlananIs);
  });

  return sonuc;
}

/// ⚠ KURGUSAL HAVUZ SİLİNDİ (9 Eyl, kullanıcı kararı): "Buradaki
/// bilgiler görüntü olarak kalmayacak, gerçek bilgilerle
/// doldurulacak."
///
/// Burada 14 uydurma isim, puan, yorum ve tamamlanan iş sayısı
/// duruyordu ve sonuç listesine karışıyordu. Dosyada BIRAKILSAYDI
/// bir sonraki turda yeniden bağlanması an meselesiydi.
///
/// ⚠ Sıralama mantığı (`mockSaglayicilariBul`) DURUYOR: ilçe
/// yakınlığı → aktiflik → puan → yorum → tamamlanan iş. Değişen tek
/// şey, artık YALNIZ gerçek hesapların sıralanması.
