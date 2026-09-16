import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'widgets/sohbet_fotograf_akisi.dart';

/// "TEKLİF TALEBİ" SOHBETİ — AYRI EKRAN.
///
/// ⚠ ÖNCEDEN detay ekranına GÖMÜLÜYDÜ (inline kutu, her zaman
/// açık). Artık `TeklifTalebiDetayScreen`deki "Mesajlaşma" kutusuna
/// dokununca BURAYA gelinir — `offer_detail_screen.dart`daki
/// `_IletisimKutusu` → `ChatScreen` deseniyle AYNI mantık: kart bir
/// ÖNİZLEME/GİRİŞ NOKTASI, gerçek sohbet kendi ekranındadır.
///
/// Metin ve TEK fotoğraf gönderimi destekler. Mevcut sohbet sistemi
/// (`ChatController`) `Listing`/`Offer` kimliğine bağlıdır ve bu YENİ
/// modele (`TeklifTalebi`) DOKUNULMADAN bağlanamaz; bu yüzden
/// mesajlar `TeklifTalebi.mesajlar` üzerinde, KENDİ bağımsız
/// zincirinde tutulur — `ChatController`a DOKUNULMADI.
///
/// Fotoğraf seçimi `image_picker` ile DOĞRUDAN yapılır
/// (`ListingPhotoPicker` çoklu-seçim/yükleme akışı için
/// tasarlanmıştı; burada tek dosya anlık gönderim ihtiyacı farklı,
/// bu yüzden o bileşen ZORLA uydurulmadı).
class TeklifTalebiSohbetScreen extends StatefulWidget {
  const TeklifTalebiSohbetScreen({
    super.key,
    required this.talepId,
    required this.baslik,
  });

  final String talepId;

  /// Üst bardaki başlık — çağıran ekran "hizmet" ya da "karşı taraf
  /// adı" geçirir; bu ekran o kararı VERMEZ.
  final String baslik;

  @override
  State<TeklifTalebiSohbetScreen> createState() =>
      _TeklifTalebiSohbetScreenState();
}

class _TeklifTalebiSohbetScreenState extends State<TeklifTalebiSohbetScreen> {
  final _metin = TextEditingController();
  bool _gonderiliyor = false;

  @override
  void initState() {
    super.initState();
    // ⚠ YENİ — sohbet açılınca karşı taraftan gelen mesajlar
    // "okundu" işaretlenir (2 tik, renk değişir). Kare sonrası
    // çalışır — `context.read` build dışında güvenli.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = context.read<AuthController>().currentAccount;
      if (me == null || !mounted) {
        return;
      }
      context
          .read<TeklifTalebiController>()
          .mesajlariOkunduIsaretle(widget.talepId, me.id);
    });
  }

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  Future<void> _gonder({String? fotografYolu}) async {
    final t = _metin.text.trim();
    if (t.isEmpty && fotografYolu == null) return;
    final me = context.read<AuthController>().currentAccount;
    if (me == null) return;
    setState(() => _gonderiliyor = true);
    final err = await context.read<TeklifTalebiController>().mesajGonder(
          widget.talepId,
          gonderenId: me.id,
          metin: t.isEmpty ? null : t,
          fotografYolu: fotografYolu,
        );
    if (!mounted) return;
    setState(() => _gonderiliyor = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    _metin.clear();
  }

  Future<void> _fotografSecVeGonder() async {
    // ⚠ PAYLAŞIMLI AKIŞ — `chat_screen.dart` ile AYNI fonksiyon.
    // Gerekçeler orada yazılı; iki ekran ayrışamaz.
    final yollar = await sohbetFotograflariSec(context);
    for (final yol in yollar) {
      if (!mounted) {
        return;
      }
      await _gonder(fotografYolu: yol);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentAccount;
    final talep =
        context.watch<TeklifTalebiController>().byId(widget.talepId);
    final mesajlar = talep?.mesajlar ?? const <TeklifMesaj>[];

    return Scaffold(
      backgroundColor: RC.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  const RefBackButton(),
                  const SizedBox(width: 8),
                  // ⚠ BAŞLIK ORTALI — `chat_screen.dart` ile AYNI
                  // kural (16 Eyl, kullanıcı isteği). İki mesajlaşma
                  // ekranı ayrışamaz.
                  Expanded(
                    child: Text(widget.baslik,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s16, weight: RF.w700, color: RC.text)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFECEEF2)),
            Expanded(
              child: mesajlar.isEmpty
                  ? Center(
                      child: Text('Henüz mesaj yok.',
                          style: refText(
                              size: RF.s14,
                              weight: RF.w400,
                              color: RC.textSoft)),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        for (final m in mesajlar)
                          _MesajBalonu(m, me?.id ?? ''),
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    RefTap(
                      onTap: _gonderiliyor ? null : _fotografSecVeGonder,
                      borderRadius: BorderRadius.circular(RR.circle),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: RefSvg('assets/svg/ic_camplus.svg',
                            size: 22, color: RC.blue),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _metin,
                        enabled: !_gonderiliyor,
                        textCapitalization: TextCapitalization.sentences,
                        decoration:
                            const InputDecoration(hintText: 'Mesaj yaz...'),
                        onSubmitted: (_) => _gonder(),
                      ),
                    ),
                    RefTap(
                      onTap: _gonderiliyor ? null : () => _gonder(),
                      borderRadius: BorderRadius.circular(RR.circle),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: RefSvg('assets/svg/ic_send.svg',
                            size: 22,
                            color: _gonderiliyor ? RC.textSoft : RC.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MesajBalonu extends StatelessWidget {
  const _MesajBalonu(this.mesaj, this.benId);

  final TeklifMesaj mesaj;
  final String benId;

  @override
  Widget build(BuildContext context) {
    final benim = mesaj.gonderenId == benId;
    // ⚠ YENİ — kullanıcı bulgusu: "fotoğraflar mesaj kısmında
    // çerçeveli vs gösterilmemeli, sadece fotoğraf gösterilmeli".
    // `chat_screen.dart` ile AYNI ilke: yalnız fotoğraf İÇEREN
    // (metinsiz) mesajlar RENKLİ BALONUN DIŞINDA, şeffaf zeminde
    // gösterilir.
    final yalnizFoto = mesaj.fotografYolu != null && mesaj.metin == null;

    Widget durumSatiri({required bool acikZemin}) {
      if (!benim) {
        return const SizedBox.shrink();
      }
      // ⚠ KULLANICI İSTEĞİ — "gönderilen mesaj 1 tik, iletilen mesaj
      // 2 tik, okunduysa renk değişik 2 tik". `TeklifMesajDurumu`da
      // "sending"/"failed" ara durumu YOK (`mesajGonder` başarısız
      // olursa mesaj listeye hiç eklenmez, hata ayrıca gösterilir).
      final aktifRenk = acikZemin ? RC.textSoft : Colors.white70;
      final okunduRenk =
          acikZemin ? const Color(0xFF1D9BF0) : const Color(0xFF5EE1FF);
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (mesaj.durum == TeklifMesajDurumu.gonderildi)
          RefSvg('assets/svg/ic_checksm.svg', size: 12, color: aktifRenk),
        if (mesaj.durum == TeklifMesajDurumu.iletildi)
          RefSvg('assets/svg/ic_tick2.svg', size: 14, color: aktifRenk),
        if (mesaj.durum == TeklifMesajDurumu.okundu)
          RefSvg('assets/svg/ic_tick2.svg', size: 14, color: okunduRenk),
      ]);
    }

    if (yalnizFoto) {
      return Align(
        alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment:
                benim ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TeklifSohbetFotografi(yol: mesaj.fotografYolu!, benim: benim),
              if (benim) ...[
                const SizedBox(height: 3),
                durumSatiri(acikZemin: true),
              ],
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: benim ? RC.blue : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(RR.r12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mesaj.fotografYolu != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child:
                    _TeklifSohbetFotografi(yol: mesaj.fotografYolu!, benim: benim),
              ),
            if (mesaj.metin != null)
              Text(mesaj.metin!,
                  style: refText(
                      size: RF.s135,
                      weight: RF.w400,
                      color: benim ? RC.white : RC.text)),
            if (benim) ...[
              const SizedBox(height: 4),
              durumSatiri(acikZemin: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sohbet fotoğrafı — küçük önizleme, dokununca TAM EKRAN.
///
/// ⚠ `chat_screen.dart`daki `_SohbetFotografi`/`_FotografTamEkran`
/// İLE AYNI görsel dil — o sınıflar PRIVATE olduğu için buraya AYNEN
/// yeniden oluşturuldu (Dart dosyalar arası private import ETMEZ).
class _TeklifSohbetFotografi extends StatelessWidget {
  const _TeklifSohbetFotografi({required this.yol, required this.benim});

  final String yol;
  final bool benim;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 190,
        height: 140,
        child: RefTap(
          // ⚠ Dokununca TAM EKRAN: kullanıcı isteği — "tıklanınca
          // büyüyebilmeli ekrana sığmalı diğer mesaj kısımlarındaki
          // gibi".
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => _TeklifFotografTamEkran(yol: yol),
            ),
          ),
          child: Image.file(File(yol), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// Tam ekran fotoğraf görüntüleyici — `chat_screen.dart`daki
/// `_FotografTamEkran` ile AYNI (yakınlaştırma `InteractiveViewer`
/// ile, ayrı bir paket EKLENMEDİ).
class _TeklifFotografTamEkran extends StatelessWidget {
  const _TeklifFotografTamEkran({required this.yol});

  final String yol;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.file(File(yol)),
              ),
            ),
            Positioned(
              left: 4,
              top: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
