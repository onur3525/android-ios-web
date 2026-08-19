import '../api_client.dart';

/// /wallet ve /ledger uçları — bakiye ve hareketler SUNUCUNUN kaydıdır.
class WalletApi {
  final ApiClient c;
  WalletApi(this.c);

  Future<Map<String, dynamic>> me() => c.get('/wallet/me');
  Future<List<dynamic>> ledger({String? kind}) =>
      c.getList('/wallet/me/ledger', query: {if (kind != null) 'kind': kind});

  /// Satın alınabilir jeton paketleri (PUBLIC).
  /// Sunucu yalnız aktif + görünür + tarih aralığı geçerli paketleri döner.
  Future<List<dynamic>> tokenPackages() => c.getList('/wallet/token-packages');

  /// Bakiye yükleme — Idempotency-Key ZORUNLU (çift tahsilat engeli).
  /// Kart verisi HizmetCep backend'ine HİÇBİR ZAMAN gönderilmez.
  /// ADIM 1 — ödeme oturumu aç.
  /// KART BİLGİSİ GÖNDERİLMEZ: yalnız tutar + idempotency anahtarı.
  ///
  /// PAKETLİ yüklemede YALNIZ `packageId` gönderilir. Fiyat, jeton ve
  /// bonus İSTEMCİDEN GÖNDERİLMEZ — sunucu paketi kendisi okur ve
  /// snapshot'ını üretir. Böylece istemci daha düşük tutar ödeyemez.
  Future<Map<String, dynamic>> createTopupSession({
    String? packageId,
    int? amountTl,
    required String idempotencyKey,
    String? returnUrl,
    /// Kayıtlı kart tokenı. ⚠ Ham kart verisi DEĞİLDİR.
    String? savedCardToken,
  }) =>
      c.post('/wallet/topup/session',
          body: {
            // Paket seçiliyse tutar GÖNDERİLMEZ (sunucu yok sayar zaten).
            if (packageId != null) 'packageId': packageId,
            if (packageId == null && amountTl != null) 'amountTl': amountTl,
            if (savedCardToken != null) 'savedCardToken': savedCardToken,
            // ⚠ ANAHTAR GÖVDEDEN ÇIKARILDI: yalnız `Idempotency-Key`
            // BAŞLIĞINDA gider (§30). Aynı değeri iki yerde taşımak
            // sunucuda hangisinin okunacağı belirsizliği yaratır.
            if (returnUrl != null) 'returnUrl': returnUrl,
          },
          idempotencyKey: idempotencyKey);

  /// ADIM 2 — sonucu backend üzerinden DOĞRULA.
  /// İstemci "ödeme başarılı" diyemez; durumu sağlayıcıdan backend okur.
  Future<Map<String, dynamic>> confirmTopup({required String sessionId}) =>
      c.post('/wallet/topup/confirm', body: {'sessionId': sessionId});
  // ── KAYITLI KARTLAR ──
  // ⚠ Ham kart verisi GÖNDERİLMEZ/ALINMAZ; yalnız maskeli bilgi ve token.
  Future<Map<String, dynamic>> savedCards() => c.get('/wallet/cards');

  /// Kart kaydı oturumu başlatır.
  ///
  /// ── ⚠ IDEMPOTENCY ANAHTARI BAŞLIKTA GİDER ──
  ///
  /// Eskiden gövdede `idempotencyKey` alanı olarak gönderiliyordu ve
  /// değer `DateTime.now().microsecondsSinceEpoch` ile ÜRETİLİYORDU.
  /// İkisi de yanlıştı:
  ///
  ///   1. Gövdedeki alan tekrar korumasını SAĞLAMAZ — sözleşme
  ///      `Idempotency-Key` BAŞLIĞINI okur (§30).
  ///   2. Her çağrıda zaman damgasından yeni anahtar üretmek,
  ///      korumayı tamamen ortadan kaldırır: aynı kullanıcı aksiyonu
  ///      tekrarlandığında anahtar da değiştiği için sunucu bunu YENİ
  ///      bir işlem sanar.
  ///
  /// Artık `ApiClient.newIdempotencyKey()` ile üretilen anahtar
  /// başlığa yazılır ve gövdede idempotency alanı BULUNMAZ.
  Future<Map<String, dynamic>> startCardSetup(
          {required String idempotencyKey}) =>
      c.post(
        '/wallet/cards/setup',
        body: {'returnUrl': 'hizmetcep://payment/return'},
        idempotencyKey: idempotencyKey,
      );

  Future<void> deleteCard(String token) => c.delete('/wallet/cards/$token');

  Future<void> setDefaultCard(String token) =>
      c.post('/wallet/cards/$token/default');

  Future<Map<String, dynamic>> cardConfig() => c.get('/wallet/cards/config');

  /// ⚠ Yalnız sağlayıcı SDK tokenı gönderilir; ham kart verisi ASLA.
  Future<Map<String, dynamic>> saveCard({
    required String paymentToken,
    required String holderName,
    required bool makeDefault,
    required String idempotencyKey,
  }) =>
      // ⚠ ANAHTAR BAŞLIKTA (§30).
      //
      // Gövdedeki `idempotencyKey` alanı kaldırıldı ve zaman
      // damgasından üretim BIRAKILDI: her çağrıda yeni anahtar
      // üretmek, tekrar korumasını tamamen ortadan kaldırıyordu —
      // kullanıcı iki kez basınca sunucu bunu iki AYRI işlem sanardı.
      c.post('/wallet/cards',
          body: {
            'paymentToken': paymentToken,
            'holderName': holderName,
            'makeDefault': makeDefault,
          },
          idempotencyKey: idempotencyKey);

}
