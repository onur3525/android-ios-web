import '../api_client.dart';

/// "BUL" — hizmet veren arama (`GET /providers/search`). OTURUM GEREKİR.
///
/// Sunucu eşleşme kuralı mock moddaki `saglayicilarKimSunuyor` ile
/// AYNIDIR (hizmet verenin kendi seçtiği kategoriler kümesinde kategori
/// ya da hizmet adı). Yanıtta telefon, e-posta ve açık adres YOKTUR:
/// { id, name, address{city,district}|null, serviceDistricts[],
///   rating|null, reviewCount, completedJobs, photoUrl|null }
class SaglayiciApi {
  final ApiClient c;
  SaglayiciApi(this.c);

  Future<List<dynamic>> ara({
    required String kategori,
    required String hizmet,
    required String ilce,
  }) =>
      c.getList('/providers/search', query: {
        if (kategori.isNotEmpty) 'category': kategori,
        if (hizmet.isNotEmpty) 'service': hizmet,
        if (ilce.isNotEmpty) 'district': ilce,
      });
}
