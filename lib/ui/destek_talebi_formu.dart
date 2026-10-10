import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/remote/api/destek_api.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import '../data/remote/api_error_mapper.dart';
import '../domain/destek_talebi.dart';
import '../domain/form_mesajlari.dart';
import 'ref_tokens.dart';
import 'ref_widgets.dart';

/// Gönderim sonucu: başarılıysa talep numarası, değilse kullanıcıya
/// gösterilecek hata metni (teknik ayrıntı İÇERMEZ).
typedef DestekGonderimSonucu = ({String? talepNo, String? hata});

/// Gönderici: (konu, mesaj, idempotency anahtarı) → sonuç.
typedef DestekGonderici = Future<DestekGonderimSonucu> Function(
    String konu, String mesaj, String anahtar);

/// ═══════════════════════════════════════════════════════════════
/// DESTEK MERKEZİ › TALEP GÖNDER (tek kaynak)
///
/// Android profil panelinde (`profile_screen._destekSheet`) ve web kenar
/// çubuğu panelinde (`web_destek_paneli.dart`) AYNI bileşen kullanılır —
/// iki platformun davranışı ayrışamaz.
///
/// Akış: oturum açık kullanıcı → `POST /support/tickets` (mevcut
/// ApiClient; Bearer + Idempotency-Key) → gerçek kayıt → Admin › Gelen
/// Talepler › Destek Talepleri.
///
/// KURALLAR
///   · Oturum yoksa form ÇİZİLMEZ (panel bugünkü hâliyle kalır).
///   · Mock/demo derlemesinde form ÇİZİLMEZ: sahte talep üretilmez, ağ
///     çağrısı yapılmaz (mock ağ koruması).
///   · Doğrulama sunucuyla aynı sınırlar (`destek_talebi.dart`); yalnız
///     erken geri bildirimdir, güvenlik kontrolü SUNUCUDADIR.
///   · Gönderim sürerken düğme ve alanlar kilitli (çift gönderim yok).
///     Ağ kesintisinde aynı içerik yeniden denenirse AYNI anahtar
///     gider → sunucu ikinci kayıt açmaz.
///   · Başarıda alanlar temizlenir, talep numarası gösterilir.
///   · Hata metni kullanıcı dilindedir; yığın izi/teknik kod gösterilmez.
/// ═══════════════════════════════════════════════════════════════
class DestekTalebiFormu extends StatefulWidget {
  const DestekTalebiFormu({
    super.key,
    this.gonderici,
    this.epostaDogrulanmis,
  });

  /// Yalnız testler: verilirse oturum/mod denetimi atlanır ve gönderim
  /// bu fonksiyonla yapılır.
  final DestekGonderici? gonderici;

  /// Yalnız testler: başarı metnindeki e-posta cümlesi.
  final bool? epostaDogrulanmis;

  static const konuAnahtari = ValueKey('destekTalebiKonu');
  static const mesajAnahtari = ValueKey('destekTalebiMesaj');
  static const gonderAnahtari = ValueKey('destekTalebiGonder');

  @override
  State<DestekTalebiFormu> createState() => _DestekTalebiFormuState();
}

class _DestekTalebiFormuState extends State<DestekTalebiFormu> {
  final _konu = TextEditingController();
  final _mesaj = TextEditingController();
  final _fMesaj = FocusNode();

  bool _gonderiliyor = false;

  /// Gönder'e bir kez basıldıktan sonra alan uyarıları canlı güncellenir.
  bool _denendi = false;
  String? _hata;
  String? _basari;

  /// Aynı içerik için aynı anahtar (yeniden deneme ikinci kayıt açmaz).
  String? _anahtar;
  String? _anahtarIcerigi;

  @override
  void dispose() {
    _konu.dispose();
    _mesaj.dispose();
    _fMesaj.dispose();
    super.dispose();
  }

  void _degisti(String _) {
    if (_denendi || _basari != null || _hata != null) {
      setState(() {
        _basari = null;
        _hata = null;
      });
    }
  }

  Future<DestekGonderimSonucu> _apiIleGonder(
      ApiClient istemci, String konu, String mesaj, String anahtar) async {
    try {
      final j = await DestekApi(istemci).talepGonder(
        konu: konu,
        mesaj: mesaj,
        platform: kIsWeb
            ? 'web'
            : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
        surum: ApiConfig.appVersion,
        idempotencyKey: anahtar,
      );
      final no = j['ticketNo'];
      return (talepNo: no is String && no.isNotEmpty ? no : '—', hata: null);
    } on ApiFailure catch (e) {
      return (talepNo: null, hata: e.error.message);
    } catch (_) {
      return (talepNo: null, hata: FormMesaj.destekGonderilemedi);
    }
  }

  Future<void> _gonder(bool epostaDogrulanmis) async {
    if (_gonderiliyor) {
      return;
    }
    setState(() {
      _denendi = true;
      _hata = null;
      _basari = null;
    });
    if (destekKonuHatasi(_konu.text) != null ||
        destekMesajHatasi(_mesaj.text) != null) {
      return;
    }
    final konu = _konu.text.trim();
    final mesaj = _mesaj.text.trim();
    final icerik = '$konu\u0000$mesaj';
    if (_anahtarIcerigi != icerik) {
      _anahtar = ApiClient.newIdempotencyKey();
      _anahtarIcerigi = icerik;
    }
    final anahtar = _anahtar!;
    // ⚠ İstemci `await`ten ÖNCE alınır (bağlam sonra geçersiz olabilir).
    final gonderici = widget.gonderici ??
        (() {
          final istemci = context.read<ApiClient>();
          return (String k, String m, String a) =>
              _apiIleGonder(istemci, k, m, a);
        })();
    FocusScope.of(context).unfocus();
    setState(() => _gonderiliyor = true);
    final sonuc = await gonderici(konu, mesaj, anahtar);
    if (!mounted) {
      return;
    }
    setState(() {
      _gonderiliyor = false;
      final no = sonuc.talepNo;
      if (no != null) {
        _konu.clear();
        _mesaj.clear();
        _denendi = false;
        _anahtar = null;
        _anahtarIcerigi = null;
        _basari = FormMesaj.destekGonderildi(no,
            epostaDogrulanmis: epostaDogrulanmis);
      } else {
        _hata = sonuc.hata ?? FormMesaj.destekGonderilemedi;
      }
    });
  }

  Widget _alanUyarisi(String? metin) => metin == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(metin,
              style: refText(
                  size: RF.s125, weight: RF.w500, color: RC.danger)),
        );

  @override
  Widget build(BuildContext context) {
    final bool epostaDogrulanmis;
    if (widget.gonderici != null) {
      epostaDogrulanmis = widget.epostaDogrulanmis ?? true;
    } else {
      // Mock/demo derlemesi: backend yok → form yok (sahte talep üretilmez).
      if (!ApiConfig.useRealApi) {
        return const SizedBox.shrink();
      }
      final hesap = context.watch<AuthController?>()?.currentAccount;
      // Yalnız oturum açmış kullanıcı talep gönderebilir.
      if (hesap == null) {
        return const SizedBox.shrink();
      }
      epostaDogrulanmis = hesap.emailVerified;
    }

    final konuHatasi = _denendi ? destekKonuHatasi(_konu.text) : null;
    final mesajHatasi = _denendi ? destekMesajHatasi(_mesaj.text) : null;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Talep Gönder',
              style: refText(size: RF.s15, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 4),
          Text('Sorununuzu yazın, destek ekibimiz yanıtlasın.',
              style: refText(
                  size: RF.s13,
                  weight: RF.w400,
                  color: RC.textSoft,
                  height: RF.lh150)),
          const SizedBox(height: 10),
          RefTextField(
            key: DestekTalebiFormu.konuAnahtari,
            controller: _konu,
            hint: 'Konu',
            yerTutucu: 'Talebinizin konusu',
            zorunlu: true,
            enabled: !_gonderiliyor,
            hatali: konuHatasi != null,
            inputFormatters: [
              LengthLimitingTextInputFormatter(kDestekKonuEnFazla),
            ],
            textInputAction: TextInputAction.next,
            onEditingComplete: () => _fMesaj.requestFocus(),
            onChanged: _degisti,
          ),
          _alanUyarisi(konuHatasi),
          const SizedBox(height: 12),
          RefTextField(
            key: DestekTalebiFormu.mesajAnahtari,
            controller: _mesaj,
            focusNode: _fMesaj,
            hint: 'Mesajınız',
            yerTutucu: 'Size nasıl yardımcı olabileceğimizi yazın',
            zorunlu: true,
            enabled: !_gonderiliyor,
            hatali: mesajHatasi != null,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            inputFormatters: [
              LengthLimitingTextInputFormatter(kDestekMesajEnFazla),
            ],
            onChanged: _degisti,
          ),
          _alanUyarisi(mesajHatasi),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_hata!,
                  style: refText(
                      size: RF.s13, weight: RF.w500, color: RC.danger)),
            ),
          if (_basari != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RC.successSoft,
                borderRadius: BorderRadius.circular(RR.r12),
              ),
              child: Text(_basari!,
                  style: refText(
                      size: RF.s13,
                      weight: RF.w500,
                      color: RC.success,
                      height: RF.lh150)),
            ),
          const SizedBox(height: 14),
          RefPrimaryButton(
            'Talep Gönder',
            key: DestekTalebiFormu.gonderAnahtari,
            busy: _gonderiliyor,
            onPressed:
                _gonderiliyor ? null : () => _gonder(epostaDogrulanmis),
          ),
        ],
      ),
    );
  }
}
