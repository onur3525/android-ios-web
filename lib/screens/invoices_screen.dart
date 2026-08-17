import 'package:flutter/material.dart';
import 'widgets/hata_gosterimi.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/sys_state.dart';
import '../data/controllers/invoice_controller.dart';
import '../data/models/invoice.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'nav_actions.dart';

/// FATURALARIM — hizmet verenin aylık faturaları.
///
/// ⚠ SALT OKUNUR EKRAN. Belgeler admin/muhasebe tarafında oluşturulur;
/// uygulama fatura üretmez, tutar hesaplamaz, belge düzenlemez.
/// Kullanıcı yalnız görüntüler ve varsa PDF'i açar.
///
/// ⚠ ÖDEME AKIŞI YOKTUR — GEREKMEZ.
///
/// Kullanıcı cüzdanına para yükler; her iletişim açılışında ücret
/// cüzdandan O ANDA düşülür. Fatura, ay içinde gerçekleşen bu
/// işlemlerin toplamını belgeler — sonradan tahsil edilecek bir borç
/// DEĞİLDİR. Ödeme düğmesi veya "ödeme bekliyor" uyarısı koymak
/// kullanıcıya ikinci kez ödeme yapması gerektiğini düşündürürdü.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _ilk = true;

  /// ── DÖNEM FİLTRESİ ──
  ///
  /// ⚠ Yıl ve ay listesi KODA GÖMÜLÜ DEĞİLDİR; gelen faturalardan
  /// türetilir. Böylece önceki yıllar da, ileride gelecek yıllar da
  /// kendiliğinden görünür — yeni bir sürüm gerekmez.
  ///
  /// `null` → tüm dönemler.
  int? _yil;
  int? _ay;

  /// Faturalarda geçen yıllar (yeniden eskiye).
  List<int> _yillar(List<Invoice> hepsi) {
    final set = hepsi.map((f) => f.donem.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return set;
  }

  /// Seçili yıla ait aylar (yeniden eskiye).
  List<int> _aylar(List<Invoice> hepsi, int yil) {
    final set = hepsi
        .where((f) => f.donem.year == yil)
        .map((f) => f.donem.month)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return set;
  }

  List<Invoice> _suz(List<Invoice> hepsi) => hepsi.where((f) {
        if (_yil != null && f.donem.year != _yil) {
          return false;
        }
        if (_ay != null && f.donem.month != _ay) {
          return false;
        }
        return true;
      }).toList();

  String get _filtreEtiketi {
    if (_yil == null) {
      return 'Tüm dönemler';
    }
    if (_ay == null) {
      return '$_yil';
    }
    return '${Invoice.ayAdi(_ay!)} $_yil';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ilk) {
      return;
    }
    _ilk = false;
    // İlk açılışta yüklenir; `yukle` kendi durumunu yayınlar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<InvoiceController>().yukle();
      }
    });
  }

  Future<void> _pdfAc(Invoice f) async {
    if (f.pdfUrl.trim().isEmpty) {
      sysToastErr(context, SysKind.genericError,
          extra: 'Belge henüz hazır değil');
      return;
    }
    final u = Uri.tryParse(f.pdfUrl);
    if (u == null) {
      return;
    }
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      sysToastErr(context, SysKind.genericError,
          extra: 'Belge açılamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = context.watch<InvoiceController>();

    return Scaffold(
      backgroundColor: RC.pageBg,
      bottomNavigationBar: RefBottomNav(
        activeKey: 'profil',
        items: custNavItems(context, saglayici: true),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: RefDetailHeader(title: 'Faturalarım'),
            ),
            // ── DÖNEM FİLTRESİ ──
            if (ctl.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_filtreEtiketi,
                          style: refText(
                              size: RF.s135,
                              weight: RF.w600,
                              color: RC.textSoft)),
                    ),
                    RefTap(
                      onTap: () => _filtreSec(ctl.items),
                      borderRadius: BorderRadius.circular(RR.r10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 7, horizontal: 11),
                        decoration: BoxDecoration(
                          border: Border.all(color: RC.border),
                          borderRadius: BorderRadius.circular(RR.r10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const RefSvg('assets/svg/ic_filter.svg',
                                size: 15, color: RC.text),
                            const SizedBox(width: 6),
                            Text('Dönem',
                                style: refText(
                                    size: RF.s135,
                                    weight: RF.w700,
                                    color: RC.text)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _govde(ctl)),
          ],
        ),
      ),
    );
  }

  /// Dönem seçim paneli — YIL, sonra AY.
  ///
  /// ⚠ İki adımlı: önce yıl seçilir, sonra o yılın ayları listelenir.
  /// Tek listede tüm dönemleri göstermek yıllar biriktikçe uzayan bir
  /// liste üretirdi.
  Future<void> _filtreSec(List<Invoice> hepsi) async {
    final yillar = _yillar(hepsi);
    final yil = await RefBottomSheet.goster<Object>(
      context,
      title: 'Yıl Seçin',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RefCheckRow(
            value: _yil == null,
            label: 'Tüm dönemler',
            onChanged: (_) => Navigator.of(context).pop('tumu'),
          ),
          for (final y in yillar)
            RefCheckRow(
              value: _yil == y && _ay == null,
              label: '$y',
              onChanged: (_) => Navigator.of(context).pop(y),
            ),
        ],
      ),
    );
    if (yil == null || !mounted) {
      return;
    }
    if (yil == 'tumu') {
      setState(() {
        _yil = null;
        _ay = null;
      });
      return;
    }

    final secilenYil = yil as int;
    final aylar = _aylar(hepsi, secilenYil);
    final ay = await RefBottomSheet.goster<Object>(
      context,
      title: '$secilenYil — Ay Seçin',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RefCheckRow(
            value: _ay == null,
            label: 'Tüm aylar',
            onChanged: (_) => Navigator.of(context).pop('tumu'),
          ),
          for (final a in aylar)
            RefCheckRow(
              value: _ay == a,
              label: Invoice.ayAdi(a),
              onChanged: (_) => Navigator.of(context).pop(a),
            ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _yil = secilenYil;
      // Panel kapatılırsa (ay seçilmezse) yıl filtresi geçerli kalır.
      _ay = (ay == null || ay == 'tumu') ? null : ay as int;
    });
  }

  Widget _govde(InvoiceController ctl) {
    if (ctl.yukleniyor && ctl.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // ⚠ METİN MERKEZDEN: ekran kendi cümlesini yazmaz. Ağ sorunu,
    // sunucu arızası ve oturum düşmesi AYRI görünür.
    if (ctl.lastError != null && ctl.items.isEmpty) {
      return Center(
        child: HataTamEkran(
            hata: ctl.lastError!, onTekrar: () => ctl.yukle()),
      );
    }
    if (ctl.items.isEmpty) {
      return const Center(
        child: SysState(SysKind.empty,
            title: 'Henüz faturanız yok',
            desc: 'Aylık faturalarınız düzenlendikçe burada listelenir.'),
      );
    }

    final gorunen = _suz(ctl.items);
    return RefreshIndicator(
      onRefresh: () => ctl.yukle(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ⚠ EKSTRA AÇIKLAMA YOKTUR.
          //
          // Fatura bilgi belgesidir; ödeme uyarısı, borç bildirimi
          // veya yönlendirme metni konulmaz. Ekranda yalnız belgeler
          // listelenir.
          //
          // ⚠ Liste BİR KEZ süzülür; her kart için yeniden süzmek
          // gereksiz iş yapardı.
          if (gorunen.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: SysState(SysKind.empty,
                  title: 'Bu dönemde fatura yok',
                  desc: 'Başka bir dönem seçebilirsiniz.'),
            )
          else
            for (final f in gorunen) ...[
              _FaturaKarti(fatura: f, onTap: () => _pdfAc(f)),
              if (f != gorunen.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// Tek fatura satırı — dönem, no, tutar ve durum rozeti.
class _FaturaKarti extends StatelessWidget {
  const _FaturaKarti({required this.fatura, required this.onTap});

  final Invoice fatura;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.border),
          borderRadius: BorderRadius.circular(RR.r14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3FA),
                borderRadius: BorderRadius.circular(RR.r10),
              ),
              alignment: Alignment.center,
              child: const RefSvg('assets/svg/ic_ndoc.svg',
                  size: 18, color: RC.blue),
            ),
            const SizedBox(width: 11),
            // ⚠ KARTTA YALNIZ DÖNEM YAZAR.
            //
            // Tutar, işlem adedi, fatura numarası ve düzenlenme tarihi
            // BELGENİN KENDİSİNDE zaten bulunur. Aynı bilgiyi listede
            // ikinci kez göstermek hem gereksiz hem de belgeyle
            // uyuşmazlık riski taşır (belge yeniden düzenlenirse liste
            // eski değeri gösterir).
            Expanded(
              child: Text(fatura.donemMetni,
                  style: refText(
                      size: RF.s145, weight: RF.w700, color: RC.text)),
            ),
            const SizedBox(width: 8),
            const RefSvg('assets/svg/ic_chev.svg',
                size: 16, color: Color(0xFFD3D8E0)),
          ],
        ),
      ),
    );
  }
}
