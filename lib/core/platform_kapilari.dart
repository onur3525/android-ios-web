// PLATFORM KAPILARI
//
// Bir özelliğin hangi platformda GÖRÜNECEĞİNE karar veren yerler
// burada toplanır. Amaç, aynı koşulun iki ekranda ayrı ayrı yazılıp
// birinin unutulmasını önlemektir.

import 'package:flutter/foundation.dart';

/// GOOGLE İLE GİRİŞ iOS'TA GÖSTERİLMEZ.
///
/// ⚠ NEDEN: Apple'ın App Store kuralı 4.8, üçüncü taraf giriş servisi
/// sunan uygulamalardan "eşdeğer" bir giriş seçeneği daha ister
/// (veri toplamayı ad + e-posta ile sınırlayan, e-postayı gizli
/// tutmaya izin veren bir servis). Aynı kuralın muafiyet listesinde
/// şu madde vardır: uygulama YALNIZCA kendi hesap kurulum ve giriş
/// sistemlerini kullanıyorsa başka bir giriş servisi gerekmez.
///
/// HizmetCep'in kendi iki giriş yolu zaten vardır: e-posta + şifre ve
/// telefon + SMS. Google iOS'ta gizlenince uygulama o muafiyetin
/// tanımına birebir girer.
///
/// ⚠ SEÇİLEN YOL BUDUR — Sign in with Apple EKLENMEDİ. Gerekçesi:
/// Apple girişi eklemek yeni bir paket ve ORTAK giriş/kayıt
/// ekranlarında yeni bir düğme demektir; Android tasarımının
/// değişmemesi kuralına çarpar. Gizleme ise Android'e hiç dokunmaz.
///
/// ⚠ `google_sign_in` PAKETİ KALDIRILMADI ve kaldırılmayacak:
/// Android'de kullanılmaya devam ediyor. Gizlenen yalnız iOS'taki
/// GÖRÜNÜRLÜKTÜR; iş mantığı, servis ve sunucu tarafı aynen durur.
///
/// ⚠ Web'de gizlenmez: web hedefi bugün derlenmiyor (dart:io), ama
/// koşul yine de açıkça yazıldı ki ileride yanlış tarafa düşmesin.
///
/// Kilit: test/google_giris_platform_test.dart
bool get googleGirisiGosterilir =>
    kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;
