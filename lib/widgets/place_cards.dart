import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Yatay rail'deki kompakt popüler mekan kartı (.pop)
class PopCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onTap;
  final VoidCallback? onFav;
  final bool sponsored;

  const PopCard({
    super.key,
    required this.place,
    this.onTap,
    this.onFav,
    this.sponsored = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 116,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(place.image),
                  if (sponsored)
                    Positioned(
                      top: 9,
                      left: 9,
                      child: _Tag('Sponsorlu'),
                    )
                  else
                    Positioned(
                      top: 9,
                      right: 9,
                      child: FavButton(active: place.favorite, onTap: onFav),
                    ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: place.rating > 0
                        ? RatingBadge(place.rating)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(place.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800)),
    );
  }
}

/// 2 sütunlu ızgaradaki dikey mekan kartı (.tile)
class GridTile2 extends StatelessWidget {
  final Place place;
  final VoidCallback? onTap;
  final VoidCallback? onFav;

  const GridTile2({super.key, required this.place, this.onTap, this.onFav});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(place.image),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: OpenDot(open: place.state != OpenState.closing),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: FavButton(
                        active: place.favorite, onTap: onFav, size: 28),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2)),
                      ),
                      const Icon(Icons.star_rounded,
                          size: 12, color: AppColors.star),
                      const SizedBox(width: 3),
                      Text(place.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(place.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
                  const SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(place.distance,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.muted)),
                        ],
                      ),
                      Text(place.price,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kategori ekranındaki yatay liste öğesi (.list-col .tile) + sponsorlu varyant.
class ListTileCard extends StatelessWidget {
  final Place place;
  final VoidCallback? onTap;
  final VoidCallback? onFav;

  const ListTileCard({super.key, required this.place, this.onTap, this.onFav});

  @override
  Widget build(BuildContext context) {
    if (place.sponsored) return _sponsored(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 108,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.listTile,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 108,
              height: 108,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(place.image),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: OpenDot(open: place.state != OpenState.closing),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2)),
                        ),
                        GestureDetector(
                          onTap: onFav,
                          child: Icon(
                            place.favorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 20,
                            color: place.favorite
                                ? AppColors.heart
                                : const Color(0xFFC8C8D4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(place.subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(place.distance,
                                style: const TextStyle(
                                    fontSize: 11.5, color: AppColors.muted)),
                          ],
                        ),
                        Text(place.price,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sponsored(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(place.image),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: OpenDot(open: place.state != OpenState.closing),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(place.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2)),
                      const SizedBox(width: 7),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            size: 13, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(place.subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft2,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('SPONSORLU',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: AppColors.primary)),
                      ),
                      Text(place.price,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
