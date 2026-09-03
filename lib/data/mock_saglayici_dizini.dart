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
}

/// Seçilen hizmet + kullanıcının il/ilçesi için mock hizmet veren
/// listesini, "yakınlık" bilgisiyle birlikte üretir.
///
/// ⚠ HİZMET EŞLEŞMESİ GERÇEK DEĞİL: mock veride hizmet↔hizmet veren
/// ilişkisi yok; havuzun TAMAMI her hizmet için "uygun" sayılır. Bu,
/// gerçek backend gelene kadarki bilinen bir sadeleştirmedir.
List<({MockSaglayici saglayici, int yakinlikSirasi})> mockSaglayicilariBul({
  required String il,
  required String ilce,
  required YakinlikSaglayici yakinlik,
}) {
  final yakinIlceler = yakinlik.yakinIlceler(il, ilce).toSet();

  int siraHesapla(String saglayiciIlcesi) {
    if (saglayiciIlcesi == ilce) return 0;
    if (yakinIlceler.contains(saglayiciIlcesi)) return 1;
    return 2;
  }

  final havuz = _havuz(il: il, ilce: ilce, yakinIlceler: yakinIlceler);

  final sonuc = [
    for (final s in havuz)
      (saglayici: s, yakinlikSirasi: siraHesapla(s.ilce)),
  ];

  // ── ⚠ SIRALAMA: aktiflik → puan → yorum → tamamlanan iş → mesafe ──
  //
  // Mesafe burada `yakinlikSirasi`dir (0=aynı ilçe, en yakın).
  // Kullanıcıya GÖSTERİLMEZ — yalnız sıralama kriteridir.
  sonuc.sort((a, b) {
    var c = b.saglayici.aktiflikSkoru.compareTo(a.saglayici.aktiflikSkoru);
    if (c != 0) return c;
    c = b.saglayici.puan.compareTo(a.saglayici.puan);
    if (c != 0) return c;
    c = b.saglayici.yorumSayisi.compareTo(a.saglayici.yorumSayisi);
    if (c != 0) return c;
    c = b.saglayici.tamamlananIs.compareTo(a.saglayici.tamamlananIs);
    if (c != 0) return c;
    return a.yakinlikSirasi.compareTo(b.yakinlikSirasi);
  });

  return sonuc;
}

/// ⚠ SABİT MOCK HAVUZ — gerçek isim/istatistik DEĞİL, yalnız ekranı
/// doldurmak için kurgusaldır. İlk üç kayıt kasıtlı olarak
/// kullanıcının kendi ilçesinde; kalanı "yakın ilçeler" ve il
/// geneline dağıtılmıştır — sıralama mantığını gözle görünür kılmak
/// için.
List<MockSaglayici> _havuz({
  required String il,
  required String ilce,
  required Set<String> yakinIlceler,
}) {
  final yakinListe = yakinIlceler.toList();
  String ilceSec(int i) {
    if (i < 3) return ilce; // aynı ilçe
    if (yakinListe.isNotEmpty) {
      return yakinListe[(i - 3) % yakinListe.length]; // yakın ilçeler
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
