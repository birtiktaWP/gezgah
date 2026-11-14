import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api.dart';
import '../data/models.dart' show RezGunKurali;
import '../data/uye_aktivite.dart';
import '../theme/app_theme.dart';
import '../widgets/account_page.dart';
import '../widgets/common.dart';
import '../widgets/rez_time_picker.dart';
import 'detail_screen.dart';

/// Rezervasyonlarım — Yaklaşan / Geçmiş sekmeleri (`GET /uye/rezervasyonlar`,
/// UYE_DEGERLENDIRME_REZERVASYON.md §2). Rezervasyona dokununca detay paneli
/// açılır: mekanı gör, ara, yol tarifi, değiştir (tarih/kişi/not) ve iptal.
class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

/// Bir sekmenin (yaklaşan / geçmiş) liste durumu.
class _Tab {
  final List<Rezervasyonum> items = [];
  bool loaded = false;
  bool loading = false;
  bool loadingMore = false;
  bool error = false;
  bool hasMore = false;
  int? nextPage;
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final ScrollController _scroll = ScrollController();
  final _tabs = [_Tab(), _Tab()]; // 0 = yaklaşan, 1 = geçmiş
  int _tab = 0;
  bool _notReady = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _load(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  _Tab get _cur => _tabs[_tab];

  Future<void> _load(int tab) async {
    final t = _tabs[tab];
    setState(() {
      t.loading = true;
      t.error = false;
    });
    try {
      final r = await UyeAktiviteRepository.instance.rezervasyonlar(
        gecmis: tab == 1,
      );
      if (!mounted) return;
      setState(() {
        t.items
          ..clear()
          ..addAll(r.items);
        t.hasMore = r.hasMore;
        t.nextPage = r.nextPage;
        t.loaded = true;
        t.loading = false;
      });
    } on UyeAktiviteHazirDegil {
      if (mounted) {
        setState(() {
          _notReady = true;
          t.loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          t.error = true;
          t.loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final t = _cur;
    final tab = _tab;
    if (t.loadingMore || t.loading || !t.hasMore || t.nextPage == null) {
      return;
    }
    setState(() => t.loadingMore = true);
    try {
      final r = await UyeAktiviteRepository.instance.rezervasyonlar(
        gecmis: tab == 1,
        page: t.nextPage!,
      );
      if (!mounted) return;
      final seen = {for (final x in t.items) x.id};
      setState(() {
        t.items.addAll(r.items.where((x) => seen.add(x.id)));
        t.hasMore = r.hasMore && r.items.isNotEmpty;
        t.nextPage = t.hasMore ? r.nextPage : null;
        t.loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => t.loadingMore = false);
    }
  }

  /// İptal / değişiklik sonrası iki sekme de tazelenir.
  Future<void> _reloadAll() async {
    for (final t in _tabs) {
      t.loaded = false;
    }
    await _load(_tab);
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (!_tabs[i].loaded && !_tabs[i].loading) _load(i);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ---- işlemler ---------------------------------------------------------

  void _openVenue(Rezervasyonum r) {
    if (r.mekan.id <= 0 || !r.mekan.yayinda) return;
    Navigator.push(
      context,
      detailRoute(builder: (_) => DetailScreen(place: r.mekan.toPlace())),
    );
  }

  Future<void> _call(Rezervasyonum r) async {
    final digits = r.mekan.telefon.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    final ok = await launchUrl(Uri(scheme: 'tel', path: digits));
    if (!ok) _snack('Arama başlatılamadı.');
  }

  Future<void> _directions(Rezervasyonum r) async {
    final m = r.mekan;
    if (!m.hasCoord) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${m.lat},${m.lng}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('Harita uygulaması açılamadı.');
    } catch (_) {
      _snack('Harita uygulaması açılamadı.');
    }
  }

  Future<void> _cancel(Rezervasyonum r) async {
    final neden = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rezervasyon iptal edilsin mi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.mekan.ad}'
              '${r.tarih != null ? ' · ${TrTarih.uzun(r.tarih!)}' : ''}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: neden,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'İptal nedeni (opsiyonel)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.closing),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    final reason = neden.text;
    neden.dispose();
    if (ok != true || !mounted) return;
    try {
      await UyeAktiviteRepository.instance.rezervasyonIptal(
        r.id,
        neden: reason,
      );
      _snack('Rezervasyon iptal edildi');
      await _reloadAll();
    } on UyeAktiviteHazirDegil {
      _snack('Bu işlem şu an kullanılamıyor.');
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Rezervasyon iptal edilemedi. Tekrar dene.');
    }
  }

  Future<void> _edit(Rezervasyonum r) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditReservationSheet(rez: r),
    );
    if (updated == true && mounted) {
      _snack('Değişiklik işletmeye gönderildi');
      await _reloadAll();
    }
  }

  Future<void> _openDetail(Rezervasyonum r) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReservationDetailSheet(rez: r),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'mekan':
        _openVenue(r);
      case 'ara':
        _call(r);
      case 'yol':
        _directions(r);
      case 'degistir':
        _edit(r);
      case 'iptal':
        _cancel(r);
    }
  }

  // ---- arayüz -----------------------------------------------------------

  Widget get _hero => AccountHero(
    title: 'Rezervasyonlarım',
    subtitle: 'Yaklaşan ve geçmiş rezervasyonların',
    bottom: _tabsBar(),
  );

  Widget _tabsBar() {
    Widget tab(int i, String label) {
      final sel = _tab == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: sel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectTab(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: sel ? AppColors.primary : Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(children: [tab(0, 'Yaklaşan'), tab(1, 'Geçmiş')]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccountPage(body: _body());
  }

  Widget _body() {
    final t = _cur;
    if (_notReady) {
      return AccountCentered(
        hero: _hero,
        child: const AccountInfo(
          icon: Icons.event_available_outlined,
          title: 'Çok yakında',
          subtitle:
              'Yaptığın rezervasyonlar yakında burada listelenecek; buradan '
              'değiştirip iptal edebileceksin.',
        ),
      );
    }
    if (t.loading && t.items.isEmpty) {
      return AccountCentered(
        hero: _hero,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (t.error && t.items.isEmpty) {
      return AccountCentered(
        hero: _hero,
        child: AccountInfo(
          icon: Icons.wifi_off_rounded,
          title: 'Rezervasyonlar yüklenemedi',
          subtitle: 'İnternet bağlantını kontrol edip tekrar dene.',
          action: 'Tekrar dene',
          onAction: () => _load(_tab),
        ),
      );
    }
    if (t.items.isEmpty) {
      return AccountCentered(
        hero: _hero,
        child: AccountInfo(
          icon: Icons.event_available_outlined,
          title: _tab == 0
              ? 'Yaklaşan rezervasyonun yok'
              : 'Geçmiş rezervasyonun yok',
          // Telefonla yapılmış eski rezervasyonlar üyeye bir sonraki SMS'li
          // girişte (ya da yeni rezervasyonda) bağlanır; o yüzden liste ilk
          // girişte boş görünebilir.
          subtitle: _tab == 0
              ? 'Rezervasyon alan mekanların sayfasında "Rezerve" ile masa '
                    'ayırtabilirsin. Önceki rezervasyonların bir sonraki '
                    'girişinde burada görünür.'
              : 'Geçmiş ve iptal edilen rezervasyonların burada görünür. '
                    'Önceki rezervasyonların bir sonraki girişinde eklenir.',
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(_tab),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 130),
        itemCount: 1 + t.items.length + (t.loadingMore ? 1 : 0),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _hero,
            );
          }
          final i = index - 1;
          if (i < t.items.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: _card(t.items[i]),
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

  Widget _card(Rezervasyonum r) {
    final m = r.mekan;
    final detay = [
      '${r.kisi} kişi',
      if (r.bolge.isNotEmpty) r.bolge,
      if (r.masa.isNotEmpty) 'Masa ${r.masa}',
    ].join(' · ');
    return GestureDetector(
      onTap: () => _openDetail(r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.listTile,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 128,
              child: m.gorsel.isNotEmpty
                  ? NetImage(m.gorsel)
                  : const ColoredBox(
                      color: AppColors.primarySoft,
                      child: Icon(
                        Icons.storefront_outlined,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ad tam genişlikte (rozet yanında kısalıyordu).
                        Expanded(
                          child: Text(
                            m.ad.isEmpty ? 'Mekan' : m.ad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (r.tarih != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              TrTarih.uzun(r.tarih!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            detay,
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _statusChip(r),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Duruma göre etiket + renk.
(String, Color) rezDurumEtiket(RezDurum d) => switch (d) {
  RezDurum.beklemede => ('Onay bekliyor', const Color(0xFFD97706)),
  RezDurum.onaylandi => ('Onaylandı', AppColors.open),
  RezDurum.reddedildi => ('Reddedildi', AppColors.closing),
  RezDurum.iptal => ('İptal edildi', AppColors.muted),
  RezDurum.tamamlandi => ('Tamamlandı', AppColors.primary),
  RezDurum.gelmedi => ('Gelinmedi', AppColors.muted),
};

Widget _statusChip(Rezervasyonum r) {
  final (label, color) = rezDurumEtiket(r.durum);
  return StatusChip(label, color);
}

/// Rezervasyon detayı + işlemler. Seçilen işlemin anahtarıyla kapanır.
class _ReservationDetailSheet extends StatelessWidget {
  final Rezervasyonum rez;
  const _ReservationDetailSheet({required this.rez});

  @override
  Widget build(BuildContext context) {
    final r = rez;
    final m = r.mekan;
    final rows = <(IconData, String, String)>[
      if (r.tarih != null)
        (Icons.event_outlined, 'Tarih', TrTarih.uzun(r.tarih!)),
      (Icons.people_outline, 'Kişi', '${r.kisi} kişi'),
      if (r.bolge.isNotEmpty) (Icons.map_outlined, 'Bölge', r.bolge),
      if (r.masa.isNotEmpty) (Icons.table_restaurant_outlined, 'Masa', r.masa),
      if (r.not.isNotEmpty) (Icons.notes_outlined, 'Not', r.not),
      if (r.redNedeni.isNotEmpty)
        (Icons.info_outline, 'İşletmenin notu', r.redNedeni),
      if (r.iptalNedeni.isNotEmpty)
        (Icons.event_busy_outlined, 'İptal nedenin', r.iptalNedeni),
      if (r.olusturma != null)
        (Icons.schedule_outlined, 'Oluşturulma', TrTarih.uzun(r.olusturma!)),
      if (r.hash.isNotEmpty)
        (
          Icons.confirmation_number_outlined,
          'Rezervasyon no',
          r.hash.length > 8 ? r.hash.substring(0, 8).toUpperCase() : r.hash,
        ),
    ];

    Widget action(String key, IconData icon, String label, {Color? color}) {
      final c = color ?? AppColors.primary;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context, key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: c, size: 21),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetGrabber(),
              const SizedBox(height: 6),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: m.gorsel.isNotEmpty
                          ? NetImage(m.gorsel)
                          : const ColoredBox(
                              color: AppColors.primarySoft,
                              child: Icon(
                                Icons.storefront_outlined,
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
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (m.konum.isNotEmpty)
                          Text(
                            m.konum,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _statusChip(r),
                ],
              ),
              const SizedBox(height: 14),
              for (final (icon, label, value) in rows)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 104,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (r.durum == RezDurum.beklemede) ...[
                const SizedBox(height: 12),
                // Push henüz sunucudan gönderilmiyor; bildirim sözü verilmez.
                const Text(
                  'Durumu bu sayfadan takip edebilirsin.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if (m.yayinda && m.id > 0)
                    action('mekan', Icons.storefront_outlined, 'Mekanı gör'),
                  if (m.telefon.isNotEmpty)
                    action('ara', Icons.call_outlined, 'Ara'),
                  if (m.hasCoord)
                    action('yol', Icons.directions_outlined, 'Yol tarifi'),
                ],
              ),
              if (r.duzenlenebilir || r.iptalEdilebilir) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (r.duzenlenebilir)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context, 'degistir'),
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: const Text('Değiştir'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    if (r.duzenlenebilir && r.iptalEdilebilir)
                      const SizedBox(width: 10),
                    if (r.iptalEdilebilir)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context, 'iptal'),
                          icon: const Icon(Icons.event_busy_outlined),
                          label: const Text('İptal et'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.closing,
                            side: const BorderSide(color: AppColors.closing),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarih / saat / kişi / not değişikliği. Başarıda `true` ile kapanır.
class _EditReservationSheet extends StatefulWidget {
  final Rezervasyonum rez;
  const _EditReservationSheet({required this.rez});

  @override
  State<_EditReservationSheet> createState() => _EditReservationSheetState();
}

class _EditReservationSheetState extends State<_EditReservationSheet> {
  // Gün + saat: oluşturma paneliyle aynı seçim (rez_time_picker.dart).
  // Gece yarısından sonraki saat (ör. 00:30) önceki günün listesinde yer
  // aldığı için gün, saatten değil kullanıcının seçtiği günden tutulur.
  late DateTime? _gun = _initialDay();
  late DateTime? _tarih = widget.rez.tarih;
  // İşletmenin çalışma saatleri (`/rezervasyon/secenekler`). Yüklenene
  // kadar gün/saat seçimi beklenir; hiç bilgi yoksa ortak varsayılan aralık.
  Map<String, String?> _hours = const {};
  // İşletmenin rezervasyon gün/saat ayarı (REZERVASYON_SAATLERI.md).
  Map<String, RezGunKurali> _rez = const {};
  bool _hoursLoading = true;

  /// Çalışma saati + rezervasyon ayarına uyan saatler.
  List<DateTime> _slots(DateTime day) =>
      rezSaatleri(day, _hours, rez: _rez);

  // Sunucu PATCH'te 1–100 kabul eder (dışı 422).
  static const _maxKisi = 100;
  late int _kisi = widget.rez.kisi.clamp(1, _maxKisi);
  late final TextEditingController _not = TextEditingController(
    text: widget.rez.not,
  );
  bool _saving = false;
  String? _error;

  DateTime? _initialDay() {
    final t = widget.rez.tarih;
    if (t == null) return null;
    // 00:00–05:59 arası saat, gece açık işletmede önceki günün listesindedir.
    final d = rezDayOnly(t);
    return t.hour < 6 ? d.subtract(const Duration(days: 1)) : d;
  }

  @override
  void initState() {
    super.initState();
    _loadHours();
  }

  Future<void> _loadHours() async {
    final o = await RezervasyonRepository.instance.secenekler(
      widget.rez.mekan.id,
    );
    if (!mounted) return;
    setState(() {
      _hours = o?.calismaSaatleri ?? const {};
      _rez = o?.rezervasyonSaatleri ?? const {};
      _hoursLoading = false;
      // Önceki günün listesinde değilse (gündüz saati) kendi günü.
      final t = _tarih;
      if (t != null &&
          _gun != null &&
          !_slots(_gun!).any((s) => s.isAtSameMomentAs(t))) {
        _gun = rezDayOnly(t);
      }
    });
  }

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  bool get _unchangedTime =>
      _tarih != null &&
      widget.rez.tarih != null &&
      _tarih!.isAtSameMomentAs(widget.rez.tarih!);

  /// Gün seçildi → saat listesi kendiliğinden açılır. Önceki saat yeni günde
  /// de varsa korunur.
  Future<void> _selectDay(DateTime day) async {
    final prev = _tarih;
    final slots = _slots(day);
    setState(() {
      _gun = day;
      _error = null;
      _tarih = prev == null
          ? null
          : slots
                .where((s) => s.hour == prev.hour && s.minute == prev.minute)
                .firstOrNull;
    });
    if (slots.isNotEmpty) await _pickTime();
  }

  Future<void> _pickOtherDay() async {
    final now = DateTime.now();
    final d = await showNativeDatePicker(
      context,
      initialDate: _gun ?? now,
      firstDate: rezDayOnly(now),
      lastDate: now.add(const Duration(days: 180)),
      helpText: 'Rezervasyon günü',
    );
    if (d == null || !mounted) return;
    if (_slots(d).isEmpty) {
      setState(() {
        _gun = rezDayOnly(d);
        _tarih = null;
        _error =
            '${rezGunTarih(d)} günü rezervasyon alınmıyor. Başka bir gün seç.';
      });
      return;
    }
    await _selectDay(rezDayOnly(d));
  }

  Future<void> _pickTime() async {
    final day = _gun;
    if (day == null) return;
    final picked = await showRezTimeSelect(
      context,
      day: day,
      slots: _slots(day),
      selected: _tarih,
      rez: _rez,
    );
    if (picked != null && mounted) {
      setState(() {
        _tarih = picked;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    final t = _tarih;
    if (_gun == null || t == null) {
      setState(() => _error = 'Rezervasyon günü ve saati seç.');
      return;
    }
    if (t.isBefore(DateTime.now())) {
      setState(() => _error = 'Geçmiş bir tarih seçilemez.');
      return;
    }
    // Saat değiştiyse işletmenin açık olduğu bir saat olmalı (liste zaten
    // yalnız onları sunar; eski saat aynen kalırsa dokunulmaz).
    if (!_unchangedTime &&
        !_slots(_gun!).any((s) => s.isAtSameMomentAs(t))) {
      setState(() => _error = 'Seçtiğin saatte işletme kapalı.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await UyeAktiviteRepository.instance.rezervasyonGuncelle(
        widget.rez.id,
        tarih: TrTarih.api(t),
        kisi: _kisi,
        not: _not.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on UyeAktiviteHazirDegil {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Bu işlem şu an kullanılamıyor.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          // Sunucunun metni gösterilir ("Salı günü rezervasyon saatleri
          // 12:00 – 22:00 arasıdır…"); saat reddedildiyse işletme ayarı
          // değişmiş olabilir → saatler yeniden çekilir
          // (REZERVASYON_SAATLERI.md §2.4).
          _error = e.message;
        });
        _loadHours();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Değişiklik kaydedilemedi. Tekrar dene.';
        });
      }
    }
  }

  Widget _field(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _saving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetGrabber(),
              const SizedBox(height: 6),
              const Text(
                'Rezervasyonu değiştir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.rez.mekan.ad,
                style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              if (_hoursLoading)
                const SizedBox(
                  height: 74,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
              else ...[
                RezDayStrip(
                  selected: _gun,
                  hours: _hours,
                  rez: _rez,
                  onSelect: (d) {
                    if (!_saving) _selectDay(d);
                  },
                  onOther: () {
                    if (!_saving) _pickOtherDay();
                  },
                ),
                const SizedBox(height: 10),
                if (_gun != null && _slots(_gun!).isEmpty && !_unchangedTime)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Bu gün için uygun saat yok. Başka bir gün seç.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.closing,
                      ),
                    ),
                  )
                else if (_gun != null)
                  _field(
                    Icons.schedule_outlined,
                    'Saat',
                    _tarih == null ? 'Seç' : TrTarih.saat(_tarih!),
                    _pickTime,
                  ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 19,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Kişi',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Azalt',
                      onPressed: (_saving || _kisi <= 1)
                          ? null
                          : () => setState(() => _kisi--),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.primary,
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$_kisi',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Artır',
                      onPressed: (_saving || _kisi >= _maxKisi)
                          ? null
                          : () => setState(() => _kisi++),
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _not,
                enabled: !_saving,
                maxLines: 3,
                minLines: 2,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: 'Not (opsiyonel)',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Text(
                'Değişiklik işletmenin onayına gönderilir; onaylanana kadar '
                'rezervasyonun "Onay bekliyor" görünür.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.closing,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _saving ? null : _save,
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
                        'Değişikliği gönder',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
