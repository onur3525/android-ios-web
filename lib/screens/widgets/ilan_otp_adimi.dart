import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

/// İLAN AKIŞI — ADIM 4: SMS DOĞRULAMA
///
/// ⚠ AYRI EKRAN DEĞİLDİR: doğrulama, ilan göstergesinin içinde yer alır.
///
/// ⚠ SAYAÇ TÜM EKRANI YENİDEN ÇİZMEZ. Yalnız kendi metnini günceller;
/// aksi hâlde odak kaybolur, klavye kapanır ve kod girilemez.
class IlanOtpAdimi extends StatefulWidget {
  const IlanOtpAdimi({
    super.key,
    required this.telefon,
    required this.veri,
    required this.onDegisti,
  });

  final String telefon;
  final OtpVerisi veri;
  final VoidCallback onDegisti;

  @override
  State<IlanOtpAdimi> createState() => _IlanOtpAdimiState();
}

/// OTP durumu — ekran yeniden çizilse de KORUNUR.
class OtpVerisi {
  /// SIFIR GENİŞLİKLİ İŞARETÇİ — kutu ASLA gerçekten boş kalmaz.
  ///
  /// ⚠ NEDEN GEREKLİ
  ///
  /// Android yazılım klavyesi BOŞ bir alanda geri silmeye basıldığında
  /// tuş olayı ÜRETMEZ; metin zaten boş olduğu için `onChanged` de
  /// tetiklenmez. Sonuç: kullanıcı her kutuya AYRI AYRI dokunup
  /// silmek zorunda kalıyordu.
  ///
  /// Her kutuda görünmez bir karakter tutulursa silme HER ZAMAN metni
  /// değiştirir, `onChanged` çalışır ve odak kendiliğinden bir önceki
  /// kutuya kayar. Geri silmeye basılı tutmak 6 haneyi sondan başa
  /// siler.
  ///
  /// Aynı teknik `RefOtpBoxes` içinde de kullanılır.
  static const iz = '\u200b';

  final kutular =
      List.generate(6, (_) => TextEditingController(text: iz));
  final odaklar = List.generate(6, (_) => FocusNode());

  /// Bir kutunun GÖRÜNEN rakamı (işaretçi hariç).
  String rakam(int i) => kutular[i].text.replaceAll(iz, '');

  /// Kutuyu işaretçiyle birlikte yazar ve imleci sona alır.
  void yaz(int i, String r) {
    final t = '$iz$r';
    kutular[i].value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  String get kod => List.generate(6, rakam).join();
  bool get tamam => kod.length == 6;

  /// DOĞRULAMA HATASI — kutuların altında kırmızı satır.
  ///
  /// ⚠ NİÇİN VAR: bu adımda girilen kod eskiden HİÇ doğrulanmıyordu;
  /// altı hane dolar dolmaz kayıt isteği gönderiliyor, yanlış koda
  /// "Kayıt tamamlanamadı" gibi alakasız bir hata dönüyordu. Kod artık
  /// gönderimden ÖNCE denetlenir ve sonuç burada gösterilir.
  String? hata;

  void dispose() {
    for (final c in kutular) {
      c.dispose();
    }
    for (final f in odaklar) {
      f.dispose();
    }
  }
}

class _IlanOtpAdimiState extends State<IlanOtpAdimi> {
  static const _kSure = 60;

  /// ⚠ BİTİŞ ANI TUTULUR — bkz. `otp_screen` içindeki ayrıntılı not.
  /// Adımlar arası geçişte veya uygulama arka plandayken sayaç
  /// SIFIRLANMAZ; kalan süre duvar saatinden hesaplanır.
  DateTime _bitis = DateTime.now().add(const Duration(seconds: _kSure));

  int get _kalan {
    final fark = _bitis.difference(DateTime.now()).inSeconds;
    return fark > 0 ? fark : 0;
  }
  Timer? _zaman;

  @override
  void initState() {
    super.initState();
    _sayacBaslat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.veri.odaklar.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  void _sayacBaslat() {
    _bitis = DateTime.now().add(const Duration(seconds: _kSure));
    _zaman?.cancel();
    _zaman = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      // ⚠ Yalnız sayaç metnini yeniler; kutular yerinde kalır.
      setState(() {});
      if (_kalan <= 0) {
        t.cancel();
      }
    });
  }

  void _girdi(int i, String v) {
    final veri = widget.veri;

    // ── İŞARETÇİ SİLİNDİ → BOŞ KUTUDA GERİ SİLME ──
    if (!v.contains(OtpVerisi.iz)) {
      final kalan = v.replaceAll(RegExp(r'\D'), '');
      if (kalan.isEmpty) {
        veri.yaz(i, '');
        if (i > 0) {
          // Bir önceki kutuyu temizle ve oraya geç — zincir sürer.
          veri.yaz(i - 1, '');
          veri.odaklar[i - 1].requestFocus();
        }
        setState(() {});
        widget.onDegisti();
        return;
      }
      // Nadir durum: işaretçi kaybolmuş ama rakam var.
      veri.yaz(i, kalan.characters.last);
      if (i < 5) {
        veri.odaklar[i + 1].requestFocus();
      }
      setState(() {});
      widget.onDegisti();
      return;
    }

    final rakam = v.replaceAll(RegExp(r'\D'), '');

    // Yapıştırma / otomatik doldurma: tek kutuya birden çok hane.
    if (rakam.length > 1) {
      for (var k = 0; k < 6; k++) {
        veri.yaz(k, k < rakam.length ? rakam[k] : '');
      }
      veri.odaklar[rakam.length.clamp(0, 5)].requestFocus();
      setState(() {});
      widget.onDegisti();
      return;
    }

    veri.yaz(i, rakam);
    if (rakam.isNotEmpty && i < 5) {
      veri.odaklar[i + 1].requestFocus();
    }
    setState(() {});
    widget.onDegisti();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: Color(0xFFEAF1FB), shape: BoxShape.circle),
              child: const RefSvg('assets/svg/ic_chat.svg',
                  size: 44, color: RC.blue),
            ),
          ),
          const SizedBox(height: 16),
          Text('SMS Doğrulama',
              textAlign: TextAlign.center,
              style: refText(size: RF.s18, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 8),
          Text(
            '${widget.telefon} numarasına gönderilen 6 haneli '
            'doğrulama kodunu girin.',
            textAlign: TextAlign.center,
            style: refText(
                size: RF.s13,
                weight: RF.w400,
                color: RC.textSoft,
                height: RF.lh145),
          ),
          const SizedBox(height: 22),

          // 6 kutu — rakam girilince otomatik ilerler.
          Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 9),
                Expanded(child: _kutu(i)),
              ],
            ],
          ),

          // Doğrulama hatası — kutuların hemen altında.
          if (widget.veri.hata != null) ...[
            const SizedBox(height: 10),
            Text(
              widget.veri.hata!,
              textAlign: TextAlign.center,
              style: refText(
                  size: RF.s135, weight: RF.w600, color: RC.danger),
            ),
          ],

          const SizedBox(height: 18),
          Center(
            // ⚠ BİÇİM DİĞER SMS EKRANIYLA AYNI: `dk:sn` geri sayım.
            // Önceki "Kodu tekrar gönder 48 sn" ifadesi hem yanıltıcıydı
            // (o sırada tekrar gönderme KAPALI) hem biçim farklıydı.
            child: _kalan > 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Yeni kod isteyebilmek için bekleyin',
                          style: refText(
                              size: RF.s135,
                              weight: RF.w400,
                              color: RC.textSoft)),
                      const SizedBox(height: 2),
                      Text(
                        '${(_kalan ~/ 60).toString().padLeft(2, '0')}:'
                        '${(_kalan % 60).toString().padLeft(2, '0')}',
                        style: refText(
                            size: RF.s16, weight: RF.w700, color: RC.blue),
                      ),
                    ],
                  )
                : RefTap(
                    onTap: _sayacBaslat,
                    borderRadius: BorderRadius.circular(RR.r10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Text('Kodu Tekrar Gönder',
                          style: refText(
                              size: RF.s14,
                              weight: RF.w700,
                              color: RC.blue)),
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          Text(
            'Doğrulama tamamlandığında ilanınız tek sefer yayınlanır.',
            textAlign: TextAlign.center,
            style: refText(
                size: RF.s12,
                weight: RF.w400,
                color: RC.textSoft,
                height: RF.lh145),
          ),
        ],
      );

  Widget _kutu(int i) => AspectRatio(
        aspectRatio: 1 / 1.15,
        child: TextField(
          controller: widget.veri.kutular[i],
          focusNode: widget.veri.odaklar[i],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          // ⚠ Sınır ve rakam filtresi KULLANILMAZ: görünmez işaretçi
          // hem uzunluğa dahildir hem de filtreye takılır. Ayıklama
          // `_girdi` içinde yapılır.
          style: refText(size: 22, weight: RF.w700, color: RC.text),
          onChanged: (v) => _girdi(i, v),
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: RC.white,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE7EAEF), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: RC.blue, width: 1.6),
            ),
          ),
        ),
      );
}
