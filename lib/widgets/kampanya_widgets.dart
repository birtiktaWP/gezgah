import 'package:flutter/material.dart';

import '../data/kampanya.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'common.dart';

/// İndirim rozeti: "%30". [upTo] true ise "%30'a varan" (birden çok
/// kampanyası olan işletme kartı).
class KampanyaRozet extends StatelessWidget {
  final int oran;
  final bool upTo;
  final double fontSize;

  const KampanyaRozet(
    this.oran, {
    super.key,
    this.upTo = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.62,
        vertical: fontSize * 0.28,
      ),
      decoration: BoxDecoration(
        color: AppColors.closing,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '%$oran',
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
            ),
            if (upTo)
              TextSpan(
                text: "'a varan",
                style: TextStyle(
                  fontSize: fontSize * 0.82,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        style: const TextStyle(color: Colors.white, height: 1.15),
      ),
    );
  }
}

/// Kampanya satırı (mekan detayı ve kampanyalar listesindeki kart içinde):
/// solda oran kutusu, ortada başlık + kapsam · kalan süre / kontenjan, sağda
/// ok. Dokununca [onTap].
class KampanyaSatiri extends StatelessWidget {
  final Kampanya kampanya;
  final VoidCallback onTap;
  final bool dense;

  const KampanyaSatiri({
    super.key,
    required this.kampanya,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final k = kampanya;
    final meta = [
      k.kapsam,
      k.kalanSure(),
      k.kontenjan(),
    ].whereType<String>().join(' · ');
    final box = dense ? 46.0 : 52.0;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dense ? 7 : 10),
          child: Row(
            children: [
              Container(
                width: box,
                height: box,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x14E0533D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '%${k.oran}',
                  style: TextStyle(
                    fontSize: dense ? 15 : 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.closing,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.gosterilenBaslik,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kampanyalar listesindeki işletme kartı: geniş görsel + "%30'a varan"
/// rozeti; altta ad, konum, kampanya satırları (en çok 3, fazlası
/// "+N kampanya daha").
class KampanyaMekanKarti extends StatelessWidget {
  final KampanyaliMekan item;
  final ValueChanged<Kampanya> onKampanya;
  final VoidCallback onMekan;

  const KampanyaMekanKarti({
    super.key,
    required this.item,
    required this.onKampanya,
    required this.onMekan,
  });

  @override
  Widget build(BuildContext context) {
    final m = item.mekan;
    final list = item.kampanyalar;
    final shown = list.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.listTile,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onKampanya(list.first),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  m.thumbWide.isNotEmpty
                      ? NetImage(m.thumbWide)
                      : const ColoredBox(
                          color: AppColors.primarySoft,
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: KampanyaRozet(
                      item.enYuksekIndirim,
                      upTo: list.length > 1,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 6),
            child: GestureDetector(
              onTap: onMekan,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.ad.isNotEmpty ? m.ad : 'Mekan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        if (m.konum.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const AppSvgIcon(
                                AppIcons.pin,
                                size: 11,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  m.konum,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Text(
                    'Mekan',
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, thickness: 1, color: AppColors.line),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 12, 8),
            child: Column(
              children: [
                for (final k in shown)
                  KampanyaSatiri(
                    kampanya: k,
                    dense: true,
                    onTap: () => onKampanya(k),
                  ),
                // Tüm kampanyalar mekan detayındaki "Kampanyalar" bölümünde.
                if (list.length > shown.length)
                  GestureDetector(
                    onTap: onMekan,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Text(
                        '+${list.length - shown.length} kampanya daha',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
