import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// QR menü sayfası — mekan detayındaki "QR Menü" ile açılır (MEKAN_DETAY.md).
/// Menü verisi (`menu`) detay yanıtından geldiği için burada yeniden istek
/// atılmaz. Web menüsüyle aynı tasarım: üstte kaydırmalı/yapışkan kategori
/// pill barı (scroll ile aktif kategori otomatik seçilir ve pill'e kayar;
/// pill'e dokununca ilgili bölüme kaydırır).
class MenuScreen extends StatefulWidget {
  final String title; // mekan adı
  final List<MenuKategori> menu;
  const MenuScreen({super.key, required this.title, required this.menu});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  /// Açıklama rengi (web: #6b6b80).
  static const Color _descColor = Color(0xFF6B6B80);

  final ScrollController _list = ScrollController();
  final ScrollController _pills = ScrollController();

  // Boş kategorileri ele — yalnız ürünü olan bölümler gösterilir/pill'lenir.
  late final List<MenuKategori> _sections = widget.menu
      .where((c) => c.urunler.isNotEmpty)
      .toList(growable: false);

  late final List<GlobalKey> _sectionKeys =
      List.generate(_sections.length, (_) => GlobalKey());
  late final List<GlobalKey> _pillKeys =
      List.generate(_sections.length, (_) => GlobalKey());
  final GlobalKey _listKey = GlobalKey();

  int _active = 0;
  bool _tapScrolling = false; // pill dokunuşuyla scroll sürerken oto-seçim kapalı

  @override
  void initState() {
    super.initState();
    _list.addListener(_onScroll);
  }

  @override
  void dispose() {
    _list.removeListener(_onScroll);
    _list.dispose();
    _pills.dispose();
    super.dispose();
  }

  /// Scroll konumuna göre aktif bölümü bul ve pill barı ona kaydır.
  void _onScroll() {
    if (_tapScrolling || _sections.isEmpty) return;
    final listCtx = _listKey.currentContext;
    if (listCtx == null) return;
    final listBox = listCtx.findRenderObject() as RenderBox?;
    if (listBox == null) return;
    final threshold = listBox.localToGlobal(Offset.zero).dy + 12;

    int active = 0;
    for (var i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy <= threshold) {
        active = i;
      } else {
        break;
      }
    }
    if (active != _active) {
      setState(() => _active = active);
      _revealPill(active);
    }
  }

  /// Aktif pill'i yatay bar içinde görünür kıl (ortalayarak).
  void _revealPill(int i) {
    final ctx = _pillKeys[i].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Pill'e dokununca ilgili bölümü listede en üste kaydır.
  Future<void> _jumpToSection(int i) async {
    final ctx = _sectionKeys[i].currentContext;
    if (ctx == null) return;
    setState(() {
      _active = i;
      _tapScrolling = true;
    });
    _revealPill(i);
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    if (mounted) _tapScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _header(context),
          if (_sections.isEmpty)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Bu mekan için menü bulunmuyor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.muted)),
                ),
              ),
            )
          else ...[
            _pillBar(),
            const Divider(height: 1, thickness: 1, color: AppColors.line),
            Expanded(
              child: ListView(
                key: _listKey,
                controller: _list,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                children: [
                  for (var i = 0; i < _sections.length; i++)
                    ..._section(i, _sections[i]),
                  _footerNote(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 22, 22),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.7, -1.1),
          radius: 1.2,
          colors: [AppColors.primary2, AppColors.primary],
          stops: [0.0, 0.55],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GlassButton(
                icon: Icons.chevron_left, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Menü',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  if (widget.title.isNotEmpty)
                    Text(widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Yatay kaydırmalı kategori pill barı (cat-pill: navy-06 bg / navy metin;
  /// aktif: navy bg / beyaz metin).
  Widget _pillBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          controller: _pills,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _sections.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final active = i == _active;
            return GestureDetector(
              key: _pillKeys[i],
              onTap: () => _jumpToSection(i),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _sections[i].kategori.isEmpty
                      ? 'Menü'
                      : _sections[i].kategori,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _section(int i, MenuKategori cat) {
    return [
      Padding(
        key: _sectionKeys[i],
        padding: EdgeInsets.only(top: i == 0 ? 8 : 26, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(cat.kategori.isEmpty ? 'Menü' : cat.kategori,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary)),
            const SizedBox(width: 12),
            const Expanded(child: Divider(color: AppColors.line, thickness: 1)),
          ],
        ),
      ),
      for (var k = 0; k < cat.urunler.length; k++) ...[
        _item(cat.urunler[k]),
        if (k != cat.urunler.length - 1)
          const Divider(height: 1, thickness: 1, color: AppColors.line),
      ],
    ];
  }

  /// Menü listesinin sonundaki bilgilendirme notu.
  Widget _footerNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 15, color: AppColors.muted),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Menü fiyat ve bilgiler değişiklik gösterebilir.',
                  style: TextStyle(
                      fontSize: 12.5, height: 1.45, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _item(MenuUrun u) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Görseli olmayan ürünlerde görsel alanı hiç çizilmez.
          if (u.gorsel.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 96,
                height: 96,
                child: NetImage(u.gorsel),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(u.ad,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink)),
                    ),
                    if (u.fiyat.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text('${u.fiyat} ₺',
                          softWrap: false,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ],
                  ],
                ),
                if (u.aciklama.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(u.aciklama,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                          color: _descColor)),
                ],
                if (u.icindekiler.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('İçindekiler: ${u.icindekiler}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
                if (u.kalori != null) ...[
                  const SizedBox(height: 4),
                  Text('${u.kalori} kcal',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
