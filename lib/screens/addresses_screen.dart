import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/profile_controller.dart';
import '../data/controllers/region_controller.dart';
import '../data/models/account.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'nav_actions.dart';
import 'widgets/region_picker.dart';

/// ADRESİM (HTML vAddr)
///
/// KESİN İŞ KURALI — TEK ADRES:
///  • Kullanıcının yalnızca BİR adres kaydı olur.
///  • Adres yalnız İl / İlçe / Mahalle seçiminden oluşur.
///  • Mevcut kayıt ekranda seçili gelir.
///  • Kullanıcı yalnız mevcut adresi GÜNCELLEYEBİLİR.
///  • Yeni adres ekleme YOK, adres silme YOK.
///  • Ev/İşyeri başlığı YOK, serbest açık adres alanı YOK.
///  • FloatingActionButton YOK, adres geçmişi/kartları YOK.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  // İl SUNUCUDAN gelir; sabit dosya kullanılmaz.
  String _city = '';
  String? _district;
  String? _neighborhood;

  bool _saving = false;
  String? _error;

  /// Kullanıcı alanlara DOKUNDU mu?
  ///
  /// Kayıtlı adres ekrana yalnız kullanıcı henüz bir seçim yapmadıysa
  /// yansıtılır; yaptıysa yazdığı seçim EZİLMEZ.
  bool _kullaniciDegistirdi = false;

  /// Ekrana yansıtılmış son kayıt (tekrar tekrar aynı değeri
  /// yazmamak için).
  String? _sonYansiyan;

  /// Bölge yüklemesi yalnız bir kez planlanır.
  bool _regionYuklemePlanlandi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _kayittanDoldur();
    // ── BÖLGE VERİSİ: İLK KAREDEN SONRA ──
    //
    // `RegionController.load()` ilk `await`ten ÖNCE `notifyListeners()`
    // çağırır. `didChangeDependencies` build aşamasının içinde koştuğu
    // için bu, "setState() or markNeedsBuild() called during build"
    // assertion'ını atıyordu (aynı hata `register_screen`de de vardı).
    // İş kuralı değişmez: yükleme yine ekran açılışında başlar.
    // Çift yükleme iki katmanda engellenir: buradaki bayrak ve
    // `load()` içindeki `_tree != null` + `setBusy` kilidi.
    if (!_regionYuklemePlanlandi) {
      _regionYuklemePlanlandi = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<RegionController>().load();
      });
    }
  }

  /// Kayıtlı adresi alanlara yansıtır.
  ///
  /// ⚠ `context.watch` yalnız `build` içinde çağrılabilir; bu yüzden
  /// `didChangeDependencies` `read`, `build` ise `watch` kullanır.
  /// İkisi de aynı yansıtma mantığını paylaşır.
  void _kayittanDoldur({bool izle = false}) {
    final a = izle
        ? context.watch<ProfileController>().address
        : context.read<ProfileController>().address;
    if (a == null) {
      return;
    }
    final imza = '${a.city}|${a.district}|${a.neighborhood}';
    if (imza == _sonYansiyan || _kullaniciDegistirdi) {
      return;
    }
    _sonYansiyan = imza;
    // Eski kayıtlarda `city` boş olabilir; alan `String` olduğu
    // için mevcut değer korunur (varsayılan aktif il).
    if (a.city.isNotEmpty) {
      _city = a.city;
    }
    _district = a.district.isEmpty ? null : a.district;
    _neighborhood = a.neighborhood.isEmpty ? null : a.neighborhood;
  }

  RegionController get _regions => context.read<RegionController>();

  /// Seçili ilçenin mahalleleri.
  ///
  /// ⚠ İL DE GEÇİLİR: aynı adı taşıyan ilçeler farklı illerde
  /// bulunabilir (ör. "Merkez"). İl verilmezse varsayılan ilin
  /// mahalleleri gelir ve yanlış liste gösterilirdi.
  List<String> get _neighborhoods => _district == null
      ? const []
      : _regions.neighborhoodsOf(_district!,
          city: _city.isNotEmpty ? _city : _regions.cityName);

  /// Seçili kayıt sunucuda PASİFLEŞTİRİLMİŞ olabilir — kullanıcı
  /// uyarılır ve yeniden seçim yapması istenir.
  String? get _staleWarning {
    final r = context.watch<RegionController>();
    if (!r.hasData) {
      return null;
    }
    final il = _city.isNotEmpty ? _city : r.cityName;

    // ⚠ İL DE DENETLENİR: admin bir ili tamamen kapatabilir.
    if (_city.isNotEmpty && !r.isKnownCity(_city)) {
      return 'Seçili il artık hizmet dışı. Lütfen yeniden seçin.';
    }
    if (_district != null && !r.isKnownDistrict(_district!, city: il)) {
      return 'Seçili ilçe artık hizmet dışı. Lütfen yeniden seçin.';
    }
    if (_district != null &&
        _neighborhood != null &&
        !r.isKnownNeighborhood(_district!, _neighborhood!, city: il)) {
      return 'Seçili mahalle artık hizmet dışı. Lütfen yeniden seçin.';
    }
    return null;
  }

  bool get _valid =>
      _district != null &&
      _neighborhood != null &&
      _neighborhood!.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_valid || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final cityName = _city.isNotEmpty
        ? _city
        : (context.read<RegionController>().cityName ?? '');
    final err = await context.read<ProfileController>().saveAddress(
          district: _district!,
          neighborhood: _neighborhood!,
          city: cityName,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _error = err?.message;
    });
    if (err == null) {
      // Kayıt tamamlandı: artık depodaki değer geçerli kabul edilir,
      // dışarıdan gelecek değişiklikler yeniden yansıyabilir.
      _kullaniciDegistirdi = false;
      _sonYansiyan = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresiniz güncellendi')),
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kayıtlı adres her değiştiğinde alanlara yansır (kullanıcı kendi
    // seçimini yapmadıysa). Kayıt sırasında girilen adres bu sayede
    // ekran ilk açıldığında da, sonradan geldiğinde de görünür.
    _kayittanDoldur(izle: true);
    final p = context.watch<ProfileController>();
    final r = context.watch<RegionController>();
    final hasAccount = p.me != null;
    final uyari = _staleWarning;

    return RefShell(
      nav: RefBottomNav(
        activeKey: 'profil',
        items: custNavItems(
          context,
          saglayici:
              context.watch<AuthController>().activeRole == Role.provider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RefPageTitle('Adreslerim'),
          const RefSubtitle(
              'Mevcut adresinizi görüntüleyin ve güncelleyin.'),

          if (!hasAccount)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Adres bilgisi için giriş yapmalısınız.',
                textAlign: TextAlign.center,
                style: refText(
                    size: RF.s14, weight: RF.w400, color: RC.greyLight),
              ),
            )
          else
            RefFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RefCardTitle('Mevcut Adresiniz'),
                  // ⚠ BİLGİLENDİRME KUTUSU KARTTAN ÇIKARILDI.
                  //
                  // Başlık ile seçim satırlarının ARASINA sıkışıyordu:
                  // kullanıcının asıl işi olan üç seçim aşağı itiliyor,
                  // ekranın alt yarısı ise boş kalıyordu. Kutu artık
                  // kartın ALTINDA, o boş alanda duruyor (aşağıya
                  // bakınız). İçerik ve metin DEĞİŞMEDİ; yalnız yeri.
                  //
                  // Sunucu kaydı pasifleştiyse uyarı (iş kuralı korundu).
                  if (uyari != null)
                    RefInfoBox(
                      margin: const EdgeInsets.only(top: 10),
                      child: Text(
                        uyari,
                        style: refText(
                          size: RF.s135,
                          weight: RF.w600,
                          color: RC.danger,
                          height: RF.lh150,
                        ),
                      ),
                    ),
                  // ⚠ İL SEÇİLEBİLİRDİR — TEK İL OLSA BİLE.
                  //
                  // Alan daha önce salt okunurdu. Bugün mock veride
                  // yalnız İzmir bulunuyor; admin/backend yeni bir il
                  // aktif ettiğinde liste KENDİLİĞİNDEN büyür ve
                  // kullanıcı seçebilir — ekran kodu değişmez.
                  RefDropdownField(
                    etiket: 'İl',
                    placeholder: 'Seçiniz',
                    zorunlu: true,
                    value: _city.isNotEmpty ? _city : r.cityName,
                    onTap: _saving ? null : _pickCity,
                  ),
                  // ⚠ Etiketler kaldırılınca dikey aralık
                  // kayboldu; kayıt ekranıyla aynı değer.
                  const SizedBox(height: 12),
                  RefDropdownField(
                    etiket: 'İlçe',
                    placeholder: 'Seçiniz',
                    zorunlu: true,
                    value: _district,
                    onTap: _saving ? null : _pickDistrict,
                  ),
                  // ⚠ Etiketler kaldırılınca dikey aralık
                  // kayboldu; kayıt ekranıyla aynı değer.
                  const SizedBox(height: 12),
                  RefDropdownField(
                    etiket: 'Mahalle',
                    placeholder: 'Seçiniz',
                    zorunlu: true,
                    value: _neighborhood,
                    onTap: (_saving || _district == null)
                        ? null
                        : _pickNeighborhood,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: refText(
                            size: RF.s125,
                            weight: RF.w600,
                            color: RC.danger),
                      ),
                    ),
                  const SizedBox(height: 18), // .po-next{margin-top:18px}
                  RefNextButton(
                    'Adresi Güncelle',
                    iconAsset: 'assets/svg/ic_pen.svg',
                    busy: _saving,
                    onPressed: _valid ? _save : null,
                  ),
                ],
              ),
            ),

          // ── ⚠ BİLGİLENDİRME — KARTIN ALTINDA ──
          //
          // Kart içindeyken başlıkla seçim satırları arasına giriyor
          // ve asıl işi aşağı itiyordu. Burada, ekranın zaten boş olan
          // alt bölümünde duruyor: kullanıcı önce adresini görüyor,
          // açıklamayı sonra okuyor.
          //
          // ⚠ Yalnız hesap VARKEN gösterilir; yoksa üstteki boş durum
          // metni zaten aynı işi yapar.
          if (hasAccount)
            RefInfoBox(
              mavi: true,
              margin: const EdgeInsets.only(top: 14),
              child: Text(
                'Sistemde yalnızca bir adres kaydı bulunabilir. '
                'Adres değişikliği yapmak için bilgilerinizi '
                'güncelleyebilirsiniz.',
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
    );
  }

  /// İL SEÇİMİ.
  ///
  /// ⚠ Liste sunucudan gelen AKTİF illerdir (`cityNames`); koda
  /// gömülü değildir. Admin yeni il eklediğinde burada görünür,
  /// pasifleştirdiğinde listeden düşer.
  ///
  Future<void> _pickCity() async {
    final iller = _regions.cityNames;
    if (iller.isEmpty) {
      return;
    }
    final simdiki = _city.isNotEmpty ? _city : _regions.cityName;
    final sel = await _showPicker(
      title: 'İl Seçin',
      options: iller,
      selected: simdiki,
      searchable: iller.length > 8,
    );
    if (sel == null || sel == simdiki) {
      return;
    }
    setState(() {
      _kullaniciDegistirdi = true;
      _city = sel;
      _district = null;
      _neighborhood = null;
    });
  }

  Future<void> _pickDistrict() async {
    final sel = await _showPicker(
      title: 'İlçe Seçin',
      // ⚠ Seçili İLİN ilçeleri — varsayılan ilin değil.
      options: _regions.districtsOf(
          _city.isNotEmpty ? _city : _regions.cityName),
      selected: _district,
      searchable: true,
    );
    if (sel == null) {
      return;
    }
    setState(() {
      _kullaniciDegistirdi = true;
      _district = sel;
      // İlçe değişince mahalle sıfırlanır (HTML addrSetDistrict davranışı).
      _neighborhood = null;
    });
  }

  Future<void> _pickNeighborhood() async {
    final sel = await _showPicker(
      title: 'Mahalle Seçin',
      options: _neighborhoods,
      selected: _neighborhood,
      searchable: true,
    );
    if (sel == null) {
      return;
    }
    setState(() {
      _kullaniciDegistirdi = true;
      _neighborhood = sel;
    });
  }

  Future<String?> _showPicker({
    required String title,
    required List<String> options,
    String? selected,
    bool searchable = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => RegionPickerSheet(
        title: title,
        options: options,
        selected: selected,
        searchable: searchable,
      ),
    );
  }
}
