// EKRAN ÖLÇÜSÜ — KIRILMA NOKTALARI VE GENİŞLİK KURALLARI
//
// ⚠ BU DOSYA MOBİL DAVRANIŞI DEĞİŞTİRMEZ.
//
// Buradaki her değer GENİŞLİĞE bağlıdır, PLATFORMA değil. Telefon
// genişliğinde (<600) dönen sonuçlar bugünkü mobil ölçülerle
// birebir aynıdır; büyüme yalnız daha geniş ekranlarda başlar.
// Yani aynı kod Android'de telefonda eskisi gibi, katlanabilir bir
// cihazın açık hâlinde veya tablette ise ferah çizer.
//
// ⚠ NİÇİN PLATFORM DEĞİL GENİŞLİK: `kIsWeb` ile dallanmak, dar bir
// tarayıcı penceresinde masaüstü düzeni çizerdi. Kullanıcının
// gördüğü şey platform değil, ekranın genişliğidir.

import 'package:flutter/widgets.dart';

/// Ekran genişlik sınıfı.
enum EkranSinifi {
  /// < 600 — telefon. ⚠ Bugünkü mobil düzenin ta kendisi.
  mobil,

  /// 600 – 1023 — tablet, katlanabilir, dar tarayıcı penceresi.
  tablet,

  /// 1024 – 1439 — dizüstü.
  laptop,

  /// ≥ 1440 — geniş masaüstü.
  masaustu;

  /// Telefon dışındaki her şey.
  bool get genisMi => this != EkranSinifi.mobil;

  /// Dizüstü ve üzeri — imleçle kullanılan ekranlar.
  bool get masaustuMu =>
      this == EkranSinifi.laptop || this == EkranSinifi.masaustu;
}

/// ⚠ KIRILMA NOKTALARI TEK KAYNAKTA.
///
/// Ekranlar kendi sayısını yazmaz; hepsi buradan okur. Aksi hâlde
/// bir ekran 900'de, öteki 960'ta kırılır ve arayüz tutarsızlaşır.
abstract final class Kirilma {
  /// Tablet bu genişlikten itibaren başlar.
  static const double tablet = 600;

  /// Dizüstü bu genişlikten itibaren başlar.
  static const double laptop = 1024;

  /// Geniş masaüstü bu genişlikten itibaren başlar.
  static const double masaustu = 1440;
}

/// Verilen genişliğin sınıfı.
EkranSinifi ekranSinifiFor(double genislik) {
  if (genislik >= Kirilma.masaustu) {
    return EkranSinifi.masaustu;
  }
  if (genislik >= Kirilma.laptop) {
    return EkranSinifi.laptop;
  }
  if (genislik >= Kirilma.tablet) {
    return EkranSinifi.tablet;
  }
  return EkranSinifi.mobil;
}

/// Bağlamdaki ekranın sınıfı.
EkranSinifi ekranSinifi(BuildContext context) =>
    ekranSinifiFor(MediaQuery.sizeOf(context).width);

/// ⚠ İÇERİK GENİŞLİK SINIRLARI — OKUNABİLİRLİK İÇİN.
///
/// Geniş ekranda metin satırı sayfa boyunca uzarsa okunmaz hâle
/// gelir. Bu yüzden içerik sütunu sınırlanır ve ORTALANIR.
///
/// ⚠ Ama sınır her yerde aynı DEĞİLDİR: form dar, liste orta,
/// ızgara geniş olur. Tek bir sınır koymak ya formu gereksiz
/// yayardı ya ızgarayı boğardı.
abstract final class IcerikGenisligi {
  /// Form, giriş, kayıt, ayar ekranları — tek sütun.
  static const double form = 560;

  /// Liste ve detay ekranları — okunabilir gövde.
  static const double liste = 760;

  /// Kart ızgaraları ve ana sayfa — çok sütunlu yüzeyler.
  static const double izgara = 1200;
}

/// ⚠ IZGARA SÜTUN SAYISI — KARTLAR GERİLMEZ, ÇOĞALIR.
///
/// Geniş ekranda tek yapılacak şey kartları büyütmek olsaydı,
/// masaüstünde dev kartlar ve boş alan kalırdı. Doğrusu sütun
/// sayısını artırmaktır.
///
/// [mobilSutun] bugünkü telefon değeri; DEĞİŞTİRİLMEZ.
int izgaraSutun(EkranSinifi sinif, {required int mobilSutun}) =>
    switch (sinif) {
      EkranSinifi.mobil => mobilSutun,
      EkranSinifi.tablet => mobilSutun + 1,
      EkranSinifi.laptop => mobilSutun + 2,
      EkranSinifi.masaustu => mobilSutun + 3,
    };

/// Sayfa kenar boşluğu. Telefonda bugünkü değer korunur.
double sayfaKenari(EkranSinifi sinif) => switch (sinif) {
      EkranSinifi.mobil => 16,
      EkranSinifi.tablet => 24,
      EkranSinifi.laptop => 32,
      EkranSinifi.masaustu => 40,
    };

/// ⚠ METİN ÖLÇEĞİ — MOBİLDE 1.0, YANİ HİÇ DEĞİŞMEZ.
///
/// Masaüstünde göz ekrana daha uzaktır; telefon punto değerleri
/// orada küçük kalır. Ölçek yalnız geniş ekranlarda büyür.
///
/// ⚠ Üst sınır 1.15'te tutuldu: daha fazlası kilitli ölçülere sahip
/// bileşenlerde (kart yüksekliği, rozet) taşmaya yol açar.
double metinOlcegi(EkranSinifi sinif) => switch (sinif) {
      EkranSinifi.mobil => 1.0,
      EkranSinifi.tablet => 1.05,
      EkranSinifi.laptop => 1.10,
      EkranSinifi.masaustu => 1.15,
    };

/// ⚠ DOKUNMA/İMLEÇ HEDEFİ — masaüstünde düğme KÜÇÜLMEZ.
///
/// Telefonda 52 px'lik birincil düğme parmağa göre ölçülmüştür;
/// masaüstünde aynı yükseklik orantısız küçük DURMAZ, korunur.
/// Bu yüzden değer düşürülmez, yalnız gerekirse bir tık artırılır.
double dugmeYuksekligi(EkranSinifi sinif) =>
    sinif.masaustuMu ? 54 : 52;
