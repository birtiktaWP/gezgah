import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

/// Etkinlik detay ekranı — mekan detayına benzer düzen (üst görsel + yuvarlak
/// köşeli gövde). İçerik `Etkinlik` (mekan detayındaki `etkinlikler`, liste
/// ya da öne çıkan kaydı) ile hemen çizilir; açılınca `/etkinlikler/{id}` ile
/// eksik alanlar (bugün listede gelmeyen `mekan`) tamamlanır.
/// Mekan satırına dokununca (mekan yayındaysa) mekan detayı açılır.
class EventDetailScreen extends StatefulWidget {
  final Etkinlik etkinlik;
  const EventDetailScreen({super.key, required this.etkinlik});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Etkinlik _e = widget.etkinlik;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final full = await HomeRepository.instance.etkinlikDetay(_e.id);
    if (!mounted || full == null) return;
    setState(() => _e = _e.merge(full));
  }

  void _openMekan() {
    final id = _e.mekanId;
    if (!_e.mekanAcilir || id == null) return;
    final alt = _e.mekanIlce;
    Navigator.push(
      context,
      detailRoute(
        builder: (_) => DetailScreen(
          place: Place(
            id: id,
            name: _e.mekanAd.isNotEmpty ? _e.mekanAd : 'Mekan',
            category: 'Mekan',
            subtitle: alt,
            rating: 0,
            distance: alt,
            price: '',
            image: '',
            lat: double.nan,
            lng: double.nan,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
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
    final mekan = [e.mekanAd, e.mekanIlce]
        .where((s) => s.isNotEmpty)
        .join(' · ');
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
            if (mekan.isNotEmpty)
              _chip(
                Icons.storefront_outlined,
                mekan,
                onTap: e.mekanAcilir ? _openMekan : null,
              ),
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

  /// Bilgi çipi. [onTap] verilirse (mekan) sağda ok çıkar ve dokunulabilir.
  Widget _chip(IconData icon, String text, {VoidCallback? onTap}) {
    final chip = Container(
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
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right,
                size: 17, color: AppColors.primary),
          ],
        ],
      ),
    );
    return onTap == null ? chip : GestureDetector(onTap: onTap, child: chip);
  }
}
