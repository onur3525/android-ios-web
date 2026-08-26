import '../api_client.dart';

/// ÜCRETSİZ İLETİŞİM AÇMA HAKKI — /free-rights uçları
///
/// ⚠ Bu hak PARA DEĞİLDİR. Cüzdan, bakiye veya jeton ile ilişkisi yoktur.
/// Yalnız HİZMET VEREN rolünde çağrılır; Hizmet Alan görünümünde kullanılmaz.
class FreeRightApi {
  final ApiClient c;
  FreeRightApi(this.c);

  /// Kullanılabilir hak özeti (adet — TL DEĞİL).
  Future<Map<String, dynamic>> summary() => c.get('/free-rights/me/summary');

  /// Teklif öncesi kaynak kararı — YAN ETKİSİZ ÖN İZLEME.
  /// Gerçek tüketim, teklif verildiğinde sunucuda atomik olarak yapılır;
  /// istemci kaynağı SEÇEMEZ, yalnız sunucunun kararını gösterir.
  Future<Map<String, dynamic>> fundingPreview() =>
      c.get('/free-rights/me/funding-preview');
}
