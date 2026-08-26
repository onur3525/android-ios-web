// GENİŞ EKRAN KABUĞU — MASAÜSTÜ YERLEŞİMİ
//
// ⚠ BU DOSYA YENİDİR VE MOBİL DAVRANIŞI DEĞİŞTİRMEZ.
//
// Buradaki her bileşen telefon genişliğinde (<600) çocuğunu OLDUĞU
// GİBİ döndürür — ne sarmalar, ne ölçü değiştirir, ne boşluk ekler.
// Yani bir ekran bu bileşenlerle sarıldığında Android telefonda
// çizilen ağaç bugünküyle aynı kalır.
//
// ⚠ NİÇİN AYRI DOSYA: mevcut `ref_widgets.dart` 4000+ satır ve 19
// test dosyası onun ham metnini okuyor. Oraya eklemek gereksiz
// regresyon riski üretirdi.

import 'package:flutter/material.dart';

import 'olcu.dart';

/// ⚠ İÇERİĞİ ORTALAR VE ÜST GENİŞLİK SINIRI UYGULAR.
///
/// Geniş ekranda metin satırı 1900 px boyunca uzarsa okunmaz.
/// Bu bileşen içeriği sınırlar ve ortalar; mobilde HİÇBİR ŞEY yapmaz.
///
/// ⚠ "Devasa boşluk" tuzağı: sınır uygulanınca yanlarda boşluk
/// oluşur. Bu yüzden [zemin] verilebilir — sayfa zemini kenarlara
/// kadar uzanır, yalnız İÇERİK ortalanır. Böylece ekranın iki yanı
/// boş beyaz şerit gibi durmaz.
class MerkezliIcerik extends StatelessWidget {
  const MerkezliIcerik({
    super.key,
    required this.child,
    this.enFazla = IcerikGenisligi.liste,
    this.kenarBosluguEkle = true,
  });

  final Widget child;

  /// Üst genişlik sınırı. `IcerikGenisligi` sabitlerinden biri.
  final double enFazla;

  /// Genişliğe göre yatay kenar boşluğu eklensin mi?
  final bool kenarBosluguEkle;

  @override
  Widget build(BuildContext context) {
    final sinif = ekranSinifi(context);

    // ⚠ MOBİLDE ARAYA HİÇBİR ŞEY GİRMEZ.
    if (!sinif.genisMi) {
      return child;
    }

    final kenar = kenarBosluguEkle ? sayfaKenari(sinif) : 0.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: enFazla + kenar * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: kenar),
          child: child,
        ),
      ),
    );
  }
}

/// ⚠ GENİŞ EKRANDA METNİ BÜYÜTÜR — MOBİLDE DOKUNMAZ.
///
/// Telefon puntoları masaüstünde küçük kalır. Bu sarmalayıcı, alt
/// ağacın metin ölçeğini genişliğe göre artırır.
///
/// ⚠ Kullanıcının kendi yazı tipi boyutu ayarı EZİLMEZ: sistem
/// ölçeği ile çarpılır, yerine geçmez.
class GenisEkranTipografi extends StatelessWidget {
  const GenisEkranTipografi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sinif = ekranSinifi(context);
    if (!sinif.genisMi) {
      return child;
    }
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: metinOlcegi(sinif),
          maxScaleFactor: metinOlcegi(sinif) * 1.3,
        ),
      ),
      child: child,
    );
  }
}

/// ⚠ GÖRSEL ORANI KORUYAN KUTU.
///
/// Fotoğraflar masaüstünde küçük karelere sıkıştırılmaz; kutu
/// genişledikçe görsel de büyür ve EN-BOY ORANI korunur.
///
/// [oran] genişlik/yükseklik. 4/3, 16/9 gibi.
class OranliGorsel extends StatelessWidget {
  const OranliGorsel({
    super.key,
    required this.child,
    this.oran = 4 / 3,
    this.kose = 14,
  });

  final Widget child;
  final double oran;
  final double kose;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(kose),
        child: AspectRatio(
          aspectRatio: oran,
          // ⚠ `BoxFit.cover` ÇAĞIRAN tarafta verilir; burada zorlanmaz.
          child: child,
        ),
      );
}

/// ⚠ GENİŞLİĞE GÖRE FARKLI AĞAÇ ÇİZER.
///
/// `LayoutBuilder`ı her ekranda tekrar yazmak yerine tek yerden.
/// [mobil] zorunludur; ötekiler verilmezse bir alt sınıfa düşer —
/// böylece eksik dal yüzünden ekran boş kalmaz.
class GenislikDali extends StatelessWidget {
  const GenislikDali({
    super.key,
    required this.mobil,
    this.tablet,
    this.laptop,
    this.masaustu,
  });

  final Widget mobil;
  final Widget? tablet;
  final Widget? laptop;
  final Widget? masaustu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, kutu) {
          final sinif = ekranSinifiFor(kutu.maxWidth);
          return switch (sinif) {
            EkranSinifi.mobil => mobil,
            EkranSinifi.tablet => tablet ?? mobil,
            EkranSinifi.laptop => laptop ?? tablet ?? mobil,
            EkranSinifi.masaustu =>
              masaustu ?? laptop ?? tablet ?? mobil,
          };
        },
      );
}

/// ⚠ KART IZGARASI — KARTLAR GERİLMEZ, SÜTUN ÇOĞALIR.
///
/// Geniş ekranda tek yapılan şey kartı büyütmek olsaydı masaüstünde
/// dev kartlar ve boşluk kalırdı.
class UyumluIzgara extends StatelessWidget {
  const UyumluIzgara({
    super.key,
    required this.cocuklar,
    required this.mobilSutun,
    this.aralik = 12,
    this.enBoyOrani = 1,
  });

  final List<Widget> cocuklar;

  /// Telefondaki sütun sayısı. ⚠ Bugünkü değer; değiştirilmez.
  final int mobilSutun;

  final double aralik;
  final double enBoyOrani;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, kutu) {
          final sinif = ekranSinifiFor(kutu.maxWidth);
          final sutun = izgaraSutun(sinif, mobilSutun: mobilSutun);
          return GridView.count(
            crossAxisCount: sutun,
            mainAxisSpacing: aralik,
            crossAxisSpacing: aralik,
            childAspectRatio: enBoyOrani,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cocuklar,
          );
        },
      );
}
