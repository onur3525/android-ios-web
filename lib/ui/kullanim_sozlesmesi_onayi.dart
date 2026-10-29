import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'ref_tokens.dart';
import 'ref_widgets.dart';

/// KAYIT — ZORUNLU SÖZLEŞMELER (TEK KAYNAK)
///
/// ⚠ 16 Eki (kullanıcı kararı, örnek görsel): kayıt ekranlarının en
/// altında İKİ AYRI ZORUNLU onay bulunur — metinler görseldeki gibidir:
///   1. "Kullanım Sözleşmesi'ni okudum ve kabul ediyorum. *"
///      HizmetCep'i kullanırken geçerli olan kuralları, hak ve
///      sorumluluklarımı içerir.
///   2. "Gizlilik Politikası ve Aydınlatma Metni'ni okudum; kişisel
///      verilerimin hizmet sunumu amacıyla yurt dışındaki sunucularda
///      işlenmesine yasal haklarım saklı kalmak kaydıyla AÇIK RIZA
///      veriyorum. *"
///      ⚠ 29 Eki (işletmeci kararı, metin birebir): "yurt dışı sunucu"
///      ifadesi ve açık rıza kutuda AÇIKÇA geçer; ülke adları ve hukuki
///      ayrıntı metinlerin içindedir. Sunucu iki belgenin sürümünü +
///      SHA-256'sını + zamanını kaydeder (rızanın ispatı).
/// İkisi de işaretlenmeden kayıt tamamlanmaz. 18 yaş koşulu Kullanım
/// Sözleşmesi'nin 4. maddesindedir — ayrı yaş kutusu YOKTUR.
///
/// ⚠ İKİ KAYIT EKRANI (Kayıt Ol ve İlan Ver içindeki kayıt adımı) bu
/// bileşeni kullanır; metin ve bağlantılar tek yerden gelir.
class KullanimSozlesmesiOnayi extends StatelessWidget {
  const KullanimSozlesmesiOnayi({
    super.key,
    required this.sozlesme,
    required this.aydinlatma,
    required this.onSozlesme,
    required this.onAydinlatma,
    this.enabled = true,
  });

  final bool sozlesme;
  final bool aydinlatma;
  final ValueChanged<bool> onSozlesme;
  final ValueChanged<bool> onAydinlatma;

  /// Zorunlu alanlar tamamlanmadan işaretlenemez (önceki kural aynen).
  final bool enabled;

  static const String kBaslik = 'Kullanım Sözleşmesi';
  static const String kAydinlatma = 'Aydınlatma Metni';
  static const String kGizlilik = 'Gizlilik Politikası';
  static const String kCerez = 'Çerez Politikası';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _OnaySatiri(
            enabled: enabled,
            value: sozlesme,
            onChanged: onSozlesme,
            parcalar: [
              (
                text: kBaslik,
                onTap: () => Navigator.pushNamed(context, '/legal',
                    arguments: {'slug': 'terms', 'title': kBaslik}),
              ),
              (text: '’ni okudum ve kabul ediyorum.', onTap: null),
            ],
            altYazi: 'HizmetCep’i kullanırken geçerli olan kuralları, hak ve '
                'sorumluluklarımı içerir.',
          ),
          _OnaySatiri(
            enabled: enabled,
            value: aydinlatma,
            onChanged: onAydinlatma,
            parcalar: [
              (
                text: kGizlilik,
                onTap: () => Navigator.pushNamed(context, '/legal',
                    arguments: {'slug': 'privacy', 'title': kGizlilik}),
              ),
              (text: ' ve ', onTap: null),
              (
                text: kAydinlatma,
                onTap: () => Navigator.pushNamed(context, '/legal',
                    arguments: {'slug': 'kvkk', 'title': kAydinlatma}),
              ),
              (
                text: '’ni okudum; kişisel verilerimin hizmet sunumu '
                    'amacıyla yurt dışındaki sunucularda işlenmesine yasal '
                    'haklarım saklı kalmak kaydıyla AÇIK RIZA veriyorum.',
                onTap: null,
              ),
            ],
            altYazi: 'Hangi kişisel verilerimin, hangi amaçla ve hangi '
                'hukuki sebeple işlendiğini ve haklarımı anlatır.',
          ),
          // 22 Eki: web'de çerez/tarayıcı deposu bilgilendirmesi (onay
          // istemez; yalnız zorunlu çerezler kullanılır).
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
              child: RefTap(
                key: const ValueKey('cerez-politikasi'),
                onTap: () => Navigator.pushNamed(context, '/legal',
                    arguments: {'slug': 'cookies', 'title': kCerez}),
                child: Text.rich(TextSpan(
                  style: refText(
                      size: RF.s12, weight: RF.w400, color: RC.textSoft),
                  children: [
                    const TextSpan(
                        text: 'Web sitesinde yalnız zorunlu çerezler '
                            'kullanılır. Ayrıntılar: '),
                    TextSpan(
                        text: kCerez,
                        style: refText(
                            size: RF.s12, weight: RF.w600, color: RC.blue)),
                  ],
                )),
              ),
            ),
        ],
      );
}

/// Tek onay satırı: onay kutusu + bağlantılı metin + kırmızı yıldız +
/// gri açıklama. Kutu görünümü `RefAgreeRow` ile aynıdır.
class _OnaySatiri extends StatelessWidget {
  const _OnaySatiri({
    required this.enabled,
    required this.value,
    required this.onChanged,
    required this.parcalar,
    required this.altYazi,
  });

  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;
  final List<({String text, VoidCallback? onTap})> parcalar;
  final String altYazi;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RefTap(
                onTap: enabled ? () => onChanged(!value) : null,
                borderRadius: BorderRadius.circular(RR.r6),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value ? RC.blue : Colors.transparent,
                    border: Border.all(
                        color: value ? RC.blue : const Color(0xFFC7CEDA),
                        width: 2),
                    borderRadius: BorderRadius.circular(RR.r6),
                  ),
                  child: value ? const RefTik() : null,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: refText(
                            size: RF.s135,
                            weight: RF.w400,
                            color: RC.textDark,
                            height: RF.lh145),
                        children: [
                          for (final p in parcalar)
                            TextSpan(
                              text: p.text,
                              style: p.onTap == null
                                  ? null
                                  : refText(
                                          size: RF.s135,
                                          weight: RF.w400,
                                          color: RC.blue,
                                          height: RF.lh145)
                                      .copyWith(
                                          decoration: TextDecoration.underline,
                                          decorationColor: RC.blue),
                              recognizer: (p.onTap == null || !enabled)
                                  ? null
                                  : (TapGestureRecognizer()..onTap = p.onTap),
                            ),
                          TextSpan(
                            text: '  *',
                            style: refText(
                                size: RF.s135,
                                weight: RF.w600,
                                color: RC.danger,
                                height: RF.lh145),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(altYazi,
                        style: refText(
                            size: RF.s125,
                            weight: RF.w400,
                            color: RC.textSoft,
                            height: RF.lh145)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
