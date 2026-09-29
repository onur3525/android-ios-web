import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/baglanti_modu.dart';
import '../core/sys_state.dart';
import '../data/models/support_info.dart';
import '../data/remote/api/legal_api.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import 'ref_tokens.dart';
import 'ref_widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// WEB — DESTEK MERKEZİ PANELİ (kenar çubuğu)
///
/// Kenar çubuğundaki "Destek Merkezi" eskiden `/profile` sayfasına
/// gidiyordu: panel `profile_screen.dart` içinde private olduğu için
/// dışarıdan açılamıyordu ve kullanıcı alakasız Profil sayfasına
/// düşüyordu. Artık panel, bulunulan sayfanın ÜSTÜNDE doğrudan açılır.
///
/// ⚠ ANDROID KİLİTLİ — BİLİNÇLİ İKİNCİ TANIM: Android profil ekranı
/// kendi `_destekSheet`ini kullanmaya devam eder; o dosyaya dokunulmadı
/// (kullanıcı kararı). İki tanımın AYRIŞMAMASI
/// `test/widget/web_destek_paneli_test.dart` ile kilitli: başlık, ikon,
/// renkler, açıklama kaynağı, e-posta kutusu ve hata metinleri
/// `profile_screen._destekSheet` ile BİREBİR aynı olmak zorunda. Birini
/// değiştiren ötekini de değiştirmeli.
/// ═══════════════════════════════════════════════════════════════
Future<void> webDestekPaneliniAc(BuildContext c) async {
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
        onTap: () => _mailAc(c, bilgi.email),
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

/// Destek içeriği — API modunda sunucudan, aksi hâlde ya da hata
/// durumunda `SupportInfo.fallback` (panel ASLA boş kalmaz).
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

/// `mailto:` ile varsayılan e-posta uygulamasını açar.
Future<void> _mailAc(BuildContext c, String adres) async {
  final uri = Uri(scheme: 'mailto', path: adres);
  try {
    final ok = await launchUrl(uri, mode: acilisModu());
    if (!ok && c.mounted) {
      sysToastErr(c, SysKind.genericError,
          extra: 'E-posta uygulaması bulunamadı: $adres');
    }
  } catch (_) {
    if (c.mounted) {
      sysToastErr(c, SysKind.genericError,
          extra: 'E-posta uygulaması açılamadı: $adres');
    }
  }
}
