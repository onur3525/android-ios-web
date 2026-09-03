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

  final havuz =
      _havuz(il: il, ilce: ilce, siraliIlceler: siraliIlceler);

  final sonuc = [
    for (final s in [...gercekSaglayicilar, ...havuz])
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

/// ⚠ SABİT MOCK HAVUZ — gerçek isim/istatistik DEĞİL, yalnız ekranı
/// doldurmak için kurgusaldır. İlk üç kayıt kasıtlı olarak
/// kullanıcının kendi ilçesinde; kalanı `siraliIlceler`in BAŞINDAN
/// SONUNA doğru dağıtılmıştır — yani gerçekten YAKINDAN UZAĞA giden
/// ilçelere yerleştirilir, sıralama mantığı gözle görünür olsun diye.
List<MockSaglayici> _havuz({
  required String il,
  required String ilce,
  required List<String> siraliIlceler,
}) {
  String ilceSec(int i) {
    if (i < 3) return ilce; // aynı ilçe
    if (siraliIlceler.isNotEmpty) {
      // ⚠ (i - 3) arttıkça `siraliIlceler`de İLERİ gidilir — yani
      // sonraki hizmet veren bir öncekinden DAHA UZAK bir ilçeye
      // düşer. Modulo yalnız havuz ilçe sayısını AŞARSA devreye
      // girer (30 ilçeden fazla mock kayıt varsa).
      return siraliIlceler[(i - 3) % siraliIlceler.length];
    }
    return ilce;
  }

  const isimler = [
    'Ahmet Bulut', 'Mehmet Kaya', 'Ayşe Demir', 'Fatma Şahin',
    'Mustafa Çelik', 'Emine Aydın', 'Hüseyin Öztürk', 'Zeynep Arslan',
    'Ali Doğan', 'Elif Yıldız', 'İbrahim Kurt', 'Hatice Aksoy',
    'Osman Koç', 'Merve Tan',
  ];
  const puanlar = [
    5.0, 4.9, 4.8, 4.7, 4.9, 4.6, 5.0, 4.5, 4.8, 4.4, 4.7, 4.3, 4.9, 4.2,
  ];
  const yorumlar = [126, 84, 210, 45, 97, 33, 156, 12, 68, 9, 51, 6, 73, 4];
  const tamamlanan = [140, 90, 230, 50, 105, 38, 170, 15, 72, 11, 55, 8, 80, 5];
  const aktiflik = [
    0.95, 0.88, 0.92, 0.60, 0.85, 0.55, 0.90, 0.40, 0.78, 0.35, 0.70,
    0.30, 0.82, 0.25,
  ];

  return List.generate(isimler.length, (i) {
    return MockSaglayici(
      id: 'mock-saglayici-$i',
      adSoyad: isimler[i],
      ilce: ilceSec(i),
      puan: puanlar[i],
      yorumSayisi: yorumlar[i],
      tamamlananIs: tamamlanan[i],
      aktiflikSkoru: aktiflik[i],
    );
  });
}
