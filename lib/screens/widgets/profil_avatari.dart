
import 'package:flutter/material.dart';

import '../../ui/ref_widgets.dart';
import 'foto_goruntuleyici.dart';
import '../../core/platform/yerel_gorsel.dart';

/// ═══════════════════════════════════════════════════════════════
/// PROFİL AVATARI — DOKUNULUNCA BÜYÜR
///
/// ⚠ KULLANICI İSTEĞİ (12 Eyl): "Kullanıcılar birbirlerinin profil
/// fotoğraflarına dokunduğunda fotoğraflar büyümeli."
///
/// ## NİÇİN AYRI BİR BİLEŞEN
///
/// Fotoğraf çizimi `RefBasHarfAvatar` içinde (ortak, `lib/ui`),
/// tam ekran görüntüleyici ise `screens/widgets` katmanında. İkisini
/// birleştiren kuralı `RefBasHarfAvatar`a koymak, arayüz katmanını
/// ekran katmanına bağımlı kılardı. Bu yüzden birleştirme BURADA
/// yapılır ve karşı tarafı gösteren her yüzey bunu çağırır.
///
/// ⚠ ÇAĞIRAN EKRANLAR KENDİ AÇMA KODUNU YAZMAZ. İki yüzey var
/// (`SahipKarti` ve `SaglayiciOzetSatiri`); üçüncüsü eklendiğinde
/// davranışı kendiliğinden alır.
///
/// ## DOKUNMA YALNIZ FOTOĞRAF VARSA
///
/// ⚠ Baş harf rozetine dokunmak hiçbir şey açmaz — açılacak bir şey
/// yoktur. Tepki vermeyen bir dokunma alanı bırakmak, kullanıcıya
/// "bozuk" hissi verir.
///
/// ⚠ MASKELEME ÇAĞIRANDA: kimlik gizliyken çağıran boş yol geçirir,
/// bileşen kendiliğinden dokunulamaz olur.
///
/// ## ROZET YOK
///
/// ⚠ KULLANICI İSTEĞİ (12 Eyl): "Fotoğraf yanındaki kalkan ve tik
/// ikonları tamamen kaldırılsın." Avatarın köşesindeki doğrulama
/// rozeti (`ic_vbadge`) üç yüzeyden birden kaldırıldı. Bu bileşen
/// rozet ÇİZMEZ; geri eklenmesi istenirse kural burada tek yerde
/// tartışılır.
/// ═══════════════════════════════════════════════════════════════
class ProfilAvatari extends StatelessWidget {
  const ProfilAvatari({
    super.key,
    required this.ad,
    this.fotoYolu = '',
    this.cap = 46,
  });

  /// Baş harf için görünen ad.
  final String ad;

  /// Profil fotoğrafının yolu. Boşsa baş harf çizilir ve dokunma
  /// kapalı kalır.
  final String fotoYolu;

  final double cap;

  @override
  Widget build(BuildContext context) {
    final avatar = RefBasHarfAvatar(ad: ad, fotoYolu: fotoYolu, cap: cap);
    final yol = fotoYolu.trim();

    // ⚠ DOSYA YOKSA DOKUNMA DA YOK: `RefBasHarfAvatar` okunamayan
    // dosyada baş harfe düşüyor; aynı durumda tam ekranı açmak boş
    // siyah bir sayfa gösterirdi.
    if (yol.isEmpty || !yerelVarMi(yol)) {
      return avatar;
    }

    return RefTap(
      // ⚠ AYNI GÖRÜNTÜLEYİCİ: ilan fotoğraflarının kullandığı
      // `FotoGoruntuleyici`. Profil için ayrı bir tam ekran ekranı
      // YAZILMADI — yakınlaştırma, kapatma ve geri davranışı tek
      // yerde tanımlı.
      onTap: () => FotoGoruntuleyici.ac(context, yollar: [yol]),
      borderRadius: BorderRadius.circular(cap / 2),
      child: avatar,
    );
  }
}
