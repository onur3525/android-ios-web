
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/chat_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/models/chat.dart';
import '../domain/failures.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/validators.dart';
import '../domain/config.dart';
import 'widgets/sohbet_fotograf_akisi.dart';
import '../core/platform/yerel_gorsel.dart';
import '../ui/olcu.dart';
import '../domain/sohbet_okunmamis.dart';
import '../core/baglanti_modu.dart';

/// Sohbet (HTML vChat): balonlar, mesaj durumları
/// (Gönderiliyor / Gönderildi / Okundu / Gönderilemedi + Tekrar Gönder),
/// fotoğraf gönderme (mock). Erişim controller'da doğrulanır.
class ChatScreen extends StatefulWidget {
  final String offerId;
  const ChatScreen({super.key, required this.offerId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// ── ⚠ EKRAN KORUMASI AÇIK ──
//
// Bu ekranda karşı tarafın adı ve telefon numarası görünür.
class _ChatScreenState extends State<ChatScreen>
 {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  DomainError? _accessError;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ⚠ Kare sonrası çalışır; bu arada oturum düşmüş olabilir.
      final me = context.read<AuthController>().currentAccount;
      if (me == null || !mounted) {
        return;
      }
      // Geçmiş sunucudan yüklenir, okundu işaretlenir ve gerçek zamanlı
      // bağlantı kurulur (mock modda bellek içi çalışır).
      final r = await context
          .read<ChatController>()
          .openThread(widget.offerId, actorId: me.id);
      if (mounted) setState(() => _accessError = r.error);
    });
  }

  Future<void> _send({String? imagePath}) async {
    final text = _input.text.trim();
    if (_sending || (text.isEmpty && imagePath == null)) {
      return;
    }
    final me = context.read<AuthController>().currentAccount;
    if (me == null) {
      // Oturum düşmüşse mesaj gönderilmez; metin KAYBOLMAZ.
      return;
    }
    setState(() => _sending = true);
    _input.clear();
    final r = await context.read<ChatController>().sendDelivered(widget.offerId,
        senderId: me.id,
        text: text.isEmpty ? null : text,
        imagePath: imagePath);
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (r.error != null) {
      sysToastErr(context, SysKind.messageSendError, extra: r.error!.message);
    }
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _pickPhoto() async {
    // ⚠ PAYLAŞIMLI AKIŞ — `sohbet_fotograf_akisi.dart`. İki sohbet
    // ekranı da aynı fonksiyonu çağırır; rol ayrımı YOKTUR.
    //
    // ── ⚠ ÇOKLU SEÇİM (kullanıcı kararı) ──
    //
    // Önizleme ekranı kaldırıldı, galeriden çoklu seçim geldi.
    // Gönderilen fotoğrafa dokununca zaten tam ekran açılıyor.
    //
    // ⚠ HER FOTOĞRAF AYRI MESAJDIR: sohbet modeli mesaj başına TEK
    // görsel taşır. Liste sırayla gönderilir.
    //
    // ⚠ METİN YALNIZ İLK MESAJA GİDER: `_send` metni `_input`tan okur
    // ve gönderdikten sonra temizler. Aynı açıklamayı her fotoğrafa
    // tekrarlamak sohbeti kirletirdi.
    //
    // ⚠ SIRAYLA VE `await` İLE: paralel gönderim mesaj sırasını
    // bozar; sohbette sıra anlamın parçasıdır.
    final yollar = await sohbetFotograflariSec(context);
    for (final yol in yollar) {
      if (!mounted) {
        return;
      }
      await _send(imagePath: yol);
    }
  }

  String _statusText(MessageStatus s) => switch (s) {
        MessageStatus.sending => 'Gönderiliyor…',
        MessageStatus.sent => 'Gönderildi',
        MessageStatus.delivered => 'İletildi',
        MessageStatus.read => 'Okundu',
        MessageStatus.failed => 'Gönderilemedi',
      };

  @override
  Widget build(BuildContext context) {
    // ⚠ OTURUM DÜŞERSE ÇÖKME YOK — bkz. job_detail_screen notu.
    final auth = context.watch<AuthController>();
    final me = auth.currentAccount;
    if (me == null) {
      return const Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(child: Center(child: SysState(SysKind.sessionExpired))),
      );
    }
    final chatCtl = context.watch<ChatController>();
    final listingCtl = context.watch<ListingController>();

    if (_accessError != null) {
      return Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(
          child: Column(children: [
            Expanded(child: Center(
            child: SysState(
                _accessError is InvalidStateError
                    ? SysKind.unauthorized
                    : SysKind.genericError,
                title: 'Sohbet açılamadı',
                desc: _accessError!.message))),
          ]),
        ),
      );
    }

    final msgs = chatCtl.threadFor(widget.offerId) ?? const <ChatMessage>[];
    String title = 'Sohbet';
    // ⚠ KARŞI TARAFIN NUMARASI — "Ara" düğmesi için.
    //
    // İletişim açılmamışsa boş kalır ve düğme çizilmez; sohbette
    // olmayan bir numarayı aramaya çalışmak anlamsız olurdu.
    String telefon = '';
    final oList = chatCtl.conversationsFor(me.id)
        .where((x) => x.id == widget.offerId);
    if (oList.isNotEmpty) {
      final o = oList.first;
      final l = listingCtl.byId(o.listingId);
      final otherId = me.id == o.providerId ? (l?.ownerId ?? '') : o.providerId;
      final other = auth.accountById(otherId);
      if (other != null && other.name.isNotEmpty) {
        title = other.name;
      }
      // Sohbet zaten yalnız iletişim açıldıktan sonra kurulur; yine de
      // numara boşsa düğme gösterilmez.
      telefon = other?.phone ?? '';
    }

    // ── GÖRÜNÜM: referans `vChat()` ──
    // ⚠ Referansta AppBar YOKTUR; başlık sayfa içi üst çubuktadır.
    return Scaffold(
      // `.ch-scroll{background:#F4F6FA}` — sohbet zemini genel sayfa
      // zemininden AYRIDIR; beyaz baloncuklar bu zeminde ayrışır.
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        // ── ⚠ MASAÜSTÜ WEB: SOL KONUŞMA LİSTESİ + SAĞ AKTİF SOHBET ──
        //
        // Masaüstünde tek sohbet ekranı 1200 px'i boş bırakıyordu ve
        // başka bir konuşmaya geçmek için geri dönmek gerekiyordu.
        //
        // ⚠ YENİ VERİ YOK: soldaki liste, bu ekranın ZATEN okuduğu
        // `chatCtl.conversationsFor(me.id)` sonucudur — karşı tarafı
        // çözme mantığı da aynı (`byId` → sahip/sağlayıcı ayrımı).
        //
        // ⚠ AKTİF SOHBET DEĞİŞMEDİ: sağdaki sütun, bugüne kadar tüm
        // ekranı kaplayan `Column`un TA KENDİSİ. Üst çubuk, mesaj
        // listesi, fotoğraf akışı, giriş alanı, Enter/Shift+Enter —
        // hiçbiri kopyalanmadı, taşınmadı.
        //
        // ⚠ ÜÇÜNCÜ KAYDIRMA ALANI AÇILMADI: sol liste kendi
        // kaydırmasını yönetir, sağdaki sohbet bugünkü kaydırmasını
        // sürdürür. Toplam iki, eskisi gibi.
        child: _sohbetKabugu(
          context,
          aktifId: widget.offerId,
          sohbet: Column(children: [
          // Üst çubuk: geri + karşı taraf adı
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 6),
            child: Row(
              children: [
                // ⚠ GERİ OKU GERİ GELDİ — HER PLATFORMDA.
                // iOS'ta donanım geri tuşu yok; platforma göre
                const RefBackButton(),
                // ── ⚠ AD SOYAD ORTALI (16 Eyl, kullanıcı isteği) ──
                //
                // "Mesajlarda en üstte yer alan isim soyisim ortalı
                // olmalı."
                //
                // ⚠ GERİ OKU VE "Ara" DÜĞMESİ SOLDA/SAĞDA KALIR:
                // ikisi de gezinme/eylem öğesidir, başlığın parçası
                // değil. `Expanded` ortada kalan boşluğu kapladığı
                // için `textAlign: center` adı O BOŞLUĞUN ortasına
                // koyar — iki yan öğenin genişlikleri farklı olduğu
                // sürece ad, EKRANIN tam ortasına düşmez. Kabul
                // edilen davranış budur; adı ekran ortasına sabitlemek
                // `Stack` gerektirir ve iki yan öğenin üstüne binme
                // riski doğurur.
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s17, weight: RF.w700, color: RC.text),
                  ),
                ),
                // ── `Ara` — SAĞ ÜST ──
                //
                // ⚠ Referansta sohbet başlığının sağında telefon
                // ikonu + "Ara" bulunur. Eksikti: kullanıcı sohbetten
                // aramaya geçmek için geri dönüp ilan detayına
                // gitmek zorunda kalıyordu.
                //
                // ⚠ İletişim AÇILMADAN görünmez: numara zaten yok.
                if (telefon.isNotEmpty)
                  RefTap(
                    onTap: () => _ara(context, telefon),
                    borderRadius: BorderRadius.circular(RR.r10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const RefSvg('assets/svg/ic_phone_f.svg',
                            size: 20, color: RC.blue),
                        const SizedBox(width: 6),
                        Text('Ara',
                            style: refText(
                                size: RF.s17,
                                weight: RF.w700,
                                color: RC.blue)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          // HTML vChat: gün ayırıcı
          if (msgs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: HC.border, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Bugün',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700, color: HC.grey)),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                final mine = m.senderId == me.id;
                // ⚠ YENİ — kullanıcı bulgusu: "fotoğraflar mesaj
                // kısmında çerçeveli vs gösterilmemeli, sadece
                // fotoğraf gösterilmeli". Yalnız fotoğraf İÇEREN
                // (metinsiz) mesajlar artık RENKLİ BALONUN DIŞINDA,
                // şeffaf zeminde gösterilir — WhatsApp'taki gibi.
                // Metin de varsa (fotoğraf+açıklama), mevcut balon
                // KORUNUR (fotoğraf balonun İÇİNDE, üstte).
                final yalnizFoto = m.imagePath != null && m.text == null;

                Widget durumSatiri({required bool acikZemin}) {
                  if (!mine) {
                    return const SizedBox.shrink();
                  }
                  // ⚠ Şeffaf/açık zeminde (yalnız-fotoğraf durumunda)
                  // beyaz tikler/metin OKUNMAZ — koyu bir renk seti
                  // kullanılır. Mavi balon zemininde ise mevcut
                  // beyaz/yarı-saydam renkler KORUNUR.
                  final aktifRenk =
                      acikZemin ? RC.textSoft : Colors.white70;
                  final okunduRenk =
                      acikZemin ? const Color(0xFF1D9BF0) : const Color(0xFF5EE1FF);
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    if (m.status == MessageStatus.sending)
                      SizedBox(
                          width: 10, height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.6, color: aktifRenk)),
                    // ⚠ DÜZELTİLDİ — kullanıcı bulgusu: "sent" ve
                    // "delivered" ikisi de AYNI tek tik ikonunu
                    // gösteriyordu. Artık: gönderildi = 1 tik,
                    // iletildi = 2 tik (soluk), okundu = 2 tik
                    // (WhatsApp'taki gibi FARKLI, canlı bir renkte).
                    if (m.status == MessageStatus.sent)
                      RefTik(size: 13, color: aktifRenk),
                    if (m.status == MessageStatus.delivered)
                      RefSvg('assets/svg/ic_tick2.svg',
                          size: 15, color: aktifRenk),
                    if (m.status == MessageStatus.read)
                      RefSvg('assets/svg/ic_tick2.svg',
                          size: 15, color: okunduRenk),
                    const SizedBox(width: 4),
                    Text(_statusText(m.status),
                        style: TextStyle(
                            fontSize: 10,
                            color: m.status == MessageStatus.failed
                                ? const Color(0xFFE5452C)
                                : aktifRenk)),
                    if (m.status == MessageStatus.failed) ...[
                      const SizedBox(width: 8),
                      // ⚠ `GestureDetector` YERİNE `RefTap`: gerçek bir
                      // eylem ama klavyeyle odaklanamıyordu; imleç de
                      // el işaretine dönmüyordu.
                      RefTap(
                        onTap: () => context
                            .read<ChatController>()
                            .retry(widget.offerId, m),
                        child: const Text('Tekrar Gönder',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE5452C),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFE5452C))),
                      ),
                    ],
                  ]);
                }

                if (yalnizFoto) {
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: mine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SohbetFotografi(yol: m.imagePath!, benim: mine),
                          if (mine) ...[
                            const SizedBox(height: 3),
                            durumSatiri(acikZemin: true),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  // ── `.ch-bub` ──
                  //
                  // ```css
                  // .ch-row{margin-bottom:10px}
                  // .ch-bub{max-width:78%;14px;1.45;padding:11px 13px 20px;r15}
                  // .in  .ch-bub{#fff;#16233D;1px #EEF0F3;alt-sol r5}
                  // .out .ch-bub{#1D6BE3;#fff;alt-sağ r5}
                  // ```
                  //
                  // ⚠ GELEN baloncuk BEYAZ ve ÇERÇEVELİDİR — gri
                  // (#F2F4F7) zemin referansta YOKTUR; o renk sohbet
                  // ARKA PLANINA yakındır ve baloncuk kaybolur.
                  //
                  // ⚠ Genişlik sabit 280px DEĞİL, ekranın %78'idir.
                  // Alt dolgu 20px'tir: saat damgası baloncuğun
                  // İÇİNDE, sağ altta durur.
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 20),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: mine ? RC.blue : RC.white,
                      border: mine
                          ? null
                          : Border.all(color: const Color(0xFFEEF0F3)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: Radius.circular(mine ? 15 : 5),
                        bottomRight: Radius.circular(mine ? 5 : 15),
                      ),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── ⚠ FOTOĞRAF ÖNİZLEMELİ ──
                          //
                          // Burada yalnız bir ikon ve "Fotoğraf"
                          // yazısı vardı: kullanıcı GÖNDERDİĞİ
                          // fotoğrafı bile göremiyordu. Artık küçük
                          // önizleme çizilir, dokununca tam ekran
                          // açılır.
                          if (m.imagePath != null)
                            _SohbetFotografi(
                              yol: m.imagePath!,
                              benim: mine,
                            ),
                          if (m.text != null)
                            Text(m.text!,
                                style: TextStyle(
                                    fontSize: 13.5, height: 1.4,
                                    color: mine ? Colors.white : HC.dark)),
                          if (mine) ...[
                            const SizedBox(height: 3),
                            durumSatiri(acikZemin: false),
                          ],
                        ]),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: HC.border))),
            child: Row(children: [
              RefTap(
                onTap: _sending ? null : _pickPhoto,
                borderRadius: BorderRadius.circular(RR.circle),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: RefSvg('assets/svg/ic_camplus.svg',
                      size: 24, color: RC.blue),
                ),
              ),
              Expanded(
                // ── ⚠ WEB'DE ENTER GÖNDERİR, SHIFT+ENTER SATIR AÇAR ──
                //
                // Alan çok satırlı (`maxLines: 4`); çok satırlı bir
                // `TextField`ta Enter YENİ SATIR açar ve `onSubmitted`
                // TETİKLENMEZ. Masaüstünde mesajlaşmanın beklentisi
                // bunun tersidir.
                //
                // ⚠ MOBİL DAVRANIŞ HİÇ DEĞİŞMEZ: koşul `kIsWeb`.
                // Android/iOS'ta klavyenin dönüş tuşu bugünkü gibi
                // satır açmaya devam eder; donanım klavyesi bağlı bir
                // tablette bile bu dal çalışmaz.
                //
                // ⚠ SHIFT BASILIYSA KARIŞILMAZ: `ignored` dönülür,
                // `TextField` kendi işini yapar ve satır açılır. Aksi
                // hâlde kullanıcı web'de hiç paragraf yazamazdı.
                //
                // ⚠ YALNIZ TUŞ BASIMINDA: `KeyDownEvent` denetlenmesi
                // şart; `KeyUpEvent` de yakalansaydı tek Enter iki
                // mesaj gönderirdi.
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (!kIsWeb ||
                        event is! KeyDownEvent ||
                        event.logicalKey != LogicalKeyboardKey.enter) {
                      return KeyEventResult.ignored;
                    }
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      return KeyEventResult.ignored;
                    }
                    unawaited(_send());
                    return KeyEventResult.handled;
                  },
                  child: TextField(
                  controller: _input,
                  // ⚠ Domain katmanında da denetlenir (bkz.
                  // `MockChatPort.send`); bu yalnız kullanıcı kolaylığı.
                  maxLength: kMesajMaxLength,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      hintText: 'Mesaj yaz...',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  // ⚠ MOBİLDE TEK SATIRLIK KLAVYELERDE HÂLÂ GEÇERLİ.
                  onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: HC.blue,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sending ? null : _send,
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: _sending
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white))
                        : const RefSvg('assets/svg/ic_send.svg',
                            size: 20, color: RC.white),
                  ),
                ),
              ),
            ]),
          ),
        ]),
        ),
      ),
    );
  }
}

/// Masaüstünde iki sütun, mobilde tek sütun.
///
/// ⚠ İKİ KOŞUL BİRLİKTE: `kIsWeb` VE ≥1024 px. Öteki masaüstü
/// yapılarıyla (`masaustuNav`, `MasaustuListe`, `MasaustuDetay`) AYNI
/// eşik; biri iki sütuna geçip öteki tek sütun kalsaydı sayfa
/// tutarsız görünürdü.
Widget _sohbetKabugu(
  BuildContext context, {
  required String aktifId,
  required Widget sohbet,
}) {
  if (!kIsWeb || !ekranSinifi(context).masaustuMu) {
    return sohbet;
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(width: 320, child: _KonusmaListesi(aktifId: aktifId)),
      // ⚠ Mevcut ayraç rengi; yeni renk üretilmedi.
      const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFECEEF2)),
      Expanded(child: sohbet),
    ],
  );
}

/// Masaüstü sol sütunu — kullanıcının açık sohbetleri.
///
/// ⚠ YENİ EKRAN DEĞİL: bu liste yalnız masaüstü sohbet görünümünün
/// sol sütunudur; mobilde hiç çizilmez ve ayrı bir route'u yoktur.
class _KonusmaListesi extends StatelessWidget {
  const _KonusmaListesi({required this.aktifId});

  final String aktifId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentAccount;
    if (me == null) {
      return const SizedBox.shrink();
    }
    final chatCtl = context.watch<ChatController>();
    final listingCtl = context.watch<ListingController>();
    final konusmalar = chatCtl.conversationsFor(me.id);

    if (konusmalar.isEmpty) {
      // ⚠ Mevcut boş durum bileşeni; yeni tasarım yok.
      return const Center(
        child: SysEmpty(
            title: 'Sohbet yok', desc: 'Henüz açılmış bir sohbetiniz yok.'),
      );
    }

    return ColoredBox(
      color: RC.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: konusmalar.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F7)),
        itemBuilder: (_, i) {
          final o = konusmalar[i];
          // ⚠ KARŞI TARAF ÇÖZÜMÜ AKTİF SOHBETLE AYNI MANTIK: ilanın
          // sahibi miyim, değil miyim.
          final l = listingCtl.byId(o.listingId);
          final otherId =
              me.id == o.providerId ? (l?.ownerId ?? '') : o.providerId;
          final other = auth.accountById(otherId);
          final ad = (other?.name ?? '').trim();
          final okunmamis =
              okunmamisSohbetMesaji(chatCtl.threadFor(o.id), me.id);
          final aktif = o.id == aktifId;

          return RefTap(
            // ⚠ `pushReplacement`: yığın büyümesin. Kullanıcı sohbetler
            // arasında gezinirken geri tuşu onlarca adım geriye
            // gitmemeli.
            onTap: aktif
                ? null
                : () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatScreen(offerId: o.id),
                      ),
                    ),
            child: ColoredBox(
              color: aktif ? RC.blueSoft : RC.white,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // ⚠ MEVCUT AVATAR BİLEŞENİ.
                    RefBasHarfAvatar(ad: ad.isEmpty ? '?' : ad),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ad.isEmpty ? 'Kullanıcı' : ad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s135,
                            weight: aktif ? RF.w700 : RF.w600,
                            color: RC.text),
                      ),
                    ),
                    if (okunmamis > 0) ...[
                      const SizedBox(width: 8),
                      // ⚠ MEVCUT ROZET BİLEŞENİ, aynı kırmızı.
                      RefSayiRozeti(sayi: okunmamis, halkaRengi: RC.white),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// `<a href="tel:...">` karşılığı — telefon uygulamasını açar.
Future<void> _ara(BuildContext context, String ham) async {
  final d = Validators.phoneLocal(ham);
  if (d.isEmpty) {
    return;
  }
  final acildi = await launchUrl(Uri.parse('tel:$d'),
      mode: acilisModu());
  // ⚠ Sahte başarı YOK: arama uygulaması açılamazsa kullanıcı uyarılır.
  if (!acildi && context.mounted) {
    sysToastErr(context, SysKind.genericError,
        extra: 'Arama uygulaması açılamadı');
  }
}

/// SOHBET FOTOĞRAFI — önizleme + tam ekran.
///
/// ── ⚠ KAYNAK İKİ TÜRLÜ OLABİLİR ──
///
/// · CİHAZ YOLU — kullanıcının az önce seçtiği dosya (galeriden
///   gelir, mock modda ve gönderim anında budur).
/// · SUNUCU REFERANSI (`storageRef`) — karşı taraftan gelen mesajda
///   `Mappers.chatMessage` bu alanı doldurur.
///
/// ⚠ REFERANS ÇÖZÜMLEME YAPILMADI. `StorageApi.resolve` ucu tanımlı
/// ama YANIT BİÇİMİ sözleşmede belirsiz (hangi alan URL taşıyor
/// yazılı değil). Uydurma bir alan adı okumak yerine referans
/// çözülemediğinde nötr bir yer tutucu çizilir — bkz. rapor.
class _SohbetFotografi extends StatelessWidget {
  const _SohbetFotografi({required this.yol, required this.benim});

  final String yol;
  final bool benim;

  bool get _ag => yol.startsWith('http://') || yol.startsWith('https://');
  bool get _yerel => !_ag && yerelVarMi(yol);

  @override
  Widget build(BuildContext context) {
    final gorsel = _gorsel(kucuk: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 190,
          height: 140,
          child: (_ag || _yerel)
              ? RefTap(
                  // ⚠ Dokununca TAM EKRAN: sohbet balonundaki küçük
                  // önizlemede ayrıntı seçilemiyor.
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _FotografTamEkran(yol: yol),
                    ),
                  ),
                  child: gorsel,
                )
              : gorsel,
        ),
      ),
    );
  }

  Widget _gorsel({required bool kucuk}) {
    if (_ag) {
      return Image.network(yol, fit: BoxFit.cover, errorBuilder: _hata);
    }
    if (_yerel) {
      // ⚠ `hataYedegi` TEK parametrelidir; `_hata` üç parametreli
      // `errorBuilder` imzasını korur ve üstteki `Image.network`
      // onu kullanmaya devam eder. Yedek görüntü ikisinde de aynı.
      return yerelGorsel(yol,
          fit: BoxFit.cover, hataYedegi: (_) => _yerTutucu());
    }
    return _yerTutucu();
  }

  Widget _hata(BuildContext _, Object __, StackTrace? ___) => _yerTutucu();

  /// ⚠ Görsel açılamadığında BOŞ KUTU BIRAKILMAZ: kullanıcı bir
  /// fotoğraf gönderildiğini yine de görmeli.
  Widget _yerTutucu() => ColoredBox(
        color: benim ? Colors.white24 : const Color(0xFFF1F4F9),
        child: Center(
          child: RefSvg('assets/svg/ic_camg.svg', size: 22),
        ),
      );
}

/// Tam ekran fotoğraf görüntüleyici.
///
/// ⚠ Yakınlaştırma `InteractiveViewer` ile: ayrı bir paket
/// EKLENMEDİ.
class _FotografTamEkran extends StatelessWidget {
  const _FotografTamEkran({required this.yol});

  final String yol;

  @override
  Widget build(BuildContext context) {
    final ag = yol.startsWith('http://') || yol.startsWith('https://');
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: ag
                    ? Image.network(yol)
                    : yerelGorsel(yol),
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
