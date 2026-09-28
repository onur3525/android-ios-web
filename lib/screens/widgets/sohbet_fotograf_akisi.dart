import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'fotograf_kaynak_paneli.dart';

/// ── ⚠ PAYLAŞIMLI SOHBET FOTOĞRAFI AKIŞI ──
///
/// `chat_screen.dart` VE `teklif_talebi_sohbet_screen.dart`nin
/// İKİSİ de kullanır — kullanıcı isteği: "mesajlaşma bölümleri her
/// yerde aynı olmalı". İki ekranın private sınıfları birbirine
/// import EDİLEMEDİĞİ için (Dart kısıtı), bu akış PUBLIC bir
/// yardımcı olarak buraya çıkarıldı; kod tekrarı YOK, TEK kaynak.
///
/// ⚠ ROL AYRIMI YOKTUR: hizmet veren de hizmet alan da AYNI akışı
/// görür. Bu dosyada rolü sorgulayan tek bir satır bile olmamalıdır.
///
/// ── ⚠ ÖNİZLEME KALDIRILDI, ÇOKLU SEÇİM GELDİ (kullanıcı kararı) ──
///
/// "Önizleme olmasın, çoklu seçim yapılıp yüklensin; zaten gönderilen
/// mesajlar tıklandığında büyük ekran oluyor."
///
/// ESKİ AKIŞ: galeriden TEK fotoğraf (`pickImage`) → tam ekran
/// önizleme ekranı (fotoğraf + opsiyonel açıklama + "Gönder"). Bu,
/// ilan oluşturma ekranındaki seçiciden (çoklu seçim, küçük kareler)
/// farklıydı ve kullanıcı farkı fark etti.
///
/// YENİ AKIŞ: kaynak paneli → galeride ÇOKLU seçim
/// (`pickMultiImage`) → seçilenler DOĞRUDAN gönderilir.
///
/// ⚠ KAMERA TEK FOTOĞRAF KALIR: `pickMultiImage` yalnız galeri
/// içindir; kamera zaten tek kare çeker.
///
/// ⚠ AÇIKLAMA ALANI KALKTI: önizleme ekranıyla birlikte gitti.
/// Kullanıcı açıklamayı sohbetin kendi metin kutusuna yazabilir —
/// fotoğrafla aynı mesajda gider (bkz. çağıran ekranların `_send`
/// metotları, metni `_input`tan okur).
///
/// ⚠ SIRA KORUNUR: seçim sırasıyla gönderilir; çağıran ekran listeyi
/// sırayla işler.
///
/// Döner: seçilen dosya yolları. Vazgeçilirse BOŞ liste — `null`
/// değil, çünkü çağıran taraf her hâlükârda üzerinde dönecek.
Future<List<String>> sohbetFotograflariSec(BuildContext context) async {
  // ── ⚠ PANEL ORTAK ──
  //
  // Kaynak seçimi (Fotoğraf Çek / Galeriden Seç) ilan oluşturma
  // ekranlarındakiyle AYNI bileşenden gelir
  // (`widgets/fotograf_kaynak_paneli.dart`); burada ayrı bir panel
  // çizilmez.
  final kaynak = await fotografKaynagiSec(context);
  if (kaynak == null || !context.mounted) {
    return const [];
  }

  try {
    if (kaynak == ImageSource.camera) {
      // ⚠ KAMERA: tek kare. `maxWidth` ilan seçicisiyle aynı mantıkta
      // tutulur — büyük dosya hem yüklemeyi hem belleği zorlar.
      final tek = await ImagePicker().pickImage(
          source: ImageSource.camera, maxWidth: 1280, imageQuality: 85);
      return tek == null ? const [] : [tek.path];
    }
    // ⚠ GALERİ: çoklu seçim. Kullanıcı tek tek seçer, sistem seçicisi
    // sırayı korur.
    final coklu = await ImagePicker().pickMultiImage(imageQuality: 85);
    return coklu.map((x) => x.path).toList(growable: false);
  } catch (_) {
    // Seçici açılamadı ya da izin reddedildi — sessizce vazgeçilir.
    return const [];
  }
}
