import '../api_client.dart';

/// Hesap durumu (dondurma / silme talebi) ve uygulama değerlendirmesi.
class AccountApi {
  final ApiClient c;
  AccountApi(this.c);

  // ── Hesap ──
  Future<Map<String, dynamic>> freeze({String? reason}) =>
      c.post('/profiles/me/freeze',
          body: {if (reason != null && reason.isNotEmpty) 'reason': reason});

  Future<Map<String, dynamic>> requestDeletion({String? reason}) =>
      c.post('/profiles/me/deletion-request',
          body: {if (reason != null && reason.isNotEmpty) 'reason': reason});

  Future<Map<String, dynamic>> cancelDeletion() =>
      c.delete('/profiles/me/deletion-request');

  Future<List<dynamic>> myRequests() =>
      c.getList('/profiles/me/account-requests');

  // ── Uygulama değerlendirmesi ──
  Future<Map<String, dynamic>?> myFeedback() =>
      c.getOrNull('/profiles/me/app-feedback');

  Future<Map<String, dynamic>> submitFeedback({
    required int stars,
    String? comment,
    required String platform,
    required String appVersion,
  }) =>
      c.post('/profiles/me/app-feedback', body: {
        'stars': stars,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        'platform': platform,
        'appVersion': appVersion,
      });
}
