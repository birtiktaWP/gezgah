import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Etkinlik detay ekranı — mekan detayına benzer düzen (üst görsel + yuvarlak
/// köşeli gövde). İçerik `Etkinlik` (mekan detayındaki `etkinlikler` veya
/// `/etkinlikler/{id}`) verisinden gelir.
class EventDetailScreen extends StatelessWidget {
  final Etkinlik etkinlik;
  const EventDetailScreen({super.key, required this.etkinlik});

  @override
  Widget build(BuildContext context) {
    final e = etkinlik;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _hero(e),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: EdgeInsets.fromLTRB(22, 24, 22, 40 + bottomInset),
                  child: _body(e),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_left,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(Etkinlik e) {
    return SizedBox(
      height: 300,
      child: e.image.isNotEmpty
          ? NetImage(e.image)
          : Container(
              color: AppColors.primarySoft,
              child: const Center(
                child: Icon(Icons.celebration_outlined,
                    size: 56, color: AppColors.primary),
              ),
            ),
    );
  }

  Widget _body(Etkinlik e) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.name,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (e.tarihSaat.isNotEmpty)
              _chip(Icons.event_outlined, e.tarihSaat),
            _chip(Icons.local_offer_outlined, e.fiyatLabel),
          ],
        ),
        if (e.description.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Açıklama',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(height: 10),
          Text(e.description,
              style: const TextStyle(
                  fontSize: 14, height: 1.65, color: AppColors.muted)),
        ],
      ],
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 7),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}
