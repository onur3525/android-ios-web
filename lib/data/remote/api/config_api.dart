import '../api_client.dart';

/// PUBLIC uygulama meta ucu — açılışta çağrılır.
/// Kimlik doğrulaması GEREKTİRMEZ ve bakım sırasında da yanıt verir.
class ConfigApi {
  final ApiClient c;
  ConfigApi(this.c);

  Future<Map<String, dynamic>> app({required String platform}) =>
      c.get('/config/app', query: {'platform': platform});
}
