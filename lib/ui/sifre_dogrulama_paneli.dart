import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import 'ref_tokens.dart';
import 'ref_widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// ŞİFRE İLE KİMLİK DOĞRULAMA PANELİ — TEK KAYNAK (15 Eki)
///
/// Önce yalnız hesap silmede (`account_settings_screen`) vardı. Telefon
/// numarası değiştirme de artık mevcut şifreyi istiyor (çalınmış oturumla
/// numara değiştirip şifre sıfırlayarak hesabı ele geçirme engellenir);
/// iki akış AYNI paneli kullanır, kopya yok.
///
/// Doğrulama kararı sunucunundur (`AuthController.verifyPassword`). Doğru
/// şifre geri döner: kritik işlemin kendisi de onu sunucuya iletir ve
/// sunucu yeniden doğrular (yalnız istemci denetimine güvenilmez). Ekran
/// şifreyi SAKLAMAZ; çağıran işlem bitince bırakır. Vazgeçilirse `null`.
/// ═══════════════════════════════════════════════════════════════
Future<String?> sifreIleDogrula(
  BuildContext context, {
  required String aciklama,
  Color renk = HC.red,
}) async {
  final ctl = TextEditingController();
  final hataNot = ValueNotifier<String?>(null);
  // ⚠ Alan dolu mu? Düğmenin aktifliği buna bağlı.
  final doluNot = ValueNotifier<bool>(false);
  String? dogrulanan;
  try {
    await RefBottomSheet.goster<void>(
      context,
      title: 'Kimliğinizi Doğrulayın',
      child: StatefulBuilder(
        builder: (c, yenile) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              aciklama,
              style: refText(
                  size: RF.s135,
                  weight: RF.w400,
                  color: RC.textDark,
                  height: RF.lh155),
            ),
            const SizedBox(height: 14),
            // ── ⚠ ORTAK FORM STANDARDI ──
            //
            // İki ihlal vardı:
            ValueListenableBuilder<String?>(
              valueListenable: hataNot,
              builder: (_, hata, __) => TextField(
                controller: ctl,
                obscureText: true,
                // ⚠ Şifrede baş harf büyütülmez.
                textCapitalization: TextCapitalization.none,
                autofocus: true,
                onChanged: (_) {
                  if (hataNot.value != null) {
                    hataNot.value = null;
                  }
                  doluNot.value = ctl.text.trim().isNotEmpty;
                },
                decoration: InputDecoration(
                  hintText: 'Şifreniz',
                  errorText: hata,
                  errorMaxLines: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<bool>(
              valueListenable: doluNot,
              builder: (_, dolu, __) => OutlinedButton(
              onPressed: !dolu
                  ? null
                  : () async {
                final err = await c
                    .read<AuthController>()
                    .verifyPassword(ctl.text);
                if (err != null) {
                  hataNot.value = err.message;
                  return;
                }
                dogrulanan = ctl.text;
                if (c.mounted) {
                  Navigator.of(c).pop();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: renk,
                side: BorderSide(color: renk, width: 1.4),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RR.r12),
                ),
              ),
              child: Text('Doğrula',
                  style: refText(
                      size: RF.s14, weight: RF.w700, color: renk)),
            )),
          ],
        ),
      ),
    );
  } finally {
    // ⚠ NOTIFIER'LAR BİR SONRAKİ KAREDE BIRAKILIR.
    //
    // Panel kapanma animasyonu sürerken `ValueListenableBuilder`
    // öğeleri hâlâ ağaçta ve bu notifier'ları dinliyor olabilir.
    // Hemen `dispose` çağrılınca dinleyicisi olan bir nesne
    // kapatılıyor ve ağaç yıkımı sırasında çerçeve doğrulaması
    // patlıyordu (`_dependents.isEmpty`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctl.dispose();
      hataNot.dispose();
      doluNot.dispose();
    });
  }
  return dogrulanan;
}
