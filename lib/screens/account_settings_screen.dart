import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/models/listing.dart';
import '../data/models/offer.dart';
import '../data/remote/api/account_api.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_error_mapper.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../data/repositories/oturum_tercihi.dart';
import '../data/remote/api_config.dart';

/// HESAP AYARLARI — dondurma ve silme talebi
///
/// ── DONDURMA ──
/// Backend hesabı dondurur ve TÜM aktif oturumları iptal eder; uygulama
/// çıkış yapar. Kullanıcı tekrar giriş yaptığında hesabı yeniden aktifleşir.
///
/// ── SİLME ──
/// ⚠ DONDURMA İLE SİLME AYRI İŞLERDİR ve biri ötekinin yerine
/// kullanılamaz: dondurma geçici, silme kalıcıdır.
///
/// Silme ÜÇ AŞAMALIDIR — tek dokunuşla gerçekleşmez:
///   1. Ne olacağının açıklaması → Vazgeç / Devam Et
///   2. ŞİFRE DOĞRULAMASI (kritik işlem kapısı)
///   3. Son kesin onay → Vazgeç / Hesabımı Sil
///
/// ⚠ EKRANDA KULLANILMAYACAK İFADELER: "teklif ve işlem geçmişi
/// silinmez", "kalan bakiye iade edilmez", "kişisel bilgileriniz
/// anonimleştirilir". Bakiye cümlesi ÖZELLİKLE yasaktır — müşteri
/// rolünde cüzdan yoktur; hizmet verendeki finansal kayıtların
/// akıbeti ayrı bir politikadır ve bu ekranda varsayılmaz.
///
/// Metin yalnız şunu söyler: hesaba erişim biter, mevzuat gereği
/// saklanması zorunlu kayıtlar yasal süre boyunca tutulur, hukuki
/// sebebi kalmayan kişisel veriler silinir/yok edilir/anonim hâle
/// getirilir.
///
/// ⚠ Backend şu an yalnız TALEP oluşturuyor; kullanıcıya "hesabınız
/// silindi" DENMEZ ("Hesap silme işleminiz alındı."). Sunucu anında
/// silmeye geçtiğinde metin güncellenir.
///
/// ⚠ TELEFON TEK HESABA BAĞLIDIR: silme hesabın TAMAMINI kapsar,
/// yalnız aktif rolü değil. Bu kural backend'de de böyle olmalıdır.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _requests = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic>? get _pendingDeletion {
    for (final r in _requests) {
      if (r['kind'] == 'DELETE' && r['status'] == 'PENDING') {
        return r;
      }
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // ── ⚠ MOCK MODDA AĞ ÇAĞRISI YAPILMAZ ──
    //
    // Bu ekran port sistemini atlayıp DOĞRUDAN HTTP çağırıyor. Mock
    // modda backend yok; istek 20 saniye timeout'a düşüyor, `GET`
    // olduğu için 2 kez daha deneniyor ve kullanıcı yaklaşık BİR
    // DAKİKA dönen çark görüyordu:
    //
    //   3 deneme × 20sn + geri çekilme ≈ 61 saniye
    //
    // Ekranın geri kalanı (şifre · bildirim · dondurma · silme)
    // zaten çizilmişti; yalnız alttaki çark takılı kalıyordu.
    //
    // ⚠ `app_rate_screen` ile AYNI kalıp: mock modda liste BOŞ kabul
    // edilir ve kullanıcıya hata gösterilmez — ortada hata yok,
    // sunucu yok.
    if (!ApiConfig.useRealApi) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = const [];
        _loading = false;
      });
      return;
    }

    try {
      final api = AccountApi(context.read<ApiClient>());
      final rows = await api.myRequests();
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = rows.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Hesap bilgileri yüklenemedi.';
      });
    }
  }

  // ── DONDURMA ──────────────────────────────────────────────────────────
  /// ⚠ ONAY BURADA SORULMAZ: kararı `_dondurPaneli` aldı.
  ///
  /// Eskiden panel "Devam Et" dedikten sonra BİR ONAY EKRANI daha
  /// açılıyordu; kullanıcı aynı şeyi iki kez onaylıyordu.
  Future<void> _freeze() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // ⚠ MOCK MODDA AĞ ÇAĞRISI YAPILMAZ (proje kuralı): backend
      // yokken istek 20sn timeout'a düşer ve ekran donmuş görünür.
      // Akış birebir aynı yürütülür, yalnız sunucu adımı atlanır —
      // API bağlandığında UI davranışı DEĞİŞMEZ.
      if (ApiConfig.useRealApi) {
        final api = AccountApi(context.read<ApiClient>());
        await api.freeze();
      }
      if (!mounted) {
        return;
      }
      sysToastOk(context, 'Hesabınız donduruldu');
      // Sunucu oturumları iptal etti; yerel oturum da temizlenir.
      // ⚠ CİHAZ HATIRLAMASI DA SİLİNİR.
      //
      // "Beni Hatırla" işaretliyken çıkış yapan kullanıcı bir
      // daha otomatik giriş YAPMAMALIDIR; aksi hâlde çıkış
      // düğmesi hiçbir işe yaramaz.
      // ⚠ CONTROLLER `await`'TEN ÖNCE ALINIR.
      //
      // `OturumTercihi().temizle()` diskten okur; o sırada widget
      // ağaçtan kalkabilir ve `context.read` çöker.
      final auth = context.read<AuthController>();
      await OturumTercihi().temizle();
      await auth.logout();
      if (!mounted) {
        return;
      }
      // HTML sözleşmesi: oturum sona erdiğinde hedef HOME'dur.
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        // ⚠ SUNUCUNUN GEREKÇESİ GİZLENMEZ.
        //
        // "Devam eden işleminiz var" gibi bir engel varsa kullanıcı
        // ne yapacağını ancak o cümleden anlar; genel hata onu
        // çaresiz bırakıyordu.
        _error = _sunucuGerekcesi(e) ??
            'Hesap dondurulamadı. Lütfen tekrar deneyin.';
      });
    }
  }

  /// Sunucudan gelen okunabilir gerekçe; yoksa `null`.
  String? _sunucuGerekcesi(Object e) {
    if (e is ApiFailure) {
      final m = e.error.message.trim();
      if (m.isNotEmpty) {
        return m;
      }
    }
    return null;
  }

  // ── SİLME TALEBİ ──────────────────────────────────────────────────────
  /// ⚠ ONAY VE DOĞRULAMA BURADA SORULMAZ.
  ///
  /// Üç aşamalı akışın tamamı `_silmePaneli` içindedir: açıklama →
  /// şifre doğrulaması → son kesin onay. Buraya gelindiğinde karar
  /// verilmiş demektir.
  ///
  /// ⚠ ESKİ METİN KALDIRILDI: "kalan bakiyeniz iade edilmez",
  /// "teklif ve işlem geçmişiniz korunur", "anonimleştirilir"
  /// maddeleri artık gösterilmiyor — bakiye ifadesi müşteri
  /// rolünde karşılığı olmayan bir varsayımdı.
  Future<void> _requestDeletion() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // ⚠ MOCK MODDA AĞ ÇAĞRISI YAPILMAZ — akış aynen yürür.
      if (ApiConfig.useRealApi) {
        final api = AccountApi(context.read<ApiClient>());
        await api.requestDeletion();
      }
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      // ⚠ "HESABINIZ SİLİNDİ" DENMEZ.
      //
      // Backend şu an yalnız TALEP oluşturuyor; hesap o anda
      // silinmiyor. Kullanıcıya olmayan bir sonucu bildirmek
      // yanlış olurdu. Sunucu anında silmeye geçtiğinde metin
      // "Hesabınız silindi." olarak güncellenecektir.
      //
      // ⚠ SÜRE BİLDİRİMİ ZORUNLUDUR (30 GÜN — ürün taahhüdü).
      //
      // Apple'ın hesap silme kuralı, silmenin elle veya zaman alarak
      // yapılmasını KABUL EDER; ancak iki şart koşar: kullanıcıya
      // NE KADAR SÜRECEĞİ bildirilmeli ve tamamlandığında ONAY
      // verilmelidir. Birincisi buradadır.
      //
      // ⚠ İKİNCİSİ HENÜZ YOK: silme tamamlandığında kullanıcıya
      // bildirim/e-posta gönderilmesi BACKEND işidir ve bu pakette
      // YAPILMAMIŞTIR.
      sysToastOk(
        context,
        'Hesap silme işleminiz alındı. Hesabınız, talebinizden '
        'itibaren 30 gün içinde kalıcı olarak silinecektir.',
      );

      // ── OTURUM KAPATILIR ──
      //
      // Silme süreci başlatıldıktan sonra kullanıcı uygulamada
      // dolaşmaya devam etmez. Talebini iptal etmek isterse tekrar
      // giriş yapıp bu ekrandan iptal edebilir (hesap henüz
      // silinmediği için giriş çalışır).
      final auth = context.read<AuthController>();
      await OturumTercihi().temizle();
      await auth.logout();
      if (!mounted) {
        return;
      }
      // ── ⚠ YÖNLENDİRME BİR SONRAKİ KAREDE ──
      //
      // Silme akışı ÜÇ alt panel açıyor (açıklama → şifre → son
      // onay); dondurma akışında hiç panel yok. Son panelin kapanma
      // animasyonu bitmeden tüm rota yığınını silmek, ağaçtan kalkan
      // öğelerin hâlâ bağımlısı olmasına yol açıyor ve çerçeve
      // doğrulaması patlıyordu (`_dependents.isEmpty`) — ekran
      // kırmızıya dönüyordu.
      //
      // ⚠ Davranış DEĞİŞMEDİ: hedef yine `/home` ve yığın yine
      // tamamen temizleniyor; yalnız SIRA güvenli hale geldi.
      final gezgin = Navigator.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        gezgin.pushNamedAndRemoveUntil('/home', (r) => false);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = _sunucuGerekcesi(e) ??
            'Talep oluşturulamadı. Bekleyen bir talebiniz olabilir.';
      });
      await _load();
    }
  }

  Future<void> _cancelDeletion() async {
    setState(() => _busy = true);
    try {
      // ⚠ MOCK MODDA AĞ ÇAĞRISI YAPILMAZ — proje kuralı, İSTİSNASIZ.
      //
      // Bu düğme mock modda zaten görünmez (talep listesi yalnız
      // sunucudan dolar), ama kural "ulaşılamıyorsa muaf" demez:
      // ekranın öteki iki çağrısı korumalıyken burasının açıkta
      // kalması, listeyi yerel üreten ilk değişiklikte 61 saniyelik
      // donmaya dönüşürdü.
      if (ApiConfig.useRealApi) {
        final api = AccountApi(context.read<ApiClient>());
        await api.cancelDeletion();
      }
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      sysToastOk(context, 'Talebiniz geri çekildi');
      await _load();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Talep geri çekilemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingDeletion;

    return Scaffold(
      backgroundColor: HC.bg,
      // AppBar KALDIRILDI — referansta yok (başlık sayfa içinde).
      body: SafeArea(
        // ⚠ EKRAN ANINDA AÇILIR.
        //
        // Eskiden TÜM sayfa `_load()` bitene kadar boş bir çarkla
        // bekliyordu; oysa o çağrı yalnız SİLME TALEPLERİ listesini
        // getiriyor. Bildirim tercihleri, şifre değiştirme, dondurma
        // ve silme hiçbirinin o veriye ihtiyacı yok.
        //
        // Artık sayfa hemen çizilir; bekleme yalnız talep bölümünde
        // görünür.
        child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  // ⚠ GERİ OKU HER PLATFORMDA VARDIR (nihai karar).
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: RefBackButton(),
                  ),
                  const SizedBox(height: 6),
                  if (_error != null) ...[
                    Text(_error!,
                        style: const TextStyle(color: HC.red, fontSize: 13)),
                    const SizedBox(height: 12),
                  ],

                  // ── Bekleyen silme talebi ──
                  if (pending != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6E5),
                        border: Border.all(color: const Color(0xFFF6D9A8)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              RefSvg('assets/svg/ic_nclock.svg', size: 18, color: const Color(0xFFF5820C)),
                              SizedBox(width: 8),
                              Text('Silme talebiniz değerlendirmede',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: HC.dark)),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                              'Talep tarihi: ${_fmt(pending['requestedAt'])}',
                              style: const TextStyle(
                                  fontSize: 12.5, color: HC.grey),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _busy ? null : _cancelDeletion,
                                child: const Text('Talebi Geri Çek'),
                              ),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // ── BİLDİRİM TERCİHLERİ ──
                  //
                  // ⚠ Güvenlik ve hesap durumu bildirimleri (şifre
                  // değişikliği, hesap askıya alma) BURADA YOKTUR:
                  // onlar tercihe bağlı değildir, kapatılamaz.
                  //
                  // ⚠ SAYFA ÜÇ BAŞLIK ALTINDA TOPLANIR: Güvenlik,
                  // Bildirimler, Hesap. Kartlar başlıksız sıralanınca
                  // kullanıcı neyin nerede olduğunu aramak zorunda
                  // kalıyordu.
                  const _Bolum('Güvenlik'),
                  _SatirKart(
                    ikon: 'assets/svg/ic_plock.svg',
                    zemin: const Color(0xFFEFF3FA),
                    renk: RC.blue,
                    baslik: 'Şifre Değiştir',
                    aciklama: 'Hesap şifrenizi güncelleyin.',
                    onTap: _busy
                        ? null
                        : () => Navigator.pushNamed(context, '/profile/password'),
                  ),

                  const _Bolum('Bildirimler'),
                  _bildirimKarti(),

                  const _Bolum('Hesap'),

                  // ── DÖRT KART AYNI DÜZENDE ──
                  //
                  // ⚠ UZUN AÇIKLAMALAR KARTTAN ÇIKARILDI.
                  //
                  // Dondurma ve silme kartları ekranda sürekli duran
                  // 3-5 satırlık metinler taşıyordu; sayfa okunamaz
                  // hâle geliyor, kartlar farklı yüksekliklerde
                  // duruyordu.
                  //
                  // Metin artık karta dokununca açılan ALT PANELDE
                  // gösterilir — kullanıcı onu tam karar anında okur.
                  _SatirKart(
                    ikon: 'assets/svg/ic_nclock.svg',
                    zemin: const Color(0xFFFDF3E1),
                    renk: HC.orange,
                    baslik: 'Hesabı Dondur',
                    aciklama: 'Hesabınızı geçici olarak kullanıma kapatın.',
                    onTap: _busy ? null : _dondurPaneli,
                  ),

                  if (pending == null)
                    _SatirKart(
                      ikon: 'assets/svg/ic_trash.svg',
                      zemin: const Color(0xFFFDECEC),
                      renk: HC.red,
                      // ⚠ AD DEĞİŞTİ: "Hesap Silme Talebi" → "Hesabı Sil".
                      //
                      // Kullanıcı tarafında iş, hesabın silinmesidir;
                      // "talep" sözcüğü iç süreci anlatıyor ve
                      // dondurmayla karışmasına yol açıyordu.
                      baslik: 'Hesabı Sil',
                      aciklama: 'Hesabınızı ve silinebilecek kişisel '
                          'verilerinizi kalıcı olarak silin.',
                      onTap: _busy ? null : _silmePaneli,
                    ),

                  const SizedBox(height: 20),
                  // ⚠ BEKLEME YALNIZ BU BÖLÜMDE.
                  //
                  // Sayfa anında açılır; talep listesi gelene kadar
                  // burada küçük bir gösterge döner. `_loading` alanı
                  // bunun için tutulur — okunmadığında analiz uyarı
                  // veriyordu ve bekleme hiç görünmüyordu.
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 18),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_requests.isNotEmpty) ...[
                    const Text('Taleplerim',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: HC.dark)),
                    const SizedBox(height: 8),
                    ..._requests.map(_requestRow),
                  ],
                ],
              ),
      ),
    );
  }

  /// Bildirim tercihleri kartı — anahtar değişince ANINDA kaydedilir.
  ///
  /// ⚠ Ayrı bir "Kaydet" düğmesi YOKTUR: tek dokunuşluk tercihte
  /// kaydetme adımı unutulur ve kullanıcı değişikliğin geçtiğini
  /// sanır. Değişiklik hemen yazılır.
  /// ── ONAY PANELİ — dondurma / silme ──
  ///
  /// ⚠ Uzun açıklama BURADA gösterilir, kartta değil.
  /// ── İKİ DÜĞMELİ ONAY PANELİ ──
  ///
  /// Sırala/Filtreler panelleriyle aynı bileşen (`RefBottomSheet`)
  /// kullanılır; kullanıcı alışkın olduğu bir kalıpla karşılaşır.
  ///
  /// ⚠ İKİ DÜĞME ZORUNLU: "Vazgeç" ile birincil eylem YAN YANA
  /// durur. Tek düğmeli panelde vazgeçmenin tek yolu paneli
  /// kaydırıp kapatmaktı; kritik işlemlerde bu yeterli değildir.
  ///
  /// Panel yalnız METNİ ve DÜĞMEYİ taşır; asıl iş çağıran taraftadır.
  Future<bool> _onayPaneli({
    required String baslik,
    required String aciklama,
    required String onayMetni,
    required Color renk,
  }) async {
    final kabul = await RefBottomSheet.goster<bool>(
      context,
      title: baslik,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(aciklama,
              style: refText(
                  size: RF.s135,
                  weight: RF.w400,
                  color: RC.textDark,
                  height: RF.lh155)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RC.textSoft,
                    side: const BorderSide(color: RC.border, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RR.r12),
                    ),
                  ),
                  child: Text('Vazgeç',
                      style: refText(
                          size: RF.s14, weight: RF.w700, color: RC.textSoft)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: renk,
                    side: BorderSide(color: renk, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RR.r12),
                    ),
                  ),
                  child: Text(onayMetni,
                      textAlign: TextAlign.center,
                      style: refText(
                          size: RF.s14, weight: RF.w700, color: renk)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return kabul == true && mounted;
  }

  /// ── HESABI DONDUR ──
  ///
  /// ⚠ DONDURMA SİLME DEĞİLDİR. Geçici bir işlemdir; hesabı ve
  /// kişisel verileri SİLMEZ. Metin bunu açıkça söyler, yoksa
  /// kullanıcı iki kartı birbirinin yerine kullanır.
  ///
  /// Akış: açıklama → Vazgeç / Hesabı Dondur → dondurma → oturum
  /// kapatma. Ek onay ekranı YOKTUR (geri alınabilir bir işlemde
  /// üst üste iki soru sormak kullanıcıyı yorar).
  Future<void> _dondurPaneli() async {
    // ── ⚠ DEVAM EDEN İŞ DENETİMİ ──
    //
    // Dondurma, kullanıcıyı sistemin dışına çıkarır: açık ilanına
    // gelen teklifi göremez, seçtiği ustayla yazışamaz, verdiği
    // teklifin sonucunu izleyemez. Karşı taraf ise cevapsız kalır.
    //
    // ⚠ SON SÖZ SUNUCUNUNDUR — burada YEREL veriye bakılır ve
    // kullanıcı boşuna panel açmasın diye ERKEN uyarılır. Sunucu
    // aynı engeli koyduğunda gerekçesi `_freeze` içinde gösterilir.
    final engel = _devamEdenIsVar();
    if (engel) {
      setState(() => _error =
          'Hesabınızı dondurabilmek için devam eden işlemlerinizi '
          'tamamlamanız gerekiyor.');
      return;
    }
    final ok = await _onayPaneli(
      baslik: 'Hesabı Dondur',
      aciklama: 'Hesabınız geçici olarak dondurulacaktır. Bu işlem '
          'hesabınızı veya kişisel verilerinizi silmez. Hesabınızı '
          'yeniden etkinleştirene kadar HizmetCep hizmetlerini '
          'kullanamazsınız.',
      onayMetni: 'Hesabı Dondur',
      renk: HC.orange,
    );
    if (!ok) {
      return;
    }
    await _freeze();
  }

  /// Kullanıcının SONUÇLANMAMIŞ işi var mı?
  ///
  /// Sayılanlar:
  ///   · sahibi olduğu ve hâlâ yaşayan ilanlar (açık · usta seçilmiş ·
  ///     devam eden),
  ///   · hizmet veren olarak verdiği ve hâlâ geçerli teklifler
  ///     (aktif · seçilmiş).
  ///
  /// Tamamlanmış, iptal edilmiş ve süresi dolmuş kayıtlar engel
  /// DEĞİLDİR: onlarda karşı tarafın beklediği bir şey kalmamıştır.
  bool _devamEdenIsVar() {
    final me = context.read<AuthController>().currentAccount;
    if (me == null) {
      return false;
    }
    const canliIlan = {
      ListingStatus.open,
      ListingStatus.providerSelected,
      ListingStatus.inProgress,
    };
    final ilanlar = context.read<ListingController>().byOwner(me.id);
    if (ilanlar.any((l) => canliIlan.contains(l.status))) {
      return true;
    }
    const canliTeklif = {OfferStatus.active, OfferStatus.selected};
    final teklifler = context.read<OfferController>().offersByProvider(me.id);
    return teklifler.any((o) => canliTeklif.contains(o.status));
  }

  /// ── HESABI SİL ──
  ///
  /// Akış ÜÇ AŞAMALIDIR ve tek dokunuşla silinmez:
  ///   1. Ne olacağının açıklaması → Vazgeç / Devam Et
  ///   2. ŞİFRE DOĞRULAMASI (kritik işlem kapısı)
  ///   3. Son kesin onay → Vazgeç / Hesabımı Sil
  ///
  /// ⚠ METİNDE OLMAYACAKLAR: "teklif ve işlem geçmişi silinmez",
  /// "kalan bakiye iade edilmez", "kişisel bilgileriniz
  /// anonimleştirilir". Bakiye ifadesi ÖZELLİKLE yasaktır: müşteri
  /// rolünde cüzdan yoktur, hizmet verende ise finansal kayıtların
  /// akıbeti ayrı bir politikadır — bu ekranda varsayım yazılmaz.
  Future<void> _silmePaneli() async {
    final devam = await _onayPaneli(
      baslik: 'Hesabı Sil',
      aciklama: 'Hesabınızın silinmesi için işlem başlatılacaktır. '
          'Hesabınız silindikten sonra hesabınıza erişemezsiniz.\n\n'
          'Mevzuat gereği saklanması zorunlu kayıtlar, ilgili yasal '
          'saklama süreleri boyunca tutulur. Saklanmasını gerektiren '
          'hukuki sebep bulunmayan kişisel verileriniz silinir, yok '
          'edilir veya anonim hâle getirilir.',
      onayMetni: 'Devam Et',
      renk: HC.red,
    );
    if (!devam) {
      return;
    }

    // ── 2. AŞAMA: KİMLİK DOĞRULAMASI ──
    final dogrulandi = await _sifreDogrula();
    if (!dogrulandi || !mounted) {
      return;
    }

    // ── 3. AŞAMA: SON KESİN ONAY ──
    final kesin = await _onayPaneli(
      baslik: 'Hesabımı Sil',
      aciklama: 'Hesabınızı silmek istediğinize emin misiniz?\n\n'
          'Bu işlem hesabınızı kalıcı olarak kapatır ve geri alınamaz.',
      onayMetni: 'Hesabımı Sil',
      renk: HC.red,
    );
    if (!kesin) {
      return;
    }
    await _requestDeletion();
  }

  /// ŞİFRE DOĞRULAMA PANELİ.
  ///
  /// ⚠ Hesap silme doğrulamasız yapılmaz: açık bırakılmış bir
  /// telefonda üç dokunuşla hesap kapatılabilirdi.
  ///
  /// Doğrulama kararı sunucunundur (`AuthController.verifyPassword`);
  /// ekran şifreyi SAKLAMAZ, yalnız iletir.
  Future<bool> _sifreDogrula() async {
    final ctl = TextEditingController();
    final hataNot = ValueNotifier<String?>(null);
    // ⚠ Alan dolu mu? Düğmenin aktifliği buna bağlı.
    final doluNot = ValueNotifier<bool>(false);
    var dogru = false;
    try {
      await RefBottomSheet.goster<void>(
        context,
        title: 'Kimliğinizi Doğrulayın',
        child: StatefulBuilder(
          builder: (c, yenile) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hesabınızı silmeden önce güvenlik için şifrenizi '
                'girin.',
                style: refText(
                    size: RF.s135,
                    weight: RF.w400,
                    color: RC.textDark,
                    height: RF.lh155),
              ),
              const SizedBox(height: 14),
              // ── ⚠ ORTAK FORM STANDARDI ──
              //
              // İki ihlal vardı:
              //   1. Yanlış şifre uyarısı, alan SİLİNDİKTEN sonra da
              //      ekranda kalıyordu.
              //   2. Alan boşken düğmeye basılabiliyor ve "Şifrenizi
              //      giriniz" uyarısı çıkıyordu — oysa kural: boş
              //      alanda uyarı YOK, düğme PASİF.
              //
              // Değer değişince uyarı düşer; düğme doluluk denetimine
              // bağlanır (aşağıda).
              ValueListenableBuilder<String?>(
                valueListenable: hataNot,
                builder: (_, hata, __) => TextField(
                  controller: ctl,
                  obscureText: true,
                  autofocus: true,
                  onChanged: (_) {
                    if (hataNot.value != null) {
                      hataNot.value = null;
                    }
                    doluNot.value = ctl.text.trim().isNotEmpty;
                  },
                  decoration: InputDecoration(
                    hintText: 'Şifreniz',
                    errorText: hata,
                    errorMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: doluNot,
                builder: (_, dolu, __) => OutlinedButton(
                onPressed: !dolu
                    ? null
                    : () async {
                  final err = await c
                      .read<AuthController>()
                      .verifyPassword(ctl.text);
                  if (err != null) {
                    hataNot.value = err.message;
                    return;
                  }
                  dogru = true;
                  if (c.mounted) {
                    Navigator.of(c).pop();
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: HC.red,
                  side: const BorderSide(color: HC.red, width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RR.r12),
                  ),
                ),
                child: Text('Doğrula',
                    style: refText(
                        size: RF.s14, weight: RF.w700, color: HC.red)),
              )),
            ],
          ),
        ),
      );
    } finally {
      // ⚠ NOTIFIER'LAR BİR SONRAKİ KAREDE BIRAKILIR.
      //
      // Panel kapanma animasyonu sürerken `ValueListenableBuilder`
      // öğeleri hâlâ ağaçta ve bu notifier'ları dinliyor olabilir.
      // Hemen `dispose` çağrılınca dinleyicisi olan bir nesne
      // kapatılıyor ve ağaç yıkımı sırasında çerçeve doğrulaması
      // patlıyordu (`_dependents.isEmpty`).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctl.dispose();
        hataNot.dispose();
        doluNot.dispose();
      });
    }
    return dogru;
  }

  Widget _bildirimKarti() {
    final acc = context.watch<AuthController>().currentAccount;
    if (acc == null) {
      return const SizedBox.shrink();
    }
    final auth = context.read<AuthController>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: RC.border),
        borderRadius: BorderRadius.circular(RR.r14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3FA),
                borderRadius: BorderRadius.circular(RR.r10),
              ),
              alignment: Alignment.center,
              child: const RefSvg('assets/svg/ic_nbell.svg',
                  size: 17, color: RC.blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Bildirim Tercihleri',
                  style: refText(
                      size: RF.s15, weight: RF.w800, color: RC.text)),
            ),
          ]),
          // ⚠ Açıklama satırı KALDIRILDI: kart yüksekliğini
          // diğerlerinden ayırıyordu ve her açılışta okunması gereken
          // bir bilgi değildi.
          const SizedBox(height: 8),
          _bildirimSatiri('Yeni teklifler', acc.bildirimTeklif,
              (v) => auth.setNotificationPrefs(teklif: v)),
          _bildirimSatiri('Mesajlar', acc.bildirimMesaj,
              (v) => auth.setNotificationPrefs(mesaj: v)),
          _bildirimSatiri('Duyurular ve kampanyalar', acc.bildirimDuyuru,
              (v) => auth.setNotificationPrefs(duyuru: v)),
          _bildirimSatiri('E-posta ile bilgilendirme', acc.bildirimEposta,
              (v) => auth.setNotificationPrefs(eposta: v)),
        ],
      ),
    );
  }

  Widget _bildirimSatiri(String etiket, bool acik, ValueChanged<bool> ayarla) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(etiket,
                  style: refText(
                      size: RF.s135, weight: RF.w600, color: RC.text)),
            ),
            // ⚠ MATERIAL `Switch` KULLANILMIYOR.
            //
            // `activeColor` / `activeThumbColor` adlandırması Flutter
            // sürümleri arasında değişti; CI "stable" kanalını
            // kullandığı için hangi adın geçerli olduğu derleme anında
            // belli olur. Sürüme bağlı bir API'ye bel bağlamak yerine
            // anahtar projenin kendi bileşenleriyle çizilir — görünüm
            // de uygulamanın geri kalanıyla tutarlı olur.
            RefTap(
              onTap: _busy ? null : () => ayarla(!acik),
              borderRadius: BorderRadius.circular(RR.circle),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                width: 46,
                height: 27,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: acik ? RC.blue : const Color(0xFFD3D8E0),
                  borderRadius: BorderRadius.circular(RR.circle),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  alignment:
                      acik ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 21,
                    height: 21,
                    decoration: const BoxDecoration(
                      color: RC.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  // ⚠ `_card` KALDIRILDI.
  //
  // Dondurma ve silme artık `_SatirKart` kullanıyor; uzun
  // açıklama ve düğme alt panele taşındı. Bu yardımcı
  // çağrılmaz oldu.

  Widget _requestRow(Map<String, dynamic> r) {
    final kind = r['kind'] == 'FREEZE' ? 'Dondurma' : 'Silme talebi';
    final status = switch (r['status'] as String? ?? '') {
      'PENDING' => 'Değerlendirmede',
      'APPROVED' => 'Onaylandı',
      'REJECTED' => 'Reddedildi',
      'COMPLETED' => 'Tamamlandı',
      'CANCELLED' => 'Geri çekildi',
      _ => '—',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          child: Text('$kind · ${_fmt(r['requestedAt'])}',
              style: const TextStyle(fontSize: 13, color: HC.dark)),
        ),
        Text(status,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: HC.grey)),
      ]),
    );
  }

  String _fmt(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) {
      return '—';
    }
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.${l.year}';
  }
}

/// Bölüm başlığı — `Güvenlik` / `Bildirimler` / `Hesap`.
///
/// ⚠ Kartlar başlıksız sıralanınca kullanıcı neyin nerede olduğunu
/// aramak zorunda kalıyordu. Başlıklar sayfayı üç net parçaya böler.
class _Bolum extends StatelessWidget {
  const _Bolum(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(metin,
            style: refText(size: RF.s135, weight: RF.w800, color: RC.textSoft)),
      );
}

/// Tek satırlık dokunulabilir kart — `Şifre Değiştir` gibi
/// başka bir ekrana götüren girişler için.
class _SatirKart extends StatelessWidget {
  const _SatirKart({
    required this.ikon,
    required this.zemin,
    required this.renk,
    required this.baslik,
    required this.aciklama,
    required this.onTap,
  });

  final String ikon;
  final Color zemin;
  final Color renk;
  final String baslik;
  final String aciklama;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RefTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RR.r14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RC.white,
            border: Border.all(color: RC.border),
            borderRadius: BorderRadius.circular(RR.r14),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: zemin,
                  borderRadius: BorderRadius.circular(RR.r10),
                ),
                alignment: Alignment.center,
                child: RefSvg(ikon, size: 17, color: renk),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(baslik,
                        style: refText(
                            size: RF.s15, weight: RF.w800, color: RC.text)),
                    const SizedBox(height: 2),
                    Text(aciklama,
                        style: refText(
                            size: RF.s125,
                            weight: RF.w400,
                            color: RC.textSoft)),
                  ],
                ),
              ),
              const RefSvg('assets/svg/ic_chev.svg',
                  size: 16, color: Color(0xFFD3D8E0)),
            ],
          ),
        ),
      );
}
