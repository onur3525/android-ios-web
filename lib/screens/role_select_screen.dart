import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import 'register_screen.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../core/geri.dart';

/// İki modlu ekran:
/// * Kayıt için rol seçimi (girişsiz — login'deki "Kayıt Ol" buraya gelir)
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  /// Ana sayfa kartlarından doğrudan kayıt başlatma (HTML data-act="register").
  static void startRegister(BuildContext context, Role role) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => RegisterScreen(role: role)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final switching = auth.loggedIn; // girişliyse rol değiştirme modu

    return RefPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: RefBackButton(onTap: () => geriGit(context)),
          ),
          const SizedBox(height: 6),
          // ⚠ ÇİFT OK OLMASIN: bu ekranın kendi `RefBackButton`'ı var.
          RefPageTitle(
              switching ? 'Rol Değiştir' : 'Nasıl Başlamak İstersiniz?',
              geriDugmesi: false),
          RefSubtitle(
            switching
                ? 'Hesabınızdaki roller arasında geçiş yapabilirsiniz.'
                : 'Size uygun hesap türünü seçin; kayıt yalnızca birkaç '
                    'dakika sürer.',
          ),
          const SizedBox(height: 18),

          if (!switching) ...[
            _RolKarti(
              saglayici: false,
              onTap: () => startRegister(context, Role.customer),
            ),
            const SizedBox(height: 12),
            _RolKarti(
              saglayici: true,
              onTap: () => startRegister(context, Role.provider),
            ),
          ] else ...[
            for (final r in [Role.customer, Role.provider])
              if (auth.currentAccount!.roles.contains(r))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RolKarti(
                    saglayici: r == Role.provider,
                    aktif: auth.activeRole == r,
                    onTap: () => _rolDegistir(context, r),
                  ),
                ),
            // ⚠ BİLGİLENDİRME KUTUSU KALDIRILDI.
            //
            // "Aynı hesapla hem hizmet alabilir hem hizmet
            // verebilirsiniz" cümlesi, kullanıcı zaten iki rolü de
            // ekranda görürken tekrardı. Rol Değiştir ekranlarında
            // bilgilendirme metni GÖSTERİLMEZ: kartlar ve düğme
            // yeterlidir.
          ],
        ],
      ),
    );
  }

  /// Rol değişimi — iş mantığı korundu, hedef deterministik yapıldı.
  Future<void> _rolDegistir(BuildContext context, Role r) async {
    final err = await context.read<AuthController>().switchRole(r);
    if (!context.mounted) {
      return;
    }
    if (err != null) {
      sysToastErr(context, SysKind.unauthorized, extra: err.message);
      return;
    }
    sysToastOk(
      context,
      r == Role.provider
          ? 'Hizmet Veren profiline geçildi'
          : 'Hizmet alan profiline geçildi',
    );
    Navigator.of(context).pushNamedAndRemoveUntil(
      r == Role.provider ? '/provider/jobs' : '/customer/listings',
      (route) => false,
    );
  }
}

/// Rol kartı açıklamasının SATIR yüksekliği.
///
/// ⚠ İki kartın eşit yüksekliği buna bağlı: açıklamaya iki satırlık
const double _kAciklamaSatirYuksekligi = 14.5;

/// Rol kartı açıklamasının PUNTOSU.
///
/// ⚠ Yükseklik hesabı buna dayanır: ölçek puntoya uygulanır, sonuç
/// satır yüksekliği çarpanıyla çarpılır. Punto ile yükseklik ayrı
/// yerlerde yazılırsa hesap sessizce bozulur; ikisi de burada.
const double _kAciklamaPunto = 11.6;

/// Referans `.rc` rol kartı — Home'daki kartla aynı dil.
class _RolKarti extends StatelessWidget {
  const _RolKarti({
    required this.saglayici,
    required this.onTap,
    this.aktif = false,
  });

  final bool saglayici;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // ⚠ ÖLÇÜM ANAHTARI: iki kartın gerçek genişlik/yüksekliğini
      // testten okuyabilmek için. Metinden bulmaya çalışmak
      // güvenilmez — kart içinde başka `ClipRRect`'ler de var ve
      // ölçüm yanlış kutuyu yakalayabiliyordu.
      key: ValueKey(saglayici ? 'rol-karti-veren' : 'rol-karti-alan'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(RR.r16),
          child: RefTap(
            onTap: onTap,
            child: Container(
              color: saglayici
                  ? const Color(0xFFFCEDE0)
                  : const Color(0xFFE7F0FD),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RefGradientSquare(
                    gradient:
                        saglayici ? RG.orangeSquare : RG.blueSquare,
                    shadow: saglayici ? RS.orangeSquare : RS.blueSquare,
                    child: RefSvg(
                      saglayici
                          ? 'assets/svg/ic_worker_w.svg'
                          : 'assets/svg/ic_home_w.svg',
                      size: 19,
                      color: RC.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    saglayici
                        ? 'Hizmet\nVermek İstiyorum'
                        : 'Hizmet\nAlmak İstiyorum',
                    style: refText(
                      size: RF.s16,
                      weight: RF.w700,
                      color: saglayici
                          ? const Color(0xFF6B3A0A)
                          : const Color(0xFF0F2E6B),
                      letterSpacing: RF.lsM04,
                    ).copyWith(height: 19 / 16),
                  ),
                  const SizedBox(height: 8),
                  // ── ⚠ İKİ KART AYNI YÜKSEKLİKTE ──
                  //
                  // Kart yapısı, dolgusu ve yazı ölçüleri zaten
                  // aynıydı; fark AÇIKLAMA METNİNDEN geliyordu:
                  // "Hizmet Almak" tek satıra sığıyor, "Hizmet
                  // Vermek" iki satıra sarıyordu. Bu yüzden turuncu
                  // kart mavisinden yüksek görünüyordu.
                  //
                  // Açıklamaya İKİ SATIRLIK sabit alan ayrıldı: metin
                  // bir satır olsa da yer korunur, kartlar eşitlenir.
                  //
                  SizedBox(
                    // ── ⚠ ÖLÇEK PUNTOYA UYGULANIR, YÜKSEKLİĞE DEĞİL ──
                    //
                    // Önceki hâl `scale(29)` diyordu ve yine
                    // kesiliyordu. Nedeni Android 14+ ile gelen
                    // DOĞRUSAL OLMAYAN yazı ölçeklemesi: `scale()`
                    // verilen değerin BÜYÜKLÜĞÜNE göre farklı çarpan
                    // uygular — küçük puntoyu çok, büyük puntoyu az
                    // büyütür.
                    //
                    // 29 bir YÜKSEKLİK; onu punto sanıp ölçeklemek
                    // gerçek satır yüksekliğinden DAHA AZ yer ayırır:
                    //   ölçek 1,15 → kutu 31,6 · gereken 33,3
                    //   ölçek 1,30 → kutu 34,2 · gereken 37,7
                    // Aradaki fark kadarı kırpılıyordu; "kazanın"
                    // yarım görünmesinin sebebi buydu.
                    //
                    // Doğrusu: ölçek PUNTOYA uygulanır, sonuç satır
                    // yüksekliği çarpanıyla çarpılır, iki satır için
                    // ikiyle çoğaltılır.
                    //
                    // ⚠ İki kart yine EŞİT: hesap her ikisinde aynı.
                    height: MediaQuery.textScalerOf(context)
                            .scale(_kAciklamaPunto) *
                        (_kAciklamaSatirYuksekligi / _kAciklamaPunto) *
                        2,
                    child: Text(
                      saglayici
                          ? 'Hesap oluşturun, iş ilanlarını görüntüleyin ve '
                              'yeni işler kazanın.'
                          : 'Ücretsiz hesap oluşturun, ilanınızı yayınlayın '
                              've teklif alın.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                        size: _kAciklamaPunto,
                        weight: RF.w400,
                        color: const Color(0xFF3E4C61),
                        letterSpacing: RF.lsM02,
                      ).copyWith(
                          height:
                              _kAciklamaSatirYuksekligi / _kAciklamaPunto),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (aktif)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: RC.success,
                borderRadius: BorderRadius.circular(RR.r12),
              ),
              child: Text(
                'Aktif',
                style: refText(
                    size: RF.s11, weight: RF.w700, color: RC.white),
              ),
            ),
          ),
      ],
    );
  }
}
