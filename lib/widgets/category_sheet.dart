import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Footer "Kategori" sekmesi — alttan açılan kategori seçim paneli.
/// Kategori listesi `HomeRepository.kategoriler()`'den gelir; bir kategoriye
/// dokununca panel kapanır ve [onSelect] (id, ad) ile çağrılır.
void showCategorySheet(
  BuildContext context, {
  required void Function(int id, String name) onSelect,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _CategorySheet(onSelect: onSelect),
  );
}

class _CategorySheet extends StatefulWidget {
  final void Function(int id, String name) onSelect;
  const _CategorySheet({required this.onSelect});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  List<Category> _cats = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Otopark/İspark ile ilgili kategorileri gizle (id 62 = Otopark; ad/slug'da
  /// "otopark" veya "ispark" geçenler).
  bool _gizli(Category c) {
    if (c.id == 62) return true;
    // Türkçe "İ" küçültme farkını atlamak için 'spark' alt dizesi ispark/
    // İspark/İSPARK varyantlarını yakalar.
    final s = '${c.name} ${c.slug}'.toLowerCase();
    return s.contains('otopark') || s.contains('spark');
  }

  Future<void> _load() async {
    try {
      // Tüm kategoriler + mekan sayıları (/kategoriler/agac).
      final all = (await HomeRepository.instance.kategorilerAgac())
          .where((c) => !_gizli(c))
          .toList();
      // Mekanı olanları öne al ve mekan sayısına göre azalan sırala.
      final withCounts = all.where((c) => c.mekanSayisi > 0).toList()
        ..sort((a, b) => b.mekanSayisi.compareTo(a.mekanSayisi));
      final list = withCounts.isNotEmpty ? withCounts : all;
      if (!mounted) return;
      setState(() {
        _cats = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _select(Category c) {
    Navigator.pop(context);
    widget.onSelect(c.id, c.name);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            _grabber(),
            _header(),
            Expanded(child: _body(scrollController, bottomInset)),
          ],
        );
      },
    );
  }

  Widget _grabber() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(999),
        ),
      );

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 12, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text('Kategoriler',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close, color: AppColors.ink, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(ScrollController controller, double bottomInset) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.primary),
        ),
      );
    }
    if (_cats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Kategori bulunamadı',
              style: TextStyle(fontSize: 14, color: AppColors.muted)),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
      itemCount: _cats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _tile(_cats[i]),
    );
  }

  /// Tam genişlik tek satır: solda ikon, ortada başlık, en sağda mekan sayısı.
  Widget _tile(Category c) {
    return GestureDetector(
      onTap: () => _select(c),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CategoryIcon(
                    icon: c.icon,
                    id: c.id,
                    color: AppColors.primary,
                    size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            if (c.mekanSayisi > 0)
              Text(
                '${c.mekanSayisi}',
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}
