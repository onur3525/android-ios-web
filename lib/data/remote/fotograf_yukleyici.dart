import 'dart:async';
import 'dart:convert';

import '../../core/platform/yerel_gorsel.dart';
import 'api/storage_api.dart';
import 'api_client.dart';

/// Kullanıcıya gösterilecek, teknik ayrıntı içermeyen yükleme hatası.
class FotografYuklemeHatasi implements Exception {
  const FotografYuklemeHatasi(this.mesaj);
  final String mesaj;
  @override
  String toString() => mesaj;
}

/// ═══════════════════════════════════════════════════════════════
/// FOTOĞRAF YÜKLEYİCİ — TEK KAYNAK (29 Eki)
///
/// Telefondaki (ya da web'de seçilen) bir fotoğrafı depoya yükler ve
/// sunucunun verdiği `storageRef`'i döndürür:
///   bayt + tür → `upload-ref` → imzalı adrese yükle (EXIF/GPS
///   `StorageApi.uploadBytes` içinde ayıklanır) → ref.
///
/// ⚠ HATA (29 Eki, kullanıcı bulgusu): sohbet ekranları fotoğrafı HİÇ
/// yüklemeden telefondaki dosya YOLUNU mesajla gönderiyordu; sunucu
/// depoda böyle bir kayıt bulamayınca "Geçersiz fotoğraf" diyordu. İki
/// sohbet (ilan sohbeti, teklif talebi sohbeti) ve profil fotoğrafı bu
/// sınıfı kullanır.
///
/// ⚠ TÜR, DOSYA İÇERİĞİNDEN: web'de seçilen dosyanın yolu uzantısız bir
/// `blob:` adresidir; tür uzantıdan bulunamaz. JPEG/PNG/WEBP imzası ilk
/// baytlardan okunur (sunucu da aynı imzayı denetler). HEIC kabul
/// edilmez (konum verisi güvenle ayıklanamıyor).
/// ═══════════════════════════════════════════════════════════════
abstract final class FotografYukleyici {
  /// Sunucu sınırı (`backend/src/depo_dogrulama.js` TUR_SINIRI).
  static const int enFazlaBayt = 10 * 1024 * 1024;

  static const String turHatasi = 'Yalnızca JPG, PNG ya da WEBP fotoğraf gönderilebilir.';
  static const String boyutHatasi = 'Fotoğraf en fazla 10 MB olabilir.';
  static const String yuklemeHatasi = 'Fotoğraf yüklenemedi. Lütfen tekrar deneyin.';

  static final RegExp _sunucuRef =
      RegExp(r'^u/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp|heic)$');

  /// Değer zaten sunucudaki bir depo kaydı mı (yeniden yüklenmez)?
  static bool sunucuRefMi(String yol) => _sunucuRef.hasMatch(yol);

  /// İlk baytlardan görsel türü; tanınmazsa null.
  static String? icerikTuru(List<int> b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (b.length >= 8 &&
        b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 &&
        b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
      return 'image/png';
    }
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  /// (bayt, içerik türü) — `data:` adresi, web `blob:` adresi ya da
  /// mobil dosya yolu. Desteklenmeyen türde null.
  static Future<(List<int>, String)?> veri(String yol,
      {Future<List<int>> Function(String yol)? okuyucu}) async {
    List<int> baytlar;
    if (yol.startsWith('data:')) {
      final virgul = yol.indexOf(',');
      if (virgul < 0 || !yol.substring(5, virgul).contains('base64')) {
        return null;
      }
      baytlar = base64Decode(yol.substring(virgul + 1));
    } else {
      baytlar = await (okuyucu ?? yerelBaytlar)(yol);
    }
    final tur = icerikTuru(baytlar);
    return tur == null ? null : (baytlar, tur);
  }

  /// Fotoğrafı yükler, `storageRef` döndürür. Başarısızlıkta
  /// [FotografYuklemeHatasi] fırlatır; yarım kalan bekleyen kayıt atılır.
  /// Sunucunun API hatası (`ApiFailure`: oturum, hız sınırı) olduğu
  /// gibi geçer.
  static Future<String> yukle(ApiClient c, String yol,
      {String tur = 'listing-photo', StorageApi? depo}) async {
    (List<int>, String)? v;
    try {
      v = await veri(yol);
    } catch (_) {
      throw const FotografYuklemeHatasi(yuklemeHatasi);
    }
    if (v == null) {
      throw const FotografYuklemeHatasi(turHatasi);
    }
    if (v.$1.length > enFazlaBayt) {
      throw const FotografYuklemeHatasi(boyutHatasi);
    }
    final s = depo ?? StorageApi(c);
    final yanit = await s.createUploadRef(kind: tur, contentType: v.$2, sizeBytes: v.$1.length);
    final ref = yanit['storageRef'] as String?;
    final adres = yanit['uploadUrl'] as String?;
    if (ref == null || adres == null) {
      throw const FotografYuklemeHatasi(yuklemeHatasi);
    }
    try {
      await s.uploadBytes(uploadUrl: adres, bytes: v.$1, contentType: v.$2);
    } catch (_) {
      unawaited(s.discardPending(ref).then((_) {}, onError: (_) {}));
      throw const FotografYuklemeHatasi(yuklemeHatasi);
    }
    return ref;
  }
}
