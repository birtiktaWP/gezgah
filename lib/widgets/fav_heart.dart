import 'package:flutter/material.dart';
import '../data/auth_service.dart';
import '../data/favorites_service.dart';
import '../screens/login_screen.dart';
import '../theme/app_theme.dart';
import 'confetti.dart';

/// Favori (kalp) butonu — [FavoritesService]'i dinler, uygulama genelinde
/// senkron gösterir ve dokununca ekler/çıkarır. Giriş yoksa önce login açar.
///
/// [circle] true iken beyaz daireli (kart görselleri üstü) görünüm; false iken
/// düz ikon (liste satırı içi).
class FavHeart extends StatelessWidget {
  final int postId;
  final bool circle;
  final double size; // circle: daire çapı, plain: ikon boyutu
  final Color? inactiveColor;

  const FavHeart({
    super.key,
    required this.postId,
    this.circle = true,
    this.size = 30,
    this.inactiveColor,
  });

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !AuthService.instance.isLoggedIn) return;
      await FavoritesService.instance.load();
    }
    final willAdd = !FavoritesService.instance.isFavorite(postId);
    try {
      await FavoritesService.instance.toggle(postId);
      if (willAdd && context.mounted) celebrateFavorite(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: FavoritesService.instance.ids,
      builder: (context, ids, _) {
        final active = ids.contains(postId);
        final icon = active ? Icons.favorite : Icons.favorite_border;
        if (circle) {
          return GestureDetector(
            onTap: () => _toggle(context),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              child: Icon(icon,
                  size: size * 0.5,
                  color: active ? AppColors.heart : AppColors.primary),
            ),
          );
        }
        return GestureDetector(
          onTap: () => _toggle(context),
          behavior: HitTestBehavior.opaque,
          child: Icon(icon,
              size: size,
              color: active
                  ? AppColors.heart
                  : (inactiveColor ?? const Color(0xFFC8C8D4))),
        );
      },
    );
  }
}
