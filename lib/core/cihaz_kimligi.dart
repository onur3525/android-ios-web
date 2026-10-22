// CİHAZ KİMLİĞİ (22 Eki, kullanıcı kararı — bakımda test hesabı)
//
// Uygulama her cihazda BİR KEZ rastgele, tahmin edilemez bir kimlik üretir
// ve her istekte `X-HC-Cihaz` başlığıyla gönderir. Sunucu bunu yalnız
// admin'in "Bakımda erişebilecek hesaplar" listesindeki hesaplar için
// kullanır: o hesapla bakım KAPALIYKEN giriş yapılan cihaz tanınır; bakım
// açıkken gizli giriş kapısı yalnız tanınmış cihazda açılır.
//
// ⚠ KİŞİSEL/DONANIM BİLGİSİ DEĞİLDİR: IMEI, telefon numarası, reklam
// kimliği vb. OKUNMAZ. Yalnız rastgele sayı; sunucu da yalnız özetini tutar.
//
// Saklama: mobilde güvenli depo (Keychain / EncryptedSharedPreferences);
// web'de tarayıcının kalıcı deposu (gizli değildir — tek başına kimseyi
// içeri almaz; şifre + listedeki hesap ayrıca gerekir). Okunamazsa /
// yazılamazsa başlık gönderilmez, uygulama normal çalışır.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sekme_durumu.dart';

const String kCihazAnahtari = 'hc.cihazKimligi';
final RegExp _kalip = RegExp(r'^[A-Za-z0-9_-]{32,128}$');

class CihazKimligi {
  CihazKimligi._();
  static final CihazKimligi i = CihazKimligi._();

  static const FlutterSecureStorage _depo = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<String?>? _deger;

  /// Cihaz kimliği; yoksa üretilip saklanır. Depo hatasında null.
  Future<String?> deger() => _deger ??= _yukle();

  /// Yeni rastgele kimlik: 32 bayt, base64url (dolgusuz) → 43 karakter.
  static String uret([Random? r]) {
    final rnd = r ?? Random.secure();
    final b = List<int>.generate(32, (_) => rnd.nextInt(256));
    return base64Url.encode(b).replaceAll('=', '');
  }

  static bool gecerliMi(String? v) => v != null && _kalip.hasMatch(v);

  Future<String?> _yukle() async {
    try {
      final eski = kIsWeb ? kaliciOku(kCihazAnahtari) : await _depo.read(key: kCihazAnahtari);
      if (gecerliMi(eski)) {
        return eski;
      }
      final yeni = uret();
      if (kIsWeb) {
        kaliciYaz(kCihazAnahtari, yeni);
        // Depo kapalıysa (gizli sekme vb.) kalıcı kimlik yoktur.
        return kaliciOku(kCihazAnahtari) == yeni ? yeni : null;
      }
      await _depo.write(key: kCihazAnahtari, value: yeni);
      return yeni;
    } catch (_) {
      // Depo yoksa (test ortamı, eklenti hatası) başlık gönderilmez.
      return null;
    }
  }

  /// Yalnız testler.
  @visibleForTesting
  void sifirla() => _deger = null;
}
