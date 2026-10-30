import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Footer "Kategori" sekmesi — alttan açılan kategori seçim paneli.
///
/// İlk adımda yalnız ANA kategoriler listelenir. Alt kategorisi olan bir ana
/// kategoriye dokununca panel içinde o kategorinin alt kategorileri açılır
/// (başlıkta seçilen kategori + geri butonu; en üstte "Tümü" satırı ana
/// kategorinin kendisini seçer). Alt kategorisi olmayan kategoriye
/// dokununca panel kapanır ve [onSelect] (id, ad) çağrılır.
///
/// Kaynak `/kategoriler/agac` (tüm kategoriler + `parent` + `mekan_sayisi`);
/// her seviye mekan sayısına göre azalan sıralıdır. Backend değişikliği
/// gerekmez.
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
  /// Görünür (gizli olmayan) tüm kategoriler.
  List<Category> _all = const [];
  bool _loading = true;

  /// Açılmış kategori yolu: boş = ana kategoriler; son eleman = alt
  /// kategorileri gösterilen kategori.
  final List<Category> _path = [];

  /// Geri dönülünce bir önceki seviyede vurgulanacak kategori.
  int? _lastOpenedId;

  /// Geçiş yönü (true = ileri / alt seviyeye).
  bool _forward = true;

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
      // Tüm kategoriler + parent + mekan sayıları (/kategoriler/agac).
      final all = (await HomeRepository.instance.kategorilerAgac())
          .where((c) => !_gizli(c))
          .toList();
      if (!mounted) return;
      setState(() {
        _all = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// [parentId] (0 = kök) altındaki kategoriler, mekan sayısına göre azalan.
  /// Mekanı olan varsa mekanı olmayanlar elenir (eski davranış).
  List<Category> _childrenOf(int parentId) {
    final list = _all.where((c) => c.parent == parentId).toList();
    final withCounts = list.where((c) => c.mekanSayisi > 0).toList();
    final out = withCounts.isNotEmpty ? withCounts : list;
    out.sort((a, b) {
      final c = b.mekanSayisi.compareTo(a.mekanSayisi);
      return c != 0 ? c : trCompare(a.name, b.name);
    });
    return out;
  }

  Category? get _current => _path.isEmpty ? null : _path.last;

  void _tap(Category c) {
    HapticFeedback.selectionClick();
    if (_childrenOf(c.id).isEmpty) {
      _select(c);
      return;
    }
    setState(() {
      _forward = true;
      _path.add(c);
    });
  }

  void _back() {
    if (_path.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _forward = false;
      _lastOpenedId = _path.removeLast().id;
    });
  }

  void _select(Category c) {
    Navigator.pop(context);
    widget.onSelect(c.id, c.name);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Alt seviyedeyken sistem "geri" hareketi paneli kapatmaz, bir üst
    // seviyeye döner.
    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              _grabber(),
              _header(),
              // Seviye değişince yeni liste yandan kayarak gelir (ileri:
              // sağdan, geri: soldan). Eski liste ayrıca canlandırılmaz;
              // iki liste aynı anda sayfanın kaydırma denetleyicisine
              // bağlanmasın diye.
              Expanded(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_current?.id ?? 0),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, child) => Opacity(
                    opacity: t,
                    child: FractionalTranslation(
                      translation: Offset(
                        (1 - t) * (_forward ? 0.15 : -0.15),
                        0,
                      ),
                      child: child,
                    ),
                  ),
                  child: _body(scrollController, bottomInset),
                ),
              ),
            ],
          );
        },
      ),
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

  Widget _iconBtn(IconData icon, VoidCallback onTap, String label) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.ink, size: 20),
        ),
      ),
    );
  }

  Widget _header() {
    final cur = _current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          if (cur != null) ...[
            _iconBtn(Icons.chevron_left, _back, 'Geri'),
            const SizedBox(width: 10),
          ] else
            const SizedBox(width: 10),
          Expanded(
            child: Text(
              cur?.name ?? 'Kategoriler',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          _iconBtn(Icons.close, () => Navigator.pop(context), 'Kapat'),
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
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }
    final cur = _current;
    final items = _childrenOf(cur?.id ?? 0);
    if (items.isEmpty && cur == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Kategori bulunamadı',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ),
      );
    }
    // Alt seviyede ilk satır: seçilen kategorinin tamamı (seçili görünür).
    final rows = <Widget>[
      if (cur != null)
        _tile(cur, label: 'Tümü', selected: true, onTap: () => _select(cur)),
      for (final c in items)
        _tile(
          c,
          selected: cur == null && c.id == _lastOpenedId,
          hasChildren: _childrenOf(c.id).isNotEmpty,
          // Alt kategorilerin çoğunda ikon yok: üst kategorinin ikonu.
          fallbackIcon: cur?.icon,
          onTap: () => _tap(c),
        ),
    ];
    return ListView.separated(
      controller: controller,
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => rows[i],
    );
  }

  /// Tam genişlik tek satır: solda ikon, ortada başlık, sağda mekan sayısı
  /// (+ alt kategorisi varsa ok). [selected] satırı marka rengiyle çerçeveler.
  Widget _tile(
    Category c, {
    required VoidCallback onTap,
    String? label,
    bool selected = false,
    bool hasChildren = false,
    String? fallbackIcon,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: CategoryIcon(
                    icon: c.icon ?? fallbackIcon,
                    id: c.id,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label ?? c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (c.mekanSayisi > 0)
                Text(
                  '${c.mekanSayisi}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                ),
              if (hasChildren) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
