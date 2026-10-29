import '../api_client.dart';

/// Şikâyet konusu (sunucu: `backend/src/routes/sikayet.js`).
enum SikayetHedefi {
  ilan('LISTING'),
  kullanici('USER'),
  yorum('REVIEW');

  const SikayetHedefi(this.api);
  final String api;
}

/// Şikâyet nedeni — ekrandaki metin ve sunucu kodu TEK yerde.
enum SikayetNedeni {
  dolandiricilik('FRAUD', 'Dolandırıcılık'),
  hakaret('INSULT', 'Hakaret'),
  yaniltici('MISLEADING', 'Yanıltıcı Bilgi'),
  diger('OTHER', 'Diğer');

  const SikayetNedeni(this.api, this.etiket);
  final String api;
  final String etiket;
}

/// Şikâyet Et (29 Eki) — OTURUM GEREKİR.
///
/// Aynı içerik için açık şikâyet varsa sunucu ikinci kayıt AÇMAZ, ilkini
/// döndürür (`duplicate: true`); kullanıcıya yine "alındı" gösterilir.
class SikayetApi {
  final ApiClient c;
  SikayetApi(this.c);

  Future<Map<String, dynamic>> gonder({
    required SikayetHedefi hedef,
    required String hedefId,
    required SikayetNedeni neden,
    String? aciklama,
  }) =>
      c.post('/reports', body: {
        'targetType': hedef.api,
        'targetId': hedefId,
        'reason': neden.api,
        if (aciklama != null && aciklama.trim().isNotEmpty)
          'note': aciklama.trim(),
      });
}
