import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/kedy_chat.dart';
import '../widgets/place_cards.dart';
import '../widgets/tabbar.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ScrollController _scroll = ScrollController();
  bool _liked = true;
  bool _aboutExpanded = false;
  bool _showTabbar = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 60;
      if (show != _showTabbar) setState(() => _showTabbar = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
              _hero(),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 40),
                  child: _body(),
                ),
              ),
            ],
          ),
          _topButtons(),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: _showTabbar ? 0 : -120,
            child: SafeArea(child: _detailTabbar()),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const NetImage(
              'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=900&q=75'),
          Positioned(
            right: 14,
            bottom: 32,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x8C080526),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.photo_library_outlined,
                      size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text('1 / 15',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _roundBtn(Icons.chevron_left, AppColors.ink,
                () => Navigator.pop(context)),
            _roundBtn(
              _liked ? Icons.favorite : Icons.favorite_border,
              _liked ? AppColors.heart : const Color(0xFFC8C8D4),
              () => setState(() => _liked = !_liked),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: AppShadows.soft,
        ),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }

  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _badge(Icons.local_cafe_outlined, 'Kahve & Brunch'),
        const SizedBox(height: 12),
        const Text('Petra Roasting Co.',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4)),
        const SizedBox(height: 6),
        Row(
          children: const [
            Icon(Icons.location_on_outlined,
                size: 15, color: AppColors.primary),
            SizedBox(width: 6),
            Text('Moda, Kadıköy · 3.5 km',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 16),
        _verifiedBanner(),
        const SizedBox(height: 14),
        _statusStrip(),
        const SizedBox(height: 16),
        _venueCard(),
        _divider(),
        _sectionH('Etkinlikler'),
        _eventsRail(),
        _divider(),
        _sectionH('Bilgiler'),
        ...MockData.detailInfo.map(_infoRow),
        _divider(),
        _sectionH('Mekan Özellikleri'),
        ...MockData.detailAmenities.map(_amenityRow),
        _divider(),
        _sectionH('Hakkında'),
        _about(),
        _divider(),
        _sectionH('Benzer Mekanlar'),
        _similarRail(),
      ],
    );
  }

  Widget _badge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _verifiedBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.verified, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Gezgah Onaylı Mekan',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('Kalite ve hizmet ekibimizce doğrulandı',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FBF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0DE)),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
                color: AppColors.open, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text('Şu an açık',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.open)),
          const SizedBox(width: 6),
          const Text("· 23:00'a kadar",
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _venueCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _vcAction(Icons.qr_code_2, 'QR Menü')),
                const VerticalDivider(width: 1, color: AppColors.line),
                Expanded(child: _vcAction(Icons.near_me_outlined, 'Yol Tarifi')),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _feat(Icons.wifi, 'Wi-Fi'),
                _feat(Icons.work_outline, 'Çalışma'),
                _feat(Icons.wb_sunny_outlined, 'Teras'),
                _feat(Icons.music_note_outlined, 'Canlı M.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vcAction(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.ink),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _feat(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppColors.ink),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Divider(height: 1, color: AppColors.line),
      );

  Widget _sectionH(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(t,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600)),
      );

  Widget _eventsRail() {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MockData.detailEvents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final e = MockData.detailEvents[i];
          return SizedBox(
            width: 168,
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
                    height: 116,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NetImage(e.image),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(999)),
                            child: Text('${e.day} ${e.month}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(e.location,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(InfoRow r) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: const Color(0xFFF4F5F9),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(r.icon, size: 18, color: AppColors.ink),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(r.value,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _amenityRow(Amenity a) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Opacity(
        opacity: a.available ? 1 : 0.5,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: a.available
                      ? AppColors.primarySoft
                      : const Color(0xFFF1F1F5),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(a.icon,
                  size: 19,
                  color: a.available
                      ? AppColors.primary
                      : const Color(0xFFB6B6C2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(a.name,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: a.available ? AppColors.ink : AppColors.muted)),
            ),
            Icon(
              a.available ? Icons.check_circle : Icons.cancel,
              size: 22,
              color: a.available ? AppColors.primary : const Color(0xFFC2C2CC),
            ),
          ],
        ),
      ),
    );
  }

  Widget _about() {
    return GestureDetector(
      onTap: () => setState(() => _aboutExpanded = !_aboutExpanded),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
              fontSize: 14, height: 1.65, color: AppColors.muted),
          children: [
            TextSpan(
                text: _aboutExpanded
                    ? '${MockData.aboutText} Geniş pencereleri, ahşap dokusu ve özenli servisiyle gün boyu konuk ağırlıyor.'
                    : MockData.aboutText),
            TextSpan(
              text: _aboutExpanded ? '  Daha az' : '  Devamını oku',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _similarRail() {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MockData.detailSimilar.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => PopCard(
          place: MockData.detailSimilar[i],
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DetailScreen())),
        ),
      ),
    );
  }

  Widget _detailTabbar() {
    return FloatingTabBarShell(
      onKedyTap: () => showKedyChat(context),
      items: [
        TabItemData(Icons.event_available_outlined, 'Rezerve', false, () {}),
        TabItemData(Icons.phone_outlined, 'Telefon', false, () {}),
        null,
        TabItemData(Icons.calendar_today_outlined, 'Etkinlik', false, () {}),
        TabItemData(Icons.qr_code_2, 'QR', false, () {}),
      ],
    );
  }
}
