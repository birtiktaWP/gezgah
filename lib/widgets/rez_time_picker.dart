import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';

/// Rezervasyon gün / saat seçimi — oluşturma paneli (`reservation_sheet.dart`)
/// ve "Rezervasyonu değiştir" paneli (Rezervasyonlarım) aynı parçaları
/// kullanır:
///
/// - [RezDayStrip]: bugünden itibaren 14 günlük yatay şerit + "Diğer"
///   (takvim). İşletmenin kapalı olduğu gün pasif.
/// - [showRezTimeSelect]: seçilen günün saatleri, 15 dk arayla, tek sütun
///   seçim listesi. Yalnız işletmenin açık olduğu saatler listelenir.
/// - [rezSaatleri]: saat listesini çalışma saatlerinden üretir.

/// Saat aralığı (dakika).
const int kRezSlotStep = 15;

/// Bugün için en erken rezervasyon: şimdiden en az bu kadar sonra.
const Duration kRezMinLead = Duration(minutes: 30);

/// Kapanıştan en geç bu kadar önce rezervasyon alınır.
const int kRezLastBeforeClose = 30;

/// İşletmenin HİÇ çalışma saati bilgisi yoksa kullanılan aralık.
const (int, int) _fallbackRange = (8 * 60, 24 * 60);

const _gunKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _gunUzun = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];
const _ayUzun = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

DateTime rezDayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _p2(int n) => n.toString().padLeft(2, '0');

/// "20:15"
String rezHm(DateTime d) => '${_p2(d.hour)}:${_p2(d.minute)}';

/// "Pazar, 15 Kasım"
String rezGunTarih(DateTime d) =>
    '${_gunUzun[d.weekday - 1]}, ${d.day} ${_ayUzun[d.month - 1]}';

/// Bir günün açık olduğu aralık (dakika, gün başından). Kapalıysa null.
///
/// - Çalışma saati hiç yoksa ([hours] boş) bilgi yok sayılır, varsayılan
///   aralık kullanılır (rezervasyon tamamen kapanmasın).
/// - Bilgi varsa o gün için "HH:MM - HH:MM" beklenir; gün boş, "Kapalı" ya
///   da tanınmayan biçimdeyse işletme o gün **kapalı** sayılır.
/// - "00:00 - 00:00" 24 saat açık; kapanış açılıştan küçükse gece yarısını
///   aşar (09:00 – 01:00 → 540 … 1500).
(int, int)? rezAcikAralik(DateTime day, Map<String, String?> hours) {
  if (hours.isEmpty) return _fallbackRange;
  final raw = (hours[kGunAnahtarlari[day.weekday - 1]] ?? '').trim();
  final m = RegExp(r'(\d{1,2}):(\d{2})\D+(\d{1,2}):(\d{2})').firstMatch(raw);
  if (m == null) return null;
  final s = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  var e = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);
  if (e == s) return (0, 24 * 60);
  if (e < s) e += 24 * 60;
  return (s, e);
}

/// [d] anı işletmenin rezervasyon ayarına uyuyor mu
/// (`rezervasyon_saatleri`, REZERVASYON_SAATLERI.md §2 — sunucudaki kuralın
/// aynısı). Önceki günün gece yarısını aşan aralığının devamı (00:00–bitis)
/// her zaman sayılır; sonra o günün ayarı: kapalı → hayır, saat kısıtı
/// yok → evet, aralık varsa iki uç dahil. Ayar hiç yoksa evet.
bool rezSaatUygun(DateTime d, Map<String, RezGunKurali> rs) {
  if (rs.isEmpty) return true;
  final m = d.hour * 60 + d.minute;
  final dun = rs[kGunAnahtarlari[(d.weekday - 2 + 7) % 7]];
  if (dun != null && dun.acik && dun.geceAsar && m <= dun.bitis!) return true;
  final bugun = rs[kGunAnahtarlari[d.weekday - 1]];
  if (bugun == null) return true;
  if (!bugun.acik) return false;
  if (!bugun.kisitli) return true;
  final f = bugun.baslangic!, t = bugun.bitis!;
  return t > f ? (m >= f && m <= t) : m >= f;
}

/// Seçilen günün rezervasyon saatleri: çalışma saatlerinde açılıştan
/// (15 dk'ya yuvarlanarak) kapanıştan [kRezLastBeforeClose] öncesine kadar,
/// 15 dk arayla; üstüne [rez] (işletmenin rezervasyon ayarı) uygulanır.
/// Rezervasyona kapalı gün boş liste. Gece yarısını aşan saatler ertesi
/// günün tarihini taşır. Bugünse şimdiden [kRezMinLead] öncesi listelenmez.
List<DateTime> rezSaatleri(
  DateTime day,
  Map<String, String?> hours, {
  Map<String, RezGunKurali> rez = const {},
  DateTime? now,
}) {
  final d = rezDayOnly(day);
  if (rez[kGunAnahtarlari[d.weekday - 1]]?.acik == false) return const [];
  final range = rezAcikAralik(d, hours);
  if (range == null) return const [];
  final (s, e) = range;
  final start = ((s + kRezSlotStep - 1) ~/ kRezSlotStep) * kRezSlotStep;
  final last = (s == 0 && e == 24 * 60)
      ? e - kRezSlotStep
      : e - kRezLastBeforeClose;
  final earliest = (now ?? DateTime.now()).add(kRezMinLead);
  return [
    for (var m = start; m <= last; m += kRezSlotStep)
      if (!d.add(Duration(minutes: m)).isBefore(earliest) &&
          rezSaatUygun(d.add(Duration(minutes: m)), rez))
        d.add(Duration(minutes: m)),
  ];
}

/// "Rezervasyon saatleri: 12:00 – 22:00" bilgi metni (o gün kısıt yoksa
/// null).
String? rezAraligiMetni(DateTime day, Map<String, RezGunKurali> rez) {
  final r = rez[kGunAnahtarlari[day.weekday - 1]];
  if (r == null || !r.acik || !r.kisitli) return null;
  String f(int m) => '${_p2((m ~/ 60) % 24)}:${_p2(m % 60)}';
  return 'Rezervasyon saatleri: ${f(r.baslangic!)} – ${f(r.bitis!)}';
}

// ---------------------------------------------------------------------------

/// Yatay gün şeridi (bugünden 14 gün) + "Diğer" (takvim). Kapalı ya da
/// saati kalmamış günler pasif. Şeritte olmayan bir gün seçiliyse "Diğer"in
/// önünde o gün de gösterilir.
class RezDayStrip extends StatefulWidget {
  final DateTime? selected;
  final Map<String, String?> hours;
  final Map<String, RezGunKurali> rez;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onOther;

  const RezDayStrip({
    super.key,
    required this.selected,
    required this.hours,
    this.rez = const {},
    required this.onSelect,
    required this.onOther,
  });

  @override
  State<RezDayStrip> createState() => _RezDayStripState();
}

class _RezDayStripState extends State<RezDayStrip> {
  static const double _chipW = 58;
  static const double _gap = 8;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    // Seçili gün (ör. değiştirilen rezervasyonun günü) görünür açılsın:
    // solunda bir gün kalacak kadar kaydırılır.
    final sel = widget.selected;
    var offset = 0.0;
    if (sel != null) {
      final i = rezDayOnly(sel).difference(rezDayOnly(DateTime.now())).inDays;
      final idx = (i >= 0 && i < 14) ? i : 14; // şerit dışı → sondaki çip
      if (idx > 1) offset = (idx - 1) * (_chipW + _gap);
    }
    _scroll = ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = widget.hours;
    final onSelect = widget.onSelect;
    final onOther = widget.onOther;
    final today = rezDayOnly(DateTime.now());
    final days = [for (var i = 0; i < 14; i++) today.add(Duration(days: i))];
    final sel = widget.selected == null ? null : rezDayOnly(widget.selected!);
    final selOutside = sel != null && !days.contains(sel);
    String top(DateTime d) {
      if (d == today) return 'Bugün';
      if (d == today.add(const Duration(days: 1))) return 'Yarın';
      return _gunKisa[d.weekday - 1];
    }

    return SizedBox(
      height: 74,
      child: ListView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final d in days) ...[
            _DayChip(
              top: top(d),
              mid: '${d.day}',
              bottom: _ayUzun[d.month - 1].substring(0, 3),
              selected: d == sel,
              enabled: rezSaatleri(d, hours, rez: widget.rez).isNotEmpty,
              onTap: () => onSelect(d),
            ),
            const SizedBox(width: 8),
          ],
          if (selOutside) ...[
            _DayChip(
              top: _gunKisa[sel.weekday - 1],
              mid: '${sel.day}',
              bottom: _ayUzun[sel.month - 1].substring(0, 3),
              selected: true,
              enabled: true,
              onTap: onOther,
            ),
            const SizedBox(width: 8),
          ],
          _DayChip(
            top: 'Diğer',
            icon: Icons.calendar_month_outlined,
            bottom: 'Takvim',
            selected: false,
            enabled: true,
            onTap: onOther,
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String top;
  final String? mid;
  final IconData? icon;
  final String bottom;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _DayChip({
    required this.top,
    this.mid,
    this.icon,
    required this.bottom,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? Colors.white
        : enabled
        ? AppColors.ink
        : const Color(0xFFB9B9C6);
    final sub = selected
        ? Colors.white70
        : enabled
        ? AppColors.muted
        : const Color(0xFFC9C9D4);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: enabled ? null : '$top kapalı',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 58,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
            ),
          ),
          // Büyük sistem yazı boyutunda taşmasın: içerik sığmazsa küçülür.
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  top,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sub,
                  ),
                ),
                const SizedBox(height: 3),
                if (icon != null)
                  Icon(icon, size: 20, color: fg)
                else
                  Text(
                    mid ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      height: 1.1,
                      decoration: enabled ? null : TextDecoration.lineThrough,
                      decorationColor: fg,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  enabled ? bottom : 'Kapalı',
                  style: TextStyle(fontSize: 10.5, color: sub),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Saat seçim listesi: [slots] tek sütun, seçili saate (yoksa ilk saate)
/// kaydırılmış açılır. Ertesi güne taşan saatin altında "Ertesi gün" yazar.
Future<DateTime?> showRezTimeSelect(
  BuildContext context, {
  required DateTime day,
  required List<DateTime> slots,
  DateTime? selected,
  Map<String, RezGunKurali> rez = const {},
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _TimeSelectSheet(
      day: day,
      slots: slots,
      selected: selected,
      info: rezAraligiMetni(day, rez),
    ),
  );
}

class _TimeSelectSheet extends StatefulWidget {
  final DateTime day;
  final List<DateTime> slots;
  final DateTime? selected;

  /// İşletmenin o güne ait rezervasyon aralığı metni (yoksa "Uygun saatler").
  final String? info;

  const _TimeSelectSheet({
    required this.day,
    required this.slots,
    required this.selected,
    this.info,
  });

  @override
  State<_TimeSelectSheet> createState() => _TimeSelectSheetState();
}

class _TimeSelectSheetState extends State<_TimeSelectSheet> {
  static const double _rowH = 54;
  late final ScrollController _scroll;

  int get _selIndex {
    final s = widget.selected;
    if (s == null) return -1;
    return widget.slots.indexWhere((x) => x.isAtSameMomentAs(s));
  }

  @override
  void initState() {
    super.initState();
    // Seçili saat listenin üst kısmında (2 satır üstü görünür) açılsın.
    final i = _selIndex;
    _scroll = ScrollController(
      initialScrollOffset: i > 2 ? (i - 2) * _rowH : 0,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final d0 = rezDayOnly(widget.day);
    final range = widget.slots.isEmpty
        ? null
        : '${rezHm(widget.slots.first)} – ${rezHm(widget.slots.last)}';
    final infoText =
        widget.info ?? (range == null ? null : 'Uygun saatler: $range');
    final listH = (widget.slots.length * _rowH).clamp(
      _rowH,
      mq.size.height * 0.55,
    );
    final sel = _selIndex;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Text(
                    'Saat seç',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  rezGunTarih(widget.day),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (infoText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  infoText,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ),
          SizedBox(
            height: listH,
            child: ListView.builder(
              controller: _scroll,
              itemExtent: _rowH,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.slots.length,
              itemBuilder: (context, i) {
                final s = widget.slots[i];
                final next = !rezDayOnly(s).isAtSameMomentAs(d0);
                final isSel = i == sel;
                return Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: isSel,
                  label: next ? '${rezHm(s)}, ertesi gün' : rezHm(s),
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primarySoft : null,
                        borderRadius: BorderRadius.circular(12),
                        border: isSel
                            ? null
                            : const Border(
                                bottom: BorderSide(color: AppColors.line),
                              ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            rezHm(s),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSel ? AppColors.primary : AppColors.ink,
                            ),
                          ),
                          if (next) ...[
                            const SizedBox(width: 10),
                            const Text(
                              'Ertesi gün',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                          const Spacer(),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel
                                    ? AppColors.primary
                                    : const Color(0xFFC9C9D6),
                                width: isSel ? 7 : 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
