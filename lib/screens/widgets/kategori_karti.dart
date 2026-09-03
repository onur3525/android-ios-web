import 'package:flutter/material.dart';

import '../../data/category_tree.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import '../category_ui.dart';

/// KATEGORİ KARTI — TEK KAYNAK.
///
/// ⚠ NİÇİN ORTAK.
///
/// Aynı kart iki ekranda çiziliyordu: ana sayfa ve ilan oluşturma
/// kategori ızgarası. İki ayrı kopya vardı ve ölçüleri AYRIŞMIŞTI:
///
///   | özellik      | ana sayfa | ızgara |
///   |--------------|-----------|--------|
///   | köşe         | r8        | r13    |
///   | dolgu        | v8 h6     | 8      |
///   | yazı         | 11px      | 12.5px |
///   | FittedBox    | yok       | var    |
///
/// Aynı kategori iki ekranda farklı görünüyordu. Artık tek bileşen
/// var; bir ölçü değişirse her iki ekran birlikte değişir.
///
/// ## GÖRSEL KAYNAĞI
///
/// ⚠ ÜÇ KATMANLI, KART ASLA BOŞ KALMAZ:
///   1. `kCategoryImage` fotoğrafı varsa → fotoğraf
///   2. yoksa `categoryIcon` SVG'si → 53/53 kategoriyi kapsar
///   3. dosya bozuksa `errorBuilder` → yine SVG
///
/// ## ⚠ KULLANIM SINIRI — İŞ KURALI
///
/// Kategori FOTOĞRAFINI çizen TEK bileşen budur ve YALNIZCA ilan verme
/// ekranında kullanılır:
///   · `/customer/new-listing` (kayıtlı kullanıcı)
///   · `/listing/new` (kayıtsız; ana sayfadaki arama çubuğundan gelen
///     akış) — ikisi de ortak `CreateListingScreen`'i çizer.
///
/// Ana sayfa, Tüm Kategoriler, kategori detayı, arama sonucu, kayıt ve
/// rol değiştirme ekranlarında fotoğraf İSTENMEZ; oralarda SVG ikon
/// (`categoryIcon` / `CategoryBadge`) kullanılır. Bu kural
/// `test/kategori_fotograf_kapsami_test.dart` ile kilitlidir.
class KategoriKarti extends StatelessWidget {
  const KategoriKarti({
    super.key,
    required this.ad,
    required this.onTap,
    this.secili = false,
  });

  /// KATALOG KİMLİĞİ — `kCategoryTree` anahtarıyla birebir aynı.
  final String ad;
  final VoidCallback onTap;
  final bool secili;

  @override
  Widget build(BuildContext context) {
    final foto = kCategoryImage[ad];
    final yol = foto ?? categoryIcon(ad);
    final svg = foto == null || kCategoryImageIsSvg(ad);

    final ikon = ColoredBox(
      color: const Color(0xFFEAF1FB),
      child: Center(child: RefSvg(yol, size: 34, color: RC.blue)),
    );

    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r13),
      child: Container(
        // ⚠ YATAY DOLGU 8 → 4 (metin için); GÖRSEL AYNI YERDE KALIR.
        //
        // Metin alanı kartın iç dolgusu kadar daralıyordu: 320dp'lik
        // ekranda 73,3px kalıyor ve üç etiket bozuluyordu —
        // "Marangozluk" (74,5px) ile "Organizasyon" (79,4px) tek
        // kelime olarak sığmayıp ORTADAN KESİLİYOR ("Marangozl…"),
        // "Araç Temizlik & Detaylı Bakım" ise 4 satıra taşıp son
        // satırı kırpılıyordu.
        //
        // Ölçüm gerçek Poppins-Bold metrikleriyle yapıldı. Yatay dolgu
        // 4'e inince metin alanı 81,3px olur ve 50 etiketin TAMAMI
        // en fazla 3 satırda, kelime kesilmeden sığar.
        //
        // Görselin konumu DEĞİŞMEZ: kaybedilen 4px, fotoğrafın kendi
        // `Padding`'i olarak geri verilir (4 + 4 = eski 8).
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(
              color: secili ? RC.blue : const Color(0xFFECEEF1),
              width: secili ? 1.6 : 1),
          borderRadius: BorderRadius.circular(RR.r13),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // .pc-photo — kare görsel alanı
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(RR.r10),
                  child: svg
                      ? ikon
                      : Image.asset(
                          yol,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          // Dosya bozuksa ikona düş — kart boş kalmaz.
                          errorBuilder: (_, __, ___) => ikon,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // .pc-l — kategori adı
            //
            SizedBox(
              // ⚠ SABİT YÜKSEKLİK: metin 1 satır da olsa 3 satır da
              // olsa görsel alanı aynı kalır — kartlar aynı hizada
              // durur, ızgara zıplamaz.
              //
              // 11px × 1.20 satır yüksekliği = 13,2px; üç satır 39,6px
              // eder ve 40px kutuya sığar.
              height: 40,
              child: Center(
                // ⚠ SİSTEM YAZI ÖLÇEĞİ BU ETİKETTE 1.0 İLE SINIRLI.
                //
                // Cihaz ayarından yazı boyutu büyütüldüğünde 3 satır
                // 40px kutuya sığmıyor (ölçek 1.15'te 45,5px, 1.3'te
                // 51,5px) ve ızgara taşıyordu. Kart üç sütunlu sabit
                // bir ızgaradır; etiket büyüdükçe genişleyecek yeri
                // yoktur.
                //
                // ⚠ SINIR YALNIZ BU ETİKETE AİTTİR. Uygulamanın geri
                // kalanı sistem ölçeğini aynen uygular; erişilebilirlik
                // ayarı genel olarak çalışmaya devam eder. Küçültme de
                // serbesttir; yalnız BÜYÜTME sınırlanır.
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.0,
                  child: Text(
                    // ⚠ KİMLİK DEĞİL ETİKET.
                    //
                    // `ad` katalog kimliğidir ve dokunma/seçim onu
                    // taşır; kartta okunan metin `kategoriEtiketi`
                    // ile kısaltılır ("Cam Balkon" →
                    // "Cam Balkon", "Koltuk ve Döşeme Yıkama" →
                    // "Koltuk & Döşeme Yıkama").
                    kategoriEtiketi(ad),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s11,
                        weight: RF.w700,
                        color: RC.text,
                        height: RF.lh120),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kategori ızgarası — ana sayfa ve ilan oluşturmada AYNI.
///
/// ⚠ SIRALAMA KATALOG SIRASIDIR (`kTreeCategories`). Elle seçilmiş
/// bir alt küme YOKTUR; iki ekran birebir aynı listeyi aynı sırada
/// gösterir.
const int kKategoriIzgaraSutun = 3;

/// `.pc-grid` — kart en-boy oranı.
///
/// ⚠ 0.82 → 0.76: metin alanı sabit 40px'e çıkınca kart biraz
/// uzatıldı, aksi hâlde görsel alanı eziliyordu.
const double kKategoriIzgaraOran = 0.76;

/// `.pc-grid` — kartlar arası boşluk.
const double kKategoriIzgaraBosluk = 10;
