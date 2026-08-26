import 'package:flutter/material.dart';

import '../../data/models/listing.dart';
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
/// GEÇMEZ: küçük punto, soluk renk, kalın değil. Kartlarda tek
/// ── ⚠ TEK KURAL: SAĞ ÜST KÖŞE ──
///
/// İlan numarası YALNIZ DETAY ekranlarında gösterilir ve her zaman
/// başlığın ÜSTÜNDE, sağ köşede durur.
///
/// ⚠ ÖNİZLEME KARTLARINDA GÖSTERİLMEZ: liste kartında numara yer
/// kaplıyor ve kullanıcı kartları başlığa göre tarıyor. Numara
/// karta girince gerekli.
///
/// ⚠ YENİ İLAN EKRANLARI DA BU KURALA UYAR: numara göstermek gereken
/// her detay ekranı bu bileşeni çağırır, kendi hizalamasını YAZMAZ.
///
/// ## BOŞ NUMARA
///
/// ⚠ Numara yoksa HİÇBİR ŞEY ÇİZİLMEZ. API modunda sunucu alanı
/// göndermediğinde `ilanNo` boş kalır; "İlan No: " yazan boş bir
/// etiket göstermek kullanıcıyı yanıltır.
/// ═══════════════════════════════════════════════════════════════
class IlanNoEtiketi extends StatelessWidget {
  /// ⚠ VARSAYILAN: SAĞ ÜST KÖŞE.
  ///
  /// Ürün kuralı gereği ilan numarası detay ekranlarında başlığın
  /// ÜSTÜNDE, sağ köşede durur. Bu yüzden varsayılan davranış budur;
  /// çağıran ekranların ayrıca hizalama yazmasına gerek yoktur.
  const IlanNoEtiketi(this.listing, {super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    if (listing.ilanNo.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    // ⚠ SAĞA YASLI + ALTINDA BOŞLUK: başlıkla arasında sabit aralık,
    // ekranlar kendi `SizedBox`ını eklemez — ölçü tek yerde.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          listing.ilanNoEtiketi,
          style: refText(
            size: RF.s12,
            weight: RF.w400,
            color: RC.textSoft,
            letterSpacing: RF.lsM02,
          ),
        ),
      ),
    );
  }
}
