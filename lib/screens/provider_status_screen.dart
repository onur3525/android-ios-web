import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/controllers/profile_controller.dart';
import '../data/models/provider_approval.dart';
import 'widgets/hc_widgets.dart';
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';

/// HİZMET VEREN — HESAP ONAY DURUMU
///
/// Onay bildirimi tıklandığında ve profil menüsünden açılır.
/// Kullanıcı teklif veremiyorsa nedenini ve ne yapması gerektiğini
/// burada görür.
class ProviderStatusScreen extends StatefulWidget {
  const ProviderStatusScreen({super.key});
  @override
  State<ProviderStatusScreen> createState() => _ProviderStatusScreenState();
}

class _ProviderStatusScreenState extends State<ProviderStatusScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await context.read<ProfileController>().loadApproval();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ProfileController>().approval;

    return Scaffold(
      backgroundColor: RC.pageBg,
      // AppBar KALDIRILDI — referansta yok (başlık sayfa içinde).
      body: SafeArea(
        child: _loading && s == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                  children: [
                    // ⚠ GERİ OKU HER PLATFORMDA VARDIR (nihai karar).
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: RefBackButton(),
                    ),
                    const SizedBox(height: 6),
                    ProviderStatusCard(state: s ?? ProviderApprovalState.unknown),
                    const SizedBox(height: 16),
                    const InfoBox(
                      child: Text(
                        'Hesabınız onaylandıktan sonra ilanlara teklif '
                        'verebilirsiniz. Onay süreci kimlik doğrulaması '
                        'içermez; platform kullanım uygunluğu değerlendirilir.',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Onay durumu kartı — hem durum ekranında hem teklif ekranında kullanılır.
class ProviderStatusCard extends StatelessWidget {
  final ProviderApprovalState state;
  const ProviderStatusCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (state.status) {
      ProviderApproval.pending => (
          const Color(0xFFF5820C), const Color(0xFFFFF6E5), 'assets/svg/ic_nclock.svg'),
      // ⚠ `ic_x.svg` DEĞİL: o ikon dolgulu daire içinde beyaz çarpıdır
      // ve burada tek renge boyanıyor — çarpı kaybolur, düz bir daire
      // kalırdı. `ic_close.svg` dolgusuzdur.
      ProviderApproval.rejected => (
          RC.danger, const Color(0xFFFDECEC), 'assets/svg/ic_close.svg'),
      ProviderApproval.suspended => (
          RC.danger, const Color(0xFFFDECEC), 'assets/svg/ic_nclock.svg'),
      ProviderApproval.approved => (
          RC.success, const Color(0xFFE9F9EF), 'assets/svg/ic_checkcircle.svg'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RefSvg(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(state.status.label,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          state.message.isNotEmpty
              ? state.message
              : 'Teklif verebilmek için hesabınızın onaylanması gerekir.',
          style: refText(size: RF.s135, weight: RF.w400, color: RC.text, height: 1.55),
        ),
        if (state.reason != null && state.reason!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('Gerekçe: ${state.reason}',
                style: refText(size: RF.s125, weight: RF.w400, color: RC.textSoft)),
          ),
        ],
        // REDDEDİLDİ → yeniden başvuru yönlendirmesi.
        if (state.status == ProviderApproval.rejected) ...[
          const SizedBox(height: 12),
          RefSecondaryButton(
            'Bilgilerimi güncelle ve yeniden başvur',
            iconAsset: 'assets/svg/ic_pen.svg',
            onPressed: () =>
                Navigator.pushNamed(context, '/provider/categories'),
          ),
        ],
      ]),
    );
  }
}
