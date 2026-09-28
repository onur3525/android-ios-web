import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'sertifika_sabitleme.dart';

// ⚠ MOBİL — ANDROID VE iOS. Bu dosya web derlemesine GİRMEZ.

/// Sabitlemeli istemci; pin yoksa düz istemci.
///
/// ⚠ DAVRANIŞ DEĞİŞMEDİ: `api_client.dart` içindeki satırın birebir
/// aynısı, yalnız buraya taşındı.
http.Client sabitlemeliIstemci() => SertifikaSabitleme.etkin
    ? IOClient(SertifikaSabitleme.istemci())
    : http.Client();

/// Release + gerçek API modunda pin zorunluluğunu denetler.
///
/// ⚠ SADECE DEVREDER: kural `SertifikaSabitleme.pinDenetimi` içinde;
/// burada ikinci bir kopya yok.
void pinDenetimi({required bool gercekApi}) =>
    SertifikaSabitleme.pinDenetimi(gercekApi: gercekApi);
