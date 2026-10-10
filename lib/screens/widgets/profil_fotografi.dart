import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/platform/yerel_gorsel.dart';
import '../../core/sys_state.dart';
import '../../data/controllers/profile_controller.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import '../../ui/olcu.dart';
// ⚠ `fotografSecenekSatiri` BURADA TANIMLI: bileşen bu dosyaya
// taşınırken import atlanmıştı. Satır çizimi ortak; kopyalanmadı.
import 'fotograf_kaynak_paneli.dart';

/// ═══════════════════════════════════════════════════════════════
/// PROFİL FOTOĞRAFI — TEK KAYNAK
///
/// Avatar + kamera rozeti + seçim paneli (galeri / kamera / kaldır).
///
/// ## ⚠ NİÇİN TAŞINDI
///
/// Bu bileşen `profile_screen` içinde özel (`_Avatar`) duruyordu.
/// Masaüstü web'de kenar çubuğu gelince Profil ekranı GEREKSİZ hâle
/// geldi — menüsü kenar çubuğunda zaten var — ama fotoğrafa ulaşmanın
/// tek yolu orasıydı. Bileşen ortak yere alındı; artık "Profil
/// Bilgilerim" de kullanıyor.
///
/// ⚠ KOPYALANMADI: iki ekran AYNI sınıfı çağırır. Kopyalasaydım
/// biri düzeltilip öteki unutulurdu.
///
/// ⚠ DAVRANIŞ DEĞİŞMEDİ: seçenek paneli, web'de `data:` adresine
/// çevirme, yalnız aktif role yazma — hepsi aynen taşındı.
/// ═══════════════════════════════════════════════════════════════
class ProfilFotografi extends StatelessWidget {
  const ProfilFotografi({
    required this.ad,
    required this.fotoYolu,
    this.kameraRozeti = true,
  });

  final String ad;
  final String fotoYolu;

  /// `.pf-cam` kamera rozeti çizilsin mi?
  ///
  /// ⚠ VARSAYILAN AÇIK: Profil ekranı ve Android/iOS'taki bütün
  /// çağrılar bu parametreyi VERMEZ; mobil görünüm DEĞİŞMEZ.
  /// Yalnız web'de Profil Bilgilerim ekranı kapatır (kullanıcı
  /// kararı). Rozet kalksa da avatarın TAMAMI tıklanabilir; fotoğraf
  /// menüsü avatara dokununca açılır.
  final bool kameraRozeti;

  /// ⚠ SEÇENEK PANELİ — tek bir "galeriden seç" değil.
  ///
  /// Eskiden avatara dokunmak DOĞRUDAN galeriyi açıyordu: kamerayla
  /// çekmek ya da mevcut fotoğrafı silmek mümkün değildi. Artık
  /// uygulamanın ortak alt paneli açılır ve kullanıcı seçer.
  ///
  /// ⚠ "Fotoğrafı Kaldır" YALNIZ fotoğraf varken görünür.
  Future<void> _fotoMenusu(BuildContext context) async {
    final secim = await RefBottomSheet.goster<String>(
      context,
      title: 'Profil Fotoğrafı',
      // ── ⚠ İLAN AKIŞIYLA AYNI SATIRLAR (12 Eyl, kullanıcı isteği) ──
      //
      // "İlan oluştururken fotoğraf yükle ve fotoğraf çek ikonları,
      // assetleri, renkleri profil fotoğrafı yüklerken de aynı
      // olmalı — iki rol için de."
      //
      // ⚠ ÖNCEDEN `RefSecimKarti` KULLANILIYORDU: renkli daire rozet
      // yok, gri düz ikon, sağda chevron yerine RADYO DAİRESİ ve
      // farklı metinler ("Galeriden Yükle" / "Cihazınızdaki bir
      // fotoğrafı seçin."). Aynı iş, iki farklı panel görünümü.
      //
      // ⚠ SATIR ORTAK, PANEL DEĞİL: burada üçüncü bir seçenek var
      // ("Fotoğrafı Kaldır"), ilan panelinde yok. Paylaşılan şey
      // GÖRÜNÜM; seçenek kümesi her panelin kendi işi.
      //
      // ⚠ METİNLER DE EŞİTLENDİ: ilan akışı referanstır.
      //
      // ⚠ ROL AYRIMI YOK: panel hesap rolüne bakmaz, iki rolde de
      // aynı çizilir.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⚠ KAMERA YOKSA SEÇENEK GÖSTERİLMEZ (`kameraVarMi`).
      // Masaüstü tarayıcıda "Fotoğraf Çek" ya web kamerasını açıyor
      // ya da hiçbir şey yapmıyordu; çalışmayan bir seçenek
      // gösterilmez. Mobil web ve uygulamalarda AYNEN durur.
          if (kameraVarMi(context)) ...[
          fotografSecenekSatiri(
            context,
            rozetRengi: RC.blue,
            ikon: 'assets/svg/ic_cam.svg',
            baslik: 'Fotoğraf Çek',
            aciklama: 'Kamerayı açar',
            onTap: () => Navigator.of(context).pop('kamera'),
          ),
          const SizedBox(height: 2)
          ],
          fotografSecenekSatiri(
            context,
            rozetRengi: RC.success,
            ikon: 'assets/svg/ic_gallery.svg',
            ikonRengi: RC.white,
            baslik: 'Galeriden Seç',
            aciklama: 'Kayıtlı fotoğraflarınız',
            onTap: () => Navigator.of(context).pop('galeri'),
          ),
          // ⚠ YALNIZ FOTOĞRAF VARKEN: silinecek bir şey yokken
          // satırı göstermek kullanıcıyı yanıltır.
          //
          // ⚠ KIRMIZI ROZET: yıkıcı eylem, mavi/yeşilden ayrılır.
          if (fotoYolu.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            fotografSecenekSatiri(
              context,
              rozetRengi: RC.danger,
              ikon: 'assets/svg/ic_trash.svg',
              ikonRengi: RC.white,
              baslik: 'Fotoğrafı Kaldır',
              aciklama: 'Yerine adınızın baş harfi gösterilir',
              onTap: () => Navigator.of(context).pop('sil'),
            ),
          ],
        ],
      ),
    );
    if (secim == null || !context.mounted) {
      return;
    }
    if (secim == 'sil') {
      await _fotoYaz(context, '', 'Profil fotoğrafı kaldırıldı');
      return;
    }
    await _fotoSec(
      context,
      secim == 'kamera' ? ImageSource.camera : ImageSource.gallery,
    );
  }

  /// Seçilen görüntüyü `data:` adresine çevirir (yalnız web).
  ///
  /// ⚠ TÜR SEÇİM ANINDAN: `XFile.mimeType` tarayıcının bildirdiği
  /// gerçek türdür; `blob:` yolunda uzantı yoktur ve türetilemez.
  /// Çözülemezse `image/jpeg` VARSAYILMAZ — işlem iptal edilir,
  /// bozuk bir adres yazılmaz.
  ///
  /// ⚠ BOYUT SINIRI: `maxWidth: 1024` ile küçültülmüş görüntü
  /// beklenir. Yine de 2 MB üstü veri saklanmaz — base64 üçte bir
  /// büyür ve kalıcı depo şişerdi.
  Future<String?> _dataAdresi(XFile x) async {
    final tur = x.mimeType;
    if (tur == null || !tur.startsWith('image/')) {
      return null;
    }
    final bayt = await x.readAsBytes();
    if (bayt.isEmpty || bayt.length > 2 * 1024 * 1024) {
      return null;
    }
    return 'data:$tur;base64,${base64Encode(bayt)}';
  }

  Future<void> _fotoSec(BuildContext context, ImageSource kaynak) async {
    try {
      final x = await ImagePicker().pickImage(source: kaynak, maxWidth: 1024);
      if (x == null || !context.mounted) {
        return;
      }
      // ── ⚠ WEB'DE YOL KALICI DEĞİLDİR ──
      //
      // `image_picker` web'de `blob:https://…/uuid` döndürür. Bu adres
      // YALNIZ o sekme açıkken geçerlidir: sayfa yenilenince ya da
      // tarayıcı kapanınca ölür ve profil fotoğrafı kayboluyordu.
      //
      // Görüntü `data:` adresine çevrilerek saklanır; hesap verisiyle
      // birlikte kalıcı depoya yazılır ve yenilemeden sonra da
      // görünür.
      //
      // ⚠ MOBİLDE DEĞİŞMEZ: orada `path` gerçek bir dosya yoludur ve
      // kalıcıdır; base64'e çevirmek boşuna yer kaplardı.
      //
      // ⚠ SUNUCUYA YÜKLEME AYRI İŞTİR: backend hazır olduğunda bu
      // veri `StorageApi` üzerinden gönderilmeli. Şimdilik yerelde
      // kalır.
      final yol = kIsWeb ? await _dataAdresi(x) : x.path;
      if (yol == null || !context.mounted) {
        return;
      }
      await _fotoYaz(context, yol, 'Profil fotoğrafı güncellendi');
    } catch (_) {
      if (context.mounted) {
        sysToastErr(context, SysKind.photoUploadError);
      }
    }
  }

  /// ⚠ FOTOĞRAF YALNIZ AKTİF ROLE YAZILIR.
  ///
  /// `Account.photoPath` aktif rolün fotoğrafına bağlıdır; çift rollü
  /// kullanıcıda öteki rol ETKİLENMEZ (bkz. `Account.fotografAta`).
  Future<void> _fotoYaz(
      BuildContext context, String yol, String basariMesaji) async {
    final err = await context
        .read<ProfileController>()
        .updateProfile(photoPath: yol);
    if (!context.mounted) {
      return;
    }
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    sysToastOk(context, basariMesaji);
  }

  @override
  Widget build(BuildContext context) {
    final harf = ad.trim().isEmpty ? '?' : ad.trim()[0].toUpperCase();
    final varFoto = fotoYolu.trim().isNotEmpty && yerelVarMi(fotoYolu);

    return SizedBox(
      width: 96,
      height: 100, // .pf-cam{bottom:4px} taşmasına pay
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatarın TAMAMI tıklanabilir.
          RefTap(
            onTap: () => _fotoMenusu(context),
            borderRadius: BorderRadius.circular(RR.circle),
            child: ClipOval(
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                color: RC.blueSoft,
                child: varFoto
                    ? yerelGorsel(
                        fotoYolu,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        hataYedegi: (_) => Text(
                          harf,
                          style: refText(
                              size: 38, weight: RF.w700, color: RC.blue),
                        ),
                      )
                    : Text(
                        harf,
                        style: refText(
                            size: 38, weight: RF.w700, color: RC.blue),
                      ),
              ),
            ),
          ),

          // .pf-cam — kamera ikonu da tıklanabilir.
          if (kameraRozeti)
          Positioned(
            right: 0,
            bottom: 4,
            child: RefTap(
              onTap: () => _fotoMenusu(context),
              borderRadius: BorderRadius.circular(RR.circle),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RC.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: RC.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33142850),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                // ⚠ `color` VERİLMEZ — referans `IC_CAM(15)` İKİ
                // RENKLİDİR: gövde beyaz (`fill=#fff`), objektif
                // halkası mavi (`fill=#1D6BE3`). Tek renge zorlanınca
                // objektif kayboluyor ve ikon düz beyaz leke oluyordu.
                child: const RefSvg('assets/svg/ic_cam.svg', size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
