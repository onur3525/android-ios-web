import '../api_client.dart';

/// PUBLIC bölge ağacı — kimlik doğrulaması gerektirmez.
/// Kayıt ekranında da (oturum açılmadan) kullanılır.
class RegionApi {
  final ApiClient c;
  RegionApi(this.c);

  Future<Map<String, dynamic>> tree({String? city}) =>
      c.get('/regions/tree', query: {if (city != null) 'city': city});
}
