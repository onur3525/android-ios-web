import 'package:flutter/material.dart';

import '../../data/repositories/ilan_no_uretici.dart';
import '../../ui/ref_tokens.dart';

/// ═══════════════════════════════════════════════════════════════
/// İLAN NUMARASI ETİKETİ — TEK BİLEŞEN
///
/// ## NİÇİN AYRI BİR BİLEŞEN
///
/// Numara ONBEŞE yakın görünümde çıkıyor (müşteri listesi, hizmet
/// veren listesi, iki detay ekranı, arama sonuçları, teklif ve
/// mesaj referansları, admin/destek). Her ekranda elle yazılırsa
/// biçim ve ölçü kaçınılmaz olarak ayrışır.
///
/// ## GÖRSEL KURAL
///
/// ⚠ İKİNCİL BİLGİDİR. Başlık, kategori, konum ve fiyatın ÖNÜNE
/// GEÇMEZ: küçük punto, soluk renk, kalın değil.
/// ── ⚠ TEK KURAL: SAĞ ÜST KÖŞE ──
///
/// İlan numarası HER İLAN KARTINDA (önizleme dahil) ve her detay
/// ekranında gösterilir; her zaman kartın/ekranın EN ÜST SAĞ
/// KÖŞESİNDE durur.
///
/// ⚠ DEĞİŞTİ (kullanıcı isteği) — ÖNCEDEN yalnız detay ekranlarında
/// gösteriliyordu, önizleme kartlarında "yer kaplıyor" gerekçesiyle
/// GİZLENİYORDU. Artık "#12345" gibi kısa, soluk bir biçimde HER
/// kartta da var — göz önünde değil, hafif/silik.
///
/// ⚠ TÜM İLAN KARTI EKRANLARI BU KURALA UYAR: kart çizen her ekran
/// bu bileşeni çağırır, kendi hizalamasını YAZMAZ.
///
/// ## BOŞ NUMARA
///
/// ⚠ Numara yoksa HİÇBİR ŞEY ÇİZİLMEZ. API modunda sunucu alanı
/// göndermediğinde `ilanNo` boş kalır; "#" yazan boş bir etiket
/// göstermek kullanıcıyı yanıltır.
/// ═══════════════════════════════════════════════════════════════
class IlanNoEtiketi extends StatelessWidget {
  /// ⚠ VARSAYILAN: SAĞ ÜST KÖŞE.
  ///
  /// Ürün kuralı gereği ilan numarası her kartın/ekranın EN ÜSTÜNDE,
  /// sağ köşede durur. Bu yüzden varsayılan davranış budur; çağıran
  /// ekranların ayrıca hizalama yazmasına gerek yoktur.
  /// ⚠ HAM NUMARA ALIR, MODEL ALMAZ (12 Eyl).
  ///
  /// Önceden yalnız `Listing` kabul ediyordu. Teklif talepleri de
  /// numara aldığı için (ürün kararı: "ilan oluştur ya da bul
  /// üzerinden istensin farketmez") bileşen tek bir modele
  /// bağlı kalamazdı. İkinci bir etiket bileşeni yazmak biçimi
  /// ayrıştırırdı.
  ///
  /// Çağıranlar `l.ilanNo` ya da `t.talepNo` verir; "#" ekleme
  /// `IlanNoUretici.etiket` içinde, TEK YERDE.
  const IlanNoEtiketi(this.no, {super.key});

  /// Ham numara — "#" olmadan.
  final String no;

  @override
  Widget build(BuildContext context) {
    if (no.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    // ⚠ SAĞA YASLI + ALTINDA BOŞLUK: başlıkla arasında sabit aralık,
    // ekranlar kendi `SizedBox`ını eklemez — ölçü tek yerde.
    //
    // ⚠ RENK/PUNTO DAHA DA SOLUK — kullanıcı isteği: "çok göz önünde
    // değil hafif silik okunabilir olsun". Önceki `RC.textSoft`tan
    // (detay ekranlarında yeterliydi) daha açık bir tona geçildi;
    // artık HER kartta göründüğü için dikkat çekmemesi daha önemli.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          IlanNoUretici.etiket(no),
          style: refText(
            size: RF.s11,
            weight: RF.w400,
            color: RC.greyLight,
            letterSpacing: RF.lsM02,
          ),
        ),
      ),
    );
  }
}
