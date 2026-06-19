import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'place_cards.dart';

/// Gelişmiş arama — tam ekran açılan modal.
void showSearchModal(BuildContext context, {void Function()? onOpenDetail}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => _SearchModal(onOpenDetail: onOpenDetail),
      transitionsBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
    ),
  );
}

class _SearchModal extends StatefulWidget {
  final void Function()? onOpenDetail;
  const _SearchModal({this.onOpenDetail});

  @override
  State<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<_SearchModal> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _sectionTitle('Popüler Aramalar'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MockData.popularSearches
                        .map((s) => _chip(s, Icons.trending_up))
                        .toList(),
                  ),
                  const SizedBox(height: 26),
                  _kedyHeader(),
                  const SizedBox(height: 12),
                  ...MockData.kedyTips.map(_kedyItem),
                  const SizedBox(height: 26),
                  _sectionTitle('Sponsorlu', link: true),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 188,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: MockData.popular.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, i) => PopCard(
                        place: MockData.popular[i],
                        sponsored: true,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpenDetail?.call();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _sectionTitle('Kategoriler'),
                  const SizedBox(height: 14),
                  _categoryGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Ara',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Restoran, kafe, marka veya mekan ara…',
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _controller.clear()),
                    child: const Icon(Icons.cancel,
                        color: AppColors.muted, size: 20),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, {bool link = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(t,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        if (link)
          const Text('Tümü',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
      ],
    );
  }

  Widget _chip(String label, IconData icon) {
    return GestureDetector(
      onTap: () => setState(() => _controller.text = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _kedyHeader() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: const Center(child: KedyIcon(size: 18, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Kedy Tavsiyeleri',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Sana özel akıllı öneriler',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }

  Widget _kedyItem(String label) {
    return GestureDetector(
      onTap: () => setState(() => _controller.text = label),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.lightbulb_outline,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryGrid() {
    final cats = [
      [Icons.local_cafe_outlined, 'Kafe'],
      [Icons.coffee_outlined, 'Restoran'],
      [Icons.apartment_outlined, 'Otel'],
      [Icons.sentiment_satisfied_alt_outlined, 'Eğlence'],
      [Icons.account_balance_outlined, 'Müze'],
      [Icons.park_outlined, 'Doğa'],
      [Icons.local_bar_outlined, 'Bar'],
      [Icons.cake_outlined, 'Tatlı'],
    ];
    return Wrap(
      spacing: 14,
      runSpacing: 16,
      children: cats.map((c) {
        return SizedBox(
          width: 64,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _controller.text = c[1] as String),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(c[0] as IconData,
                      color: AppColors.primary, size: 24),
                ),
              ),
              const SizedBox(height: 8),
              Text(c[1] as String,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
