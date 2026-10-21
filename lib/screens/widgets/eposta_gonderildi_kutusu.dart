import 'package:flutter/material.dart';

import '../../ui/ref_tokens.dart';

/// ── ⚠ "DOĞRULAMA E-POSTASI GÖNDERİLDİ" KUTUSU (21 Eki, kullanıcı isteği) ──
///
/// Kullanıcının verdiği görselle birebir: açık yeşil zemin, yeşil çerçeve,
/// solda yeşil daire içinde beyaz zarf, kalın yeşil başlık ve iki satır
/// açıklama. Başarı uyarıları (`sysToastOk`) çizilmediği için gönderimin
/// tek görünür sonucu budur; e-posta alanının altında kalıcı durur.
class EpostaGonderildiKutusu extends StatelessWidget {
  const EpostaGonderildiKutusu({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RC.successSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RC.success.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: RC.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_outlined,
                  size: 24, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Doğrulama e-postası gönderildi.',
                      style: refText(
                          size: RF.s15, weight: RF.w800, color: RC.success)),
                  const SizedBox(height: 4),
                  Text(
                      'E-posta kutunuzu kontrol edin.\n'
                      'Bulamazsanız spam klasörüne bakın.',
                      style: refText(
                          size: RF.s13, weight: RF.w400, color: RC.text)),
                ],
              ),
            ),
          ],
        ),
      );
}
