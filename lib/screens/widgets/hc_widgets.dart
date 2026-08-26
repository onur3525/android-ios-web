import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Kayıt adım göstergesi — HTML stepper birebir:
/// 1 Bilgileriniz · 2 Doğrulama · 3 Tamamla
class StepIndicator extends StatelessWidget {
  final int current; // 1..3
  const StepIndicator(this.current, {super.key});

  @override
  Widget build(BuildContext context) {
    const labels = ['Bilgileriniz', 'Doğrulama', 'Tamamla'];
    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          Expanded(
            child: Column(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? HC.blue : const Color(0xFFEDF0F4),
                ),
                child: Center(
                  child: i < current
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                      : Text(i.toString(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: i <= current ? Colors.white : HC.lightGrey)),
                ),
              ),
              const SizedBox(height: 6),
              Text(labels[i - 1],
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: i <= current ? HC.blue : HC.lightGrey)),
            ]),
          ),
          if (i < 3)
            Expanded(
              child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 22),
                  color: i < current ? HC.blue : const Color(0xFFEDF0F4)),
            ),
        ],
      ],
    );
  }
}

/// Mavi bilgi kutusu (HTML rg-infobox blue).
class InfoBox extends StatelessWidget {
  final Widget child;
  const InfoBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HC.softBlue, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: HC.blue),
          const SizedBox(width: 8),
          Expanded(
              child: DefaultTextStyle(
                  style: const TextStyle(
                      fontSize: 12.5, color: HC.dark, fontFamily: 'Poppins'),
                  child: child)),
        ]),
      );
}

/// 6 haneli OTP giriş kutuları (HTML rg-otp birebir davranış:
/// yazınca ileri, silince geri, son hanede otomatik doğrulama tetiği).
class OtpBoxes extends StatefulWidget {
  final void Function(String code) onCompleted;
  final ValueChanged<String>? onChanged;
  const OtpBoxes({super.key, required this.onCompleted, this.onChanged});
  @override
  State<OtpBoxes> createState() => OtpBoxesState();
}

class OtpBoxesState extends State<OtpBoxes> {
  final _c = List.generate(6, (_) => TextEditingController());
  final _f = List.generate(6, (_) => FocusNode());

  String get code => _c.map((e) => e.text).join();
  void clear() {
    for (final c in _c) {
      c.clear();
    }
    _f.first.requestFocus();
  }

  @override
  void dispose() {
    for (final c in _c) { c.dispose(); }
    for (final f in _f) { f.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (i) => Container(
              width: 46,
              margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
              child: TextField(
                controller: _c[i],
                focusNode: _f[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: HC.dark),
                decoration: const InputDecoration(counterText: ''),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) {
                    _f[i + 1].requestFocus();
                  }
                  if (v.isEmpty && i > 0) {
                    _f[i - 1].requestFocus();
                  }
                  widget.onChanged?.call(code);
                  if (code.length == 6) {
                    widget.onCompleted(code);
                  }
                },
              ),
            )),
      );
}

/// Ana sayfa rol kartı — HTML .rc kartlarıyla aynı içerik istifi.
class RoleCard extends StatelessWidget {
  final bool provider; // false: müşteri (mavi), true: hizmet veren (turuncu)
  final VoidCallback onTap;
  const RoleCard({super.key, required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = provider ? HC.orange : HC.blue;
    return Material(
      color: accent.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: .25))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(11)),
              child: Icon(provider ? Icons.engineering_rounded : Icons.home_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(provider ? 'Hizmet\nVermek İstiyorum' : 'Hizmet\nAlmak İstiyorum',
                style: const TextStyle(
                    fontSize: 19, height: 1.2,
                    fontWeight: FontWeight.w800, color: HC.dark)),
            const SizedBox(height: 6),
            Text(
                provider
                    ? 'Hesap oluşturun, iş ilanlarını görüntüleyin ve yeni müşteriler kazanın.'
                    : 'Ücretsiz hesap oluşturun, ilanınızı yayınlayın ve teklif alın.',
                style: const TextStyle(fontSize: 13, height: 1.5, color: HC.grey)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.person_outline_rounded, size: 17, color: accent),
              const SizedBox(width: 6),
              Text(
                  provider
                      ? 'Hizmet Sağlayıcı Olarak Başla'
                      : 'Müşteri Olarak Başla',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: HC.dark)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, size: 20, color: HC.dark),
            ]),
            const SizedBox(height: 8),
            Text(
                provider
                    ? 'Hızlı kayıt  •  Yeni işler  •  Kazanç'
                    : 'Ücretsiz kayıt  •  Ücretsiz ilan',
                style: const TextStyle(fontSize: 11.5, color: HC.lightGrey)),
          ]),
        ),
      ),
    );
  }
}

/// İlan/teklif durum rozeti (HTML stChip karşılığı).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

/// Onay diyaloğu (silme/iptal gibi geri alınamaz işlemler).
Future<bool> hcConfirm(BuildContext context,
    {required String title, required String desc, String yes = 'Evet'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: HC.dark)),
      content: Text(desc,
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: HC.grey)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç')),
        TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(yes,
                style: const TextStyle(
                    color: HC.red, fontWeight: FontWeight.w700))),
      ],
    ),
  );
  return r ?? false;
}
