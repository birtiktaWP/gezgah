import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/kedy_chat.dart';
import '../widgets/place_cards.dart';
import '../widgets/search_modal.dart';
import '../widgets/tabbar.dart';
import 'detail_screen.dart';
import 'map_screen.dart';

class CategoryScreen extends StatefulWidget {
  final String title;
  const CategoryScreen({super.key, this.title = 'Kahvaltı'});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  int _activeCat = 0;
  late final List<dynamic> _places = MockData.categoryList;

  void _openDetail() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const DetailScreen()));
  }

  void _onTab(int i) {
    switch (i) {
      case 0:
        Navigator.popUntil(context, (r) => r.isFirst);
        break;
      case 1:
        showSearchModal(context, onOpenDetail: _openDetail);
        break;
      case 2:
        showKedyChat(context);
        break;
      case 4:
        Navigator.popUntil(context, (r) => r.isFirst);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _header(),
              const SizedBox(height: 16),
              _categoryPills(),
              const SizedBox(height: 18),
              _listHead(),
              ...List.generate(_places.length, (i) {
                final p = _places[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: ListTileCard(
                    place: p,
                    onTap: _openDetail,
                    onFav: () => setState(() => p.favorite = !p.favorite),
                  ),
                );
              }),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: FloatingTabBar(activeIndex: 0, onTap: _onTab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GlassButton(
              icon: Icons.chevron_left,
              flat: true,
              onTap: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
            ),
            GlassButton(
              icon: Icons.location_on_outlined,
              flat: true,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MapScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryPills() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: MockData.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = MockData.categories[i];
          return CategoryPill(
            icon: c.icon,
            label: c.label,
            active: _activeCat == i,
            onTap: () => setState(() => _activeCat = i),
          );
        },
      ),
    );
  }

  Widget _listHead() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_places.length * 4} mekan bulundu',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          Row(
            children: [
              _actBtn(Icons.swap_vert),
              const SizedBox(width: 8),
              _actBtn(Icons.filter_list),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actBtn(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
      ),
      child: Icon(icon, size: 18, color: AppColors.primary),
    );
  }
}
