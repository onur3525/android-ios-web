/// BÖLGE SEÇİM BİLEŞENLERİ — üç ekranda ortak kullanılır
/// (kayıt, adres, ilan oluşturma).
///
/// SERBEST METİN KABUL EDİLMEZ: kullanıcı yalnız sunucudan gelen
/// listeden seçim yapar.
library;

import 'package:flutter/material.dart';
import '../../core/sys_state.dart';
import '../../core/theme.dart';
import '../../ui/ref_widgets.dart';
import '../../ui/ref_tokens.dart';
import '../../core/turkce_arama.dart';


/// Dokunmatik seçim alanı (HTML addrField karşılığı).
class RegionField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final VoidCallback? onTap;
  final bool enabled;
  const RegionField({super.key, 
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: HC.grey)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: enabled && onTap != null
                  ? Colors.white
                  : const Color(0xFFF7F8FA),
              border: Border.all(color: HC.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  filled ? value! : hint,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: filled ? HC.dark : HC.lightGrey,
                    fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (onTap != null)
                RefSvg('assets/svg/ic_chev.svg', size: 20, color: RC.greyLight),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Aranabilir seçim listesi (1300 mahalle için arama gereklidir).
class RegionPickerSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final bool searchable;
  const RegionPickerSheet({super.key, 
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
  });
  @override
  State<RegionPickerSheet> createState() => RegionPickerSheetState();
}

class RegionPickerSheetState extends State<RegionPickerSheet> {
  String _q = '';

  /// Türkçe karakter duyarsız arama — ortak kural.
  ///
  /// ⚠ Eski sürümde `toLowerCase()` önce çalıştığı için `'İ'`
  /// sadeleştirmesi ölü koddu ve "ÇİĞLİ" araması sonuç vermiyordu.
  String _norm(String s) => turkceNormalize(s);

  @override
  Widget build(BuildContext context) {
    final list = _q.trim().isEmpty
        ? widget.options
        : widget.options.where((o) => _norm(o).contains(_norm(_q))).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
                color: HC.border, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 12),
          // Başlık + kapat (X). `RefBottomSheet` ile aynı sözleşme:
          // yarım ekranlar hem boş alana dokununca hem X ile kapanır.
          Padding(
            padding: const EdgeInsets.only(left: 18, right: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HC.dark)),
                ),
                RefTap(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(RR.circle),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: RefSvg('assets/svg/ic_x.svg', size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Ara…',
                  prefixIcon: Padding(
                        padding: const EdgeInsets.fromLTRB(15, 0, 12, 0),
                        child: RefSvg('assets/svg/ic_search.svg', size: 20),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 47, minHeight: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: SysState(SysKind.empty,
                        title: 'Sonuç bulunamadı',
                        desc: 'Farklı bir arama deneyin.'),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: HC.border),
                    itemBuilder: (_, i) {
                      final o = list[i];
                      final sel = o == widget.selected;
                      return ListTile(
                        title: Text(o,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w400,
                                color: sel ? HC.blue : HC.dark)),
                        trailing: sel
                            ? RefSvg('assets/svg/ic_checksm.svg', size: 20, color: RC.blue)
                            : null,
                        onTap: () => Navigator.of(context).pop(o),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
