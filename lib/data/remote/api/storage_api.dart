import 'dart:io';

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

  /// ── ⚠ EKSİK OLAN ADIM: DOSYANIN KENDİSİNİ YÜKLE ──
  ///
  /// Sözleşme üç adımlıdır (bkz. sınıf notu): upload-ref al →
  /// `uploadUrl`'e DOĞRUDAN yükle → `storageRef`'i kaydet.
  ///
  /// İKİNCİ ADIM HİÇBİR ÇAĞRI YERİNDE YOKTU. Üç ekran da
  /// `createUploadRef` çağırıp dönen `storageRef`'i alıyor, dosya
  /// baytlarını hiçbir yere göndermiyordu. Sonuç: kullanıcı
  /// "yüklendi" görüyor, karşı taraf boş görüyor, sunucuda sahipsiz
  /// PENDING kayıtlar birikiyordu.
  ///
  /// ⚠ `ApiClient` KULLANILMAZ: `uploadUrl` bizim API'mize değil,
  /// depolama sağlayıcısına ait imzalı bir adrestir. Oraya
  /// `Authorization` başlığı göndermek oturum jetonunu üçüncü tarafa
  /// sızdırırdı. Ayrıca gövde JSON değil ham bayttır.
  ///
  /// ⚠ SERTİFİKA SABİTLEME BURADA UYGULANMAZ: pin kendi alan
  /// adımızın sertifikasıdır; depolama sağlayıcısının sertifikası
  /// farklıdır. Sistem TLS doğrulaması geçerlidir.
  ///
  /// ⚠ BAŞARISIZLIK SESSİZ GEÇMEZ: 2xx dışı her yanıtta istisna
  /// fırlatılır. Çağıran taraf `storageRef`'i ancak bu metot
  /// dönerse kaydeder.
  ///
  /// ⚠ İÇERİK TÜRÜ DOĞRULAMASI SUNUCUNUNDUR: istemci MIME'ı dosya
  /// UZANTISINDAN türetir (`contentTypeOf`); `.jpg` uzantılı herhangi
  /// bir dosya `image/jpeg` sayılır. Gerçek doğrulama, dosyanın
  /// sihirli baytlarına bakarak SUNUCUDA yapılmalıdır.
  Future<void> uploadBytes({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final istek = await HttpClient().putUrl(Uri.parse(uploadUrl));
    istek.headers.set(HttpHeaders.contentTypeHeader, contentType);
    istek.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
    istek.add(bytes);
    final yanit = await istek.close().timeout(const Duration(seconds: 60));
    // Gövde okunmazsa bağlantı açık kalır.
    await yanit.drain<void>();
    if (yanit.statusCode < 200 || yanit.statusCode >= 300) {
      throw HttpException(
        'Dosya yüklenemedi (HTTP ${yanit.statusCode})',
        uri: Uri.parse(uploadUrl),
      );
    }
  }

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
