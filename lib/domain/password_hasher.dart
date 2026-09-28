import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/boot_log.dart';

/// Şifreler bellek içinde bile DÜZ METİN tutulmaz.
///
/// ── NEDEN TEK TURLU SHA-256 YETMEZ ──
///
/// SHA-256 HIZLI bir özet fonksiyonudur. Tuz, aynı şifrenin iki
/// hesapta aynı özeti üretmesini engeller ama KABA KUVVETİ
/// yavaşlatmaz: sızan bir özet listesinde 6 haneli şifrelerin tamamı
/// saniyeler içinde denenebilir. Bu projede şifrenin alt sınırı 6
/// KARAKTER olduğu için kısa şifrelerin arama uzayı küçüktür.
///
/// Bu yüzden özet, PBKDF2-HMAC-SHA256 ile TÜRETİLİR: aynı hesap için
/// tekrar tekrar özet alınır ve doğrulama maliyeti bilerek artırılır.
///
/// ⚠ NİHAİ OTORİTE SUNUCUDUR. Backend bcrypt/argon2 kullanır;
/// buradaki uygulama istemci tarafındaki geçici (mock) hesap
/// defterinin "state'te düz metin yok" garantisidir.
abstract final class PasswordHasher {
  /// Tur sayısı. Mobil cihazda kullanıcı gecikmesi hissettirmeyecek,
  /// buna karşılık kaba kuvveti onbinlerce kat pahalılaştıracak
  /// düzeyde seçildi.
  static const int _turSayisi = 20000;

  /// Türetilen anahtar uzunluğu (bayt) — SHA-256 blok boyu.
  static const int _uzunluk = 32;

  /// Biçim: `pbkdf2$<tur>$<hexÖzet>`
  ///
  /// Tur sayısı özetin İÇİNE yazılır; ileride tur sayısı artırılırsa
  /// eski kayıtlar doğrulanmaya devam eder (geriye dönük uyumluluk).
  static String hash(String password, String salt) {
    // ⚠ ÖLÇÜM — YALNIZ DEBUG (`BootLog.olc` release'de doğrudan işi
    // çalıştırır). Tur sayısı, algoritma ve dönüş değeri AYNIDIR;
    // burada yalnız süre kaydedilir. Açılışta `_seedDemo` bu yolu
    // kullandığı için ölçüm noktası buraya kondu.
    final ozet = BootLog.olc(
        'PBKDF2', () => _pbkdf2(password, salt, _turSayisi, _uzunluk));
    return 'pbkdf2\$$_turSayisi\$${_hex(ozet)}';
  }

  /// ⚠ SABİT ZAMANLI karşılaştırma.
  ///
  /// `==` ilk farklı baytta durur; harcanan süre kaç baytın
  /// eşleştiğini ele verir (zamanlama saldırısı). Burada tüm baytlar
  /// her koşulda karşılaştırılır.
  static bool verify(String password, String salt, String expectedHash) {
    final parcalar = expectedHash.split('\$');

    // ── ESKİ BİÇİM (tuz + tek turlu SHA-256) ──
    //
    // Daha önce oluşturulmuş kayıtlar KIRILMAZ: eski biçim kabul
    if (parcalar.length != 3 || parcalar[0] != 'pbkdf2') {
      final eski = sha256.convert(utf8.encode('$salt::$password')).toString();
      return _sabitZamanliEsit(eski, expectedHash);
    }

    final tur = int.tryParse(parcalar[1]) ?? _turSayisi;
    final beklenen = parcalar[2];
    final uretilen = _hex(_pbkdf2(password, salt, tur, _uzunluk));
    return _sabitZamanliEsit(uretilen, beklenen);
  }

  // ── PBKDF2-HMAC-SHA256 (RFC 2898) ──
  //
  // Tek blokluk çıktı yeterlidir (32 bayt = SHA-256 blok boyu),
  // bu yüzden blok döngüsü değil yalnız iç tur döngüsü vardır.
  static Uint8List _pbkdf2(
      String password, String salt, int tur, int uzunluk) {
    final hmac = Hmac(sha256, utf8.encode(password));

    // U1 = HMAC(P, S || INT(1))
    final ilkGirdi = <int>[...utf8.encode(salt), 0, 0, 0, 1];
    var u = Uint8List.fromList(hmac.convert(ilkGirdi).bytes);
    final sonuc = Uint8List.fromList(u);

    for (var i = 1; i < tur; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < sonuc.length; j++) {
        sonuc[j] ^= u[j];
      }
    }
    return Uint8List.sublistView(sonuc, 0, uzunluk);
  }

  static String _hex(Uint8List b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  static bool _sabitZamanliEsit(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    var fark = 0;
    for (var i = 0; i < a.length; i++) {
      fark |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return fark == 0;
  }
}
