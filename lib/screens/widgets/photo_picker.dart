import 'dart:async';
import '../../data/remote/api_config.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../data/remote/api/storage_api.dart';
import '../../ui/ref_widgets.dart';
import '../../ui/ref_tokens.dart';
import 'fotograf_kaynak_paneli.dart';
import '../../core/platform/yerel_gorsel.dart';

/// İLAN FOTOĞRAFI SEÇİCİ
///
/// Kurallar (backend politikasıyla BİREBİR aynı):
///  • En fazla [maxPhotos] fotoğraf
///  • İzinli türler: jpeg / png / webp
///  • En fazla 10 MB
///
/// Yükleme başarılı olmadan ilan kaydedilmez: dışarıya yalnız
/// SUNUCUDAN alınan `storageRef` değerleri verilir. Yerel dosya yolu
/// veya geçici URL asla ilan verisine yazılmaz.
class PhotoItem {
  final String localPath;
  final int sizeBytes;
  final String contentType;

  /// Sunucudan alınan kalıcı referans (yükleme başarılıysa dolu).
  String? storageRef;

  /// Yükleme durumu.
  bool uploading;
  String? error;

  /// Sunucudan iptal (discard) isteği sürüyor mu?
  bool discarding = false;

  /// İptal başarısız olduysa gösterilecek mesaj (kullanıcı tekrar dener).
  String? discardError;

  /// ── ⚠ REFERANS YEREL Mİ? ──
  ///
  /// Mock modda sunucu yoktur; referans olarak dosyanın kendi yolu
  /// kullanılır. Böyle bir referansın sunucuda karşılığı YOKTUR:
  /// iptal isteği göndermek anlamsızdır ve zaman aşımına kadar asılı
  /// kalır.
  ///
  /// ⚠ Ayrım `ApiConfig` ile YAPILMAZ: testler mock modda çalışır ama
  /// sahte SUNUCU referansları kullanır ve iptal yolunun gerçekten
  /// çağrıldığını doğrular. Karar referansın kendisine bakılarak
  /// verilir.
  bool yerelRef = false;

  /// İlana bağlandıysa artık iptal edilemez (yalnız ilan silinerek gider).
  bool attached = false;

  PhotoItem({
    required this.localPath,
    required this.sizeBytes,
    required this.contentType,
    this.storageRef,
    this.uploading = false,
    this.error,
  });

  bool get isUploaded => storageRef != null && storageRef!.isNotEmpty;
}

const int kMaxListingPhotos = 5;
const int kMaxPhotoBytes = 10 * 1024 * 1024;
const List<String> kAllowedPhotoTypes = ['image/jpeg', 'image/png', 'image/webp'];

/// Dosya uzantısından MIME türü. Bilinmeyen uzantı → null (reddedilir).
String? contentTypeOf(String path) {
  final p = path.toLowerCase();
  if (p.endsWith('.jpg') || p.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (p.endsWith('.png')) {
    return 'image/png';
  }
  if (p.endsWith('.webp')) {
    return 'image/webp';
  }
  return null;
}

/// Seçilen dosyanın MIME türü — WEB DAHİL.
///
/// ── ⚠ WEB'DE `path` BİR BLOB ADRESİDİR ──
///
/// `image_picker` web'de `XFile.path` olarak `blob:https://…/uuid`
/// döndürür; bu adreste UZANTI YOKTUR. Tür yalnız uzantıdan
/// türetildiği için `contentTypeOf` `null` dönüyor ve seçilen HER
/// fotoğraf "Yalnızca JPG, PNG ve WEBP dosyaları yüklenebilir"
/// diyerek reddediliyordu — web'de ilan fotoğrafı hiç eklenemiyordu.
///
/// ⚠ SIRA ÖNEMLİ:
///   1. `mimeType` — tarayıcı dosyanın gerçek türünü bildirir;
///      en güvenilir kaynak budur.
///   2. `name` — özgün dosya adı, uzantısıyla birlikte gelir
///      (web'de de doludur).
///   3. `path` — mobildeki bugünkü davranış, aynen korunur.
///
/// ⚠ ALLOWLIST DEĞİŞMEDİ: `mimeType` tarayıcıdan gelse bile
/// `kAllowedPhotoTypes` dışındaki tür reddedilir.
///
/// ⚠ GERÇEK DOĞRULAMA SUNUCUNUNDUR: hem uzantı hem tarayıcının
/// bildirdiği tür istemci verisidir ve değiştirilebilir. Sunucu
/// dosyanın sihirli baytlarına bakmalıdır.
String? fotografTuru(XFile x) {
  final bildirilen = x.mimeType?.toLowerCase().trim();
  if (bildirilen != null && kAllowedPhotoTypes.contains(bildirilen)) {
    return bildirilen;
  }
  return contentTypeOf(x.name) ?? contentTypeOf(x.path);
}

/// Seçilen dosyayı politikaya göre doğrular. Uygunsa null döner.
String? validatePhoto({required String path, required int sizeBytes}) {
  final type = contentTypeOf(path);
  if (type == null || !kAllowedPhotoTypes.contains(type)) {
    return 'Yalnızca JPG, PNG ve WEBP dosyaları yüklenebilir';
  }
  return validatePhotoTur(tur: type, sizeBytes: sizeBytes);
}

/// Türü ZATEN çözülmüş dosya için boyut denetimi.
///
/// ⚠ `validatePhoto` İLE AYNI KURALLAR: iki ayrı eşik tutmamak için
/// boyut denetimi tek yerde. `validatePhoto` de buraya devreder.
String? validatePhotoTur({required String? tur, required int sizeBytes}) {
  if (tur == null || !kAllowedPhotoTypes.contains(tur)) {
    return 'Yalnızca JPG, PNG ve WEBP dosyaları yüklenebilir';
  }
  if (sizeBytes <= 0) {
    return 'Dosya okunamadı';
  }
  if (sizeBytes > kMaxPhotoBytes) {
    return 'Dosya boyutu en fazla ${kMaxPhotoBytes ~/ 1048576} MB olabilir';
  }
  return null;
}

class ListingPhotoPicker extends StatefulWidget {
  final List<PhotoItem> photos;
  final StorageApi storage;
  final ValueChanged<List<PhotoItem>> onChanged;
  final bool enabled;

  /// BACKEND'E YÜKLEME AÇIK MI?
  ///
  /// ⚠ Kayıt öncesi (oturumsuz) akışta `false` verilir: kullanıcının
  /// yükleme yetkisi yoktur. Fotoğraf yalnız cihazda tutulur ve
  /// yükleme kayıt tamamlandıktan SONRA yapılır.
  /// ⚠ SADE MOD — referans `vPost2` görünümü.
  ///
  /// Başlık ("Fotoğraflar 0/5") ve biçim satırı ("JPG, PNG veya
  /// WEBP…") GİZLENİR; yerine geniş kesikli "Fotoğraf ekle" kutusu
  /// çizilir. Diğer ekranlar varsayılan görünümü kullanmaya devam eder.
  final bool sade;

  final bool uploadEnabled;

  const ListingPhotoPicker({
    super.key,
    required this.photos,
    required this.storage,
    required this.onChanged,
    this.enabled = true,
    this.uploadEnabled = true,
    this.sade = false,
  });

  @override
  State<ListingPhotoPicker> createState() => _ListingPhotoPickerState();
}

class _ListingPhotoPickerState extends State<ListingPhotoPicker> {
  final _picker = ImagePicker();

  bool get _full => widget.photos.length >= kMaxListingPhotos;

  /// ── ⚠ EBEVEYNE HER ZAMAN KOPYA GÖNDERİLİR ──
  ///
  /// `create_listing_screen` geri çağrısı şudur:
  ///
  ///     onChanged: (next) => setState(() {
  ///       _photos..clear()..addAll(next);
  ///     })
  ///
  /// Buradan `widget.photos` NESNESİNİN KENDİSİ gönderilirse `next` ile
  /// hedef AYNI listedir: `clear()` listeyi boşaltır, ardından `addAll`
  /// artık boş olan listeyi ekler — TÜM FOTOĞRAFLAR SİLİNİR.
  ///
  /// Galeriden seçilen fotoğrafın ekranda hiç görünmemesinin nedeni
  /// buydu: seçim listeye doğru ekleniyor, hemen ardından çalışan
  /// yükleme bildirimi listeyi sıfırlıyordu. Aynı yol API modundaki
  /// başarılı yüklemede ve yerel referanslı kaldırmada da geçiliyordu
  /// (kaldırmada bir fotoğrafı silmek hepsini siliyordu).
  ///
  /// ⚠ Ebeveyne giden her bildirim bu geçitten geçer. `widget.onChanged`
  /// doğrudan çağrılmaz.
  void _bildir(List<PhotoItem> liste) => widget.onChanged(List.of(liste));

  Future<void> _pick(ImageSource source) async {
    if (!widget.enabled || _full) {
      return;
    }
    try {
      final remaining = kMaxListingPhotos - widget.photos.length;

      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final one = await _picker.pickImage(
            source: ImageSource.camera, imageQuality: 85);
        picked = one == null ? const [] : [one];
      } else {
        // ÇOKLU SEÇİM
        final many = await _picker.pickMultiImage(imageQuality: 85);
        picked = many.take(remaining).toList();
      }
      if (picked.isEmpty || !mounted) {
        return;
      }

      final added = <PhotoItem>[];
      for (final x in picked) {
        final size = await x.length();
        // ⚠ TÜR ÖNCE ÇÖZÜLÜR: web'de `path` uzantısızdır, bu yüzden
        // doğrulama da bu türle yapılır (bkz. `fotografTuru`).
        final tur = fotografTuru(x);
        // ⚠ NULL DENETİMİ AYRI DALDA: üçlü ifadeyle yazıldığında
        // Dart, `tur`u aşağıda non-null'a YÜKSELTEMİYOR ve
        // `contentType: tur` "String? → String" hatası veriyordu.
        // Erken dönüş, hem derleyiciyi hem okuyanı ikna eder.
        if (tur == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Yalnızca JPG, PNG ve WEBP dosyaları yüklenebilir')));
          }
          continue;
        }
        final err = validatePhotoTur(tur: tur, sizeBytes: size);
        if (err != null) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(err)));
          }
          continue;
        }
        added.add(PhotoItem(
          localPath: x.path,
          sizeBytes: size,
          // ⚠ `!` KALDIRILDI: `tur` yukarıda zaten denetlendi;
          // `contentTypeOf(x.path)!` web'de null olup ÇÖKERTİYORDU.
          contentType: tur,
        ));
      }
      if (added.isEmpty || !mounted) {
        return;
      }

      final next = [...widget.photos, ...added];
      _bildir(next);
      // Seçilen her dosya hemen yüklenmeye başlar.
      for (final p in added) {
        unawaitedUpload(p);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf seçilemedi')),
      );
    }
  }

  /// Yükleme — hata durumunda öğe listede kalır ve "Tekrar dene" gösterilir.
  void unawaitedUpload(PhotoItem p) {
    _upload(p);
  }

  Future<void> _upload(PhotoItem p) async {
    // ⚠ KAYIT ÖNCESİ: oturumsuz kullanıcının yükleme yetkisi yoktur.
    // Dosya yalnız cihazda tutulur; yükleme kayıt tamamlandıktan
    // SONRA yapılır (`PendingListingController.publishIfAny`).
    if (!widget.uploadEnabled) {
      return;
    }
    if (p.isUploaded || p.uploading) {
      return;
    }

    // ── ⚠ MOCK MODDA AĞ ÇAĞRISI YAPILMAZ ──
    //
    // Bu ekran doğrudan HTTP çağırıyordu ve `ApiConfig.useRealApi`
    // denetimi YOKTU. Sunucu bağlı olmadığında istek zaman aşımına
    // kadar asılı kalıyor, üstelik yeniden deneniyordu: kullanıcı
    // fotoğrafı seçiyor, kutu "yükleniyor" durumunda KALIYORDU.
    //
    // ⚠ Proje kuralı: doğrudan HTTP çağıran her ekran önce bu kapıyı
    // geçer. Kural vardı, burada uygulanmamıştı.
    //
    // Mock modda dosya cihazda durur ve YERELDE yüklenmiş sayılır;
    // gerçek referans API modunda sunucudan gelir.
    if (!ApiConfig.useRealApi) {
      setState(() {
        // ⚠ Referans biçimi mevcut sözleşmeyle AYNI: kayıtsız akışta
        // da mock modda yerel yol referans olarak kullanılıyor
        // (`create_listing_screen`). İki yol ayrışmamalı.
        p.storageRef = p.localPath;
        p.yerelRef = true;
        p.uploading = false;
        p.error = null;
      });
      _bildir(widget.photos);
      return;
    }

    setState(() {
      p.uploading = true;
      p.error = null;
    });
    try {
      final res = await widget.storage.createUploadRef(
        kind: 'listing-photo',
        contentType: p.contentType,
        sizeBytes: p.sizeBytes,
      );
      final ref = res['storageRef'] as String? ?? res['ref'] as String?;
      if (ref == null || ref.isEmpty) {
        throw StateError('storageRef alınamadı');
      }
      // ── ⚠ EKSİK ADIM TAMAMLANDI: DOSYA GERÇEKTEN YÜKLENİR ──
      //
      // Önceden yalnız referans alınıyor, dosyanın baytları hiçbir
      // yere gönderilmiyordu. Kullanıcı "yüklendi" görüyor, karşı
      // taraf boş görüyordu.
      //
      // ⚠ BAŞARISIZLIKTA `storageRef` KAYDEDİLMEZ: `uploadBytes`
      // istisna fırlatırsa aşağıdaki `catch` çalışır, fotoğraf
      // "Yüklenemedi" olarak işaretlenir. Başarılı gibi davranmak,
      // ilanın fotoğrafsız yayınlanmasına yol açardı.
      final uploadUrl = res['uploadUrl'] as String?;
      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw StateError('uploadUrl alınamadı');
      }
      await widget.storage.uploadBytes(
        uploadUrl: uploadUrl,
        bytes: await yerelBaytlar(p.localPath),
        contentType: p.contentType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        p.storageRef = ref;
        p.uploading = false;
      });
      _bildir(widget.photos);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        p.uploading = false;
        p.error = 'Yüklenemedi';
      });
    }
  }

  /// ÖNİZLEMEDEN KALDIRMA
  ///
  /// Fotoğraf yalnız yerel listeden çıkarılmaz: sunucudaki BEKLEYEN
  /// yükleme de iptal edilir. Böylece sahipsiz dosya kalmaz.
  ///
  ///  • Henüz yüklenmemiş öğe → doğrudan listeden çıkar (sunucuda kayıt yok).
  ///  • Yüklenmiş öğe → discard çağrılır; BAŞARIDA listeden çıkar.
  ///  • Hata → öğe listede KALIR ve tekrar deneme gösterilir.
  ///  • Aynı discard iki kez çağrılsa da sunucu idempotenttir.
  ///  • ATTACHED dosya bu yoldan iptal EDİLMEZ.
  Future<void> _remove(PhotoItem p) async {
    if (p.discarding) {
      return;
    }

    // Sunucuya hiç yüklenmemişse iptal edilecek kayıt yoktur.
    if (!p.isUploaded) {
      final next = [...widget.photos]..remove(p);
      _bildir(next);
      setState(() {});
      return;
    }

    // İlana bağlanmış dosya önizlemeden iptal edilemez.
    if (p.attached) {
      setState(() => p.discardError = 'Yayınlanmış ilanın fotoğrafı buradan kaldırılamaz');
      return;
    }

    setState(() {
      p.discarding = true;
      p.discardError = null;
    });
    // ⚠ YEREL REFERANS: sunucuda karşılığı yok, iptal isteği
    // gönderilmez. Kutu "iptal ediliyor"da asılı kalmasın diye
    // doğrudan listeden düşülür.
    if (p.yerelRef) {
      // ⚠ `widget.photos` ÜZERİNDE DEĞİŞİKLİK YAPILMAZ; diğer kaldırma
      // dallarıyla aynı desen kullanılır: kopya çıkarılır, ebeveyne o
      final next = [...widget.photos]..remove(p);
      setState(() => p.discarding = false);
      _bildir(next);
      return;
    }
    try {
      final result = await widget.storage.discardPending(p.storageRef!);
      if (!mounted) {
        return;
      }

      // HTTP 200 tek başına BAŞARI DEĞİLDİR: sunucu storage silmeyi
      // başaramadıysa ok:false döner ve kayıt PENDING kalır.
      if (!result.ok) {
        setState(() {
          p.discarding = false;
          p.discardError = result.retryScheduled
              ? 'Kaldırılamadı — otomatik olarak yeniden denenecek'
              : 'Kaldırılamadı — tekrar deneyin';
        });
        return;
      }

      // BAŞARI: kayıt listeden çıkarılmadan ÖNCE yükleniyor durumu
      // kapatılır. Aksi hâlde ebeveyn listeyi yenilemezse aynı
      // PhotoItem ekranda kalır ve göstergesi sonsuza kadar döner.
      p.discarding = false;
      p.discardError = null;

      final next = [...widget.photos]..remove(p);
      _bildir(next);
      setState(() {});
    } catch (e) {
      if (!mounted) {
        return;
      }
      // Ağ/zaman aşımı: öğe GÖRÜNÜR kalır, kullanıcı tekrar deneyebilir.
      // Başarısız kalanları sunucudaki zamanlayıcı yedek olarak temizler.
      setState(() {
        p.discarding = false;
        p.discardError = 'Kaldırılamadı — tekrar deneyin';
      });
    }
  }

  /// Ekran kapanırken kalan BEKLEYEN yüklemeler için best-effort iptal.
  /// Başarısız olanları sunucudaki zamanlayıcı temizler.
  Future<void> discardAllPending() async {
    for (final p in widget.photos) {
      if (!p.isUploaded || p.attached) {
        continue;
      }
      try {
        // Sonuç ok:false olsa da burada kullanıcıya gösterilecek bir
        // ekran kalmadı; sunucudaki zamanlayıcı yedek güvenlik ağıdır.
        await widget.storage.discardPending(p.storageRef!);
      } catch (_) {
        // Yut: zamanlayıcı yedek güvenlik ağıdır.
      }
    }
  }

  Future<void> _sheet() async {
    if (!widget.enabled || _full) {
      return;
    }
    // ── ⚠ PANEL ARTIK TEK KAYNAKTAN GELİYOR ──
    //
    // Kullanıcı isteği (9 Eyl): ilan oluşturma ekranlarındaki ve
    // mesajlaşmadaki fotoğraf paneli AYNI olmalı. Panelin çizimi
    // `widgets/fotograf_kaynak_paneli.dart`a taşındı — buradaki
    // kopya (başlık + iki `_secenek` satırı) SİLİNDİ, davranış
    // AYNEN korundu: seçim yapılırsa `_pick` çağrılır, panel
    // kapatılırsa hiçbir şey olmaz.
    final kaynak = await fotografKaynagiSec(context);
    if (kaynak == null || !mounted) {
      return;
    }
    await _pick(kaynak);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (widget.sade) {
      return _sadeGorunum(photos);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Fotoğraflar',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: HC.dark)),
        const Spacer(),
        Text('${photos.length}/$kMaxListingPhotos',
            style: const TextStyle(fontSize: 12.5, color: HC.grey)),
      ]),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...photos.map(_tile),
          if (!_full)
            InkWell(
              onTap: widget.enabled ? _sheet : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  border: Border.all(color: HC.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RefSvg('assets/svg/ic_camplus.svg', size: 20, color: RC.greyLight),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'JPG, PNG veya WEBP · en fazla 10 MB · en fazla 5 fotoğraf',
        style: TextStyle(fontSize: 11.5, color: HC.lightGrey),
      ),
    ]);
  }

  /// `.po-ph` — geniş kesikli ekleme kutusu (referans `vPost2`).
  Widget _sadeGorunum(List<PhotoItem> photos) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (photos.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: photos.map(_tile).toList()),
          const SizedBox(height: 10),
        ],
        if (!_full)
          InkWell(
            onTap: widget.enabled ? _sheet : null,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F9FE),
                border: Border.all(
                    color: const Color(0xFFB9CBE8), width: 1.6),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Column(children: [
                  const RefSvg('assets/svg/ic_camplus.svg',
                      size: 26, color: RC.blue),
                  const SizedBox(height: 6),
                  Text('Fotoğraf ekle',
                      style: refText(
                          size: RF.s15, weight: RF.w700, color: RC.blue)),
                  const SizedBox(height: 4),
                  Text('Galeriden seç veya kamera ile çek',
                      style: refText(
                          size: RF.s13,
                          weight: RF.w400,
                          color: RC.textSoft)),
                ]),
              ),
            ),
          ),
      ]);

  Widget _tile(PhotoItem p) => SizedBox(
        width: 84,
        height: 84,
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: yerelGorsel(
              p.localPath,
              width: 84, height: 84, fit: BoxFit.cover,
              hataYedegi: (_) => Container(
                width: 84, height: 84,
                color: const Color(0xFFF1F4F9),
                child: RefSvg('assets/svg/ic_camg.svg', size: 20, color: RC.greyLight),
              ),
            ),
          ),
          if (p.uploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
            ),
          if (p.error != null)
            Positioned.fill(
              // ⚠ `GestureDetector` YERİNE `RefTap`: başarısız
              // yüklemeyi yeniden deneyen gerçek bir kontrol; klavye
              // erişimi ve imleç eksikti.
              child: RefTap(
                onTap: () => _upload(p),
                ipucu: 'Yeniden dene',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RefSvg('assets/svg/ic_ul.svg', size: 20, color: RC.white),
                        Text('Tekrar',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -6, top: -6,
            child: IconButton(
              // Testler bu düğmeyi anahtarla bulur (ikon artık SVG).
              key: const ValueKey('photo-discard'),
              tooltip: 'Fotoğrafı kaldır',
              iconSize: 18,
              icon: p.discarding
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  // ⚠ `ic_x.svg` KENDİ renklerini taşır (dolu daire +
                  // beyaz çarpı). Renk verilirse tüm çizim tek renge
                  // boyanır ve DOLU LEKE görünür.
                  : const RefSvg('assets/svg/ic_x.svg', size: 20),
              onPressed: (widget.enabled && !p.discarding)
                  ? () => unawaited(_remove(p))
                  : null,
            ),
          ),
          if (p.discardError != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                color: HC.red.withValues(alpha: .85),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  p.discardError!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 8.5),
                ),
              ),
            ),
        ]),
      );
}
