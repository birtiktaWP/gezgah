import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/location_service.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../data/view_tracker.dart';
import '../navigation/main_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/place_cards.dart';
import '../widgets/search_modal.dart';
import '../widgets/tabbar.dart';
import '../widgets/track_impression.dart';
import 'detail_screen.dart';
import 'map_screen.dart';

class CategoryScreen extends StatefulWidget {
  final int? categoryId;

  /// Post type slug'ı (kategori yerine). Verilirse `/mekanlar?type=<type>` ile
  /// listelenir (otopark | muze | mesire | plaj). Alt sekmeler tipin
  /// kategorileridir (`/kategoriler/tip/{type}`); ilk sekme "Tümü". Pin yok.
  final String? type;
  final String title;
  const CategoryScreen({
    super.key,
    this.categoryId,
    this.type,
    this.title = 'Kategori',
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

/// Çözülmüş konum tipi.
typedef _Loc = ({double lat, double lng, bool real});

/// Sıralama biçimi.
enum _SortMode { yakinlik, tarih }

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scroll = ScrollController();

  // Ekranda görünen mekanlar bu ziyaret için bir kez sayılır (GORUNTULENME.md).
  // Alt kategori sekmesi değişince yeni kapsam açılır (kaynak_id = seçili id).
  late ImpressionScope _impressions = widget.type != null
      ? ImpressionScope(kaynak: 'tip', kaynakId: widget.type)
      : ImpressionScope(
          kaynak: 'kategori',
          kaynakId: widget.categoryId?.toString(),
        );

  bool _loading = true;
  bool _loadingMore = false;

  // Alt kategori sekmeleri aynı sayfada çalışır: sekmeler (_category + _subs)
  // ilk yüklemedeki kök kategoriden gelir ve sabit kalır; seçilen sekmeye göre
  // yalnız liste değişir. null = kök kategori seçili.
  int? _activeId;
  int? get _currentId => _activeId ?? widget.categoryId;
  bool _switching = false; // sekme değişti, yeni liste yükleniyor
  int _reqSeq = 0; // hızlı sekme değişiminde eski yanıtları yok saymak için
  final Map<int, GlobalKey> _pillKeys = {};

  Category? _category;
  List<Category> _subs = const [];
  Place? _pinned;
  List<Place> _places = [];
  int _total = 0;
  bool _hasMore = false;
  int? _nextPage;

  _Loc? _loc; // cihaz konumu (bir kez çözülür)
  _SortMode _sort = _SortMode.yakinlik; // varsayılan: yakınlık

  List<Filter> _filters = const []; // /filtreler → data
  final Set<int> _selectedFilters = {}; // seçili filtre id'leri
  List<Filter> _ozellikler = const []; // /filtreler → meta.ozellikler
  final Set<int> _selectedOzellikler = {}; // seçili özellik id'leri
  // Bölge (ilçe) filtresi: `/ilceler` listesi + tek seçim (null = tümü).
  // Tip modunda sunucuda (`/yerler?bolge=`), kategori modunda istemcide
  // süzülür (`/kategoriler/{id}` henüz `bolge=` almıyor, LISTE_BOLGE_FILTRE.md).
  List<Ilce> _bolgeler = const [];
  int? _selectedBolge;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _load();
    _loadBolgeler();
  }

  /// Filtre modalındaki "Bölge" sekmesi için ilçe listesi (oturumda cache'li).
  Future<void> _loadBolgeler() async {
    final list = await UyeRepository.instance.ilceler();
    if (!mounted || list.isEmpty) return;
    setState(() => _bolgeler = list);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<_Loc> _ensureLoc() async {
    final cached = _loc;
    if (cached != null) return cached;
    final r = await LocationService.resolve();
    _loc = r;
    return r;
  }

  // Kartın asıl "İl · İlçe" metni ([Place.distance] km eklenerek değiştiği
  // için bir kez saklanır; etiketler tekrar uygulanınca km çoğalmasın).
  final Expando<String> _baseLoc = Expando<String>();

  /// Kart alt yazısı: tür etiketi. Konum satırı (pin): "İl · İlçe · 3,4 km".
  ///
  /// Mesafe YALNIZ sunucudan gelir (`mesafe_m`; istekte konum gidiyor,
  /// LISTE_MESAFE.md). Uygulama tahmin etmez: eskiden sunucu mesafesi yokken
  /// kuş uçuşu × 1,3 gösteriliyordu ve detaydaki gerçek yol mesafesinden
  /// (Boğaz geçişlerinde 2–3 kat) farklı çıkıyordu. Sunucu mesafesi yoksa km
  /// yazılmaz.
  void _applyLabels(List<Place> list) {
    final label = switch (widget.type) {
      'plaj' => 'Plaj',
      'mesire' => 'Mesire',
      'otopark' => 'Otopark',
      'muze' => 'Müze',
      _ => 'Restoran',
    };
    for (final p in list) {
      p.subtitle = label;
      final base = _baseLoc[p] ??= p.distance;
      final km = LocationService.formatM(p.mesafeM);
      final parts = [base, km].where((s) => s.isNotEmpty).toList();
      p.distance = parts.isEmpty ? 'Konum bilgisi yok' : parts.join(' · ');
    }
  }

  /// "Yakınlık" sıralaması: sunucu mesafesi varsa o. Yoksa yalnız SIRALAMA
  /// için kuş uçuşu kullanılır (ekranda gösterilmez).
  double _distMeters(Place p, _Loc loc) {
    final m = p.mesafeM;
    if (m != null) return m.toDouble();
    if (p.lat.isNaN || p.lng.isNaN) return double.infinity;
    return LocationService.distanceMeters(loc.lat, loc.lng, p.lat, p.lng);
  }

  /// Sonsuz kaydırmada gelen yeni sayfayı listenin SONUNA ekler. Yalnız yeni
  /// sayfa kendi içinde sıralanır; ekranda görülmüş kayıtların yeri değişmez.
  ///
  /// Eskiden yeni sayfa eklenip TÜM liste yeniden sıralanıyordu. Sunucu
  /// listeyi mesafeye göre göndermediği için yeni kayıtlar listenin her yerine
  /// dağılıyor, kullanıcının baktığı alt kısım daha önce gördüğü mekanlarla
  /// doluyordu ("liste başa döndü / aynı şeyler yeniden yüklendi" etkisi).
  /// Ayrıca zaten listede olan kayıtlar (sunucu sırası değişirse) tekrar
  /// eklenmez.
  void _appendPage(List<Place> page) {
    final seen = {for (final p in _places) p.id};
    final fresh = [
      for (final p in page)
        if (p.id <= 0 || seen.add(p.id)) p,
    ];
    _sortList(fresh);
    _places.addAll(fresh);
  }

  /// Tüm listeyi seçili sıralamaya göre dizer (ilk yükleme / konum gelmesi /
  /// kullanıcı sıralamayı değiştirdiğinde).
  void _sortPlaces() => _sortList(_places);

  void _sortList(List<Place> list) {
    final loc = _loc;
    switch (_sort) {
      case _SortMode.yakinlik:
        // Konum izni yoksa varsayılan merkeze göre sıralama yapılmaz;
        // sunucu sırası korunur (MESAFE-MOBIL.md §6).
        if (loc != null && loc.real) {
          list.sort(
            (a, b) => _distMeters(a, loc).compareTo(_distMeters(b, loc)),
          );
        }
        break;
      case _SortMode.tarih:
        // Yeni → eski. `date` yalnız gün içerir; aynı gün eklenen çok kayıt
        // var (ör. otoparkların hepsi aynı gün), eşitlikte büyük id (sonra
        // eklenen) önce gelir. Sunucunun varsayılan sırasıyla aynıdır.
        list.sort((a, b) {
          final c = b.date.compareTo(a.date);
          return c != 0 ? c : b.id.compareTo(a.id);
        });
        break;
    }
  }

  Future<void> _load() async {
    final id = widget.categoryId;
    final type = widget.type;
    if (id == null && type == null) {
      _useFallback();
      return;
    }
    // Konumu PARALEL çöz — veri yüklemeyi bloklamasın. Gerçek cihazda GPS
    // fix'i saniyeler sürebildiğinden, önce konumu beklemek ekranı gereksiz
    // yere 4-5 sn döndürüyordu. Veri gelir gelmez gösterilir; konum gelince
    // mesafe + sıralama uygulanır.
    // Konum zaten biliniyorsa (ana sayfa açılışta çözüyor) liste İLK çizimde
    // sıralı gelir. Eskiden konum 1-2 sn sonra gelince liste yeniden
    // sıralanıyor, aynı satıra başka mekanın görseli yüklenip "resim baştan
    // yükleniyor" gibi görünüyordu.
    final known = LocationService.lastReal;
    if (known != null && _loc == null) {
      _loc = (lat: known.lat, lng: known.lng, real: true);
    }
    final locFuture = _ensureLoc();

    // Type modu: kategori değil post type listesi (GET /yerler?type=).
    if (type != null) {
      final seqAtStart = _reqSeq;
      try {
        // Tipe ait filtreler paralel çekilir (FILTRELER_TIP_BAZLI.md).
        // Not: `meta.ozellikler` tipe göre süzülmediği ve restoran odaklı
        // olduğu için otopark/plaj/mesire'de özellik grubu gösterilmez.
        // Süzme sunucuda yapılır (YERLER_FILTRE_IDS.md §8).
        // Alt sekmeler: tipin kategorileri (ör. mesire → Tabiat Parkı, Seyir
        // Tepesi…). Seçili sekme varsa liste sunucuda `kategori=` ile süzülür.
        final results = await Future.wait([
          HomeRepository.instance.yerler(
            type,
            limit: 20,
            filtreler: _selectedFilters.toList(),
            kategori: _activeId,
            bolge: _selectedBolge,
          ),
          HomeRepository.instance.filtreler(type: type),
          HomeRepository.instance.kategorilerTip(type),
        ]);
        if (seqAtStart != _reqSeq) return; // bu arada sekme değişti
        final r =
            results[0]
                as ({
                  List<Place> items,
                  bool hasMore,
                  int? nextPage,
                  int total,
                });
        final f =
            results[1] as ({List<Filter> filtreler, List<Filter> ozellikler});
        final cats = results[2] as List<Category>;
        if (!mounted) return;
        setState(() {
          _loading = false;
          _switching = false;
          _loadingMore = false;
          // Tek kategori varsa sekme anlamsız ("Tümü" ile aynı liste).
          _subs = cats.length > 1 ? cats : const [];
          _filters = f.filtreler;
          _ozellikler = const [];
          _places = List<Place>.from(r.items);
          _total = r.total;
          _hasMore = r.hasMore;
          _nextPage = r.nextPage;
        });
        _applyLocationWhenReady(locFuture);
      } catch (_) {
        if (!mounted || seqAtStart != _reqSeq) return;
        if (_subs.isEmpty) {
          _useFallback();
        } else {
          // Sekmeler duruyor: mock'a düşme, yalnız liste boş kalsın.
          setState(() {
            _loading = false;
            _switching = false;
            _places = [];
            _total = 0;
            _hasMore = false;
            _nextPage = null;
          });
        }
      }
      return;
    }

    try {
      final results = await Future.wait([
        HomeRepository.instance.kategoriDetay(id!, limit: 20),
        HomeRepository.instance.filtreler(type: 'restoran'),
      ]);
      final d = results[0] as CategoryDetail;
      final f =
          results[1] as ({List<Filter> filtreler, List<Filter> ozellikler});
      if (!mounted) return;
      setState(() {
        _loading = false;
        _filters = f.filtreler;
        _ozellikler = f.ozellikler;
        _category = d.category;
        _subs = d.subCategories;
        _pinned = d.pinned;
        _places = List<Place>.from(d.places);
        _total = d.total;
        _hasMore = d.hasMore;
        _nextPage = d.nextPage;
      });
      _applyLocationWhenReady(locFuture);
    } catch (_) {
      // Endpoint yoksa/hata olursa mock vitrine düş (tasarım bozulmasın).
      _useFallback();
    }
  }

  /// Etiketleri hemen uygular; konum (paralel) çözülünce listeyi yakınlığa
  /// göre yeniden sıralar. Konum gelene kadar sunucu sırası görünür.
  Future<void> _applyLocationWhenReady(Future<_Loc> locFuture) async {
    final hadLoc = _loc != null;
    setState(() {
      _applyLabels(_places);
      if (_pinned != null) _applyLabels([_pinned!]);
      if (hadLoc) _sortPlaces(); // bilinen konumla ilk çizimde sıralı
    });
    if (hadLoc) return; // konum zaten uygulandı; ikinci kez sıralama yok
    await locFuture;
    if (!mounted) return;
    setState(() {
      // Konum geldi: km'yi ekle (sunucu mesafesi yoksa yedek tahmin).
      _applyLabels(_places);
      if (_pinned != null) _applyLabels([_pinned!]);
      _sortPlaces();
    });
  }

  void _useFallback() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _places = List<Place>.from(MockData.categoryList);
      _total = _places.length;
      _hasMore = false;
      _nextPage = null;
    });
  }

  /// Alt kategori sekmesine geçer: aynı sayfada kalır, sekmeler yerinde durur,
  /// yalnız liste (ve sabit restoran) seçilen kategoriye göre yenilenir.
  /// Seçili filtre/özellik ve sıralama korunur.
  Future<void> _selectCategory(Category c) async {
    final type = widget.type;
    if (type != null) return _selectTypeCategory(type, c);
    if (c.id == _currentId) return;
    HapticFeedback.selectionClick();
    final seq = ++_reqSeq;
    setState(() {
      _activeId = c.id == widget.categoryId ? null : c.id;
      _switching = true;
      _loadingMore = false;
      _impressions = ImpressionScope(kaynak: 'kategori', kaynakId: '${c.id}');
    });
    _revealPill(c.id);
    try {
      final d = await HomeRepository.instance.kategoriDetay(c.id, limit: 20);
      if (!mounted || seq != _reqSeq) return; // bu arada başka sekme seçildi
      _applyLabels(d.places);
      if (d.pinned != null) _applyLabels([d.pinned!]);
      setState(() {
        _switching = false;
        _pinned = d.pinned;
        _places = List<Place>.from(d.places);
        _total = d.total;
        _hasMore = d.hasMore;
        _nextPage = d.nextPage;
        _sortPlaces();
      });
      _fillFilteredResults();
    } catch (_) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _switching = false;
        _pinned = null;
        _places = [];
        _total = 0;
        _hasMore = false;
        _nextPage = null;
      });
    }
  }

  /// Tip modunda ("Tümü" sekmesinin id'si). Gerçek kategori id'leri > 0.
  static const int _tumuId = 0;

  /// Tip ekranında (mesire/plaj/otopark) sekme değişimi: sekmeler yerinde
  /// kalır, liste `GET /yerler?type=&kategori=` ile yeniden çekilir. Seçili
  /// filtreler ve sıralama korunur. "Tümü" kategorisiz tüm tipi gösterir.
  Future<void> _selectTypeCategory(String type, Category c) async {
    final next = c.id == _tumuId ? null : c.id;
    if (next == _activeId) return;
    HapticFeedback.selectionClick();
    _reqSeq++;
    setState(() {
      _activeId = next;
      _switching = true;
      _loadingMore = false;
      _nextPage = null;
      _hasMore = false;
      _impressions = next == null
          ? ImpressionScope(kaynak: 'tip', kaynakId: type)
          : ImpressionScope(kaynak: 'kategori', kaynakId: '$next');
    });
    _revealPill(c.id);
    await _load();
  }

  /// Seçilen sekmeyi yatay listede ortalar.
  void _revealPill(int id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _pillKeys[id]?.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Kaydırma sonuna gelince otomatik olarak sonraki 20 kaydı yükler.
  Future<void> _loadMore() async {
    final id = _currentId;
    final type = widget.type;
    if ((id == null && type == null) ||
        _loadingMore ||
        _loading ||
        _switching ||
        !_hasMore ||
        _nextPage == null) {
      return;
    }
    final seq = _reqSeq;
    setState(() => _loadingMore = true);

    // Type modu: sonraki sayfayı GET /yerler?type= ile çek (filtreli).
    if (type != null) {
      try {
        final r = await HomeRepository.instance.yerler(
          type,
          page: _nextPage!,
          limit: 20,
          filtreler: _selectedFilters.toList(),
          kategori: _activeId,
          bolge: _selectedBolge,
        );
        if (!mounted) return;
        if (seq != _reqSeq) return; // sekme değişti; eski sekmenin sayfası
        _applyLabels(r.items);
        setState(() {
          _appendPage(r.items);
          // Yeni kayıt gelmediyse daha fazla isteme (sonsuz boş istek olmasın).
          _hasMore = r.hasMore && r.items.isNotEmpty;
          _nextPage = _hasMore ? r.nextPage : null;
          _loadingMore = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loadingMore = false);
      }
      return;
    }

    try {
      final d = await HomeRepository.instance.kategoriDetay(
        id!,
        page: _nextPage!,
        limit: 20,
      );
      if (!mounted) return;
      if (seq != _reqSeq) return; // sekme değişti; eski kategorinin sayfası
      _applyLabels(d.places);
      setState(() {
        _appendPage(d.places);
        _total = d.total;
        // Yeni kayıt gelmediyse daha fazla isteme (sonsuz boş istek olmasın).
        _hasMore = d.hasMore && d.places.isNotEmpty;
        _nextPage = _hasMore ? d.nextPage : null;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  bool get _hasActiveFilter =>
      _selectedFilters.isNotEmpty ||
      _selectedOzellikler.isNotEmpty ||
      _selectedBolge != null;

  /// Süzme sunucuda mı yapılıyor? Type modunda (`/yerler`) `filtreler=`
  /// gönderiliyor; kategori modunda (`/kategoriler/{id}`) böyle bir parametre
  /// olmadığı için istemci tarafında süzülür (YERLER_FILTRE_IDS.md §8).
  bool get _serverFiltered => widget.type != null;

  /// Kategori modunda süzme istemci tarafında ve yalnız yüklenmiş kayıtlara
  /// uygulandığı için, filtreli sonuç ekranı doldurmuyorsa sonraki sayfalar
  /// otomatik çekilir. Aksi halde liste kaydırılamaz ve `_loadMore` tetiklenmez.
  Future<void> _fillFilteredResults() async {
    if (_serverFiltered) return; // sunucu süzüyor, sayfa doldurmaya gerek yok
    var guard = 0; // en fazla 5 ek sayfa (100 kayıt) — istek yağmuru olmasın
    while (mounted &&
        _hasActiveFilter &&
        _hasMore &&
        _visiblePlaces.length < 10 &&
        guard < 5) {
      guard++;
      final before = _places.length;
      await _loadMore();
      if (!mounted || _places.length == before) break; // ilerleme yoksa dur
    }
  }

  bool _matchesFilters(Place p) {
    // Sunucu süzdüyse gelen kayıtlar zaten uygun.
    if (_serverFiltered || !_hasActiveFilter) return true;
    // AND mantığı: tüm seçili filtre + tüm seçili özellik id'leri mekanda
    // olmalı; bölge seçiliyse mekan o ilçede olmalı.
    final bolge = _selectedBolge;
    return (bolge == null || p.bolgeId == bolge) &&
        _selectedFilters.every((id) => p.filterIds.contains(id)) &&
        _selectedOzellikler.every((id) => p.ozellikIds.contains(id));
  }

  /// Seçili filtre/özelliklere göre görünecek mekanlar.
  List<Place> get _visiblePlaces => (_serverFiltered || !_hasActiveFilter)
      ? _places
      : _places.where(_matchesFilters).toList();

  Place? get _visiblePinned {
    final p = _pinned;
    if (p == null) return null;
    return _matchesFilters(p) ? p : null;
  }

  /// Filtre modalı açılabilir mi (filtre, özellik ya da bölge listesi var).
  bool get _canFilter =>
      _filters.isNotEmpty || _ozellikler.isNotEmpty || _bolgeler.isNotEmpty;

  /// Filtre bottom sheet'i (ortak `showFilterSheet`) — çoklu seçim + bölge.
  Future<void> _openFilterSheet() async {
    if (!_canFilter) return;
    final result = await showFilterSheet(
      context,
      filters: _filters,
      selected: _selectedFilters,
      ozellikler: _ozellikler,
      selectedOzellikler: _selectedOzellikler,
      bolgeler: _bolgeler,
      selectedBolge: _selectedBolge,
    );
    if (result != null && mounted) {
      setState(() {
        _selectedFilters
          ..clear()
          ..addAll(result.filters);
        _selectedOzellikler
          ..clear()
          ..addAll(result.ozellikler);
        _selectedBolge = result.bolge;
      });
      _onFilterChanged();
    }
  }

  /// Filtre seçimi değişti. Sunucu süzmeli modda liste 1. sayfadan yeniden
  /// çekilir (total/pages filtreli kümeye ait olur); kategori modunda mevcut
  /// kayıtlar üzerinde süzülüp gerekiyorsa sayfa doldurulur.
  void _onFilterChanged() {
    if (_serverFiltered) {
      _reqSeq++; // süren eski istek (sekme/filtre) yanıtı yok sayılsın
      _nextPage = null;
      _hasMore = false;
      _load();
    } else {
      _fillFilteredResults();
    }
  }

  /// Sıralama bottom sheet'i.
  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        Widget option(_SortMode mode, IconData icon, String label) {
          final selected = _sort == mode;
          return ListTile(
            leading: Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.muted,
            ),
            title: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
            trailing: selected
                ? const Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () {
              Navigator.pop(sheetCtx);
              if (_sort != mode) {
                setState(() {
                  _sort = mode;
                  _sortPlaces();
                });
              }
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sırala',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              option(
                _SortMode.yakinlik,
                Icons.near_me_outlined,
                'Yakınlığa göre',
              ),
              // Otoparklarda eklenme tarihi anlamlı değil (hepsi toplu, aynı
              // gün eklenmiş); bu seçenek gösterilmez.
              if (widget.type != 'otopark')
                option(
                  _SortMode.tarih,
                  Icons.schedule,
                  'Eklenme tarihine göre',
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String get _title => _category?.name ?? widget.title;

  void _openDetail(Place p, {Object? heroTag}) {
    Navigator.push(
      context,
      detailRoute(
        builder: (_) =>
            DetailScreen(place: p, heroTag: heroTag, type: widget.type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 120),
            // Lazy: 0 = başlık (+ alt kategori/pin), sonra mekan kartları, en
            // sonda durum/footer. Mekan kartları ve görselleri yalnızca ekrana
            // geldikçe oluşturulur.
            itemCount: (_loading || _switching) ? 1 : 2 + _visiblePlaces.length,
            // Kartlar mekan id'siyle anahtarlı: liste yeniden sıralanınca
            // (ilk kez konum gelince, sıralama değişince) kart görseliyle
            // birlikte yer değiştirir, görsel yeniden yüklenmez.
            findChildIndexCallback: (key) {
              if (key is! ValueKey<String>) return null;
              final v = key.value;
              if (!v.startsWith('cat-tile-')) return null;
              final id = int.tryParse(v.substring(9));
              final i = _visiblePlaces.indexWhere((p) => p.id == id);
              return i < 0 ? null : i + 1;
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 90),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 16),
                      if (_subs.isNotEmpty) ...[
                        _categoryPills(),
                        const SizedBox(height: 18),
                      ],
                      // Sekme değişirken sekmeler yerinde kalır; altında
                      // yalnız liste yükleniyor göstergesi.
                      if (_switching)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        _listHead(),
                        if (_hasActiveFilter) _selectedChips(),
                        if (_visiblePinned != null)
                          TrackImpression(
                            scope: _impressions,
                            placeId: _visiblePinned!.id,
                            featured: true,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                              child: ListTileCard(
                                place: _visiblePinned!,
                                heroTag: _visiblePinned!.id > 0
                                    ? 'cat-pin-${_visiblePinned!.id}'
                                    : null,
                                onTap: () => _openDetail(
                                  _visiblePinned!,
                                  heroTag: _visiblePinned!.id > 0
                                      ? 'cat-pin-${_visiblePinned!.id}'
                                      : null,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ],
                );
              }

              final i = index - 1;
              if (i < _visiblePlaces.length) {
                final p = _visiblePlaces[i];
                final tag = p.id > 0 ? 'cat-${p.id}' : null;
                return TrackImpression(
                  key: p.id > 0 ? ValueKey('cat-tile-${p.id}') : null,
                  scope: _impressions,
                  placeId: p.id,
                  position: i,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                    child: ListTileCard(
                      place: p,
                      heroTag: tag,
                      hideImage: widget.type == 'otopark',
                      onTap: () => _openDetail(p, heroTag: tag),
                    ),
                  ),
                );
              }

              // Son slot: boş durum mesajı ve/veya "daha fazla yükleniyor".
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_visiblePlaces.isEmpty && _visiblePinned == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
                      child: Center(
                        child: Text(
                          !_hasActiveFilter
                              ? 'Bu kategoride mekan bulunamadı'
                              : 'Seçili filtrelere uygun mekan bulunamadı',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  if (_loadingMore)
                    const Padding(
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
                    ),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: FloatingTabBar(
                activeIndex: -1,
                onTap: MainNav.instance.select,
              ),
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
        // Başlık ekranın tam ortasında dursun: solda 1, sağda 2 buton olduğu
        // için `Expanded + Center` başlığı sola kaydırıyordu. Stack ile başlık
        // tüm genişlikte ortalanır, butonlar üstüne yerleşir.
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              // Butonların altına girmesin (sağ taraf daha geniş).
              padding: const EdgeInsets.symmetric(horizontal: 96),
              child: Text(
                _title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            Row(
              children: [
                GlassButton(
                  icon: Icons.chevron_left,
                  flat: true,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                GlassButton(
                  icon: Icons.search,
                  flat: true,
                  onTap: () =>
                      showSearchModal(context, onOpenDetail: _openDetail),
                ),
                const SizedBox(width: 4),
                GlassButton(
                  icon: Icons.location_on_outlined,
                  svg: AppIcons.pin,
                  flat: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(
                        // Haritada da seçili sekmenin kategorisi açılsın.
                        initialCategoryId:
                            _currentId ?? _category?.id ?? widget.categoryId,
                        // Otopark/mesire/plaj listesinden geçilirse haritada da
                        // aynı tip seçili gelsin.
                        initialType: widget.type,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Kategori sekmeleri — ilk sekme kök kategori, sonrakiler alt kategoriler.
  /// Sekmeye dokununca yeni sayfa açılmaz; aynı sayfada liste değişir, seçili
  /// sekme ortalanır. Elle kaydırmaya başlayınca hafif titreşim verilir.
  /// Tüm sekmeler oluşturulur (sayı az) ki ekran dışındaki de ortalanabilsin.
  Widget _categoryPills() {
    // Tip modunda kök kategori yok; ilk sekme "Tümü" (tüm tip).
    final isType = widget.type != null;
    final items = <Category>[
      if (isType) const Category(id: _tumuId, name: 'Tümü') else ?_category,
      ..._subs,
    ];
    final current = isType
        ? (_activeId ?? _tumuId)
        : (_currentId ?? _category?.id);
    return SizedBox(
      height: 44,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (n) {
          // Yalnız parmakla kaydırma (ortalama animasyonunda titreşim yok).
          if (n.dragDetails != null) HapticFeedback.lightImpact();
          return false;
        },
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                KeyedSubtree(
                  key: _pillKeys.putIfAbsent(items[i].id, GlobalKey.new),
                  // Gerçek (API) ikon; yoksa ikonsuz hap.
                  child: CategoryPill.fromApi(
                    apiIcon: items[i].icon,
                    label: items[i].name,
                    active: items[i].id == current,
                    onTap: () => _selectCategory(items[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _listHead() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            // Sunucu süzmeli modda `_total` filtreli kümenin toplamıdır.
            !_hasActiveFilter
                ? '$_total mekan bulundu'
                : (_serverFiltered
                      ? '$_total mekan (filtreli)'
                      : '${_visiblePlaces.length} mekan (filtreli)'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _openSortSheet,
                child: _actBtn(Icons.swap_vert, svg: AppIcons.sort),
              ),
              // Bu liste için hiç filtre/özellik yoksa butonu gizle.
              if (_canFilter) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openFilterSheet,
                  child: _actBtn(
                    Icons.filter_list,
                    active: _hasActiveFilter,
                    svg: AppIcons.filter,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Seçili filtre/özellikleri liste başlığının altında ikonsuz badge olarak
  /// gösterir; her badge'deki × ile o filtre/özellik kaldırılır.
  Widget _selectedChips() {
    // Seçili id'leri (bölge + filtre + özellik) ad + kaynak türüyle eşle.
    // kind: 0 = filtre, 1 = özellik, 2 = bölge.
    final chips = <({int id, String name, int kind})>[];
    final bolge = _selectedBolge;
    if (bolge != null) {
      final ad = _bolgeler.where((b) => b.id == bolge).map((b) => b.ad);
      chips.add((id: bolge, name: ad.firstOrNull ?? 'Bölge', kind: 2));
    }
    for (final f in _filters) {
      if (_selectedFilters.contains(f.id)) {
        chips.add((id: f.id, name: f.name, kind: 0));
      }
    }
    for (final f in _ozellikler) {
      if (_selectedOzellikler.contains(f.id)) {
        chips.add((id: f.id, name: f.name, kind: 1));
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in chips)
            GestureDetector(
              onTap: () {
                setState(() {
                  switch (c.kind) {
                    case 2:
                      _selectedBolge = null;
                    case 1:
                      _selectedOzellikler.remove(c.id);
                    default:
                      _selectedFilters.remove(c.id);
                  }
                });
                _onFilterChanged();
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const AppSvgIcon(
                      AppIcons.xmark,
                      size: 10,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actBtn(IconData icon, {bool active = false, String? svg}) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: active ? AppColors.primary : AppColors.line),
      ),
      child: svg != null
          ? AppSvgIcon(
              svg,
              size: 17,
              color: active ? Colors.white : AppColors.primary,
            )
          : Icon(
              icon,
              size: 18,
              color: active ? Colors.white : AppColors.primary,
            ),
    );
  }
}
