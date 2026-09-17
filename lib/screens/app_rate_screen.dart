import 'package:flutter/material.dart';
import '../domain/form_mesajlari.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/boot.dart';
import '../core/sys_state.dart';
import '../data/remote/api/account_api.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import '../data/controllers/auth_controller.dart';
import '../data/store_links.dart';
import '../data/models/account.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'nav_actions.dart';

/// HİZMETCEP'İ PUANLA (HTML vAppRate)
///
/// ÜRÜN KARARI: HTML referansı UYGULAMA İÇİ değerlendirme kullanır
/// (1–5 yıldız + isteğe bağlı yorum, YALNIZCA BİR KEZ gönderilir).
/// Bu ekran mağazaya YÖNLENDİRMEZ; değerlendirme backend'e kaydedilir.
/// Mağaza bağlantısı yalnız zorunlu güncelleme akışında kullanılır
/// (bkz. splash_screen.dart + store_links.dart).
class AppRateScreen extends StatefulWidget {
  const AppRateScreen({super.key});
  @override
  State<AppRateScreen> createState() => _AppRateScreenState();
}

class _AppRateScreenState extends State<AppRateScreen> {
  final _text = TextEditingController();
  int _stars = 0;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  /// Daha önce gönderilmiş değerlendirme (varsa) — tekrar gönderilemez.
  Map<String, dynamic>? _existing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // MOCK MOD: sunucu yok. Ağ çağrısı YAPILMAZ ve kullanıcıya
    // "yüklenemedi" hatası gösterilmez — ekran boş formla açılır.
    if (!ApiConfig.useRealApi) {
      if (!mounted) {
        return;
      }
      setState(() {
        _existing = null;
        _loading = false;
      });
      return;
    }
    try {
      final api = AccountApi(context.read<ApiClient>());
      final j = await api.myFeedback();
      if (!mounted) {
        return;
      }
      setState(() {
        _existing = j;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      // ⚠ Önceki değerlendirme OKUNAMADI diye ekran hata göstermez;
      // kullanıcı yine de puan verebilmelidir. Sessizce boş forma düşer.
      setState(() {
        _existing = null;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_sending) {
      return;
    }
    if (_stars < 1) {
      setState(() => _error = FormMesaj.puanSec);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    // MOCK MOD: gerçek cihazda test edilebilmesi için gönderim yerel
    // olarak simüle edilir; ağ çağrısı YAPILMAZ.
    if (!ApiConfig.useRealApi) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) {
        return;
      }
      setState(() {
        _existing = {
          'stars': _stars,
          'comment': _text.text.trim(),
        };
        _sending = false;
      });
      sysToastOk(context, 'Teşekkürler! Değerlendirmeniz alındı');
      return;
    }
    try {
      final api = AccountApi(context.read<ApiClient>());
      final j = await api.submitFeedback(
        stars: _stars,
        comment: _text.text.trim(),
        platform: currentPlatform(),
        appVersion: ApiConfig.appVersion,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _existing = j;
        _sending = false;
      });
      sysToastOk(context, 'Teşekkürler! Değerlendirmeniz alındı');
    } catch (e) {
      if (!mounted) {
        return;
      }
      // Sunucu "zaten gönderilmiş" derse ekran gönderilmiş moduna geçer.
      setState(() {
        _sending = false;
        _error = 'Değerlendirmeniz gönderilemedi. Lütfen tekrar deneyin.';
      });
      await _load();
    }
  }

  /// Gönderilmiş değerlendirme (sunucudan) — varsa ekran salt okunur.
  int get _gonderilmisPuan => (_existing?['stars'] as num?)?.toInt() ?? 0;
  String get _gonderilmisMetin =>
      (_existing?['comment'] as String?)?.trim() ?? '';
  bool get _gonderildi => _existing != null && _gonderilmisPuan > 0;

  @override
  Widget build(BuildContext context) {
    return RefShell(
      nav: RefBottomNav(
        activeKey: 'profil',
        items: custNavItems(
          context,
          saglayici:
              context.watch<AuthController>().activeRole == Role.provider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RefPageTitle('Uygulama Değerlendirmesi'),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_gonderildi)
            ..._gonderilmisGorunum()
          else
            ..._formGorunum(),
        ],
      ),
    );
  }

  /// `APP_RATED` dalı — değerlendirme zaten gönderilmiş.
  /// GÖNDERİLMİŞ GÖRÜNÜM
  ///
  /// ⚠ ORTALANMIŞ ve SADE. Önceki hâl sola yaslı bir bilgi kutusuydu;
  /// ekranın geri kalanı boş kaldığı için yarım görünüyordu. Artık
  /// onay simgesi, puan ve tek satır mesaj ekranın ortasında durur.
  List<Widget> _gonderilmisGorunum() => [
        const RefSubtitle('Geri bildiriminiz için teşekkür ederiz.'),
        const SizedBox(height: 34),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: RC.successSoft,
                  shape: BoxShape.circle,
                ),
                child: const RefSvg('assets/svg/ic_okgreen.svg', size: 40),
              ),
              const SizedBox(height: 18),
              RefStars(value: _gonderilmisPuan),
              const SizedBox(height: 16),
              Text(
                'Değerlendirmeniz alındı',
                textAlign: TextAlign.center,
                style: refText(size: 18, weight: RF.w800, color: RC.text),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  'Görüşünüz ürün ekibimize iletildi.',
                  textAlign: TextAlign.center,
                  style: refText(
                      size: RF.s135,
                      weight: RF.w400,
                      color: RC.textSoft,
                      height: RF.lh150),
                ),
              ),
              if (_gonderilmisMetin.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    border: Border.all(color: RC.border),
                    borderRadius: BorderRadius.circular(RR.r12),
                  ),
                  child: Text(
                    _gonderilmisMetin,
                    textAlign: TextAlign.center,
                    style: refText(
                        size: RF.s13,
                        weight: RF.w400,
                        color: RC.textSoft,
                        height: RF.lh150),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              const _MagazaKarti(),
            ],
          ),
        ),
      ];

  /// Puanlama formu.
  List<Widget> _formGorunum() => [
        // ⚠ NEREYE GİTTİĞİ AÇIKÇA SÖYLENİR.
        //
        // Bu değerlendirme UYGULAMA İÇİ geri bildirimdir; Google Play
        // veya App Store'da YAYINLANMAZ (bkz. `_MagazaKarti` notu).
        // Kullanıcıya bunun aksini ima eden bir metin yazılmaz.
        const RefSubtitle(
            'Deneyiminizi değerlendirin. Geri bildiriminiz ürün '
            'ekibimize iletilir.'),
        const SizedBox(height: 22), // .rv-stars{margin-top:22px}
        RefStars(
          value: _stars,
          onChanged: _sending ? null : (v) => setState(() => _stars = v),
        ),
        // .rv-hint
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Deneyiminizi puanlayın',
                style: refText(
                    size: RF.s13, weight: RF.w500, color: RC.textSoft),
              ),
              Text(
                '*',
                style: refText(
                    size: RF.s125, weight: RF.w600, color: RC.requiredStar),
              ),
            ],
          ),
        ),
        // .rv-h3{margin:20px 1px 4px}
        Padding(
          padding: const EdgeInsets.fromLTRB(1, 20, 1, 4),
          child: Row(
            children: [
              Text(
                'Görüşünüz ',
                style: refText(size: 16.5, weight: RF.w700, color: RC.text),
              ),
              Text(
                '(İsteğe Bağlı)',
                style: refText(
                    size: RF.s125, weight: RF.w500, color: RC.textMuted),
              ),
            ],
          ),
        ),
        // .rv-tawrap + .rv-cnt
        Stack(
          children: [
            RefTextField(
              controller: _text,
              hint: 'Deneyiminizi paylaşabilirsiniz...',
              maxLines: 5,
            ),
            Positioned(
              right: 13,
              bottom: 10, // .rv-cnt{right:13px;bottom:10px}
              child: Text(
                '${_text.text.length}/500',
                style: refText(
                    size: RF.s12, weight: RF.w400, color: RC.grey),
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: refText(
                  size: RF.s125, weight: RF.w600, color: RC.danger),
            ),
          ),
        RefInfoBox(
          mavi: true,
          margin: const EdgeInsets.only(top: 14),
          child: Text(
            'Verdiğiniz değerlendirme, HizmetCep ekibi tarafından '
            'incelenebilir ve uygulamayı geliştirmemize yardımcı olur.',
            style: refText(
              size: RF.s135,
              weight: RF.w400,
              color: RC.textDark,
              height: RF.lh150,
            ),
          ),
        ),
        const SizedBox(height: 16), // .po-next{margin-top:16px}
        RefNextButton(
          'Değerlendirmeyi Gönder',
          iconAsset: 'assets/svg/ic_star_full.svg',
          busy: _sending,
          onPressed: _submit,
        ),
      ];
}

/// MAĞAZA DEĞERLENDİRMESİ KARTI
///
/// ── ARAŞTIRMA SONUCU (Google Play / App Store kuralları) ──
///
/// 1. Bu ekrandaki yıldızlar UYGULAMA İÇİ geri bildirimdir ve
///    mağazalarda ASLA görünmez. Mağazada görünmesi için Google'ın
///    "In-App Review API"si (veya iOS'ta `SKStoreReviewController`)
///    kullanılmalıdır; bu API kendi kartını çizer, puanı önceden
///    doldurmaya veya sonucu okumaya İZİN VERMEZ.
///
/// 2. ⚠ "REVIEW GATING" YASAKTIR. Kullanıcıya önce "memnun musunuz?"
///    diye sorup yalnız memnun olanları mağazaya yönlendirmek hem
///    Google Play program politikalarına hem Apple inceleme
///    kurallarına AYKIRIDIR ve uygulamanın reddine yol açar.
///
/// Bu yüzden buradaki bağlantı KOŞULSUZDUR: puanı kaç olursa olsun
/// herkese aynı şekilde gösterilir, hiçbir filtre uygulanmaz.
class _MagazaKarti extends StatelessWidget {
  const _MagazaKarti();

  Future<void> _ac(BuildContext c) async {
    final adres = storeUrlForPlatform();
    try {
      final ok = await launchUrl(Uri.parse(adres),
          mode: LaunchMode.externalApplication);
      if (!ok && c.mounted) {
        sysToastErr(c, SysKind.genericError,
            extra: 'Mağaza uygulaması açılamadı');
      }
    } catch (_) {
      if (c.mounted) {
        sysToastErr(c, SysKind.genericError,
            extra: 'Mağaza uygulaması açılamadı');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bu değerlendirme uygulama içinde kalır.',
            textAlign: TextAlign.center,
            style: refText(
                size: RF.s125, weight: RF.w400, color: RC.greyLight),
          ),
          const SizedBox(height: 10),
          RefTap(
            onTap: () => _ac(context),
            borderRadius: BorderRadius.circular(RR.r12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
              decoration: BoxDecoration(
                color: RC.white,
                border: Border.all(color: RC.blue, width: 1.5),
                borderRadius: BorderRadius.circular(RR.r12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RefSvg('assets/svg/ic_starfill.svg',
                      size: 17, color: RC.blue),
                  const SizedBox(width: 9),
                  Text(
                    'Mağazada da değerlendir',
                    style: refText(
                        size: RF.s135, weight: RF.w700, color: RC.blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
