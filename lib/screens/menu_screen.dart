import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// QR menü sayfası — mekan detayındaki "QR Menü" ile açılır (MEKAN_DETAY.md).
/// Menü verisi (`menu`) detay yanıtından geldiği için burada yeniden istek
/// atılmaz; kategori → ürün yapısında listelenir.
class MenuScreen extends StatelessWidget {
  final String title; // mekan adı
  final List<MenuKategori> menu;
  const MenuScreen({super.key, required this.title, required this.menu});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: menu.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Bu mekan için menü bulunmuyor.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 14, color: AppColors.muted)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
                    children: [
                      for (final cat in menu) ..._category(cat),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 22, 22),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.7, -1.1),
          radius: 1.2,
          colors: [AppColors.primary2, AppColors.primary],
          stops: [0.0, 0.55],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GlassButton(
                icon: Icons.chevron_left, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Menü',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  if (title.isNotEmpty)
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _category(MenuKategori cat) {
    return [
      if (cat.kategori.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: Text(cat.kategori,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ),
      ...cat.urunler.map(_item),
      const SizedBox(height: 6),
    ];
  }

  Widget _item(MenuUrun u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (u.gorsel.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 66, height: 66, child: NetImage(u.gorsel)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(u.ad,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                    ),
                    if (u.fiyat.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('${u.fiyat} ₺',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ],
                  ],
                ),
                if (u.aciklama.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(u.aciklama,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
                ],
                if (u.icindekiler.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('İçindekiler: ${u.icindekiler}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
                ],
                if (u.kalori != null) ...[
                  const SizedBox(height: 4),
                  Text('${u.kalori} kcal',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
