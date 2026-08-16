import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// Takipçiler / Takip edilenler ekranını açar (SOSYAL_BEGENI_TAKIP.md §2).
/// [uyeId] verilmezse giriş yapan üyenin listeleri gösterilir.
Future<void> openFollows(BuildContext context,
    {int? uyeId, int initialTab = 0}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FollowListScreen(uyeId: uyeId, initialTab: initialTab),
    ),
  );
}

/// İki sekmeli takip ekranı: Takipçiler (edenler) + Takip edilenler.
class FollowListScreen extends StatefulWidget {
  final int? uyeId;
  final int initialTab; // 0: Takipçiler, 1: Takip edilenler
  const FollowListScreen({super.key, this.uyeId, this.initialTab = 0});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
      length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left, color: AppColors.ink),
                  ),
                  const Text('Takip',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            TabBar(
              controller: _tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Takipçiler'),
                Tab(text: 'Takip Edilenler'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _FollowList(followers: true, uyeId: widget.uyeId),
                  _FollowList(followers: false, uyeId: widget.uyeId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir takip listesi (takipçiler ya da takip edilenler), sayfalı.
class _FollowList extends StatefulWidget {
  final bool followers; // true: edenler (takipçiler), false: edilenler
  final int? uyeId;
  const _FollowList({required this.followers, this.uyeId});

  @override
  State<_FollowList> createState() => _FollowListState();
}

class _FollowListState extends State<_FollowList>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();
  final List<TakipUye> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextPage = 2;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<({List<TakipUye> items, bool hasMore, int? nextPage, int total})>
      _fetch(int page) {
    return widget.followers
        ? TakipRepository.instance.edenler(uyeId: widget.uyeId, page: page)
        : TakipRepository.instance.edilenler(uyeId: widget.uyeId, page: page);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _fetch(1);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(r.items);
      _hasMore = r.hasMore;
      _nextPage = r.nextPage ?? 2;
      _loading = false;
    });
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final r = await _fetch(_nextPage);
    if (!mounted) return;
    setState(() {
      _items.addAll(r.items);
      _hasMore = r.hasMore;
      _nextPage = r.nextPage ?? (_nextPage + 1);
      _loadingMore = false;
    });
  }

  Future<void> _toggle(int index) async {
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !mounted || !AuthService.instance.isLoggedIn) return;
    }
    final u = _items[index];
    final want = !(u.takipEdiyorum ?? false);
    setState(() => _items[index] = u.copyWith(takipEdiyorum: want));
    try {
      if (want) {
        await TakipRepository.instance.takipEt(u.uyeId);
      } else {
        await TakipRepository.instance.takipBirak(u.uyeId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _items[index] = u); // geri al
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is AuthException ? e.message : 'İşlem yapılamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Text(
          widget.followers ? 'Henüz takipçi yok.' : 'Henüz kimseyi takip etmiyor.',
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          );
        }
        return _row(_items[i], i);
      },
    );
  }

  Widget _row(TakipUye u, int index) {
    final following = u.takipEdiyorum;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.listTile,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 44,
                height: 44,
                child: u.avatar.isNotEmpty
                    ? NetImage(u.avatar)
                    : Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.person,
                            color: AppColors.primary),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(u.adSoyad.isEmpty ? 'Üye' : u.adSoyad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
            // takip_ediyorum null → bu kişi kendisi; buton gösterme.
            if (following != null)
              (following
                  ? OutlinedButton(
                      onPressed: () => _toggle(index),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Takipte',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    )
                  : ElevatedButton(
                      onPressed: () => _toggle(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Takip Et',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    )),
          ],
        ),
      ),
    );
  }
}
