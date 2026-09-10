import '../data/models/teklif_talebi.dart';

/// ── ⚠ TEKLİF TALEBİ AŞAMALARI — TEK KAYNAK ──
///
/// KULLANICI KURALI (9 Eyl): "Hizmet alan teklifi seçtikten sonra
/// ilgili ilan kartı Bul'da görünmemeli, tamamlanan işlere taşınmalı.
/// Aynı zamanda hizmet verenin teklif isteklerindeki ilgili kart
/// kazandığım işlere taşınmalı."
///
/// ⚠ ÖLÇÜLEN SAPMA — DÖRT LİSTE, DÖRT AYRI SÜZGEÇ: aynı yaşam
/// döngüsü dört ekranda ayrı ayrı yorumlanmıştı ve birbirini
/// tutmuyordu:
///
///   • "Bul" içindeki gönderilen talepler → HİÇ SÜZGEÇ YOK; seçilen
///     ve tamamlanan talepler orada kalıyordu.
///   • Hizmet verenin "Teklif İstekleri" → `!= secildi`. Oysa seçim
///     anında akış `secToVer` ardından `tamamla` çağırıyor, yani
///     durum `tamamlandi` oluyor; kart listede KALIYORDU.
///   • Hizmet verenin "Kazandığım" → YALNIZ `secildi`. Aynı sebeple
///     kazanılan iş oraya HİÇ DÜŞMÜYORDU.
///   • Hizmet alanın "Tamamlanan işler" → `secildi || tamamlandi`.
///     Tek doğru olan buydu.
///
/// Sonuç: kart eski listeden çıkmıyor, yenisine de girmiyordu. Bir
/// listenin süzgecini tek başına düzeltmek dördünü tutarlı yapmaz;
/// kural bu yüzden buraya taşındı.
///
/// ⚠ İKİ TARAF AYNI KURALI PAYLAŞIR: hizmet alan ile hizmet verenin
/// gördüğü aşama AYNI `durum` alanından türetilir. Ayrı ayrı
/// yazılsaydı, biri değiştiğinde öteki sessizce ayrışırdı — zaten
/// olan buydu.

/// İş HÂLÂ SÜRÜYOR: karşı taraftan yanıt ya da karar bekleniyor.
///
/// Bu aşamadaki talepler hizmet alanda "Bul" ekranındaki gönderilen
/// talepler listesinde, hizmet verende "Teklif İstekleri" ekranında
/// görünür.
bool talepSurenMi(TeklifTalebiDurumu d) =>
    d == TeklifTalebiDurumu.beklemede || d == TeklifTalebiDurumu.teklifGeldi;

/// İŞ KAZANILDI: hizmet alan teklifi seçti.
///
/// ⚠ `secildi` VE `tamamlandi` BİRLİKTE: "Bul" akışında ayrı bir "işi
/// tamamla" adımı YOKTUR — hizmet alan teklifi seçtiği anda akış
/// `secToVer` ardından `tamamla` çağırır. Bu yüzden kayıt pratikte
/// `tamamlandi` olarak durur, ama `secildi` de kabul edilir: tek
/// adımın ikinci yarısı bir hata nedeniyle yarım kalırsa kart
/// KAYBOLMAZ, yine kazanılan/tamamlanan listede görünür.
///
/// Bu aşamadaki talepler hizmet alanda "Tamamlanan işler" sekmesinde,
/// hizmet verende "Kazandığım" ekranında görünür.
bool talepKazanildiMi(TeklifTalebiDurumu d) =>
    d == TeklifTalebiDurumu.secildi || d == TeklifTalebiDurumu.tamamlandi;

/// İŞ OLUMSUZ SONUÇLANDI: reddedildi ya da süresi doldu.
///
/// ⚠ ŞU AN HİÇBİR LİSTEDE GÖSTERİLMİYOR — bu bilinçli bir boşluktur,
/// unutulmuş bir dal değil. Nereye düşeceği (hizmet alanda "Süresi
/// dolan işler"e mi, ayrı bir geçmişe mi) ürün kararı bekliyor.
/// Fonksiyon burada duruyor ki karar verildiğinde yine TEK yerden
/// bağlansın.
bool talepSonlandiMi(TeklifTalebiDurumu d) =>
    d == TeklifTalebiDurumu.reddedildi ||
    d == TeklifTalebiDurumu.suresiDoldu;

/// [hepsi] içinden hâlâ süren talepler.
List<TeklifTalebi> surenTalepler(List<TeklifTalebi> hepsi) =>
    [for (final t in hepsi) if (talepSurenMi(t.durum)) t];

/// [hepsi] içinden kazanılmış/tamamlanmış talepler.
List<TeklifTalebi> kazanilanTalepler(List<TeklifTalebi> hepsi) =>
    [for (final t in hepsi) if (talepKazanildiMi(t.durum)) t];

/// ── ⚠ OKUNMAMIŞ MESAJ SAYISI — TEK KAYNAK ──
///
/// KULLANICI İSTEĞİ (9 Eyl): "Gelen mesajları iki tarafta da bu
/// kartlar üzerinde yeni mesajın geldiğini gösteren bir yazı vb. bir
/// şey olmalı."
///
/// ⚠ ÖNCEDEN KARTLARDA HİÇ İZ YOKTU: mesaj geldiğini anlamanın tek
/// yolu talebi açıp sohbete girmekti. Listeye bakan kullanıcı hangi
/// işte yeni mesaj olduğunu göremiyordu.
///
/// Sayım kuralı: KARŞI TARAFIN gönderdiği ve henüz `okundu`
/// olmayan mesajlar. Kendi gönderdiğin mesaj asla "yeni" sayılmaz.
///
/// ⚠ İKİ TARAF AYNI FONKSİYONU KULLANIR: hizmet alan da hizmet veren
/// de kendi id'sini geçer. Ayrı ayrı yazılsaydı biri "okundu"yu,
/// öteki "iletildi"yi ölçüt alabilirdi.
///
/// ⚠ OKUNDU İŞARETİ SOHBET AÇILINCA KONUR
/// (`mesajlariOkunduIsaretle`); bu fonksiyon yalnız OKUR, durumu
/// değiştirmez.
int okunmamisMesajSayisi(TeklifTalebi t, String benimId) => t.mesajlar
    .where((m) =>
        m.gonderenId != benimId && m.durum != TeklifMesajDurumu.okundu)
    .length;
