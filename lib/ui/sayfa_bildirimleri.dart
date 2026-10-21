import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/controllers/notification_controller.dart';

/// ── SAYFA GÖRÜLDÜ → BİLDİRİMLER OKUNDU (21 Eki) ──
///
/// Kullanıcı bildirime dokunmadan ilgili sayfayı başka yoldan açtığında
/// (ör. İlanlarım → ilan → teklifler) bildirim okunmamış kalıyordu. Sayfa
/// açılınca bu çağrılır; hangi sayfanın hangi bildirim türlerini okuduğu
/// SUNUCUDA tek yerde tanımlıdır (backend `SAYFA_BILDIRIMLERI`). Buradaki
/// adlar o tablonun anahtarlarıdır.
abstract final class BildirimSayfasi {
  /// Hizmet alanın ilan sayfası (kimlik: ilan).
  static const ilan = 'ilan';

  /// Hizmet verenin iş sayfası (kimlik: ilan).
  static const isEkrani = 'is';

  /// İlan sohbeti (kimlik: teklif).
  static const sohbet = 'sohbet';

  /// Doğrudan teklif talebi detayı (kimlik: talep).
  static const talep = 'talep';

  /// Teklif talebi sohbeti (kimlik: talep).
  static const talepSohbet = 'talep-sohbet';
}

/// İlk kareden sonra, sessizce: hata kullanıcıya gösterilmez (bildirim
/// okunmamış kalır, bir sonraki açılışta yeniden denenir).
void sayfaBildirimleriniOku(State state, String sayfa, String refId) {
  final id = refId.trim();
  if (id.isEmpty) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted) {
      return;
    }
    final n = state.context.read<NotificationController?>();
    if (n != null) {
      unawaited(n.sayfaGoruldu(sayfa, id));
    }
  });
}
