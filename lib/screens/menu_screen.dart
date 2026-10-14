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

  /// Menünün son güncellenme zamanı (`menu_guncelleme`). null ise tarih bandı
  /// gösterilmez (MENU_GUNCELLEME.md).
  final DateTime? guncelleme;
  const MenuScreen(
      {super.key, required this.title, required this.menu, this.guncelleme});

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

  late final List<GlobalKey> _sectionKeys = List.generate(
    _sections.length,
    (_) => GlobalKey(),
  );
  late final List<GlobalKey> _pillKeys = List.generate(
    _sections.length,
    (_) => GlobalKey(),
  );
  final GlobalKey _listKey = GlobalKey();

  int _active = 0;
  bool _tapScrolling =
      false; // pill dokunuşuyla scroll sürerken oto-seçim kapalı

  // Menü içi arama (ürün adı, açıklama, içindekiler; Türkçe harf duyarsız).
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool get _searching => _query.isNotEmpty;

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
    _search.dispose();
    super.dispose();
  }

  /// Arama için metni sadeleştirir: küçük harf + Türkçe karakterler
  /// (İ/ı/ş/ç/ğ/ö/ü, şapkalı harfler) Latin karşılığına → "Çorba" = "corba".
  static String _fold(String s) {
    final b = StringBuffer();
    for (final r in s.replaceAll('İ', 'i').replaceAll('I', 'ı').runes) {
      final c = String.fromCharCode(r).toLowerCase();
      b.write(switch (c) {
        'ı' || 'î' => 'i',
        'ş' => 's',
        'ç' => 'c',
        'ğ' => 'g',
        'ö' => 'o',
        'ü' || 'û' => 'u',
        'â' => 'a',
        _ => c,
      });
    }
    return b.toString();
  }

  void _onSearch(String v) {
    final q = _fold(v.trim());
    if (q == _query) return;
    setState(() => _query = q);
    if (_list.hasClients) _list.jumpTo(0);
  }

  void _clearSearch() {
    _search.clear();
    _onSearch('');
    dismissKeyboard();
  }

  bool _matches(MenuUrun u) =>
      _fold(u.ad).contains(_query) ||
      _fold(u.aciklama).contains(_query) ||
      _fold(u.icindekiler).contains(_query);

  /// Aramada: yalnız eşleşen ürünleri olan kategoriler, eşleşen ürünleriyle.
  /// Kategori adı eşleşirse o kategorinin tüm ürünleri gösterilir.
  List<MenuKategori> get _results => [
        for (final c in _sections)
          if (_fold(c.kategori).contains(_query))
            c
          else if (c.urunler.any(_matches))
            MenuKategori(
                id: c.id,
                kategori: c.kategori,
                urunler: c.urunler.where(_matches).toList()),
      ];

  static const List<String> _aylar = [
    '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  /// "12 Ekim 2026, 14:30" (saat 00:00 ise yalnız tarih).
  static String _formatDate(DateTime d) {
    final t = d.isUtc ? d.toLocal() : d;
    final date = '${t.day} ${_aylar[t.month]} ${t.year}';
    if (t.hour == 0 && t.minute == 0) return date;
    String p(int n) => n.toString().padLeft(2, '0');
    return '$date, ${p(t.hour)}:${p(t.minute)}';
  }

  /// Scroll konumuna göre aktif bölümü bul ve pill barı ona kaydır.
  void _onScroll() {
    if (_tapScrolling || _sections.isEmpty || _searching) return;
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
                  child: Text(
                    'Bu mekan için menü bulunmuyor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ),
              ),
            )
          else ...[
            _searchBar(),
            // Aramada kategori sekmeleri gizlenir (sonuçlar süzülmüş liste).
            if (!_searching) _pillBar(),
            const Divider(height: 1, thickness: 1, color: AppColors.line),
            // Not: tembel `ListView` yerine tüm bölümleri oluşturan
            // `SingleChildScrollView` kullanılıyor. Aksi halde ekran dışına
            // çıkan bölüm başlıklarının GlobalKey bağlamı yok oluyor ve
            // sekmeye dokunmak (kaydırdıktan sonra) hiçbir şey yapmıyordu.
            Expanded(
              child: SingleChildScrollView(
                key: _listKey,
                controller: _list,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _searching
                      ? _searchResults()
                      : [
                          for (var i = 0; i < _sections.length; i++)
                            ..._section(i, _sections[i]),
                          _footerNote(),
                        ],
                ),
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
              icon: Icons.chevron_left,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menü',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.title.isNotEmpty)
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  if (widget.guncelleme != null) ...[
                    const SizedBox(height: 8),
                    _updatedBadge(widget.guncelleme!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Son güncelleme: 12 Ekim 2026, 14:30" rozeti (başlıkta, en üstte).
  Widget _updatedBadge(DateTime d) {
    final text = 'Son güncelleme: ${_formatDate(d)}';
    return Semantics(
      label: 'Menü son güncelleme tarihi ${_formatDate(d)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.update, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menü içi arama kutusu (kategori sekmelerinin üstünde).
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => dismissKeyboard(),
                style: const TextStyle(fontSize: 14.5, color: AppColors.ink),
                decoration: const InputDecoration(
                  hintText: 'Menüde ara (ürün, içerik…)',
                  hintStyle: TextStyle(color: AppColors.muted),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            if (_search.text.isNotEmpty)
              Semantics(
                button: true,
                label: 'Aramayı temizle',
                child: GestureDetector(
                  onTap: _clearSearch,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.cancel, size: 19, color: AppColors.muted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Arama sonuçları: eşleşen ürünler kategorileri altında; hiç yoksa mesaj.
  List<Widget> _searchResults() {
    final res = _results;
    if (res.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Text(
            '"${_search.text.trim()}" için menüde sonuç bulunamadı.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ),
      ];
    }
    final count = res.fold<int>(0, (n, c) => n + c.urunler.length);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('$count ürün bulundu',
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ),
      for (var i = 0; i < res.length; i++)
        ..._section(i, res[i], keyed: false),
      _footerNote(),
    ];
  }

  /// Yatay kaydırmalı kategori pill barı (cat-pill: navy-06 bg / navy metin;
  /// aktif: navy bg / beyaz metin).
  Widget _pillBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 38,
        // Tüm pill'ler oluşturulur (kategori sayısı az): böylece aktif pill
        // ekran dışında olsa da ona kaydırma yapılabilir.
        child: SingleChildScrollView(
          controller: _pills,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (var i = 0; i < _sections.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                GestureDetector(
                  key: _pillKeys[i],
                  onTap: () => _jumpToSection(i),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: i == _active
                          ? AppColors.primary
                          : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _sections[i].kategori.isEmpty
                          ? 'Menü'
                          : _sections[i].kategori,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: i == _active ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// [keyed] false ise (arama sonuçları) bölüm GlobalKey'i verilmez; sekme
  /// kaydırması yalnız tam menüde kullanılır.
  List<Widget> _section(int i, MenuKategori cat, {bool keyed = true}) {
    return [
      Padding(
        key: keyed ? _sectionKeys[i] : null,
        padding: EdgeInsets.only(top: i == 0 ? 8 : 26, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              cat.kategori.isEmpty ? 'Menü' : cat.kategori,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
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
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ürün detayı — alttan açılan panel: görsel, ad, fiyat, açıklama,
  /// içindekiler ve kalori (dolu olanlar gösterilir).
  void _openItem(MenuUrun u) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).padding.bottom;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
                  children: [
                    if (u.gorsel.isNotEmpty) ...[
                      // Panel gereksiz uzamasın: sabit ve kısa görsel şeridi.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: NetImage(u.gorsel),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            u.ad,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (u.fiyat.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${u.fiyat} ₺',
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (u.aciklama.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        u.aciklama,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: _descColor,
                        ),
                      ),
                    ],
                    // İçindekiler ve kalori: ayrı başlıklar yerine tek satırda
                    // sıkıştırıldı (panel kısa kalsın).
                    if (u.icindekiler.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'İçindekiler: ${u.icindekiler}',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: _descColor,
                        ),
                      ),
                    ],
                    if (u.kalori != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_outlined,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${u.kalori} kcal',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _item(MenuUrun u) {
    return InkWell(
      onTap: () => _openItem(u),
      child: Padding(
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
                        child: Text(
                          u.ad,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (u.fiyat.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${u.fiyat} ₺',
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (u.aciklama.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      u.aciklama,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                        color: _descColor,
                      ),
                    ),
                  ],
                  if (u.icindekiler.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'İçindekiler: ${u.icindekiler}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  if (u.kalori != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${u.kalori} kcal',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
