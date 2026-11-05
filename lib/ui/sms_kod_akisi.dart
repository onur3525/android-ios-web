import 'dart:async';

import 'package:flutter/material.dart';

import '../data/controllers/auth_controller.dart';
import '../domain/form_mesajlari.dart';
import 'ref_tokens.dart';
import 'ref_widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// TELEFON DOĞRULAMA SMS KODU — TEK KAYNAK (5 Kas, kullanıcı kararı)
///
/// Profilinizi Tamamlayın ve Profil Bilgilerim (numara onayı ve 6 Kas'tan
/// beri onaylı numaranın değişimi) AYNI akışı kullanır: kod gönderme, 60 sn geri sayım, sayaç
/// bitince "Kodu tekrar gönder", 3 denemeden sonra 5 dk bloke ve uyarı.
/// Gönderim kuralı sunucudadır (`smsGonderimIzni`); burada yalnız sunucunun
/// verdiği kalan süre gösterilir.
///
/// · [gonderildiMi] — bu numaraya kod GERÇEKTEN gönderildi (kod girilebilir).
/// · [denendiMi] — bu numara için "gönder"e basıldı (kod gelsin gelmesin,
///   gönderim başarılı olsun olmasın); sayaç bitince tekrar gönderilebilir.
/// Numara değişince ikisi de sıfırlanır ([telefonDegisti]).
/// ═══════════════════════════════════════════════════════════════
/// Kod gönderen işlev — varsayılan `AuthController.profilTelefonKoduGonder`
/// (PHONE_VERIFY); onaylı numaranın değişiminde `telefonDegisimiKodGonder`
/// (PHONE_CHANGE). Sunucu kuralı ikisinde de aynıdır.
typedef SmsGonderici
    = Future<({String? challengeId, String? hata, int? kalanSaniye, bool kilit})>
        Function(String telefon);

class SmsKodAkisi extends ChangeNotifier {
  /// İki kod arasındaki bekleme — sunucu kuralıyla (60 sn) aynı.
  static const int beklemeSaniye = 60;

  String? challengeId;
  String? _gonderilenTelefon;
  int sayac = 0;
  bool kilit = false;

  /// 3 koddan sonraki kilitte gösterilen uyarı (sunucunun metni).
  String? kilitMesaji;
  bool _denendi = false;
  bool gonderiliyor = false;

  /// Gönderim hatası (kod kutusunun altında gösterilir).
  String? hata;
  Timer? _zamanlayici;

  bool gonderildiMi(String telefon) =>
      challengeId != null && _gonderilenTelefon == telefon;

  bool denendiMi(String telefon) => _denendi && _gonderilenTelefon == telefon;

  String get sayacMetni {
    final dk = sayac ~/ 60;
    final sn = (sayac % 60).toString().padLeft(2, '0');
    return dk > 0 ? '$dk:$sn' : '$sayac sn';
  }

  /// Numara değişirse gönderilmiş kod o numaraya ait değildir: sıfırlanır.
  void telefonDegisti(String telefon) {
    if (_gonderilenTelefon == telefon) {
      return;
    }
    challengeId = null;
    _denendi = false;
    hata = null;
    notifyListeners();
  }

  void hatayiTemizle() {
    if (hata != null) {
      hata = null;
      notifyListeners();
    }
  }

  /// Kodu gönderir; kod gerçekten gönderildiyse `true`.
  Future<bool> gonder(AuthController auth, String telefon,
      {SmsGonderici? gonderici}) async {
    if (gonderiliyor || sayac > 0) {
      return false;
    }
    gonderiliyor = true;
    hata = null;
    notifyListeners();
    final r = await (gonderici ?? auth.profilTelefonKoduGonder)(telefon);
    gonderiliyor = false;
    _denendi = true;
    _gonderilenTelefon = telefon;
    kilitMesaji = r.kilit ? r.hata : null;
    if (r.challengeId == null) {
      challengeId = null;
      if (r.kalanSaniye != null) {
        // Bekleme ya da 5 dk kilit: kalan süre geri sayımla gösterilir.
        _sayaciBaslat(r.kalanSaniye!, kilit: r.kilit);
      } else {
        hata = r.hata ?? FormMesaj.otpGonderilemedi;
        notifyListeners();
      }
      return false;
    }
    challengeId = r.challengeId;
    _sayaciBaslat(beklemeSaniye, kilit: false);
    return true;
  }

  /// Doğrulama tamamlandı: geri sayım durur.
  void durdur() {
    _zamanlayici?.cancel();
    sayac = 0;
    kilit = false;
  }

  void _sayaciBaslat(int saniye, {required bool kilit}) {
    _zamanlayici?.cancel();
    sayac = saniye;
    this.kilit = kilit;
    notifyListeners();
    _zamanlayici = Timer.periodic(const Duration(seconds: 1), (t) {
      sayac--;
      if (sayac <= 0) {
        sayac = 0;
        this.kilit = false;
        t.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }
}

/// Kod kutusunun altı — geri sayım, "Kodu tekrar gönder" ya da 5 dk kilit.
class SmsKodAltSatiri extends StatelessWidget {
  const SmsKodAltSatiri({
    super.key,
    required this.akis,
    required this.telefon,
    required this.onTekrar,
    this.kapali = false,
  });

  final SmsKodAkisi akis;

  /// Kutudaki numara (`Validators.phoneFmt` biçiminde).
  final String telefon;
  final VoidCallback onTekrar;

  /// İşlem sürerken tekrar gönderme pasif.
  final bool kapali;

  @override
  Widget build(BuildContext context) {
    final kucuk = refText(size: RF.s125, weight: RF.w500, color: RC.textSoft);
    if (akis.kilit && akis.sayac > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(akis.kilitMesaji ?? 'Çok fazla kod istendi.',
                style: refText(size: RF.s125, weight: RF.w600, color: RC.danger)),
            const SizedBox(height: 2),
            Text('Kalan süre: ${akis.sayacMetni}', style: kucuk),
          ],
        ),
      );
    }
    if (akis.sayac > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 2),
        child: Text('Yeni kodu ${akis.sayacMetni} sonra isteyebilirsiniz',
            style: kucuk),
      );
    }
    if (!akis.gonderildiMi(telefon) && !akis.denendiMi(telefon)) {
      return const SizedBox(height: 6);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: RefTekrarGonder(
        metin: 'Kodu tekrar gönder',
        onTap: kapali || akis.gonderiliyor ? null : onTekrar,
      ),
    );
  }
}
