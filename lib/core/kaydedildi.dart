import 'package:flutter/material.dart';

import 'theme.dart';

// ═══════════════════════════════════════════════════════════════
// "KAYDEDİLDİ" DÜĞME DURUMU — TEK KAYNAK (28 Eki, kullanıcı isteği)
// ═══════════════════════════════════════════════════════════════
//
// Sorun: web'de form sayfaları (Hizmet Bölgelerim, Hizmet Kategorilerim,
// Adreslerim, Profil Bilgilerim) kaydettikten sonra AYNI SAYFADA kalır ve
// alttaki başarı bildirimleri 9 Eyl'den beri çizilmez (kullanıcı kararı).
// Kaydet'e basınca düğme dönüp eski hâline geliyordu; kaydın olduğu
// anlaşılmıyordu.
//
// Çözüm: onay ALT BİLDİRİM olarak değil DÜĞMENİN KENDİSİNDE gösterilir.
// Kayıt başarılı olunca düğme yeşil "✓ Kaydedildi" olur ve basılamaz;
// kullanıcı bir şeyi değiştirince yeniden "Kaydet" olur. Ekranlar yalnız
// `kaydedildi` bayrağını verir; görünüm bu dosyadan gelir (SysButton ve
// RefNextButton aynı içeriği çizer).

const String kKaydedildiEtiketi = 'Kaydedildi';
const Color kKaydedildiRengi = HC.green;

/// Düğme içi "✓ Kaydedildi" içeriği.
class KaydedildiIcerik extends StatelessWidget {
  const KaydedildiIcerik({super.key, this.yaziStili});

  final TextStyle? yaziStili;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 19, color: Colors.white),
          const SizedBox(width: 7),
          Text(kKaydedildiEtiketi,
              style: (yaziStili ?? const TextStyle()).copyWith(color: Colors.white)),
        ],
      );
}
