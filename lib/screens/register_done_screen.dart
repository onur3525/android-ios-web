import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';

/// Kayıt Adım 3 — Tebrikler (HTML kuralı: BUTONSUZ; kısa bekleme
/// sonrası otomatik olarak girişli ana sayfaya yönlendirilir).
class RegisterDoneScreen extends StatefulWidget {
  const RegisterDoneScreen({super.key});
  @override
  State<RegisterDoneScreen> createState() => _RegisterDoneScreenState();
}

class _RegisterDoneScreenState extends State<RegisterDoneScreen> {
  @override
  void initState() {
    super.initState();
    // Referans `.rg-redir-s`: "2 saniye sonra otomatik geçiş yapılacak."
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _bitir();
      }
    });
  }

  /// Referans `rgFinish()` — role göre ana panele gider.
  ///
  /// `popUntil(isFirst)` yığının kökü neyse oraya döner (deterministik
  /// DEĞİL); hedef açıkça rolün paneli olmalıdır.
  void _bitir() {
    final saglayici =
        context.read<AuthController>().activeRole == Role.provider;
    Navigator.of(context).pushNamedAndRemoveUntil(
      saglayici ? '/provider/jobs' : '/customer/listings',
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final saglayici =
        context.read<AuthController>().activeRole == Role.provider;

    return RefPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Referans: sağlayıcı dalında geri düğmesi VARDIR
          // (`onclick="rgFinish()"`), müşteri dalında YOKTUR.
          if (saglayici) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: RefBackButton(onTap: _bitir),
            ),
            // ⚠ ÇİFT OK OLMASIN: bu ekranın kendi `RefBackButton`'ı var.
            const RefPageTitle('Hizmet Veren Kaydı',
                geriDugmesi: false),
          ],

          // rgStepper(4) — tüm adımlar tamamlanmış
          const RefStepper(current: 4),

          const Center(child: RefDoneIcon()),

          // .rg-done-title{25px/700;margin:0 10px 12px;line-height:1.25}
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Text(
              // HTML: müşteri → "Hesabınız Başarıyla Oluşturuldu!"
              //       sağlayıcı → "Tebrikler!"
              saglayici ? 'Tebrikler!' : 'Hesabınız Başarıyla Oluşturuldu!',
              textAlign: TextAlign.center,
              style: refText(
                size: RF.s25,
                weight: RF.w700,
                color: RC.text,
                height: RF.lh125,
              ),
            ),
          ),

          // .rg-done-sub2 — yalnız sağlayıcı dalında
          if (saglayici)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                'Hizmet sağlayıcı hesabınız başarıyla oluşturuldu.',
                textAlign: TextAlign.center,
                style: refText(
                    size: RF.s16, weight: RF.w700, color: RC.text),
              ),
            ),

          // .rg-done-sub{15px #5B6472;lh1.5;margin:0 16px 18px}
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Text(
              saglayici
                  ? "Artık HizmetCep'te ilanları görüntüleyebilir, "
                      'ilanlara teklif verebilir ve yeni işler '
                      'kazanabilirsiniz.'
                  : 'Artık ücretsiz ilan verebilir ve profesyonellerden '
                      'teklif alabilirsiniz.',
              textAlign: TextAlign.center,
              style: refText(
                size: RF.s15,
                weight: RF.w400,
                color: RC.textSoft,
                height: RF.lh150,
              ),
            ),
          ),

          // .rg-infobox.blue — yalnız sağlayıcı dalında
          if (saglayici)
            RefInfoBox(
              mavi: true,
              margin: EdgeInsets.zero,
              child: RichText(
                text: TextSpan(
                  style: refText(
                    size: RF.s135,
                    weight: RF.w400,
                    color: RC.textDark,
                    height: RF.lh150,
                  ),
                  children: [
                    TextSpan(
                      text: 'Bilgilendirme\n',
                      style: refText(
                        size: RF.s135,
                        weight: RF.w700,
                        color: RC.textDark,
                        height: RF.lh150,
                      ),
                    ),
                    const TextSpan(
                      text: 'Hizmet kategorilerinizi ve hizmet bölgelerinizi '
                          'profilinizden dilediğiniz zaman '
                          'güncelleyebilirsiniz.',
                    ),
                  ],
                ),
              ),
            ),

          const RefRedirectNotice(),
        ],
      ),
    );
  }

}