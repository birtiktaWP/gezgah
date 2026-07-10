import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

/// Bildirimler — alttan açılan panel. `GET /bildirimler`'den beslenir.
/// Tarihe göre gruplanır; tek tek veya tümü okundu işaretlenebilir (yerel).
void showNotifications(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _NotificationsSheet(),
  );
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _loading = true;
  bool _error = false;
  List<AppNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final list = await HomeRepository.instance.bildirimler(limit: 40);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  bool get _hasUnread => _items.any((n) => n.unread);

  /// Tarihe göre grup etiketi (şimdiye göre).
  String _group(DateTime? d) {
    if (d == null) return 'Daha Önce';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Bugün';
    if (diff < 7) return 'Bu Hafta';
    return 'Daha Önce';
  }

  /// "az önce" / "3 saat önce" / "2 gün önce" / "8 ay önce" gibi.
  String _relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} hafta önce';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} ay önce';
    return '${(diff.inDays / 365).floor()} yıl önce';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Row(
              children: [
                const Text('Bildirimler',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_hasUnread)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final n in _items) {
                          n.unread = false;
                        }
                      });
                      // Sunucuya bildir (cihaz token'ı ile). Endpoint yayında
                      // değilse sessizce yerel işaretleme kalır.
                      HomeRepository.instance.tumunuOkundu();
                    },
                    child: const Text('Tümünü okundu işaretle',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.primary),
        ),
      );
    }
    if (_error) {
      return _info(
        icon: Icons.wifi_off_rounded,
        title: 'Bildirimler yüklenemedi',
        subtitle: 'İnternet bağlantını kontrol edip tekrar dene.',
        action: 'Tekrar dene',
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return _info(
        icon: Icons.notifications_off_outlined,
        title: 'Henüz bildirimin yok',
        subtitle: 'Kampanya ve güncellemeler burada görünecek.',
      );
    }

    // Grupları sırayla (Bugün, Bu Hafta, Daha Önce) göster.
    const order = ['Bugün', 'Bu Hafta', 'Daha Önce'];
    final groups = <String, List<AppNotification>>{};
    for (final n in _items) {
      groups.putIfAbsent(_group(n.date), () => []).add(n);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        for (final key in order)
          if (groups[key] != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              child: Text(key,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted)),
            ),
            ...groups[key]!.map(_tile),
          ],
      ],
    );
  }

  Widget _tile(AppNotification n) {
    return GestureDetector(
      onTap: () => setState(() => n.unread = false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: AppColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.campaign_outlined,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.text,
                      style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight:
                              n.unread ? FontWeight.w700 : FontWeight.w500,
                          color: AppColors.ink)),
                  if (_relative(n.date).isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(_relative(n.date),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (n.unread)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 6),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Widget _info({
    required IconData icon,
    required String title,
    required String subtitle,
    String? action,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13.5, color: AppColors.muted)),
            if (action != null) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(action,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
