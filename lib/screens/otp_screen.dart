import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/sys_state.dart';
import '../data/remote/api_config.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../core/geri.dart';

/// OTP amacı — sunucu bu değere göre kod üretir ve doğrular.
enum OtpPurpose {
  register('REGISTER'),
  forgot('FORGOT'),
  phoneChange('PHONE_CHANGE'),

  /// TELEFONLA GİRİŞ — hesap modeli kararı.
  ///
  /// ⚠ K2: BU EKRAN KAYIT EKRANI DEĞİLDİR. Kod doğru olsa bile
  /// numara kayıtlı değilse hesap AÇILMAZ; nötr hata gösterilir.
  /// ⚠ K5: kullanıcıya numaranın kayıtlı olup olmadığı söylenmez.
  login('LOGIN'),

  /// HESAP KURTARMA — "e-postama erişemiyorum" yolu.
  ///
  /// ⚠ OTURUM AÇMAZ: kod yalnız telefon sahipliğini doğrular,
  /// ardından kısa ömürlü kurtarma yetkisi üretilir.
  hesapKurtarma('ACCOUNT_RECOVERY');

  final String api;
  const OtpPurpose(this.api);
}

/// Kayıt Adım 2 — SMS doğrulama (HTML OTP ekranı birebir):
/// 6 kutu, maskeli numara, geri sayım, yanlış kodda loading'siz anlık hata.
class OtpScreen extends StatefulWidget {
  final String phone;
  /// Doğrulanan kod çağırana iletilir: API modunda kayıt/şifre sıfırlama/
  /// telefon değişikliği uçları kodu sunucuya gönderir.
  final void Function(BuildContext context, String code) onVerified;

  /// Yeniden gönderme isteği bu amaçla sunucuya gider.
  final OtpPurpose purpose;

  /// ⚠ VERİLİRSE EKRAN KODU KENDİ DOĞRULAMAZ.
  ///
  /// Doğrulamanın authoritative noktası ekran DEĞİLDİR. Bu geri
  /// çağrı verildiğinde ekran yalnız kodu TOPLAR ve sonucu buradan
  /// bekler: `null` başarı, dolu dize kullanıcıya gösterilecek hata.
  ///
  /// ⚠ ZORUNLU. Her akış kendi use-case'ini verir; doğrulamanın
  /// authoritative noktası HİÇBİR ZAMAN bu ekran değildir.
  final Future<String?> Function(String kod) dogrula;

  /// KODU TEKRAR GÖNDER — ⚠ ZORUNLU VE AKIŞA ÖZEL.
  ///
  /// Her amaç KENDİ challenge-start metodunu çağırır (giriş →
  /// `girisTelefonKodGonder`, kayıt → `kayitKodGonder`, telefon
  /// değişikliği → `telefonDegisimiKodGonder`, kurtarma →
  /// `hesapKurtarmaKodGonder`).
  ///
  final Future<String?> Function() yenidenGonder;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.onVerified,
    required this.purpose,
    required this.dogrula,
    required this.yenidenGonder,
  });
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otp = GlobalKey<RefOtpBoxesState>();

  bool _busy = false;

  /// Girilen hane sayısı — düğmenin aktifliği buna bağlı.
  int _kodUzunluk = 0;
  bool _resending = false;
  bool _verifying = false; // çift tetik kilidi (HTML VLOCK)
  String? _error;
  /// KOD GEÇERLİLİK / YENİDEN GÖNDERME SAYACI — 60 saniye.
  ///
  /// ⚠ 119 saniyeydi (yaklaşık 2 dakika). Kullanıcı SMS gelmediğinde
  /// iki dakika bekliyordu; bu sürede ekranı terk etme oranı yüksek.
  /// Uygulamadaki DİĞER SMS ekranlarıyla (kayıtsız ilan akışı) aynı
  /// değere getirildi: 1 dakika.
  ///
  /// ⚠ Süre TEK YERDE tanımlıdır — sayaç ve yeniden gönderme kilidi
  /// aynı değeri kullanır, ikisi birbirinden ayrışamaz.
  static const int kSmsSayaciSaniye = 60;

  /// ⚠ SAYAÇ TİK SAYMAZ, BİTİŞ ANINI TUTAR.
  ///
  /// Önceki uygulama her saniye `_left--` yapıyordu. Ekrandan
  /// çıkıldığında `Timer` iptal ediliyor, geri dönüldüğünde sayaç
  /// baştan başlıyordu: kullanıcı 55 saniye bekledikten sonra ekranı
  /// terk edip dönünce yeniden 60 saniye bekliyordu. Uygulama arka
  /// plana alındığında da aynı sorun oluşuyordu.
  ///
  /// Artık kodun gönderildiği ANDAN itibaren bir BİTİŞ ZAMANI
  /// hesaplanır; kalan süre her seferinde duvar saatinden türetilir.
  /// Ekran değişse, uygulama arka plana alınsa bile süre DOĞRU akar
  /// ve gerçekten dolduğunda "Kodu Tekrar Gönder" açılır.
  DateTime _bitis = DateTime.now()
      .add(const Duration(seconds: kSmsSayaciSaniye));

  int get _left {
    final fark = _bitis.difference(DateTime.now()).inSeconds;
    return fark > 0 ? fark : 0;
  }

  Timer? _timer;

  String get _masked {
    final p = widget.phone;
    if (p.length != 10) {
      return p;
    }
    return '0${p.substring(0, 3)} *** ** ${p.substring(8)}';
  }

  @override
  void initState() {
    super.initState();
    _sayaciBaslat();
  }

  /// ⚠ ZAMANLAYICI TEK YERDEN KURULUR.
  ///
  /// Hem açılışta hem "Tekrar Gönder" sonrasında aynı kurulum
  /// gerekiyor: sıfıra düşünce zamanlayıcı DURUYOR, yeni süre
  /// verildiğinde YENİDEN kurulmazsa sayaç hiç saymaz ve ekran
  /// başlangıç değerinde donar.
  void _sayaciBaslat() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      // ── ⚠ SIFIRA DÜŞEN TETİKLEMEDE DE ÇİZİLİR ──
      //
      // Eski koşul `if (_left > 0)` idi ve sayaç SIFIRA DÜŞTÜĞÜ
      // tetiklemede çizim istemiyordu: ekranda son çizilen değer olan
      // "00:01" ASILI KALIYORDU. Sayaç aslında bitmişti ama
      // "Kod gelmedi mi?", "Numaranızın doğru olduğundan emin olun."
      // ve "Tekrar Gönder" HİÇ GÖRÜNMÜYORDU.
      //
      // ⚠ Dört akışı birden etkiliyordu: kayıt, telefonla giriş,
      // telefon değiştirme, şifre kurtarma. "Tekrar Gönder" hiçbir
      // yerde kullanılamıyordu.
      //
      // ⚠ Sıfırdan sonra zamanlayıcı DURDURULUR: bitmiş sayaç için
      // saniyede bir uyanmanın anlamı yok. `_resend` yeni süre
      // verdiğinde zamanlayıcı yeniden kurulur.
      setState(() {});
      if (_left <= 0) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    if (_verifying || _busy) {
      return;
    }
    _verifying = true;
    setState(() { _busy = true; _error = null; });
    // ── DOĞRULAMA EKRANDA YAPILMAZ ──
    //
    final hata = await widget.dogrula(code);
    if (!mounted) {
      return;
    }
    _verifying = false;
    if (hata != null) {
      setState(() {
        _busy = false;
        _error = hata;
      });
      _otp.currentState?.clear();
      return;
    }
    setState(() => _busy = false);
    widget.onVerified(context, code);
  }

  /// KODU YENİDEN GÖNDER — GERÇEK BACKEND
  ///
  /// Akış: AuthController → AuthPort → repository → API client →
  /// POST /auth/otp/request. Release derlemede mock OTP servisi
  /// HİÇBİR ŞEKİLDE devreye girmez.
  ///
  /// Ele alınan durumlar: geri sayım bitmeden tıklama, çift tetik,
  /// yükleniyor, rate-limit (429), SMS gönderilemedi, internet yok,
  Future<void> _resend() async {
    // Geri sayım bitmeden veya devam eden bir istek varken gönderilmez.
    if (_left > 0 || _resending || _busy) {
      return;
    }

    setState(() {
      _resending = true;
      _error = null;
    });

    // ⚠ AKIŞA ÖZEL YENİDEN GÖNDERİM: yeni challenge üretilir, eski
    // iptal olur (C7). Çağıran yeni challengeId'yi saklar.
    final hata = await widget.yenidenGonder();

    if (!mounted) {
      return;
    }

    if (hata != null) {
      setState(() {
        _resending = false;
        // Geri sayım SIFIRLANMAZ: başarısız denemede kullanıcı hemen
        // tekrar deneyebilmeli.
        _error = hata;
      });
      return;
    }

    setState(() {
      _resending = false;
      // yalnız BAŞARILI gönderimde yeniden başlar
      _bitis =
          DateTime.now().add(const Duration(seconds: kSmsSayaciSaniye));
      _error = null;
    });
    // ⚠ ZAMANLAYICI YENİDEN KURULUR: sıfıra düşünce durdurulmuştu;
    // kurulmazsa yeni süre ekranda 02:00'de DONAR.
    _sayaciBaslat();
    _otp.currentState?.clear();
    if (mounted) {
      sysToastOk(context, 'Doğrulama kodu yeniden gönderildi');
    }
  }

  /// Sunucu hatasını kullanıcıya gösterilecek metne çevirir.
  ///
  /// Ayrı bir exception sınıfı ÜRETİLMEZ: taşıma katmanı (api_client) ağ ve
  /// zaman aşımını `networkError()` / `timeoutError()` ile, sunucu ise
  /// `RATE_LIMITED` dahil tüm hata kodlarını `mapErrorBody()` ile zaten


  // ═════════════════════════════════════════════════════════════
  // GÖRÜNÜM — referans `vRegStep2()`
  //
  //   <button class="rg-back" onclick="rgBack()">IC_BACK</button>
  //   <div class="rg-wrap rg-vwrap">
  //     <h1 class="rg-title">Telefon Doğrulama</h1>
  //     <p class="rg-sub">Telefonunuza gönderilen 6 haneli …</p>
  //     rgStepper(2)
  //     <div class="rg-vicon">IC_VERIFY</div>
  //     <div class="rg-vlabel">Doğrulama kodu gönderilen numara</div>
  //     <div class="rg-vvalue">maskPhone(d.phone)</div>
  //     rgOtp('otp')  ·  rgResendRow('otp')
  //     <button class="rg-primary">Doğrula</button>
  //     <div class="rg-infobox">…</div>
  //   </div>
  //
  // ⚠ Referansta `AppBar` YOKTUR; geri düğmesi sayfa içindedir.
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final saglayici = widget.purpose == OtpPurpose.register;
    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // .rg-back
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: RefBackButton(
                  onTap: () => geriGit(context),
                ),
              ),
            ),
            Expanded(
              child: RefScroll(
                // .rg-wrap{padding:2px 20px 36px}
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // .rg-title
                    Text(
                      'Telefon Doğrulama',
                      style: refText(
                        size: RF.s25,
                        weight: RF.w700,
                        color: RC.text,
                        letterSpacing: RF.lsM03,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // .rg-sub
                    Text(
                      'Telefonunuza gönderilen 6 haneli doğrulama kodunu '
                      'giriniz.',
                      style: refText(
                        size: RF.s145,
                        weight: RF.w400,
                        color: RC.textSoft,
                        height: RF.lh145,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // rgStepper(2)
                    const RefStepper(current: 2),

                    // .rg-vicon + .rg-vlabel + .rg-vvalue
                    RefVerifyHeader(
                      label: 'Doğrulama kodu gönderilen numara',
                      value: _masked,
                    ),

                    // rgOtp('otp')
                    RefOtpBoxes(
                      key: _otp,
                      enabled: !_busy,
                      onCompleted: _verify,
                      // ⚠ Düğme kod TAM olmadan aktif olmasın.
                      onDegisti: (kod) {
                        if (_kodUzunluk != kod.length) {
                          setState(() => _kodUzunluk = kod.length);
                        }
                      },
                    ),

                    // Hata metni — kutuların altında.
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: refText(
                            size: RF.s135,
                            weight: RF.w600,
                            color: RC.danger,
                          ),
                        ),
                      ),

                    // rgResendRow('otp')
                    RefResendRow(
                      saniye: _left,
                      onResend: _resending ? null : _resend,
                    ),

                    // .rg-primary
                    // ── ⚠ EKSİK KODLA DÜĞME AKTİF DEĞİL ──
                    //
                    // Eskiden düğme her zaman aktifti; eksik kodla
                    // basılınca "Lütfen 6 haneli kodu eksiksiz
                    // giriniz" uyarısı çıkıyordu. Ortak kural:
                    // eksik girdiyle düğme AKTİF OLMAZ, dolayısıyla
                    // o uyarıya hiç gerek kalmaz.
                    RefPrimaryButton(
                      'Doğrula',
                      busy: _busy,
                      onPressed: _kodUzunluk < 6
                          ? null
                          : () => _verify(_otp.currentState?.code ?? ''),
                    ),

                    if (saglayici)
                      RefInfoBox(
                        child: Text(
                          'Numaranız doğrulanmadan hesabınız aktif '
                          'edilmez.',
                          style: refText(
                            size: RF.s135,
                            weight: RF.w400,
                            color: RC.textDark,
                            height: RF.lh150,
                          ),
                        ),
                      ),

                    // Sabit test kodu YALNIZ debug + mock modda geçerlidir.
                    if (kDebugMode && !ApiConfig.useRealApi)
                      RefInfoBox(
                        mavi: true,
                        margin: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Geliştirme sürümü test kodu: 123456',
                          style: refText(
                            size: RF.s135,
                            weight: RF.w400,
                            color: RC.textDark,
                            height: RF.lh150,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
