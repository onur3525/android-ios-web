import '../api_client.dart';

/// BEKLEYEN YÜKLEME İPTALİ — SUNUCU SÖZLEŞMESİ
///
///   ok: true,  retryScheduled: false → silindi, fotoğraf listeden çıkar
///   ok: false, retryScheduled: true  → storage silinemedi; kayıt sunucuda
///        PENDING kaldı ve zamanlayıcı yeniden deneyecek. Fotoğraf
///        LİSTEDE KALIR ve kullanıcıya tekrar deneme gösterilir.
///
/// HTTP 200 tek başına başarı DEĞİLDİR: `ok` alanı kontrol edilmelidir.
class DiscardUploadResult {
  final bool ok;
  final bool retryScheduled;

  const DiscardUploadResult({required this.ok, required this.retryScheduled});

  factory DiscardUploadResult.fromJson(Map<String, dynamic> j) =>
      DiscardUploadResult(
        // Alan eksikse BAŞARI VARSAYILMAZ (güvenli varsayılan).
        ok: j['ok'] == true,
        retryScheduled: j['retryScheduled'] == true,
      );
}

/// STORAGE REFERANSI altyapısı: dosya backend'den GEÇMEZ.
/// 1) upload-ref al → 2) uploadUrl'e doğrudan yükle → 3) storageRef'i kaydet.
class StorageApi {
  final ApiClient c;
  StorageApi(this.c);

  /// kind: profile-photo | listing-photo | message-photo | support-attachment
  Future<Map<String, dynamic>> createUploadRef({
    required String kind,
    required String contentType,
    required int sizeBytes,
  }) =>
      c.post('/storage/upload-ref',
          body: {'kind': kind, 'contentType': contentType, 'sizeBytes': sizeBytes});

  Future<Map<String, dynamic>> resolve(String storageRef) =>
      c.get('/storage/resolve', query: {'ref': storageRef});

  /// BEKLEYEN yüklemeyi iptal eder (kullanıcı önizlemeden kaldırdı).
  /// İdempotenttir: aynı referans iki kez gönderilebilir.
  /// ATTACHED dosyada 409, başkasının dosyasında 403 döner.
  ///
  /// DİKKAT: HTTP 200 başarı anlamına GELMEZ; dönen [DiscardUploadResult.ok]
  /// kontrol edilmelidir.
  Future<DiscardUploadResult> discardPending(String storageRef) async {
    final j = await c.delete(
      '/storage/uploads/pending', body: {'storageRef': storageRef},
    );
    return DiscardUploadResult.fromJson(j);
  }
}
