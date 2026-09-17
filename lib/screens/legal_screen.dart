import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/legal_cache.dart';
import '../data/remote/api/legal_api.dart';
import '../data/remote/api_client.dart';
import '../ui/ref_widgets.dart';
import '../core/geri.dart';
import '../data/remote/api_config.dart';

/// YASAL METİN / DESTEK İÇERİĞİ EKRANI
///
/// Desteklenenler: sürüm, yürürlük tarihi, yükleniyor, hata, ÇEVRİMDIŞI
/// görüntüleme (son başarılı içerik önbellekten okunur).
class LegalScreen extends StatefulWidget {
  final String slug;
  final String title;
  const LegalScreen({super.key, required this.slug, required this.title});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  LegalDoc? _doc;
  bool _loading = true;
  bool _fromCache = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // ⚠ MOCK MODDA AĞ ÇAĞRISI YAPILMAZ — bkz. `account_settings`.
    // Backend yokken istek 20sn timeout'a düşüyor ve `GET` olduğu
    // için 2 kez daha deneniyor: ~61 saniye dönen çark.
    if (!ApiConfig.useRealApi) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      return;
    }

    // Önce önbellek: çevrimdışı da olsa kullanıcı içeriği görebilir.
    final cached = LegalCache.instance.read(widget.slug);
    if (cached != null && mounted) {
      setState(() {
        _doc = cached;
        _fromCache = true;
        _loading = false;
      });
    }

    try {
      final api = LegalApi(context.read<ApiClient>());
      final j = await api.one(widget.slug);
      final doc = LegalDoc.fromJson(j);
      LegalCache.instance.write(doc);
      if (!mounted) {
        return;
      }
      setState(() {
        _doc = doc;
        _fromCache = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        // Önbellekte içerik varsa hata gösterilmez; eski sürüm okunur.
        _error = _doc == null ? 'İçerik yüklenemedi.' : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    return Scaffold(
      backgroundColor: HC.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => geriGit(context)),
        title: Text(d?.title ?? widget.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading && d == null
            ? const Center(child: CircularProgressIndicator())
            : (d == null
                ? Center(
                    child: SysState(SysKind.genericError,
                        title: 'İçerik bulunamadı',
                        desc: _error,
                        action: 'Tekrar Dene',
                        onAction: _load),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        // Sürüm + yürürlük tarihi
                        Row(children: [
                          _chip('Sürüm ${d.version}'),
                          const SizedBox(width: 8),
                          if (d.effectiveDate.isNotEmpty)
                            _chip('Yürürlük: ${_fmt(d.effectiveDate)}'),
                        ]),
                        if (_fromCache) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6E5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(children: [
                              // ⚠ `ic_info.svg` dolu daire + beyaz "i"
                              // içerir; renk filtresi LEKE üretir.
                              RefSvg('assets/svg/ic_info.svg', size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Çevrimdışı sürüm gösteriliyor. '
                                  'Bağlantı kurulduğunda güncellenecek.',
                                  style: TextStyle(
                                      fontSize: 12, color: HC.dark),
                                ),
                              ),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ..._render(d.body),
                      ],
                    ),
                  )),
      ),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F4F9),
            borderRadius: BorderRadius.circular(20)),
        child: Text(t,
            style: const TextStyle(fontSize: 11.5, color: HC.grey)),
      );

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) {
      return iso;
    }
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  /// Basit markdown gösterimi (# başlık, ** kalın, - madde).
  List<Widget> _render(String body) {
    final out = <Widget>[];
    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        out.add(const SizedBox(height: 10));
      } else if (line.startsWith('## ')) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(line.substring(3),
              style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: HC.dark)),
        ));
      } else if (line.startsWith('# ')) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(line.substring(2),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: HC.dark)),
        ));
      } else if (line.startsWith('- ')) {
        out.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  ',
                style: TextStyle(fontSize: 14, color: HC.grey)),
            Expanded(
              child: Text(line.substring(2),
                  style: const TextStyle(
                      fontSize: 14, height: 1.6, color: HC.dark)),
            ),
          ]),
        ));
      } else if (line.startsWith('**') && line.endsWith('**')) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(line.replaceAll('**', ''),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: HC.dark)),
        ));
      } else {
        out.add(Text(line,
            style: const TextStyle(
                fontSize: 14, height: 1.65, color: HC.dark)));
      }
    }
    return out;
  }
}
