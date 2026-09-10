import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

/// ── ⚠ FOTOĞRAF KAYNAĞI PANELİ — TEK KAYNAK ──
///
/// Kullanıcı isteği (9 Eyl): "Tüm ilan oluşturma ekranlarında
/// fotoğraf yükleme kartları bu şekilde olmalı; ikonlar, yazılar,
/// renkler, boyutlar hepsi aynı olmalı. Mesaj gönderirken fotoğraf
/// yükleme ikonuna basınca da bu şekilde görünmeli."
///
/// ⚠ ÖNCEDEN İKİ AYRI PANEL VARDI ve birbirinden SAPMIŞTI:
///   • `photo_picker.dart` (ilan/teklif akışı) — başlık "Fotoğraf
///     ekle", renkli 38 px daire rozetler, her satırda açıklama
///     ("Kamerayı açar" / "Kayıtlı fotoğraflarınız"), sağda chevron,
///     sıra: Fotoğraf Çek → Galeriden Seç.
///   • `sohbet_fotograf_akisi.dart` (mesajlaşma) — başlık "Fotoğraf
///     Ekle", rozet YOK, açıklama YOK, chevron YOK, ikisi de MAVİ
///     ikon, sıra TERS: Galeriden Seç → Kamera ile Çek.
///
/// Panel BURAYA çıkarıldı; iki taraf da bu fonksiyonu çağırır, ikinci
/// bir kopya YAZILMADI. Referans alınan görünüm ilan akışınınkidir.
///
/// ⚠ AYRI DOSYA OLMASININ NEDENİ: `photo_picker.dart`taki panel bir
/// `State` sınıfının PRIVATE metoduydu — Dart'ta dışarıdan
/// çağrılamaz. Paneli public bir yardımcıya taşımak, sohbet akışının
/// `ListingPhotoPicker`ı (çoklu seçim, yükleme, silme) import
/// etmesini de gereksiz kılar.
///
/// Döner: kullanıcı bir kaynak seçtiyse o kaynak, paneli kapattıysa
/// `null`.
Future<ImageSource?> fotografKaynagiSec(BuildContext context) {
  // ⚠ `showModalBottomSheet` DEĞİL `RefBottomSheet`: uygulamadaki tüm
  // yarım ekranlar aynı sözleşmeye tabidir — başlık + X düğmesi +
  // boş alana dokununca kapanma.
  return RefBottomSheet.goster<ImageSource>(
    context,
    title: 'Fotoğraf ekle',
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // ⚠ İKİ SEÇENEK AYRI İKON KULLANIR.
      //
      // Önceden ikisi de KAMERA ikonuydu (`ic_cam` dolu, `ic_camg`
      // konturlu) — kullanıcı hangisinin galeri olduğunu ikondan
      // ayırt edemiyordu. Artık:
      //   • Kamera  → fotoğraf makinesi (`ic_cam`)
      //   • Galeri  → fotoğraf albümü   (`ic_gallery`)
      //
      // `ic_cam` BEYAZ gövdelidir; yalnız renkli daire rozetin
      // İÇİNDE okunur, beyaz zemine doğrudan konulmaz.
      _secenek(
        context,
        rozetRengi: RC.blue,
        ikon: 'assets/svg/ic_cam.svg',
        baslik: 'Fotoğraf Çek',
        aciklama: 'Kamerayı açar',
        kaynak: ImageSource.camera,
      ),
      const SizedBox(height: 2),
      _secenek(
        context,
        rozetRengi: RC.success,
        ikon: 'assets/svg/ic_gallery.svg',
        ikonRengi: RC.white,
        baslik: 'Galeriden Seç',
        aciklama: 'Kayıtlı fotoğraflarınız',
        kaynak: ImageSource.gallery,
      ),
    ]),
  );
}

/// Paneldeki tek seçenek satırı.
///
/// Her seçenek KENDİ RENGİNDE 38 px daire rozet taşır: kamera mavi,
/// galeri yeşil. Başlığın altında ne yapacağını söyleyen kısa bir
/// açıklama bulunur — kullanıcı dokunmadan önce sonucu bilir.
///
/// ⚠ ÖLÇÜLER SABİTTİR ve `alt_panel_fotograf_test` ile kilitlidir:
/// rozet 38, ikon 20, chevron 18, başlık 14,5/w600, açıklama
/// 12,5/w400, dikey dolgu 12.
Widget _secenek(
  BuildContext context, {
  required Color rozetRengi,
  required String ikon,
  required String baslik,
  required String aciklama,
  required ImageSource kaynak,
  Color? ikonRengi,
}) =>
    RefTap(
      // ⚠ SEÇİM DEĞERLE DÖNER: panel kapanırken `kaynak` geri verilir,
      // çağıran ne yapacağına kendi karar verir (ilan akışı fotoğrafı
      // listeye ekler, sohbet akışı önizleme açar). Panel iş mantığı
      // TAŞIMAZ.
      onTap: () => Navigator.of(context).pop(kaynak),
      borderRadius: BorderRadius.circular(RR.r12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rozetRengi,
              shape: BoxShape.circle,
            ),
            child: RefSvg(ikon, size: 20, color: ikonRengi),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(baslik,
                    style: refText(
                        size: RF.s145, weight: RF.w600, color: RC.text)),
                const SizedBox(height: 2),
                Text(aciklama,
                    style: refText(
                        size: RF.s125, weight: RF.w400, color: RC.textSoft)),
              ],
            ),
          ),
          const RefSvg('assets/svg/ic_chev.svg', size: 18, color: RC.greyLight),
        ]),
      ),
    );
