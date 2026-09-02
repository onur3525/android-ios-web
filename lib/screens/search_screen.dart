import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/category_tree.dart';
import '../data/controllers/listing_controller.dart';
import '../data/models/account.dart';
import '../data/services/search_service.dart';
import 'category_screen.dart';
import 'create_listing_screen.dart';
import 'job_detail_screen.dart';
import '../data/izmir.dart';
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';
import 'prelogin_listing_route.dart';

/// Arama (HTML vSearch): kategori/alt hizmet + açık ilan başlık-açıklama.
/// Boş sorguda varsayılan görünüm (tüm kategoriler); sonuç yoksa empty state.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.prefill});

  /// Arama kutusuna önceden yazılacak metin.
  ///
  /// Referans `openSearch(prefill)`:
  /// ```js
  /// SQ = prefill || '';
  /// navigate('search', { onMount: p => {
  ///   p.querySelector('#sq').value = SQ; renderResults(p, SQ); } });
  /// ```
  /// Home'daki kategori kısayolları kategori adıyla çağırır.
  final String? prefill;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _q = TextEditingController(text: widget.prefill ?? '');

  void _openService(String category, {String? subService}) {
    final auth = context.read<AuthController>();

    void publicForma() => Navigator.pushNamed(
          context,
          PreLoginListingRoute.name,
          arguments:
              PreLoginListingArgs(category: category, subService: subService),
        );

    // ⚠ ROL SEÇİM EKRANI AÇILMAZ (bkz. category_screen).
    if (!auth.loggedIn) {
      publicForma();
      return;
    }

    final acc = auth.currentAccount;
    if (acc?.roles.contains(Role.customer) ?? false) {
      if (auth.activeRole != Role.customer) {
        unawaited(auth.switchRole(Role.customer));
      }
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CreateListingScreen(
                    initialCategory: category,
                    initialSubService: subService,
                  )));
      return;
    }

    // Yalnız Hizmet Veren rolü olan kullanıcı: taslak formu.
    publicForma();
  }
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text;
    final hits = SearchService.services(q);
    final listingCtl = context.watch<ListingController>();
    final listingHits = SearchService.listings(listingCtl.all, q);
    final searching = q.trim().isNotEmpty;
    final empty = searching && hits.isEmpty && listingHits.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: RefDetailHeader(title: 'Hizmet Ara'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
            child: TextField(
              controller: _q,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Hizmet veya kategori yazın',
                prefixIcon: Padding(
                        padding: const EdgeInsets.fromLTRB(15, 0, 12, 0),
                        child: RefSvg('assets/svg/ic_search.svg', size: 20),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 47, minHeight: 20),
                suffixIcon: q.isEmpty
                    ? null
                    : RefTap(
                        onTap: () => setState(_q.clear), // varsayılana dön
                        borderRadius: BorderRadius.circular(RR.circle),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: RefSvg('assets/svg/ic_x.svg', size: 20),
                        ),
                      ),
              ),
            ),
          ),
          Expanded(
            child: empty
                ? Center(
                    child: SysEmpty(
                        title: 'Sonuç bulunamadı',
                        desc:
                            '"${q.trim()}" için eşleşme yok. Farklı bir kelimeyle arayabilir veya kategorilere göz atabilirsiniz.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      if (!searching) ...[
                        const Text('Kategoriler',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: HC.dark)),
                        const SizedBox(height: 8),
                        ...kHomeCategories.map((c) => _catRow(c)),
                      ] else ...[
                        if (hits.isNotEmpty) ...[
                          const Text('Hizmetler',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: HC.dark)),
                          const SizedBox(height: 8),
                          ...hits.map((h) => _hitRow(h)),
                        ],
                        if (listingHits.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('Açık İlanlar (${listingHits.length})',
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: HC.dark)),
                          const SizedBox(height: 8),
                          ...listingHits.map((l) => _listingRow(l.id, l.title, l.location)),
                        ],
                      ],
                    ],
                  ),
          ),
        ]),
      ),
    );
  }

  /// Referans `row(s)` → `.srow`:
  /// ```
  /// <div class="srow tap">
  ///   <div><div class="n">isim</div><div class="p">açıklama</div></div>
  ///   IC_CHEV('#C2C9D3',20)
  /// </div>
  /// ```
  /// ⚠ KATEGORİ ve HİZMET satırlarında sol görsel YOKTUR: HTML
  /// `.srow` yalnız metin + chevron içerir. Kategori PNG'si 640×400
  /// olduğundan `BoxFit.cover` ile küçük kareye kırpılınca düz renkli
  /// bir bölge (yeşil kutu) gibi görünüyordu.
  ///
  /// [leading] YALNIZ ilan sonucu satırında kullanılır: orada gösterilen
  /// şey kategori görseli değil, ilan olduğunu belirten simgedir.
  /// Bu yüzden parametre OPSİYONELDİR ve varsayılanı yoktur.
  Widget _tile({required String title, String? sub,
          required VoidCallback onTap, Widget? leading, Key? satirAnahtari}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            // ⚠ SATIR KİMLİĞİ: aynı metin hem HİZMET hem İLAN
            // satırında çıkabilir ("Kombi Bakımı" hem katalogda hem
            // demo ilan başlığında var). Kategori alt başlığı
            key: satirAnahtari,
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  border: Border.all(color: HC.border),
                  borderRadius: BorderRadius.circular(13)),
              child: Row(children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HC.dark)),
                    if (sub != null)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 12, color: HC.grey)),
                  ]),
                ),
                RefSvg('assets/svg/ic_chev.svg', size: 20, color: RC.greyLight),
              ]),
            ),
          ),
        ),
      );

  Widget _catRow(String c) => _tile(
      // ⚠ GÖRÜNEN ad — kart ızgarasıyla aynı kısaltma.
      title: kategoriEtiketi(c),
      sub: (kSubServices[c] ?? const []).take(3).join(' · '),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => CategoryScreen(category: c))));

  /// ⚠ KATEGORİ ALT BAŞLIĞI GÖSTERİLMEZ.
  ///
  /// Satırın altında ana kategori adı yazıyordu ("Doğalgaz Kolon
  /// Hattı" → alt satır "Doğalgaz"). Ürün kuralı: hizmetin hangi
  /// kategoriye bağlı olduğu KULLANICIYA GÖSTERİLMEZ; her hizmet
  /// kendi başına bir satırdır.
  ///
  /// ⚠ Kategori arka planda taşınmaya DEVAM EDER — seçim `h.category`
  /// ve `h.subService` ile ilan formuna gider; fotoğraf, çıkar
  /// çatışması, eşleştirme ve iletişim bedeli ona bağlıdır.
  Widget _hitRow(SearchHit h) => _tile(
      satirAnahtari: ValueKey('hizmet-${h.label}'),
      title: kategoriEtiketi(h.label),
      // Alt hizmet seçildiyse ilan formuna TAŞINIR.
      onTap: () => _openService(h.category, subService: h.subService));

  Widget _listingRow(String id, String title, String loc) => _tile(
      satirAnahtari: ValueKey('ilan-$id'),
      leading: const CircleAvatar(
          radius: 19,
          backgroundColor: HC.softBlue,
          child: RefSvg('assets/svg/ic_clip.svg', size: 19, color: RC.blue)),
      title: title,
      sub: loc,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(listingId: id))));
}
