import 'package:flutter/widgets.dart';

import 'destek_merkezi_paneli.dart';

/// ═══════════════════════════════════════════════════════════════
/// WEB — DESTEK MERKEZİ (kenar çubuğu)
///
/// Kenar çubuğundaki "Destek Merkezi" bulunulan sayfanın ÜSTÜNDE paneli
/// açar (eskiden alakasız Profil sayfasına gidiyordu). Panel mobil profil
/// ekranıyla AYNI tek kaynaktır (`destek_merkezi_paneli.dart`, 15 Eki):
/// önceki ikinci tanım ve parite kilidi kaldırıldı.
/// ═══════════════════════════════════════════════════════════════
Future<void> webDestekPaneliniAc(BuildContext c) => destekMerkeziPaneliniAc(c);
