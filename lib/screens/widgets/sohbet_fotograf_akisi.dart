import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import 'fotograf_kaynak_paneli.dart';

/// ── ⚠ PAYLAŞIMLI SOHBET FOTOĞRAFI AKIŞI ──
///
/// `chat_screen.dart` VE `teklif_talebi_sohbet_screen.dart`nin
/// İKİSİ de kullanır — kullanıcı isteği: "mesajlaşma bölümleri her
/// yerde aynı olmalı". İki ekranın private sınıfları birbirine
/// import EDİLEMEDİĞİ için (Dart kısıtı), bu akış PUBLIC bir
/// yardımcı olarak buraya çıkarıldı; kod tekrarı YOK, TEK kaynak.
///
/// Akış: "+" ikonuna dokunulunca ORTAK fotoğraf paneli (Fotoğraf Çek
/// / Galeriden Seç) açılır → seçilen kaynaktan fotoğraf alınır → TAM
/// EKRAN bir ÖNİZLEME açılır (fotoğraf + opsiyonel açıklama +
/// "Gönder") → kullanıcı onaylamadan HİÇBİR ŞEY gönderilmez.
///
/// Döner: kullanıcı gönderirse `(yol, aciklama)`, vazgeçerse `null`.
Future<({String yol, String? aciklama})?> sohbetFotografiSecVeOnizle(
    BuildContext context) async {
  // ── ⚠ PANEL ARTIK ORTAK ──
  //
  // Kullanıcı isteği (9 Eyl): "mesaj gönderirken fotoğraf yükleme
  // ikonuna basınca da bu şekilde görünmeli" — yani ilan oluşturma
  // ekranlarındaki panelin AYNISI.
  //
  // ⚠ BURADAKİ PANEL SAPMIŞTI: başlık "Fotoğraf Ekle" (büyük E),
  // renkli daire rozet YOK, satır açıklamaları YOK, chevron YOK,
  // iki ikon da MAVİ ve sıra TERSTİ (önce galeri). Hepsi silindi;
  // çizim `widgets/fotograf_kaynak_paneli.dart`tan geliyor.
  //
  // ⚠ AKIŞIN GERİSİ DEĞİŞMEDİ: seçilen kaynaktan fotoğraf alınır,
  // TAM EKRAN önizleme açılır, kullanıcı onaylamadan hiçbir şey
  // gönderilmez.
  final kaynak = await fotografKaynagiSec(context);
  if (kaynak == null || !context.mounted) {
    return null;
  }

  XFile? secilen;
  try {
    secilen = await ImagePicker().pickImage(source: kaynak, maxWidth: 1280);
  } catch (_) {
    return null;
  }
  if (secilen == null || !context.mounted) {
    return null;
  }

  return Navigator.of(context).push<({String yol, String? aciklama})?>(
    MaterialPageRoute(
      builder: (_) => _FotografOnizleEkrani(yol: secilen!.path),
    ),
  );
}

/// Gönderilmeden ÖNCE gösterilen tam ekran önizleme — kullanıcı
/// isteği: "fotoğraf seçilir seçilmez gönderilmemeli".
class _FotografOnizleEkrani extends StatefulWidget {
  const _FotografOnizleEkrani({required this.yol});

  final String yol;

  @override
  State<_FotografOnizleEkrani> createState() => _FotografOnizleEkraniState();
}

class _FotografOnizleEkraniState extends State<_FotografOnizleEkrani> {
  final _aciklama = TextEditingController();

  @override
  void dispose() {
    _aciklama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.file(File(widget.yol)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aciklama,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Açıklama ekle (opsiyonel)',
                        hintStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: RC.blue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(
                          context,
                          (
                            yol: widget.yol,
                            aciklama: _aciklama.text.trim().isEmpty
                                ? null
                                : _aciklama.text.trim(),
                          )),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: RefSvg('assets/svg/ic_send.svg',
                            size: 20, color: RC.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
