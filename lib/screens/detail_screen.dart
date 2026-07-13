import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/api.dart';
import '../data/home_config.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/kedy_chat.dart';
import '../widgets/tabbar.dart';
import 'menu_screen.dart';

/// Mekan detay ekranı (`GET /mekanlar/{id}`, MEKAN_DETAY.md).
///
/// Başlık/görsel [place] önizlemesinden anında gösterilir; adres, çalışma
/// saatleri, özellikler, galeri ve QR menüsü gibi detaylar `mekanDetay` ile
/// çekilip doldurulur.
class DetailScreen extends StatefulWidget {
  final Place place;
  const DetailScreen({super.key, required this.place});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ScrollController _scroll = ScrollController();
  final PageController _gallery = PageController();

  late bool _liked = widget.place.favorite;
  bool _showTabbar = false;
  int _photo = 0;

  bool _loading = true;
  PlaceDetail? _detail;

  static const List<(String, String)> _days = [
    ('pazartesi', 'Pazartesi'),
    ('sali', 'Salı'),
    ('carsamba', 'Çarşamba'),
    ('persembe', 'Perşembe'),
    ('cuma', 'Cuma'),
    ('cumartesi', 'Cumartesi'),
    ('pazar', 'Pazar'),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 60;
      if (show != _showTabbar) setState(() => _showTabbar = show);
    });
    _fetch();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _gallery.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final d = await HomeRepository.instance.mekanDetay(widget.place.id);
    if (!mounted) return;
    setState(() {
      _detail = d;
      _loading = false;
    });
  }

  // --- Türetilmiş veriler -----------------------------------------------------

  List<String> get _images {
    final imgs = <String>[];
    final d = _detail;
    if (d != null) {
      for (final g in d.galeri) {
        if (g.url.isNotEmpty) imgs.add(g.url);
      }
      if (imgs.isEmpty && d.image.isNotEmpty) imgs.add(d.image);
    }
    if (imgs.isEmpty && widget.place.image.isNotEmpty) {
      imgs.add(widget.place.image);
    }
    return imgs;
  }

  String get _name => _detail?.name.isNotEmpty == true
      ? _detail!.name
      : widget.place.name;

  String get _typeLabel {
    final t = _detail?.type ?? '';
    return switch (t) {
      'restoran' => 'Restoran',
      'plaj' => 'Plaj',
      'mesire' => 'Mesire',
      _ => widget.place.category.isNotEmpty ? widget.place.category : 'Mekan',
    };
  }

  String get _location {
    final cd = _detail?.cityDistrict ?? '';
    if (cd.isNotEmpty) return cd;
    // Önizlemedeki alt yazı (mesafe olabilir) — konum benzeri değilse boş bırak.
    final sub = widget.place.subtitle;
    return sub;
  }

  /// Çalışma saatleri özeti: tüm günler aynı ve açıksa "Her gün X",
  /// aksi halde "Bugün X" / "Bugün kapalı".
  String _hoursSummary(PlaceDetail d) {
    final cs = d.calismaSaatleri;
    final values = <String>[];
    var closed = 0;
    for (final (key, _) in _days) {
      final v = cs[key];
      if (v == null || v.isEmpty) {
        closed++;
      } else {
        values.add(v);
      }
    }
    if (values.isEmpty) return 'Kapalı';
    if (closed == 0 && values.toSet().length == 1) {
      return 'Her gün ${_fmtHours(values.first)}';
    }
    final todayKey = _days[DateTime.now().weekday - 1].$1;
    final today = cs[todayKey];
    return today != null ? 'Bugün ${_fmtHours(today)}' : 'Bugün kapalı';
  }

  /// Saat aralığındaki tireleri " - " biçimine getirir
  /// (08:00–01:00 → 08:00 - 01:00).
  String _fmtHours(String v) =>
      v.replaceAll(RegExp(r'\s*[–—-]\s*'), ' - ').trim();

  /// Çalışma saatlerine göre şu an açık mı? Açıksa kapanış saatini de döner.
  /// Gece yarısını aşan aralıklar (ör. 18:00–01:00) desteklenir.
  ({bool open, String? until}) _openStatus(PlaceDetail d) {
    final cs = d.calismaSaatleri;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    (int, int)? parse(String? v) {
      if (v == null || v.isEmpty) return null;
      final m = RegExp(r'(\d{1,2}):(\d{2})\D+(\d{1,2}):(\d{2})').firstMatch(v);
      if (m == null) return null;
      final s = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
      final e = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
      return (s, e);
    }

    String fmtEnd(int end) {
      final h = (end ~/ 60) % 24;
      final mm = end % 60;
      return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }

    final todayKey = _days[now.weekday - 1].$1;
    final today = parse(cs[todayKey]);
    if (today != null) {
      final (s, e) = today;
      if (e > s) {
        if (nowMin >= s && nowMin < e) return (open: true, until: fmtEnd(e));
      } else if (nowMin >= s) {
        // Gece yarısını aşan aralık: başlangıçtan sonra açık (ertesi güne dek).
        return (open: true, until: fmtEnd(e));
      }
    }

    // Dünden devam eden gece aralığı (ör. dün 18:00–01:00, şu an 00:30).
    final yesterday = parse(cs[_days[(now.weekday - 2 + 7) % 7].$1]);
    if (yesterday != null) {
      final (s, e) = yesterday;
      if (e <= s && nowMin < e) return (open: true, until: fmtEnd(e));
    }

    return (open: false, until: null);
  }

  /// "Şu an açık · kapanış'a kadar" (yeşil) veya "Şu an kapalı" (kırmızı).
  Widget _statusStrip(PlaceDetail d) {
    final st = _openStatus(d);
    final open = st.open;
    final fg = open ? AppColors.open : AppColors.closing;
    final bg = open ? const Color(0xFFF0FBF4) : const Color(0xFFFDF1EF);
    final border = open ? const Color(0xFFD4F0DE) : const Color(0xFFF6D8D2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(open ? 'Şu an açık' : 'Şu an kapalı',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          if (open && st.until != null) ...[
            const SizedBox(width: 6),
            Text("· ${st.until}'a kadar",
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }

  // --- Build ------------------------------------------------------------------

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
    final images = _images;
    return SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            Container(
              color: AppColors.primarySoft,
              child: const Center(
                child: Icon(Icons.restaurant_outlined,
                    size: 48, color: AppColors.primary),
              ),
            )
          else
            PageView.builder(
              controller: _gallery,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _photo = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: _openGallery,
                child: NetImage(images[i]),
              ),
            ),
          if (images.length > 1)
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
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text('${_photo + 1} / ${images.length}',
                        style: const TextStyle(
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
            _roundBtn(Icons.chevron_left, AppColors.primary,
                () => Navigator.pop(context)),
            _roundBtn(
              _liked ? Icons.favorite : Icons.favorite_border,
              _liked ? AppColors.heart : const Color(0xFFC8C8D4),
              () => setState(() {
                _liked = !_liked;
                widget.place.favorite = _liked;
              }),
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
    final d = _detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        (d != null && d.kategoriler.isNotEmpty)
            ? _categoryBadges(d)
            : _badge(Icons.storefront_outlined, _typeLabel),
        const SizedBox(height: 12),
        Text(_name,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: AppColors.primary)),
        if (_location.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    widget.place.distance.isNotEmpty
                        ? '$_location · ${widget.place.distance}'
                        : _location,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _verifiedBanner(),
        const SizedBox(height: 18),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary),
              ),
            ),
          )
        else if (d == null)
          _errorNote()
        else
          ..._sections(d),
      ],
    );
  }

  List<Widget> _sections(PlaceDetail d) {
    return [
      if (d.calismaSaatleri.isNotEmpty) ...[
        _statusStrip(d),
        const SizedBox(height: 16),
      ],
      _venueCard(d),
      _divider(),
      _sectionH('Etkinlikler'),
      _eventsRail(),
      _divider(),
      _sectionH('Bilgiler'),
      ..._infoRows(d),
      if (d.filtreler.isNotEmpty) ...[
        _divider(),
        _sectionH('Olanaklar'),
        _olanaklar(d),
      ],
      if (d.description.isNotEmpty) ...[
        _divider(),
        _sectionH('Hakkında'),
        Text(d.description,
            style: const TextStyle(
                fontSize: 14, height: 1.65, color: AppColors.muted)),
      ],
    ];
  }

  Widget _errorNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.info_outline, size: 30, color: AppColors.muted),
          SizedBox(height: 10),
          Text('Bu mekanın detayları şu an yüklenemedi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  /// "Gezgah Onaylı Mekan" rozet bannerı (koyu mor, beyaz metin + onay rozeti).
  Widget _verifiedBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primary2],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_outlined,
                size: 22, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gezgah Onaylı Mekan',
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text('Kalite ve hizmet ekibimizce doğrulandı',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Başlık üstündeki kategori rozetleri (`kategoriler`). Birden fazlaysa hepsi
  /// gösterilir; kategori ikonu id'ye göre (HomeConfig) belirlenir.
  Widget _categoryBadges(PlaceDetail d) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in d.kategoriler) _badge(HomeConfig.iconFor(c.id), c.name),
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

  /// Aksiyonlar (QR Menü / Yol Tarifi / Ara) ve hemen altında mekan
  /// özellikleri (`restoran_ozellik` → `ozellikler`) şeridi.
  Widget _venueCard(PlaceDetail d) {
    final actions = <Widget>[];
    if (d.menu.isNotEmpty) {
      actions.add(_action(_qrIcon(), 'QR Menü', _openMenu));
    }
    if (d.hasCoord) {
      actions.add(_action(
          const Icon(Icons.near_me_outlined,
              size: 20, color: AppColors.primary),
          'Yol Tarifi',
          () {}));
    }
    final hasActions = actions.isNotEmpty;
    final hasOzellik = d.ozellikler.isNotEmpty;
    if (!hasActions && !hasOzellik) return const SizedBox.shrink();

    final row = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      row.add(Expanded(child: actions[i]));
      if (i != actions.length - 1) {
        row.add(const VerticalDivider(width: 1, color: AppColors.line));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (hasActions) IntrinsicHeight(child: Row(children: row)),
          if (hasActions && hasOzellik)
            const Divider(height: 1, color: AppColors.line),
          if (hasOzellik)
            Container(
              width: double.infinity,
              color: AppColors.primarySoft, // rgba(18,12,99,0.07)
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 14,
                alignment: WrapAlignment.spaceAround,
                children: [
                  for (final o in d.ozellikler) _feat(_ozellikIcon(o), o.name),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// QR Menü aksiyonunun ikonu (verilen SVG, primary renkte).
  Widget _qrIcon() => SvgPicture.string(
        _qrSvg,
        width: 20,
        height: 20,
        colorFilter:
            const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
      );

  static const String _qrSvg =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"></rect><rect x="14" y="3" width="7" height="7" rx="1"></rect><rect x="3" y="14" width="7" height="7" rx="1"></rect><line x1="14" y1="14" x2="14" y2="17"></line><line x1="17" y1="14" x2="17" y2="14.01"></line><line x1="21" y1="14" x2="21" y2="17"></line><line x1="14" y1="21" x2="17" y2="21"></line><line x1="21" y1="20" x2="21" y2="21"></line></svg>';

  /// Kart içi tekil özellik öğesi (ikon + etiket).
  Widget _feat(IconData icon, String label) {
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          Icon(icon, size: 25, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, height: 1.2, color: AppColors.primary)),
        ],
      ),
    );
  }

  // Detay etkinlikleri — şimdilik örnek (fake) veri.
  static const List<({String image, String day, String title, String sub})>
      _fakeEvents = [
    (
      image:
          'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=420&q=70',
      day: '14 Haz',
      title: 'Akustik Gece',
      sub: 'Cumartesi · 20:00',
    ),
    (
      image:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=420&q=70',
      day: '18 Haz',
      title: 'Kahve Tadımı',
      sub: 'Çarşamba · 15:00',
    ),
  ];

  Widget _eventsRail() {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _fakeEvents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _eventCard(_fakeEvents[i]),
      ),
    );
  }

  Widget _eventCard(({String image, String day, String title, String sub}) e) {
    return SizedBox(
      width: 190,
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
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 11, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Text(e.day,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(e.sub,
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

  Widget _action(Widget leading, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  List<Widget> _infoRows(PlaceDetail d) {
    final rows = <Widget>[];
    if (d.calismaSaatleri.isNotEmpty) {
      rows.add(_infoRow(Icons.schedule, 'Çalışma Saatleri', _hoursSummary(d),
          onTap: () => _openHoursSheet(d)));
    }
    if (d.adres.isNotEmpty) {
      rows.add(_infoRow(Icons.location_on_outlined, 'Adres', d.adres,
          onTap: () => _copy(d.adres, 'Adres')));
    }
    if (d.telefon.isNotEmpty) {
      rows.add(_infoRow(Icons.phone_outlined, 'İletişim', d.telefon,
          onTap: () => _copy(d.telefon, 'Numara')));
    }
    if (d.email.isNotEmpty) {
      rows.add(_infoRow(Icons.mail_outline, 'E-posta', d.email,
          onTap: () => _copy(d.email, 'E-posta')));
    }
    if (rows.isEmpty) {
      rows.add(_infoRow(Icons.info_outline, 'Bilgi',
          'Bu mekan için ek bilgi girilmemiş.'));
    }
    return rows;
  }

  Widget _infoRow(IconData icon, String title, String value,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F9),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }

  /// Değeri panoya kopyalar ve kısa bir bilgi gösterir.
  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$label kopyalandı'),
          duration: const Duration(seconds: 2)),
    );
  }

  /// Tam haftalık çalışma saatlerini alttan açılan panelde gösterir.
  void _openHoursSheet(PlaceDetail d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Çalışma Saatleri',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(height: 6),
              _hoursTable(d),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hoursTable(PlaceDetail d) {
    final todayKey = _days[DateTime.now().weekday - 1].$1;
    return Column(
      children: [
        for (final (key, label) in _days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: key == todayKey
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: AppColors.primary)),
                Text(
                    d.calismaSaatleri[key] != null
                        ? _fmtHours(d.calismaSaatleri[key]!)
                        : 'Kapalı',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: d.calismaSaatleri[key] != null
                            ? AppColors.primary
                            : AppColors.muted)),
              ],
            ),
          ),
      ],
    );
  }

  /// Özellik (restoran_ozellik) adına/slug'ına göre ikon türetir.
  IconData _ozellikIcon(OzellikItem o) {
    final s = '${o.slug} ${o.name}'.toLowerCase();
    bool has(String k) => s.contains(k);
    if (has('şömine') || has('somine') || has('şomine')) {
      return Icons.fireplace_outlined;
    }
    if (has('oyun')) return Icons.sports_esports_outlined;
    if (has('fasıl') ||
        has('fasil') ||
        has('canlı') ||
        has('canli') ||
        has('müzik') ||
        has('muzik') ||
        has('sıra') ||
        has('sira') ||
        has('gece')) {
      return Icons.music_note_outlined;
    }
    if (has('manzara')) return Icons.landscape_outlined;
    if (has('deniz') || has('sahil') || has('havuz')) {
      return Icons.pool_outlined;
    }
    if (has('bahçe') || has('bahce') || has('teras')) return Icons.deck_outlined;
    if (has('kahvalt')) return Icons.free_breakfast_outlined;
    if (has('nargile')) return Icons.air;
    if (has('spor') || has('maç') || has('mac')) {
      return Icons.sports_soccer_outlined;
    }
    return Icons.local_offer_outlined;
  }

  /// Aktif filtreler (Otopark, Wifi, Alkol...) — "Mekan Özellikleri" tarzı
  /// satır listesi (ikon kutusu + ad + onay çemberi). API yalnızca aktif
  /// filtreleri döndürdüğü için tümü onaylı gösterilir.
  Widget _olanaklar(PlaceDetail d) {
    return Column(
      children: [for (final f in d.filtreler) _olanakRow(f)],
    );
  }

  Widget _olanakRow(Filter f) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(11)),
            child: Icon(_filterIcon(f), size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(f.name,
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
          const Icon(Icons.check_circle_outline,
              size: 22, color: AppColors.primary),
        ],
      ),
    );
  }

  /// Filtre slug/adından bir ikon türetir. SVG `icon` alanı (MEKAN_DETAY.md)
  /// yok sayılır; istemci id/ad üzerinden kendi ikonunu uygular.
  IconData _filterIcon(Filter f) {
    final s = '${f.slug} ${f.name}'.toLowerCase();
    bool has(String k) => s.contains(k);
    if (has('otopark') || has('park')) return Icons.local_parking_outlined;
    if (has('wifi') || has('internet')) return Icons.wifi;
    if (has('alkol') || has('bar') || has('kokteyl')) {
      return Icons.local_bar_outlined;
    }
    if (has('vale')) return Icons.directions_car_outlined;
    if (has('rezerv')) return Icons.event_available_outlined;
    if (has('kredi') || has('kart')) return Icons.credit_card;
    if (has('muzik') || has('müzik') || has('canl')) {
      return Icons.music_note_outlined;
    }
    if (has('kahvalt')) return Icons.free_breakfast_outlined;
    if (has('teras') || has('bahce') || has('bahçe')) return Icons.deck;
    if (has('evcil') || has('pet')) return Icons.pets;
    if (has('tuvalet') || has(' wc')) return Icons.wc;
    if (has('sigara')) return Icons.smoking_rooms;
    if (has('engelli')) return Icons.accessible;
    if (has('çocuk') || has('cocuk') || has('aile')) {
      return Icons.child_friendly;
    }
    return Icons.check_circle_outline;
  }

  /// QR menüsünü ayrı sayfada açar (detay yanıtındaki `menu` verisiyle).
  void _openMenu() {
    final d = _detail;
    if (d == null || d.menu.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MenuScreen(title: _name, menu: d.menu)),
    );
  }

  /// Görsele dokununca fancybox tarzı tam ekran görüntüleyici (yakınlaştır +
  /// kaydır) açar.
  void _openGallery() {
    final images = _images;
    if (images.isEmpty) return;
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) =>
          _GalleryViewer(images: images, initialIndex: _photo),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Divider(height: 1, color: AppColors.line),
      );

  Widget _sectionH(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(t,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
      );

  Widget _detailTabbar() {
    return FloatingTabBarShell(
      onKedyTap: () => showKedyChat(context),
      items: [
        TabItemData(Icons.event_available_outlined, 'Rezerve', false, () {}),
        TabItemData(Icons.phone_outlined, 'Telefon', false, () {}),
        null,
        TabItemData(Icons.calendar_today_outlined, 'Etkinlik', false, () {}),
        TabItemData(Icons.qr_code_2, 'QR', false, _openMenu),
      ],
    );
  }
}

/// Tam ekran görsel görüntüleyici (fancybox tarzı): kaydırılabilir galeri,
/// çift/pinch ile yakınlaştırma, sayaç ve kapat butonu. Arka plan karartılır.
class _GalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _GalleryViewer({required this.images, this.initialIndex = 0});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _pc =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: NetImage(widget.images[i], fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const Spacer(),
                  if (widget.images.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${_index + 1} / ${widget.images.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
