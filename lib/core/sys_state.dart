import 'package:flutter/material.dart';
import 'theme.dart';

/// Ortak sistem durumları — HTML v56 kütüphanesinin birebir Flutter karşılığı.
/// Anahtarlar HTML'deki SYS_TEXT ile aynı; Flutter tarafında tek enum.
enum SysKind {
  noInternet,
  serverUnreachable,
  genericError,
  sessionExpired,
  empty,
  photoUploadError,
  messageSendError,
  insufficientBalance,
  unauthorized,
  success,
}

class _SysText {
  final String title, desc, action;
  const _SysText(this.title, this.desc, this.action);
}

const Map<SysKind, _SysText> _sysText = {
  SysKind.noInternet: _SysText(
      'İnternet bağlantısı yok',
      'Lütfen bağlantınızı kontrol edin. Bağlantı sağlandığında işleminize kaldığınız yerden devam edebilirsiniz.',
      'Tekrar Dene'),
  SysKind.serverUnreachable: _SysText('Sunucuya ulaşılamıyor',
      'Şu anda hizmet veremiyoruz. Lütfen kısa bir süre sonra tekrar deneyin.', 'Tekrar Dene'),
  SysKind.genericError: _SysText(
      'Bir sorun oluştu', 'İşleminiz tamamlanamadı. Lütfen tekrar deneyin.', 'Tekrar Dene'),
  SysKind.sessionExpired: _SysText('Oturum süreniz doldu',
      'Güvenliğiniz için yeniden giriş yapmanız gerekiyor.', 'Giriş Yap'),
  SysKind.empty: _SysText('Henüz burada bir şey yok', 'Gösterilecek kayıt bulunamadı.', ''),
  SysKind.photoUploadError: _SysText('Fotoğraf yüklenemedi',
      'Fotoğrafınız yüklenirken bir sorun oluştu. Lütfen tekrar deneyin.', 'Tekrar Dene'),
  SysKind.messageSendError: _SysText('Mesajınız gönderilemedi',
      'Bağlantı sağlandığında mesajınızı yeniden gönderebilirsiniz.', 'Tekrar Dene'),
  SysKind.insufficientBalance: _SysText('Yetersiz bakiye',
      'Bu işlem için kullanılabilir bakiyeniz yeterli değil.', 'Bakiye Yükle'),
  SysKind.unauthorized:
      _SysText('Bu işlem için yetkiniz yok', 'Bu işlemi gerçekleştirme yetkiniz bulunmuyor.', ''),
  SysKind.success: _SysText('İşlem başarılı', '', ''),
};

IconData _sysIcon(SysKind k) => switch (k) {
      SysKind.noInternet => Icons.wifi_off_rounded,
      SysKind.serverUnreachable => Icons.dns_outlined,
      SysKind.genericError => Icons.error_outline_rounded,
      SysKind.sessionExpired => Icons.schedule_rounded,
      SysKind.empty => Icons.inbox_outlined,
      SysKind.photoUploadError => Icons.broken_image_outlined,
      SysKind.messageSendError => Icons.sms_failed_outlined,
      SysKind.insufficientBalance => Icons.account_balance_wallet_outlined,
      SysKind.unauthorized => Icons.lock_outline_rounded,
      SysKind.success => Icons.check_circle_outline_rounded,
    };

Color _sysColor(SysKind k) => switch (k) {
      SysKind.genericError ||
      SysKind.photoUploadError ||
      SysKind.messageSendError ||
      SysKind.insufficientBalance =>
        HC.orange,
      SysKind.unauthorized => HC.red,
      SysKind.success => HC.green,
      SysKind.empty => HC.lightGrey,
      _ => HC.blue,
    };

/// Tam durum bloğu: ikon dairesi + başlık + açıklama + aksiyon.
class SysState extends StatelessWidget {
  final SysKind kind;
  final String? title, desc, action;
  final VoidCallback? onAction;
  const SysState(this.kind,
      {super.key, this.title, this.desc, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final t = _sysText[kind]!;
    final c = _sysColor(kind);
    final act = action ?? t.action;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration:
              BoxDecoration(color: c.withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(_sysIcon(kind), color: c, size: 32),
        ),
        const SizedBox(height: 14),
        Text(title ?? t.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: HC.dark)),
        if ((desc ?? t.desc).isNotEmpty) ...[
          // `.sys-state{gap:4px}` + `.sys-d{margin-top:3px}` = 7px
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(desc ?? t.desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.55, color: HC.grey)),
          ),
        ],
        if (act.isNotEmpty && onAction != null) ...[
          // `.sys-state{gap:4px}` + `.sys-act{margin-top:16px}` = 20px
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: ElevatedButton(onPressed: onAction, child: Text(act)),
          ),
        ],
      ]),
    );
  }
}

/// Boş liste kısayolu.
class SysEmpty extends StatelessWidget {
  final String? title, desc;
  const SysEmpty({super.key, this.title, this.desc});
  @override
  Widget build(BuildContext c) =>
      SysState(SysKind.empty, title: title, desc: desc);
}

/// Yükleniyor bloğu.
class SysLoading extends StatelessWidget {
  final String label;
  const SysLoading({super.key, this.label = 'Yükleniyor...'});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.all(34),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
              width: 30, height: 30,
              child: CircularProgressIndicator(strokeWidth: 3, color: HC.blue)),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: HC.grey)),
        ]),
      );
}

/// İskelet kart listesi.
class SysSkeleton extends StatelessWidget {
  final int rows;
  const SysSkeleton({super.key, this.rows = 3});
  @override
  Widget build(BuildContext c) => Column(
        children: List.generate(rows, (_) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: HC.border),
                  borderRadius: BorderRadius.circular(13)),
              child: Row(children: [
                const _Pulse(child: CircleAvatar(radius: 22, backgroundColor: Color(0xFFEEF1F5))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(children: [
                    _Pulse(child: _bar(.62)),
                    const SizedBox(height: 8),
                    _Pulse(child: _bar(.88)),
                  ]),
                ),
              ]),
            )),
      );
  static Widget _bar(double f) => FractionallySizedBox(
      widthFactor: f, alignment: Alignment.centerLeft,
      child: Container(height: 11,
          decoration: BoxDecoration(color: const Color(0xFFEEF1F5),
              borderRadius: BorderRadius.circular(6))));
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: Tween(begin: 1.0, end: .45).animate(_c), child: widget.child);
}

/// Buton loading + çift tıklama koruması (HTML lockBtn karşılığı).
/// [busy] true iken spinner gösterir ve dokunuşları yok sayar.
class SysButton extends StatelessWidget {
  final String label;
  final bool busy;
  final bool disabled;
  final VoidCallback? onPressed;
  const SysButton(this.label,
      {super.key, required this.onPressed, this.busy = false, this.disabled = false});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: (busy || disabled) ? null : onPressed,
        style: disabled
            ? ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC9D2DE),
                disabledBackgroundColor: const Color(0xFFC9D2DE))
            : null,
        child: busy
            ? const SizedBox(
                width: 19, height: 19,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
            : Text(label),
      );
}

/// Bildirimler (HTML toast dili).
void sysToastOk(BuildContext context, String msg) =>
    _toast(context, '$msg ✓');
void sysToastErr(BuildContext context, SysKind kind, {String? extra}) =>
    _toast(context,
        _sysText[kind]!.title + (extra != null ? ' — $extra' : ''));

/// KURAL BİLDİRİMİ — sistem hatası DEĞİL.
///
/// ⚠ "Bir sorun oluştu — …" ÖNEKİ KULLANILMAZ.
///
/// İş kuralı uyarıları `sysToastErr(genericError, extra: …)` ile
/// gösteriliyordu; o önek kullanıcıya bir ARIZA olduğunu düşündürüyor.
/// Oysa uygulama doğru çalışıyor, yalnız kural izin vermiyor.
///
/// Metin olduğu gibi gösterilir: tam cümle, açıklayıcı, suçlayıcı
/// değil.
void sysToastKural(BuildContext context, String mesaj) =>
    _toast(context, mesaj);

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      behavior: SnackBarBehavior.floating,
      backgroundColor: HC.dark,
      duration: const Duration(milliseconds: 1900),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}
