import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/home_config.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

/// Filtre bottom sheet sonucu: seçili filtre id'leri + seçili özellik id'leri.
typedef FilterResult = ({Set<int> filters, Set<int> ozellikler});

/// Ortak filtre bottom sheet'i — kategori listeleme ve arama (Mekanlar/Yemekler)
/// ekranlarında birebir aynı görünüm. Filtreler + (varsa) özellikler iki grup
/// halinde gösterilir. Uygulanırsa seçili filtre ve özellik id kümelerini
/// döndürür; kapatılırsa `null`.
Future<FilterResult?> showFilterSheet(
  BuildContext context, {
  required List<Filter> filters,
  required Set<int> selected,
  List<Filter> ozellikler = const [],
  Set<int> selectedOzellikler = const {},
}) {
  final temp = Set<int>.from(selected);
  final tempOz = Set<int>.from(selectedOzellikler);
  // Açılışta seçili öğeleri en üste al (orijinal göreli sıra korunur).
  // Sıra açılış anındaki seçime göre sabittir; toggle sırasında öğeler zıplamaz.
  final ordered = <Filter>[
    ...filters.where((f) => selected.contains(f.id)),
    ...filters.where((f) => !selected.contains(f.id)),
  ];
  final orderedOz = <Filter>[
    ...ozellikler.where((f) => selectedOzellikler.contains(f.id)),
    ...ozellikler.where((f) => !selectedOzellikler.contains(f.id)),
  ];
  final hasOzellik = orderedOz.isNotEmpty;
  return showModalBottomSheet<FilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height *
                      (hasOzellik ? 0.7 : 0.45)),
              child: Padding(
                padding:
                    EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filtrele',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600)),
                          GestureDetector(
                            onTap: () => setSheet(() {
                              temp.clear();
                              tempOz.clear();
                            }),
                            child: const Text('Temizle',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasOzellik) const _GroupHeader('Filtreler'),
                            for (final f in ordered)
                              FilterRow(
                                filter: f,
                                selected: temp.contains(f.id),
                                onToggle: () => setSheet(() {
                                  if (temp.contains(f.id)) {
                                    temp.remove(f.id);
                                  } else {
                                    temp.add(f.id);
                                  }
                                }),
                              ),
                            if (hasOzellik) ...[
                              const _GroupHeader('Özellikler'),
                              for (final f in orderedOz)
                                FilterRow(
                                  filter: f,
                                  selected: tempOz.contains(f.id),
                                  onToggle: () => setSheet(() {
                                    if (tempOz.contains(f.id)) {
                                      tempOz.remove(f.id);
                                    } else {
                                      tempOz.add(f.id);
                                    }
                                  }),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(
                              sheetCtx, (filters: temp, ozellikler: tempOz)),
                          child: const Text('Uygula',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Filtre/Özellik grup başlığı.
class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            height: 1.4),
      ),
    );
  }
}

/// Filtre satırı — solda ikon (API SVG; yoksa isme göre Material ikon), ortada
/// ad, sağda özel on/off switch. Tüm satıra dokununca toggle.
class FilterRow extends StatelessWidget {
  final Filter filter;
  final bool selected;
  final VoidCallback onToggle;
  const FilterRow({
    super.key,
    required this.filter,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(child: _icon()),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(filter.name,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
            _CustomSwitch(value: selected),
          ],
        ),
      ),
    );
  }

  Widget _icon() {
    final svg = filter.icon;
    if (svg != null && svg.trim().isNotEmpty) {
      return SvgPicture.string(
        svg,
        width: 20,
        height: 20,
        colorFilter:
            const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
      );
    }
    return Icon(_filterFallbackIcon(filter), size: 20, color: AppColors.primary);
  }
}

/// Tasarıma uygun özel on/off anahtarı (Material Switch yerine).
class _CustomSwitch extends StatelessWidget {
  final bool value;
  const _CustomSwitch({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? AppColors.primary : const Color(0xFFD9D9E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// API ikonu (SVG) gelmezse filtre adına/slug'ına göre yedek Material ikon.
IconData _filterFallbackIcon(Filter f) {
  final s = '${f.slug} ${f.name}'.toLowerCase();
  bool has(String k) => s.contains(k);
  // Otopark alt tipleri (Açık/Kapalı/Katlı/İSPARK…) — harita çipleri ve
  // pinleriyle aynı eşleme kullanılır.
  final otopark = HomeConfig.otoparkIconFor(s);
  if (otopark != null) return otopark;
  if (has('wifi') || has('internet')) return Icons.wifi;
  if (has('alkolsüz') || has('alkolsuz')) return Icons.no_drinks;
  if (has('alkol') || has('bar')) return Icons.local_bar_outlined;
  if (has('vale')) return Icons.directions_car_outlined;
  if (has('rezerv')) return Icons.event_available_outlined;
  if (has('dijital') || has('menü') || has('menu')) return Icons.qr_code_2;
  if (has('çocuk') || has('cocuk')) return Icons.child_friendly;
  if (has('çalışma') || has('calisma')) return Icons.work_outline;
  if (has('toplu') || has('etkinlik')) return Icons.celebration_outlined;
  if (has('soğutucu') || has('sogutucu') || has('klima')) return Icons.ac_unit;
  if (has('ısıtıcı') || has('isitici')) {
    return Icons.local_fire_department_outlined;
  }
  if (has('sigarasız') || has('sigarasiz')) return Icons.smoke_free;
  if (has('sigara')) return Icons.smoking_rooms;
  if (has('evcil') || has('hayvan') || has('pet')) return Icons.pets;
  if (has('yabancı') || has('dil')) return Icons.translate;
  if (has('nargile')) return Icons.air;
  if (has('engelsiz') || has('engelli')) return Icons.accessible;
  if (has('mescit') || has('ibadet')) return Icons.mosque_outlined;
  return Icons.tune;
}
