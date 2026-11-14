import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/uye_aktivite.dart';
import '../theme/app_theme.dart';
import '../widgets/account_page.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

/// Değerlendirmelerim — üyenin mekanlara verdiği puan + yorumlar
/// (`GET /uye/degerlendirmeler`, UYE_DEGERLENDIRME_REZERVASYON.md §1).
/// Her kayıt düzenlenebilir (puan/yorum) ve silinebilir.
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final ScrollController _scroll = ScrollController();
  final List<Degerlendirmem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;
  bool _notReady = false;
  bool _hasMore = false;
  int? _nextPage;

  static const _hero = AccountHero(
    title: 'Değerlendirmelerim',
    subtitle: 'Mekanlara verdiğin puanlar ve yorumlar',
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _notReady = false;
    });
    try {
      final r = await UyeAktiviteRepository.instance.degerlendirmeler();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _hasMore = r.hasMore;
        _nextPage = r.nextPage;
        _loading = false;
      });
    } on UyeAktiviteHazirDegil {
      if (mounted) {
        setState(() {
          _notReady = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore || _nextPage == null) return;
    setState(() => _loadingMore = true);
    try {
      final r = await UyeAktiviteRepository.instance.degerlendirmeler(
        page: _nextPage!,
      );
      if (!mounted) return;
      final seen = {for (final d in _items) d.id};
      setState(() {
        _items.addAll(r.items.where((d) => seen.add(d.id)));
        _hasMore = r.hasMore && r.items.isNotEmpty;
        _nextPage = _hasMore ? r.nextPage : null;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _openVenue(Degerlendirmem d) {
    if (d.mekan.id <= 0) return;
    if (!d.mekan.yayinda) {
      _snack('Bu mekan artık yayında değil.');
      return;
    }
    Navigator.push(
      context,
      detailRoute(builder: (_) => DetailScreen(place: d.mekan.toPlace())),
    );
  }

  Future<void> _edit(Degerlendirmem d) async {
    final saved = await showModalBottomSheet<({int puan, String yorum})>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditReviewSheet(review: d),
    );
    if (saved == null || !mounted) return;
    final i = _items.indexWhere((x) => x.id == d.id);
    if (i < 0) return;
    setState(() {
      _items[i] = Degerlendirmem(
        id: d.id,
        puan: saved.puan,
        yorum: saved.yorum,
        tarih: DateTime.now(),
        durum: d.durum,
        mekan: d.mekan,
      );
    });
    _snack('Değerlendirmen güncellendi');
  }

  Future<void> _delete(Degerlendirmem d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Değerlendirme silinsin mi?'),
        content: Text('${d.mekan.ad} için verdiğin puan ve yorum silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.closing),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await UyeAktiviteRepository.instance.degerlendirmeSil(d.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x.id == d.id));
      _snack('Değerlendirme silindi');
    } on UyeAktiviteHazirDegil {
      _snack('Bu işlem şu an kullanılamıyor.');
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Değerlendirme silinemedi. Tekrar dene.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountPage(body: _body());
  }

  Widget _body() {
    if (_loading) {
      return const AccountCentered(
        hero: _hero,
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_notReady) {
      return const AccountCentered(
        hero: _hero,
        child: AccountInfo(
          icon: Icons.star_outline_rounded,
          title: 'Çok yakında',
          subtitle:
              'Mekanlara verdiğin puan ve yorumlar yakında burada listelenecek.',
        ),
      );
    }
    if (_error) {
      return AccountCentered(
        hero: _hero,
        child: AccountInfo(
          icon: Icons.wifi_off_rounded,
          title: 'Değerlendirmeler yüklenemedi',
          subtitle: 'İnternet bağlantını kontrol edip tekrar dene.',
          action: 'Tekrar dene',
          onAction: _load,
        ),
      );
    }
    if (_items.isEmpty) {
      return const AccountCentered(
        hero: _hero,
        child: AccountInfo(
          icon: Icons.star_outline_rounded,
          title: 'Henüz değerlendirmen yok',
          subtitle:
              'Gittiğin mekanların sayfasından "Değerlendirme Yap" ile puan '
              'verebilirsin.',
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 130),
        itemCount: 1 + _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: _hero,
            );
          }
          final i = index - 1;
          if (i < _items.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: _card(_items[i]),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(Degerlendirmem d) {
    final m = d.mekan;
    final (String? label, Color color) = switch (d.durum) {
      'beklemede' => ('Onay bekliyor', const Color(0xFFD97706)),
      'reddedildi' => ('Yayınlanmadı', AppColors.closing),
      _ => (null, AppColors.open),
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.listTile,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openVenue(d),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: m.gorsel.isNotEmpty
                              ? NetImage(m.gorsel)
                              : const ColoredBox(
                                  color: AppColors.primarySoft,
                                  child: Icon(
                                    Icons.storefront_outlined,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.ad.isEmpty ? 'Mekan' : m.ad,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (m.konum.isNotEmpty)
                              Text(
                                m.konum,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Seçenekler',
                icon: const Icon(Icons.more_vert, color: AppColors.muted),
                onSelected: (v) => v == 'sil' ? _delete(d) : _edit(d),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                  PopupMenuItem(
                    value: 'sil',
                    child: Text(
                      'Sil',
                      style: TextStyle(color: AppColors.closing),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                _Stars(d.puan),
                const SizedBox(width: 8),
                if (d.tarih != null)
                  Text(
                    TrTarih.kisa(d.tarih!.toLocal()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                const Spacer(),
                if (label != null) StatusChip(label, color),
              ],
            ),
          ),
          if (d.yorum.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                d.yorum,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Color(0xFF4A4A5A),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int value;
  static const double size = 16;
  const _Stars(this.value);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '5 üzerinden $value puan',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i <= value ? AppColors.star : const Color(0xFFCFCFDB),
            ),
        ],
      ),
    );
  }
}

/// Puan + yorum düzenleme paneli. Mevcut `POST /mekanlar/{id}/degerlendirme`
/// (upsert) ile kaydeder; başarıda yeni değerlerle kapanır.
class _EditReviewSheet extends StatefulWidget {
  final Degerlendirmem review;
  const _EditReviewSheet({required this.review});

  @override
  State<_EditReviewSheet> createState() => _EditReviewSheetState();
}

class _EditReviewSheetState extends State<_EditReviewSheet> {
  late int _puan = widget.review.puan;
  late final TextEditingController _yorum = TextEditingController(
    text: widget.review.yorum,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _yorum.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_puan < 1) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await HomeRepository.instance.degerlendirmeGonder(
        widget.review.mekan.id,
        puan: _puan,
        yorum: _yorum.text,
      );
      if (!mounted) return;
      Navigator.pop(context, (puan: _puan, yorum: _yorum.text.trim()));
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetGrabber(),
              const SizedBox(height: 6),
              const Text(
                'Değerlendirmeyi düzenle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.review.mekan.ad,
                style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Semantics(
                        button: true,
                        label: '$i yıldız',
                        selected: i == _puan,
                        child: IconButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _puan = i);
                                },
                          iconSize: 38,
                          icon: Icon(
                            i <= _puan
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i <= _puan
                                ? AppColors.star
                                : const Color(0xFFCFCFDB),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _yorum,
                enabled: !_saving,
                maxLines: 4,
                minLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Deneyimini paylaş (opsiyonel)',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.closing,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_saving || _puan < 1) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
