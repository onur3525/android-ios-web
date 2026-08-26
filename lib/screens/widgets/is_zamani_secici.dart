import 'package:flutter/material.dart';

import '../../data/models/listing.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

/// İŞİN NE ZAMAN YAPILACAĞI — TEK SEÇİMLİ, İSTEĞE BAĞLI.
///
/// ── ⚠ TEK SEÇİM NASIL GARANTİ EDİLİYOR ──
///
/// Durum tek bir `IsZamani?` değişkeninde tutulur; "seçili olanlar
/// listesi" YOKTUR. Yeni seçim eskisinin ÜZERİNE yazılır, yani iki
/// seçeneğin aynı anda seçili olması yapısal olarak imkânsızdır.
///
/// ── ⚠ SEÇİM KALDIRILABİLİR ──
///
/// Seçili düğmeye tekrar dokunmak seçimi `null` yapar. Kullanıcı
/// yanlış seçtiğinde ilanı iptal etmek zorunda kalmaz; düzenlerken de
/// seçimini tamamen kaldırabilir.
///
/// ── ⚠ ZORUNLU DEĞİLDİR ──
///
/// Hiçbir uyarı, yıldız, "(Zorunlu)" etiketi ya da doğrulama yoktur.
/// Seçim yapılmadan ilan verilebilir.
///
/// ⚠ ÜÇ SEÇENEK KESİNDİR: kaynak `IsZamani.values`tır; ekran kendi
/// listesini yazmaz, böylece oluşturma ve görüntüleme ayrışmaz.
class IsZamaniSecici extends StatelessWidget {
  const IsZamaniSecici({
    super.key,
    required this.secili,
    required this.onDegisti,
  });

  /// Seçili değer; `null` = seçim yapılmadı.
  final IsZamani? secili;

  /// ⚠ `null` de gönderilir: seçimin KALDIRILDIĞI durum.
  final ValueChanged<IsZamani?> onDegisti;

  @override
  Widget build(BuildContext context) {
    // ⚠ `Wrap`: dar ekranda üç seçenek sığmazsa alt satıra iner,
    // taşma olmaz. `Row` sabit genişlik zorlar ve metni keserdi.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final z in IsZamani.values) _secenek(z),
      ],
    );
  }

  Widget _secenek(IsZamani z) {
    final aktif = secili == z;
    return RefTap(
      // ⚠ AYNI DÜĞMEYE TEKRAR DOKUNMAK SEÇİMİ KALDIRIR.
      onTap: () => onDegisti(aktif ? null : z),
      borderRadius: BorderRadius.circular(RR.r12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          // ⚠ ANLAM YÜKLEYEN RENK YOK (kırmızı/yeşil değil).
          // Seçim, uygulamanın mevcut birincil mavisiyle belirtilir —
          // öteki seçim yüzeyleriyle aynı dil.
          color: aktif ? RC.blueSoft : RC.white,
          border: Border.all(
            color: aktif ? RC.blue : RC.border,
            width: 1.4,
          ),
          borderRadius: BorderRadius.circular(RR.r12),
        ),
        child: Text(
          // ⚠ Etiket metni `IsZamani` içinde; ekran kendi metnini
          // yazmaz.
          z.etiket,
          style: refText(
            size: RF.s135,
            weight: aktif ? RF.w700 : RF.w500,
            color: aktif ? RC.blue : RC.textDark,
          ),
        ),
      ),
    );
  }
}

/// HİZMET VERENİN GÖRDÜĞÜ ZAMAN ETİKETİ.
///
/// ⚠ SEÇİM YOKSA HİÇBİR ŞEY ÇİZİLMEZ. `null` normal bir durumdur;
/// "belirtilmemiş" gibi bir yer tutucu gösterilmez.
///
/// ⚠ Metin kaynağı yine `IsZamani.etiket` — oluşturma ekranıyla
/// birebir aynı sözcükler.
class IsZamaniRozeti extends StatelessWidget {
  const IsZamaniRozeti(this.zaman, {super.key});

  final IsZamani? zaman;

  @override
  Widget build(BuildContext context) {
    final z = zaman;
    if (z == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: RC.blueSoft,
        borderRadius: BorderRadius.circular(RR.r10),
      ),
      child: Text(
        z.etiket,
        style: refText(size: RF.s12, weight: RF.w600, color: RC.blue),
      ),
    );
  }
}
