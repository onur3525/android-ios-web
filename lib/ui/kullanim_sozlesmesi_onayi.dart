import 'package:flutter/material.dart';

import 'ref_tokens.dart';
import 'ref_widgets.dart';

/// KAYIT — KULLANIM SÖZLEŞMESİ ONAYI (TEK KAYNAK, 16 Eki)
///
/// Kullanıcının eklettiği "HizmetCep Kullanım Sözleşmesi" (Bölüm B/3):
/// kayıtta sözleşme bağlantısı ve AYRI "Kullanım Sözleşmesi'ni okudum ve
/// kabul ediyorum" kabulü bulunur; kabul edilmeden kayıt tamamlanmaz.
/// 18 yaş koşulu sözleşmenin 4. maddesindedir — ayrı yaş kutusu YOKTUR
/// (Bölüm B/2). Gizlilik Politikası sözleşme kabulünün yerine konmaz ve
/// onunla aynı kabul sayılmaz (Bölüm B/4, madde 21); bağlantısı kabul
/// satırının altında ayrıca durur.
///
/// ⚠ İKİ KAYIT EKRANI (Kayıt Ol ve İlan Ver içindeki kayıt adımı) bu
/// bileşeni kullanır; metin ve bağlantılar tek yerden gelir.
class KullanimSozlesmesiOnayi extends StatelessWidget {
  const KullanimSozlesmesiOnayi({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Zorunlu alanlar tamamlanmadan işaretlenemez (`RefAgreeRow` kuralı).
  final bool enabled;

  static const String kBaslik = 'Kullanım Sözleşmesi';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RefAgreeRow(
            enabled: enabled,
            value: value,
            onChanged: onChanged,
            parts: [
              (
                text: kBaslik,
                onTap: () => Navigator.pushNamed(context, '/legal',
                    arguments: {'slug': 'terms', 'title': kBaslik}),
              ),
              (text: "'ni okudum ve kabul ediyorum.", onTap: null),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(35, 0, 2, 12),
            child: RefTap(
              onTap: () => Navigator.pushNamed(context, '/legal',
                  arguments: {'slug': 'privacy', 'title': 'Gizlilik Politikası'}),
              borderRadius: BorderRadius.circular(RR.r6),
              child: Text('Gizlilik Politikası',
                  style: refText(
                      size: RF.s135, weight: RF.w600, color: RC.blue)),
            ),
          ),
        ],
      );
}
