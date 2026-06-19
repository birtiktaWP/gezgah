import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Ağ görseli için tutarlı placeholder/error davranışı olan sarmalayıcı.
class NetImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (c, _) => Container(color: const Color(0xFFEDEDF3)),
      errorWidget: (c, _, __) => Container(
        color: const Color(0xFFEDEDF3),
        child: const Icon(Icons.image_not_supported_outlined,
            color: AppColors.muted),
      ),
    );
  }
}

/// "Gezgah" markası — HTML'deki orijinal SVG logo.
class GezgahWordmark extends StatelessWidget {
  final Color color;
  final double size; // logo yüksekliği (px)
  const GezgahWordmark({super.key, this.color = Colors.white, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo.svg',
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: 'Gezgah',
    );
  }
}

/// Kedy asistanı kedi ikonu — HTML'deki orijinal SVG.
class KedyIcon extends StatelessWidget {
  final double size;
  final Color color;
  const KedyIcon({super.key, this.size = 24, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/kedy.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: 'Kedy',
    );
  }
}

/// Hero/flat header'lardaki cam efektli yuvarlak buton.
class GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot;
  final bool flat; // beyaz zeminli (hero-flat) varyant

  const GlassButton({
    super.key,
    required this.icon,
    this.onTap,
    this.showDot = false,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: flat ? AppColors.primarySoft : Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: flat ? Colors.transparent : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon,
                size: 19, color: flat ? AppColors.primary : Colors.white),
          ),
          if (showDot)
            Positioned(
              top: 8,
              right: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5E7E),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: flat ? Colors.white : AppColors.primary, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bölüm başlığı + "Tümü >" bağlantısı.
class SectionHead extends StatelessWidget {
  final String title;
  final VoidCallback? onAll;
  const SectionHead(this.title, {super.key, this.onAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: AppColors.ink)),
          ),
          if (onAll != null)
            GestureDetector(
              onTap: onAll,
              child: const Row(
                children: [
                  Text('Tümü',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Yatay kaydırılan kategori hapı.
class CategoryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const CategoryPill({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(9, 8, 14, 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primarySoft,
              ),
              child: Icon(icon,
                  size: 15, color: active ? Colors.white : AppColors.primary),
            ),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// Puan rozeti (yıldız + değer).
class RatingBadge extends StatelessWidget {
  final double rating;
  const RatingBadge(this.rating, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppColors.star),
          const SizedBox(width: 3),
          Text(rating.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}

/// Açık / Kapanıyor rozeti.
class OpenDot extends StatelessWidget {
  final bool open;
  const OpenDot({super.key, required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? AppColors.open : AppColors.closing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('● ',
              style: TextStyle(fontSize: 8, color: color)),
          Text(open ? 'Açık' : 'Kapanıyor',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// Yuvarlak favori (kalp) butonu — kart görselleri üstünde.
class FavButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;
  final double size;
  const FavButton({super.key, required this.active, this.onTap, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
        ),
        child: Icon(
          active ? Icons.favorite : Icons.favorite_border,
          size: size * 0.5,
          color: active ? AppColors.heart : AppColors.primary,
        ),
      ),
    );
  }
}
