// BAKIM EKRANI — TEK BİLEŞEN (22 Eki, kullanıcı kararı)
//
// Bakım modunda uygulamanın bütün ekranlarını örten görünüm: HizmetCep
// logosu, dönen dişli animasyonu, "Bakımdayız" yazısı, admin'in yazdığı
// mesaj ve (girildiyse) tahmini bitiş. Açılıştaki engel ekranı da
// (`BootBlockedScreen`) aynı bileşeni kullanır.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/bakim_durumu.dart';
import 'ref_tokens.dart';

const String kVarsayilanBakimMesaji =
    'HizmetCep kısa süreli bakımda. Lütfen daha sonra tekrar deneyin.';

/// ISO zamanı yerel "gg.aa.yyyy ss:dd" biçimine çevirir; çözülemezse null.
String? bakimBitisMetni(String? iso) {
  if (iso == null) {
    return null;
  }
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) {
    return null;
  }
  String iki(int n) => n.toString().padLeft(2, '0');
  return '${iki(t.day)}.${iki(t.month)}.${t.year} ${iki(t.hour)}:${iki(t.minute)}';
}

class BakimEkrani extends StatefulWidget {
  const BakimEkrani({
    super.key,
    this.mesaj,
    this.bitis,
    required this.onYenile,
  });

  final String? mesaj;
  final String? bitis;
  final VoidCallback onYenile;

  @override
  State<BakimEkrani> createState() => _BakimEkraniState();
}

class _BakimEkraniState extends State<BakimEkrani>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mesaj = (widget.mesaj?.trim().isNotEmpty ?? false)
        ? widget.mesaj!.trim()
        : kVarsayilanBakimMesaji;
    final bitis = bakimBitisMetni(widget.bitis);
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: AnimatedBuilder(
                      animation: _a,
                      builder: (context, _) {
                        // Logonun arkasında yavaş dönen dişli ve hafif nabız.
                        final nabiz =
                            1 + 0.04 * math.sin(_a.value * 2 * math.pi * 3);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: _a.value * 2 * math.pi,
                              child: Icon(Icons.settings,
                                  size: 168,
                                  color: RC.blue.withValues(alpha: 0.10)),
                            ),
                            Transform.scale(
                              scale: nabiz,
                              child: Image.asset('assets/logo/logo_mark.png',
                                  width: 76, height: 76),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Image.asset('assets/logo/wordmark.png', height: 30),
                  const SizedBox(height: 26),
                  const Text(
                    'Bakımdayız',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: RC.text),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    mesaj,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, height: 1.45, color: RC.textSoft),
                  ),
                  if (bitis != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Tahmini bitiş: $bitis',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: RC.text),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: widget.onYenile,
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uygulamanın en dışında: bakım açıksa bütün ekranları örter.
class BakimKapisi extends StatelessWidget {
  const BakimKapisi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = BakimDurumu.i;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          child,
          // Alttaki ekranlara dokunuş geçmez.
          if (d.aktif)
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Colors.white),
            ),
          if (d.aktif)
            Positioned.fill(
              child: BakimEkrani(
                mesaj: d.mesaj,
                bitis: d.bitis,
                onYenile: () => unawaited(d.kontrolEt()),
              ),
            ),
        ],
      ),
    );
  }
}
