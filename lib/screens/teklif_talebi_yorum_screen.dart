import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../domain/config.dart';
import '../data/controllers/auth_controller.dart';
// ⚠ YALNIZ `Role`: fotoğraf rol bazlıdır (bkz. Account.fotografi).
import '../data/models/account.dart' show Role;
import '../data/controllers/review_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'widgets/profil_avatari.dart';

/// "BUL" AKIŞI — TAMAMLANAN İŞ İÇİN YORUM YAZ.
///
/// ⚠ MEVCUT `ReviewScreen` İLE KARIŞTIRILMAZ: o ekran `listingId`+
/// `offerId`'ye (normal ilan akışı) SIKI bağlıdır — hizmet veren
/// kartı, "zaten yorumlanmış mı" kontrolü hep Listing/Offer'dan
/// okur. "Bul" doğrudan teklif akışında bunlar YOKTUR (`TeklifTalebi`
/// ayrı bir modeldir). O ekranı ZORLA uydurmak yerine AYNI GÖRSEL
/// DİLDE (yıldız seçici, yorum kutusu, "gönderildi" görünümü) ayrı
/// ve küçük bir ekran kuruldu — ikisi de AYNI alt sisteme
/// (`ReviewController`/`Review` modeli) yazar, sahte bir ikinci
/// sistem İCAT EDİLMEDİ (bkz. `data/models/review.dart`daki
/// `talepId` notu).
class TeklifTalebiYorumScreen extends StatefulWidget {
  const TeklifTalebiYorumScreen({super.key, required this.talep});

  final TeklifTalebi talep;

  @override
  State<TeklifTalebiYorumScreen> createState() =>
      _TeklifTalebiYorumScreenState();
}

class _TeklifTalebiYorumScreenState extends State<TeklifTalebiYorumScreen> {
  int _stars = 0;
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_stars < 1) {
      setState(() => _error = 'Lütfen bir puan seçin');
      return;
    }
    final yorum = _text.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    final me = context.read<AuthController>().currentAccount!;
    final err = await context.read<ReviewController>().submit(
        talepId: widget.talep.id, actorId: me.id, stars: _stars,
        text: yorum);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err.message);
      return;
    }
    sysToastOk(context, 'Değerlendirmeniz gönderildi ✓');
  }

  String _tarih(DateTime t) {
    final f = DateTime.now().difference(t);
    if (f.inHours < 24) return 'Bugün';
    if (f.inDays < 7) return '${f.inDays} gün önce';
    return '${t.day}.${t.month}.${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final done = context.watch<ReviewController>().byTalep(widget.talep.id);

    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: RefScroll(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const RefBackButton(),
                  RefTap(
                    onTap: () => Navigator.pushNamedAndRemoveUntil(
                        context, '/customer/listings', (r) => false),
                    borderRadius: BorderRadius.circular(RR.circle),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: RC.surface,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const RefSvg('assets/svg/ic_close.svg',
                          size: 18, color: RC.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ⚠ BAŞLIK DURUMA GÖRE (9 Eyl): yorum zaten yazılmışken
              // bu ekran SALT OKUNUR açılıyor; "Yorum Yaz" başlığı
              // yapılacak bir iş varmış izlenimi veriyordu.
              Text(done == null ? 'Yorum Yaz' : 'Değerlendirmen',
                  style: refText(
                      size: 26,
                      weight: RF.w700,
                      color: RC.text,
                      letterSpacing: -0.3)),
              const SizedBox(height: 7),
              Text(
                  done == null
                      ? 'Aldığınız hizmet için puan ve yorumunuzu paylaşın.'
                      : 'Bu hizmet için verdiğiniz puan ve yorum.',
                  style: refText(
                      size: RF.s14, weight: RF.w400, color: RC.textSoft)),

              // ── HİZMET VEREN KARTI — DOĞRUDAN `TeklifTalebi`DEN ──
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: RC.white,
                  border: Border.all(color: RC.border),
                  borderRadius: BorderRadius.circular(RR.r13),
                ),
                child: Row(
                  children: [
                    // ── ⚠ HİZMET VERENİN FOTOĞRAFI (12 Eyl,
                    // kullanıcı bulgusu) ──
                    //
                    // İlan akışındaki yorum ekranıyla AYNI kural:
                    // kullanıcı burada kime puan verdiğini teyit
                    // ediyor. Yalnız baş harf çiziliyordu.
                    //
                    // ⚠ MASKELEME SORUNU YOK: bu ekran iş
                    // tamamlandıktan sonra açılır, kimlik zaten açık.
                    //
                    // ⚠ HİZMET VEREN ROLÜNÜN fotoğrafı okunur.
                    Builder(builder: (c) {
                      final hesap = c
                          .watch<AuthController>()
                          .accountById(widget.talep.saglayiciId);
                      return ProfilAvatari(
                        ad: widget.talep.saglayiciAdi,
                        fotoYolu: hesap?.fotografi(Role.provider) ?? '',
                        cap: 44,
                      );
                    }),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.talep.saglayiciAdi,
                              style: refText(
                                  size: RF.s145,
                                  weight: RF.w700,
                                  color: RC.text)),
                          Text(widget.talep.hizmet,
                              style: refText(
                                  size: RF.s13,
                                  weight: RF.w400,
                                  color: RC.textSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (done != null) ...[
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: RC.white,
                    border: Border.all(color: RC.border),
                    borderRadius: BorderRadius.circular(RR.r15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: RefSvg(
                                  i <= done.stars
                                      ? 'assets/svg/ic_starfill.svg'
                                      : 'assets/svg/ic_starempty.svg',
                                  size: 20,
                                  color: const Color(0xFFF5A319)),
                            ),
                          const SizedBox(width: 6),
                          Text('${done.stars}.0',
                              style: refText(
                                  size: RF.s15,
                                  weight: RF.w700,
                                  color: RC.text)),
                          const Spacer(),
                          Text(_tarih(done.createdAt),
                              style: refText(
                                  size: RF.s12,
                                  weight: RF.w400,
                                  color: RC.greyLight)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        done.text.trim().isEmpty
                            ? 'Yorum eklenmedi.'
                            : done.text,
                        style: refText(
                          size: RF.s135,
                          weight: RF.w400,
                          color: done.text.trim().isEmpty
                              ? RC.greyLight
                              : const Color(0xFF3A4658),
                          height: RF.lh155,
                        ).copyWith(
                            fontStyle: done.text.trim().isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal),
                      ),
                      // ⚠ YEŞİL BİLGİ ŞERİDİ KALDIRILDI (kullanıcı
                      // isteği, 9 Eyl): "Değerlendirmeniz yayınlandı.
                      // Değiştirilemez ve silinemez."
                      //
                      // ⚠ KURAL DEĞİŞMEDİ, YALNIZ CÜMLE GİTTİ: yorum
                      // hâlâ tek sefer yazılır ve düzeltilemez —
                      // kayıt varken bu ekran form dalını HİÇ
                      // çizmez, yalnız salt okunur kartı gösterir.
                      // Kuralın kilidi cümlede değil, o dalda.
                    ],
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(1, 20, 1, 4),
                  child: Text('Puanınız',
                      style: refText(
                          size: 16.5, weight: RF.w700, color: RC.text)),
                ),
                Text('Hizmet kalitesini puanlayın',
                    style: refText(
                        size: RF.s13, weight: RF.w400, color: RC.textDark)),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++) ...[
                        if (i > 1) const SizedBox(width: 10),
                        RefTap(
                          onTap: () => setState(() => _stars = i),
                          borderRadius: BorderRadius.circular(RR.circle),
                          child: RefSvg(
                              i <= _stars
                                  ? 'assets/svg/ic_starfill.svg'
                                  : 'assets/svg/ic_starempty.svg',
                              size: 42,
                              color: const Color(0xFFF5A319)),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '1 yıldız çok kötü, 5 yıldız mükemmel',
                    textAlign: TextAlign.center,
                    style: refText(
                        size: RF.s125, weight: RF.w400, color: RC.grey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(1, 20, 1, 4),
                  child: Row(
                    children: [
                      Text('Yorumunuz',
                          style: refText(
                              size: 16.5, weight: RF.w700, color: RC.text)),
                      const SizedBox(width: 6),
                      Text('(İsteğe Bağlı)',
                          style: refText(
                              size: RF.s13,
                              weight: RF.w500,
                              color: RC.textSoft)),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    RefTextField(
                      controller: _text,
                      maxLines: 6,
                      maxLength: DomainConfig.kYorumMaxKarakter,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              required maxLength}) =>
                          null,
                      onChanged: (_) => setState(() {}),
                      hint: 'Deneyiminizi paylaşabilirsiniz...',
                    ),
                    Positioned(
                      right: 13,
                      bottom: 10,
                      child: Text(
                          '${_text.text.characters.length}/'
                          '${DomainConfig.kYorumMaxKarakter}',
                          style: refText(
                              size: RF.s12,
                              weight: RF.w400,
                              color: RC.grey)),
                    ),
                  ],
                ),
                RefInfoBox(
                  mavi: true,
                  child: Text(
                    'Verdiğiniz puan ve yorum, hizmet veren profilinde '
                    'yayınlanacaktır.',
                    style: refText(
                      size: RF.s135,
                      weight: RF.w400,
                      color: RC.textDark,
                      height: RF.lh150,
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: refText(
                          size: RF.s135, weight: RF.w600, color: RC.danger),
                    ),
                  ),
                const SizedBox(height: 14),
                RefWideButton(
                  'Değerlendirmeyi Gönder',
                  busy: _busy,
                  onPressed: _stars < 1 ? null : _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
