import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/eposta_acma.dart';
import '../data/models/support_info.dart';
import '../data/remote/api/legal_api.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import 'ref_tokens.dart';
import 'ref_widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// DESTEK MERKEZİ PANELİ — TEK KAYNAK (15 Eki, kullanıcı kararı)
///
/// "Android'deki gibi görünmeli ve tepki vermeli, farklı bir şey
/// olmamalı": mobil profil ekranı ve web kenar çubuğu AYNI paneli açar.
/// İçerik: ikon, "Size nasıl yardımcı olabiliriz?", açıklama ve e-posta
/// kutusu. Başlık/açıklama yazılan talep formu panelde YOKTUR. E-postaya
/// dokununca e-posta uygulaması doğrudan açılır (`epostaUygulamasiniAc`).
///
/// Açıklama ve e-posta HARD-CODE DEĞİLDİR: `SupportInfo` (admin paneli →
/// Destek Bilgisi). Mock modda ya da hata durumunda `SupportInfo.fallback`
/// (panel ASLA boş kalmaz).
/// ═══════════════════════════════════════════════════════════════
Future<void> destekMerkeziPaneliniAc(BuildContext c) async {
  final bilgi = await _destekBilgisi(c);
  if (!c.mounted) {
    return;
  }
  await RefBottomSheet.goster<void>(
    c,
    title: 'Destek Merkezi',
    child: RefSheetBody(
      ikon: 'assets/svg/ic_phead.svg',
      ikonZemin: const Color(0xFFF3E9FD),
      baslik: 'Size nasıl yardımcı olabiliriz?',
      aciklama: bilgi.description,
      altKisim: RefTap(
        onTap: () => epostaUygulamasiniAc(c, bilgi.email),
        borderRadius: BorderRadius.circular(RR.r12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E9FD),
            borderRadius: BorderRadius.circular(RR.r12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const RefSvg('assets/svg/ic_mail.svg',
                  size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  bilgi.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: refText(
                      size: RF.s145,
                      weight: RF.w700,
                      color: const Color(0xFF7C3AED)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<SupportInfo> _destekBilgisi(BuildContext c) async {
  if (!ApiConfig.useRealApi) {
    return SupportInfo.fallback;
  }
  try {
    final j = await LegalApi(c.read<ApiClient>()).one('support');
    return SupportInfo.fromJson(j);
  } catch (_) {
    return SupportInfo.fallback;
  }
}
