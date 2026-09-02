import 'package:flutter/material.dart';
import '../../data/services/search_service.dart';
import '../../core/sys_state.dart';
import '../../domain/form_mesajlari.dart';

import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

/// HİZMET KATEGORİSİ SEÇİM PANELİ — arama tabanlı.
///
/// ⚠ NİÇİN LİSTE DEĞİL ARAMA.
///
/// Önceki hâl 53 ana kategoriyi düz bir onay kutusu listesi olarak
/// gösteriyordu. İki sorun vardı:
///
///   1. Kullanıcı YALNIZ ANA KATEGORİ seçebiliyordu. "Kombi Servis"
///      seçen usta 4 alt hizmetin tamamına bağlanıyor, "yalnız kombi
///      bakımı yapıyorum" diyemiyordu.
///   2. 53 satırlık listede kaydırarak aramak yorucuydu.
///
/// Bu panel Hizmet Kategorilerim ekranıyla AYNI mantığı kullanır:
/// kullanıcı yazar, eşleşen ALT HİZMETLER çıkar, dokununca seçilir.
/// Seçilenler üstte çip olarak durur.
///
/// ⚠ ANA KATEGORİ SAYI SINIRI YOKTUR.
class KategoriSecimPaneli extends StatefulWidget {
  const KategoriSecimPaneli({
    super.key,
    required this.baslangic,
    this.baslik = 'Hizmet Kategorileri',
  });

  /// Panel açılırken seçili olan kategoriler.
  final Set<String> baslangic;
  final String baslik;

  @override
  State<KategoriSecimPaneli> createState() => _KategoriSecimPaneliState();
}

class _KategoriSecimPaneliState extends State<KategoriSecimPaneli> {
  final _ara = TextEditingController();
  late Set<String> _secili = {...widget.baslangic};

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  // ⚠ YEREL `_norm` KALDIRILDI.
  //
  // Panel kendi Türkçe normalleştirmesini taşıyordu; artık arama
  // ortak servisten geçiyor ve normalleştirme de orada tek yerde.

  /// Arama sonuçları — `(alt hizmet, ana kategori)`, en fazla 6.
  ///
  /// ── ⚠ ORTAK ARAMA SERVİSİ — KESİN KURAL ──
  ///
  /// Bu panel KENDİ süzgecini yazıyordu ve yalnız katalog adlarına
  /// bakıyordu; eş anlamlı sözlüğü ve alias katmanı burada
  /// çalışmıyordu. Hizmet veren "ocak" ya da "kolon hattı" yazıp
  /// kendi verdiği işi BULAMIYORDU.
  ///
  /// ⚠ Sıralama da ortak servisten gelir: tam eşleşme → baştan
  /// eşleşme → ad içinde geçen → eş anlamlı.
  ///
  /// ⚠ YALNIZ ALT HİZMET SATIRLARI ALINIR. Hizmet veren işini TEK
  /// TEK seçer; ana kategori satırı seçtirilmez (bir dokunuşla
  /// onlarca hizmete abone olmak istenmeyen sonuç doğurur).
  ///
  /// ⚠ ZATEN SEÇİLİ olanlar listelenmez; tekrar eklemek anlamsızdır.
  List<({String ad, String ana})> get _sonuclar {
    final q = _ara.text.trim();
    if (q.isEmpty) {
      return const [];
    }
    final out = <({String ad, String ana})>[];
    for (final h in SearchService.services(q, enFazla: 60)) {
      final alt = h.subService;
      if (alt == null || _secili.contains(alt)) {
        continue;
      }
      out.add((ad: alt, ana: h.category));
      if (out.length >= 6) {
        break;
      }
    }
    return out;
  }

  /// ⚠ SON HİZMET KALDIRILAMAZ — hizmet verenin en az biri olmalı.
  ///
  /// Değiştirme yolu kapanmaz: önce yeni hizmet eklenir, sonra eski
  /// kaldırılır. Kural yalnız SONUNCUYU korur.
  ///
  /// ⚠ Panel `baslangic` boş gelebilir (kayıt akışı); o durumda
  /// kaldırılacak bir şey zaten yoktur.
  void _kaldir(String ad) {
    if (_secili.length == 1 && _secili.contains(ad)) {
      // ⚠ SİSTEM HATASI DEĞİL, İŞ KURALI. "Bir sorun oluştu — "
      // öneki kullanıcıya arıza varmış gibi geliyordu.
      sysToastKural(
          context,
          'En az bir hizmet kategorisi seçili olmalıdır. Bu kategoriyi '
          'kaldırmak için önce başka bir hizmet kategorisi ekleyin.');
      return;
    }
    setState(() => _secili.remove(ad));
  }

  void _ekle(String ad) => setState(() {
        _secili.add(ad);
        _ara.clear();
      });

  @override
  Widget build(BuildContext context) {
    final sonuc = _sonuclar;
    final mq = MediaQuery.of(context);

    // ── ⚠ YÜKSEKLİK SINIRLANIR ──
    //
    // Panel içeriği (başlık + arama + 6 sonuç + çipler + düğme)
    // klavye açıkken ekrana SIĞMIYORDU:
    //
    //   BOTTOM OVERFLOWED BY 42 PIXELS
    //
    // "Tamam" düğmesi görünmüyor, seçim yapılamıyordu. Ayrıca panel
    // tepeye kadar uzayınca başlık DURUM ÇUBUĞUNUN ALTINDA kalıyordu.
    //
    // Çözüm: panel en fazla ekranın %88'i kadar yükselir; başlık ve
    // düğme SABİT kalır, ortadaki liste KAYDIRILIR.
    final enFazlaYukseklik = mq.size.height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        // ⚠ `top: true` — başlık durum çubuğuna GİRMEZ.
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: enFazlaYukseklik),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // ── Başlık ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
              child: Row(children: [
                Expanded(
                  child: Text(widget.baslik,
                      style: refText(
                          size: RF.s19, weight: RF.w800, color: RC.text)),
                ),
                RefTap(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(RR.circle),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEF0F4),
                      shape: BoxShape.circle,
                    ),
                    child: const RefSvg('assets/svg/ic_close.svg',
                        size: 14, color: RC.textSoft),
                  ),
                ),
              ]),
            ),

            // ── `.po-search` — Hizmet Kategorilerim ile AYNI kutu ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: RC.white,
                  border: Border.all(color: RC.blue, width: 1.7),
                  borderRadius: BorderRadius.circular(RR.r13),
                ),
                child: Row(children: [
                  const RefSvg('assets/svg/ic_search.svg',
                      size: 20, color: Color(0xFF98A2B3)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _ara,
                      autofocus: true,
                      style: refText(
                          size: RF.s145, weight: RF.w500, color: RC.text),
                      decoration: InputDecoration(
                        isDense: true,
                        // ⚠ DÖRT KENARLIK DA KAPATILIR.
                        //
                        // `border: InputBorder.none` TEK BAŞINA YETMEZ: tema
                        // `inputDecorationTheme` içinde `enabledBorder` ve
                        // `focusedBorder` AYRI tanımlıdır ve `border`'ı ezer.
                        // Alan odaklanınca dış kutunun İÇİNDE ikinci bir mavi
                        // çerçeve çiziliyordu.
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
                        hintText: 'Hizmet veya kategori yazın...',
                        hintStyle: refText(
                            size: RF.s145,
                            weight: RF.w500,
                            color: const Color(0xFF98A2B3)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_ara.text.isNotEmpty)
                    RefTap(
                      onTap: () => setState(_ara.clear),
                      borderRadius: BorderRadius.circular(RR.circle),
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF0F4),
                          shape: BoxShape.circle,
                        ),
                        child: const RefSvg('assets/svg/ic_close.svg',
                            size: 13, color: RC.textSoft),
                      ),
                    ),
                ]),
              ),
            ),

            // ── ⚠ ORTA BÖLÜM KAYDIRILIR ──
            //
            // Arama sonuçları + seçili çipler değişken yükseklikte.
            // Sabit bırakılırsa klavye açıkken taşar ve "Tamam"
            // düğmesi ekran dışında kalır.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
            // ── `.po-row` — arama sonuçları ──
            //
            // ⚠ Dokununca DOĞRUDAN eklenir; ara adım yok.
            for (final r in sonuc)
              RefTap(
                onTap: () => _ekle(r.ad),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFEEF0F3))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r.ad,
                          style: refText(
                              size: RF.s145,
                              weight: RF.w700,
                              color: RC.text)),
                      const SizedBox(height: 2),
                      Text(r.ana,
                          style: refText(
                              size: RF.s12,
                              weight: RF.w400,
                              color: RC.grey)),
                    ],
                  ),
                ),
              ),

            // ── Seçilenler ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Seçili Hizmetlerim (${_secili.length})',
                    style: refText(
                        size: RF.s16, weight: RF.w800, color: RC.text)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(FormMesaj.kategoriSec,
                    style: refText(
                        size: RF.s125,
                        weight: RF.w400,
                        color: RC.textSoft)),
              ),
            ),

            // `.mc-chips`
            // ⚠ İÇ KAYDIRMA KALDIRILDI: dış `ListView` zaten kaydırır;
            // iç içe kaydırma parmağın hangi listeyi sürükleyeceğini
            // belirsizleştiriyordu.
            Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _secili.isEmpty
                        ? Text('Henüz hizmet seçilmedi.',
                            style: refText(
                                size: RF.s125,
                                weight: RF.w400,
                                color: RC.textSoft))
                        : Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: [
                              for (final c in _secili)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 9, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: RC.white,
                                    border: Border.all(
                                        color: const Color(0xFFE1E5EC)),
                                    borderRadius:
                                        BorderRadius.circular(RR.r11),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // ⚠ `Flexible` — ÇİP TAŞMASINI ÖNLER.
                                        //
                                        // En uzun alt hizmet 28
                                        // karakter ("Doğalgaz Boru
                                        // Hattı Tadilatı"). Normal
                                        // yazı boyutunda sığar, ama
                                        // kullanıcı SİSTEM YAZI
                                        // TİPİNİ büyütürse (Android
                                        // erişilebilirlik ayarı,
                                        // %130-200) çip ekran
                                        // genişliğini aşar ve `Wrap`
                                        // bunu kurtaramaz — tek
                                        // eleman satıra sığmıyorsa
                                        // taşar.
                                        Flexible(
                                          child: Text(c,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: refText(
                                                  size: RF.s13,
                                                  weight: RF.w600,
                                                  color: RC.text)),
                                        ),
                                        const SizedBox(width: 8),
                                        RefTap(
                                          onTap: () => _kaldir(c),
                                          borderRadius:
                                              BorderRadius.circular(RR.circle),
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: RefSvg(
                                                'assets/svg/ic_close.svg',
                                                size: 14,
                                                color: RC.textSoft),
                                          ),
                                        ),
                                      ]),
                                ),
                            ],
                          ),
                  ),
                ),
                ],
              ),
            ),

            // ── Onay ──
            //
            // ⚠ SEÇİM BOŞKEN KAPALI: hizmet veren en az bir kategori
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: SizedBox(
                width: double.infinity,
                child: RefPrimaryButton(
                  'Tamam',
                  onPressed: _secili.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_secili),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
