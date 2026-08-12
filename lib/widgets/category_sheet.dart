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

  Future<void> _load() async {
    try {
      final all = await HomeRepository.instance.kategoriler();
      // Mekanı olanları öne al (varsa mekan_sayisi'ya göre), yoksa mevcut sıra.
      final hasCounts = all.any((c) => c.mekanSayisi > 0);
      final list = hasCounts
          ? (all.where((c) => c.mekanSayisi > 0).toList()
            ..sort((a, b) => b.mekanSayisi.compareTo(a.mekanSayisi)))
          : all;
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
    return GridView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemCount: _cats.length,
      itemBuilder: (_, i) => _tile(_cats[i]),
    );
  }

  Widget _tile(Category c) {
    return GestureDetector(
      onTap: () => _select(c),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: CategoryIcon(
                    icon: c.icon,
                    id: c.id,
                    color: AppColors.primary,
                    size: 24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              c.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}
