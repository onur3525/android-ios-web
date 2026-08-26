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
/// satır, detay ekranında sabit bir bilgi alanında.
///
/// ## BOŞ NUMARA
///
/// ⚠ Numara yoksa HİÇBİR ŞEY ÇİZİLMEZ. API modunda sunucu alanı
/// göndermediğinde `ilanNo` boş kalır; "İlan No: " yazan boş bir
/// etiket göstermek kullanıcıyı yanıltır.
/// ═══════════════════════════════════════════════════════════════
class IlanNoEtiketi extends StatelessWidget {
  const IlanNoEtiketi(this.listing, {super.key, this.hizali = false});

  final Listing listing;

  /// Detay ekranlarında satırın soluna hizalanır; kartlarda akışta.
  final bool hizali;

  @override
  Widget build(BuildContext context) {
    if (listing.ilanNo.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final metin = Text(
      listing.ilanNoEtiketi,
      style: refText(
        size: RF.s12,
        weight: RF.w400,
        color: RC.textSoft,
        letterSpacing: RF.lsM02,
      ),
    );
    return hizali
        ? Align(alignment: Alignment.centerLeft, child: metin)
        : metin;
  }
}
