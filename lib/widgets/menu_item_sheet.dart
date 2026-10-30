import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Açıklama rengi (web: #6b6b80).
const Color _descColor = Color(0xFF6B6B80);

/// Menü ürünü detayı — alttan açılan panel: görsel (4:3), ad, fiyat,
/// açıklama, içindekiler ve kalori (dolu olanlar gösterilir).
///
/// QR menü ekranı ve arama "Yemekler" sekmesi aynı paneli kullanır. Aramadan
/// açılırken [mekanAdi] + [onOpenMekan] verilir: panelin altında ürünün ait
/// olduğu işletme satırı çıkar, dokununca panel kapanır ve işletme açılır.
Future<void> showMenuItemSheet(
  BuildContext context,
  MenuUrun u, {
  String? mekanAdi,
  String? mekanAlt,
  VoidCallback? onOpenMekan,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).padding.bottom;
      final screenH = MediaQuery.of(ctx).size.height;
      final showMekan =
          onOpenMekan != null && (mekanAdi?.trim().isNotEmpty ?? false);
      return Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Panel içerik kadar uzar (en fazla ekranın %85'i, fazlası
            // kaydırılır).
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  (showMekan ? 12 : 20) + (showMekan ? 0 : bottom),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (u.gorsel.isNotEmpty) ...[
                      // 4:3; çok uzun ekranlarda en fazla ekranın %40'ı.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: screenH * 0.4),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: NetImage(u.gorsel),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            u.ad,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (u.fiyat.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${u.fiyat} ₺',
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (u.aciklama.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        u.aciklama,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: _descColor,
                        ),
                      ),
                    ],
                    if (u.icindekiler.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'İçindekiler: ${u.icindekiler}',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: _descColor,
                        ),
                      ),
                    ],
                    if (u.kalori != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_outlined,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${u.kalori} kcal',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (showMekan)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
                child: _MekanRow(
                  ad: mekanAdi!.trim(),
                  alt: mekanAlt?.trim() ?? '',
                  onTap: () {
                    Navigator.pop(ctx);
                    onOpenMekan();
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Panelin altındaki "işletmeye git" satırı.
class _MekanRow extends StatelessWidget {
  final String ad;
  final String alt;
  final VoidCallback onTap;
  const _MekanRow({required this.ad, required this.alt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$ad işletmesini aç',
      excludeSemantics: true,
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      if (alt.isNotEmpty)
                        Text(
                          alt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'İşletmeyi gör',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
