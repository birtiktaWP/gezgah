import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/api.dart';
import '../data/location_service.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../data/search_history.dart';
import '../data/user_service.dart';
import '../data/view_tracker.dart';
import 'filter_sheet.dart';
import 'track_impression.dart';
import '../screens/category_screen.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'common.dart';
import 'kedy_chat.dart';
import 'menu_item_sheet.dart';
import 'place_cards.dart';

/// Aramada seçilebilen mekan tipi (ARAMA_TIP_BAZLI.md → `type`).
/// Sıra, tip seçicideki gösterim sırasıdır.
enum _SearchType { mekan, mesire, otopark, plaj }

extension _SearchTypeX on _SearchType {
  /// API'ye gönderilen `type` değeri.
  String get slug => switch (this) {
    _SearchType.mekan => 'mekan',
    _SearchType.plaj => 'plaj',
    _SearchType.mesire => 'mesire',
    _SearchType.otopark => 'otopark',
  };

  String get label => switch (this) {
    _SearchType.mekan => 'Mekanlar',
    _SearchType.mesire => 'Mesire',
    _SearchType.otopark => 'Otopark',
    _SearchType.plaj => 'Plaj',
  };

  IconData get icon => switch (this) {
    _SearchType.mekan => Icons.restaurant_outlined,
    _SearchType.plaj => Icons.beach_access_outlined,
    _SearchType.mesire => Icons.park_outlined,
    _SearchType.otopark => Icons.local_parking_outlined,
  };

  /// Yemek (QR menü) araması yalnız `mekan` tipinde geçerlidir.
  bool get yemekVar => this == _SearchType.mekan;

  /// Arama kutusunun ipucu metni (seçili sekmeye göre).
  String get hint => switch (this) {
    _SearchType.mekan => 'Mekan ve yemek ara…',
    _SearchType.mesire => 'Mesire alanı, park ara…',
    _SearchType.otopark => 'Otopark ara…',
    _SearchType.plaj => 'Plaj ara…',
  };
}

/// Gelişmiş arama — tam ekran açılan modal.
///
/// [initialQuery] verilirse (ör. sesli arama sonucu) kutu bu metinle dolu
/// açılır ve arama hemen çalışır.
void showSearchModal(
  BuildContext context, {
  void Function(Place place)? onOpenDetail,
  String? initialQuery,
}) {
  // Arama kutusuna art arda basılınca üst üste ikinci bir modal açılmasın.
  if (_searchOpen) return;
  _searchOpen = true;
  Navigator.of(context)
      .push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black26,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => _SearchModal(
            onOpenDetail: onOpenDetail,
            initialQuery: initialQuery,
          ),
          transitionsBuilder: (_, anim, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            );
          },
        ),
      )
      .whenComplete(() => _searchOpen = false);
}

/// Bir arama modalı açık mı (ikinci kez açılmayı engellemek için).
bool _searchOpen = false;

class _SearchModal extends StatefulWidget {
  final void Function(Place place)? onOpenDetail;
  final String? initialQuery;
  const _SearchModal({this.onOpenDetail, this.initialQuery});

  @override
  State<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<_SearchModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final TabController _tab;

  Timer? _debounce;
  String _query = '';

  // "Mekanlar" sekmesi (varsayılan, tab=mekan).
  final ScrollController _placeScroll = ScrollController();
  CancelToken? _placeCancel;
  List<SearchResult> _placeItems = const [];
  bool _placeLoading = false;
  bool _placeMoreLoading = false;
  bool _placeHasMore = false;
  int? _placeNextPage;

  // "Yemekler" sekmesi (lazy; sekmeye geçilince tab=yemek ile yüklenir).
  final ScrollController _foodScroll = ScrollController();
  CancelToken? _foodCancel;
  List<FoodResult> _foodItems = const [];
  bool _foodLoading = false;
  bool _foodMoreLoading = false;
  bool _foodHasMore = false;
  int? _foodNextPage;
  String? _foodTerm; // yemekler'in yüklendiği terim (null = yüklenmedi)

  // Konum (mesafe sıralaması) + yemek sekmesi sıralama/filtre durumu.
  double? _lat;
  double? _lng;
  bool _hasCoord = false;
  // Sıralama: tek seçim (en fazla 1 eleman). Çoklu sıralama kaldırıldı.
  // Boşsa varsayılan kullanılır (bkz. getter'lar).
  List<String> _foodSorts = const [];
  List<String> _placeSorts = const [];
  final Set<int> _foodFilters = {}; // seçili filtre id'leri (yemek)
  final Set<int> _placeFilters = {}; // seçili filtre id'leri (mekan)
  List<Filter> _allFilters = const []; // /filtreler (filtre sheet için)
  final Set<int> _foodOzellikler = {}; // seçili özellik id'leri (yemek)
  final Set<int> _placeOzellikler = {}; // seçili özellik id'leri (mekan)
  List<Filter> _allOzellikler = const []; // /filtreler meta.ozellikler
  // Bölge (ilçe) filtresi — liste ekranlarıyla aynı modal sekmesi. `/arama`
  // `bolge=` parametresini bugün yok sayıyor; yüklenen sonuçlar istemcide
  // süzülür (LISTE_BOLGE_FILTRE.md).
  List<Ilce> _bolgeler = const [];
  int? _placeBolge;
  int? _foodBolge;

  /// Aranan mekan tipi (ARAMA_TIP_BAZLI.md). `mekan` dışındaki tiplerde QR menü
  /// bulunmadığı için Yemekler sekmesi gösterilmez.
  _SearchType _type = _SearchType.mekan;
  final ScrollController _typeScroll = ScrollController();
  bool _typeAtEnd = false; // tip listesi sonuna kaydırıldı mı (fade'i kaldır)
  // Seçilen hapı yatay listede ortalamak için (yarım/silik görünmesin).
  final Map<_SearchType, GlobalKey> _typeKeys = {
    for (final t in _SearchType.values) t: GlobalKey(),
  };

  /// Seçili tip hapını yatay listede ortalar (kenardaki silik alanda kalmasın).
  void _revealType(_SearchType t) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _typeKeys[t]?.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String? _userId; // arama geçmişi kaydı için (varsa gerçek, yoksa anonim)
  List<String> _popular = MockData.popularSearches; // API gelene kadar fallback
  List<String> _history = const [];
  List<Category> _categories = const []; // ana sayfayla aynı kaynak

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(_onTabChanged);
    _placeScroll.addListener(() {
      if (_placeScroll.position.pixels >=
          _placeScroll.position.maxScrollExtent - 300) {
        _loadMorePlaces();
      }
    });
    _foodScroll.addListener(() {
      if (_foodScroll.position.pixels >=
          _foodScroll.position.maxScrollExtent - 300) {
        _loadMoreFoods();
      }
    });
    _loadInitial();
    _resolveLoc();
    _loadBolgeler();
    // Sesli aramadan gelen metin: kutuya yaz, aramayı başlat, geçmişe ekle.
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _controller.text = q;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onQueryChanged(q);
        _commitHistory(q);
      });
    }
  }

  /// Filtre modalındaki "Bölge" sekmesi için ilçe listesi (oturumda cache'li).
  Future<void> _loadBolgeler() async {
    final list = await UyeRepository.instance.ilceler();
    if (!mounted || list.isEmpty) return;
    setState(() => _bolgeler = list);
  }

  /// Türkçe büyük/küçük harf farkını yok sayarak ilçe adı karşılaştırması.
  static String _norm(String s) =>
      s.trim().replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  String? _bolgeAdi(int? id) =>
      _bolgeler.where((b) => b.id == id).map((b) => b.ad).firstOrNull;

  /// Bölge seçiliyse yalnız o ilçedeki mekan sonuçları (istemci süzmesi).
  List<SearchResult> get _visiblePlaceItems {
    final b = _placeBolge;
    if (b == null) return _placeItems;
    return _placeItems.where((r) => r.place.bolgeId == b).toList();
  }

  /// Bölge seçiliyse yalnız o ilçedeki mekanların ürünleri. Yemek yanıtında
  /// ilçe id'si yok; varsa id, yoksa ilçe adı eşleştirilir.
  List<FoodResult> get _visibleFoodItems {
    final b = _foodBolge;
    if (b == null) return _foodItems;
    final ad = _norm(_bolgeAdi(b) ?? '');
    return _foodItems.where((f) {
      final id = f.mekan.bolgeId;
      if (id != null) return id == b;
      return ad.isNotEmpty && _norm(f.ilce) == ad;
    }).toList();
  }

  /// İstemci süzmesi yüklenmiş sayfalara uygulandığı için seçili ilçede az
  /// sonuç kaldıysa sonraki sayfalar otomatik çekilir (en fazla 5 sayfa).
  Future<void> _fillPlaces() async {
    var guard = 0;
    while (mounted &&
        _placeBolge != null &&
        _placeHasMore &&
        _visiblePlaceItems.length < 10 &&
        guard < 5) {
      guard++;
      final before = _placeItems.length;
      await _loadMorePlaces();
      if (!mounted || _placeItems.length == before) break;
    }
  }

  /// Yemek sonuçları mekana göre gruplu: her işletme bir kez, en iyi eşleşen
  /// ürünüyle (ARAMA_YEMEK_GRUPLU.md). İşletme sırası, ürünlerinin sunucu
  /// sırasındaki ilk göründüğü yerdir (seçili sıralama korunur). Gruptaki
  /// "en iyi" ürün, ada göre en iyi eşleşen; eşitlikte sunucu sırası.
  /// Sunucu gruplu yanıt verirse (`diger_urunler`) o ürünler de gruba girer.
  List<_FoodGroup> get _foodGroups {
    final q = _norm(_foodTerm ?? _query);
    final byMekan = <int, _FoodGroup>{};
    final order = <_FoodGroup>[];
    var anon = -1; // mekan id'si 0 olan kayıtlar birleştirilmez
    for (final f in _visibleFoodItems) {
      final id = f.mekan.id > 0 ? f.mekan.id : anon--;
      final g = byMekan.putIfAbsent(id, () {
        final n = _FoodGroup(f);
        order.add(n);
        return n;
      });
      for (final item in [f, ...f.diger]) {
        g.add(item, _matchScore(item.urun, q));
      }
      final s = f.eslesenSayisi;
      if (s != null && s > g.serverCount) g.serverCount = s;
    }
    return order;
  }

  /// Ürün adının aramayla eşleşme puanı (büyük = daha iyi). Tam eşleşme >
  /// adla başlama > kelime başında > içinde geçme; çok kelimeli aramada
  /// eşleşen kelime sayısı eklenir; kısa ad hafif öne çıkar.
  static double _matchScore(String name, String q) {
    final n = _norm(name);
    if (q.isEmpty || n.isEmpty) return 0;
    double s = 0;
    if (n == q) {
      s = 100;
    } else if (n.startsWith(q)) {
      s = 80;
    } else if (RegExp('(^|[^a-z0-9çğıöşü])${RegExp.escape(q)}').hasMatch(n)) {
      s = 60;
    } else if (n.contains(q)) {
      s = 40;
    }
    final words = q.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.length > 1) {
      s += 10 * words.where(n.contains).length;
    }
    return s - n.length * 0.05;
  }

  Future<void> _fillFoods() async {
    var guard = 0;
    // Gruplama (ve varsa bölge süzmesi) ekranda az kart bırakabilir; ekran
    // dolana kadar (10 işletme) en fazla 5 ek sayfa çekilir.
    while (mounted && _foodHasMore && _foodGroups.length < 10 && guard < 5) {
      guard++;
      final before = _foodItems.length;
      await _loadMoreFoods();
      if (!mounted || _foodItems.length == before) break;
    }
  }

  /// Konumu (mesafe sıralaması için) çözer. Gerçek konum varsa mekan/yemek
  /// varsayılanı mesafeye döner; aktif bir sorgu varsa yeniden çalıştırılır.
  Future<void> _resolveLoc() async {
    final loc = await LocationService.resolve();
    if (!mounted || !loc.real) return;
    setState(() {
      _lat = loc.lat;
      _lng = loc.lng;
      _hasCoord = true;
      // Kullanıcı elle sıralama seçmediyse varsayılan kendiliğinden mesafeye
      // döner (bkz. _foodSortsEff / _placeSortsEff).
    });
    // Konum geç geldiyse ve arama aktifse mesafeye göre yenile.
    final term = _query.trim();
    if (term.length >= 2) {
      _runMekan(term);
      if (_tab.index == 1) _runFood(term);
    }
  }

  /// Etkin sıralama kriteri (tek elemanlı liste). Seçim yoksa varsayılan:
  /// konum varsa mesafe, yoksa yemekte beğeni / mekanda ilgi düzeyi.
  List<String> get _foodSortsEff =>
      _foodSorts.isNotEmpty ? _foodSorts : [_hasCoord ? 'distance' : 'likes'];
  List<String> get _placeSortsEff => _placeSorts.isNotEmpty
      ? _placeSorts
      : [_hasCoord ? 'distance' : 'relevance'];

  /// Seçili kriter `sort=` ile gider.
  String get _foodSort => _foodSortsEff.first;
  String? get _mekanSort {
    final s = _placeSortsEff.first;
    return s == 'relevance' ? null : s; // ilgi = sunucu varsayılanı
  }

  /// Sıralama seçenekleri (değer, tam etiket, kısa etiket, dışlayan grup).
  /// Aynı gruptakiler birlikte seçilemez (fiyat artan/azalan).
  List<({String v, String label, String short, String? group})>
  get _foodSortOptions => [
    if (_hasCoord)
      (v: 'distance', label: 'Yakınlığa göre', short: 'Yakınlık', group: null),
    (v: 'likes', label: 'Beğeniye göre', short: 'Beğeni', group: null),
    (v: 'price_asc', label: 'Fiyat: Artan', short: 'Fiyat ↑', group: 'fiyat'),
    (v: 'price_desc', label: 'Fiyat: Azalan', short: 'Fiyat ↓', group: 'fiyat'),
  ];
  List<({String v, String label, String short, String? group})>
  get _placeSortOptions => [
    if (_hasCoord)
      (v: 'distance', label: 'Yakınlığa göre', short: 'Yakınlık', group: null),
    (v: 'relevance', label: 'İlgi düzeyine göre', short: 'İlgi', group: null),
  ];

  /// "Yakınlık · Beğeni" gibi kısa özet (araç çubuğunda).
  String _sortSummary(
    List<String> sorts,
    List<({String v, String label, String short, String? group})> opts,
  ) {
    if (sorts.length == 1) {
      return opts
          .firstWhere(
            (o) => o.v == sorts.first,
            orElse: () => (v: '', label: 'Sıralama', short: '', group: null),
          )
          .label;
    }
    return sorts
        .map(
          (s) => opts
              .firstWhere(
                (o) => o.v == s,
                orElse: () => (v: s, label: s, short: s, group: null),
              )
              .short,
        )
        .join(' · ');
  }

  /// Metre → "1.2 km" (yoksa boş).
  String _km(int? m) => m == null ? '' : LocationService.format(m.toDouble());

  /// Yemekler sekmesine geçilince aynı terimle bir kez yükler (tab=yemek).
  void _onTabChanged() {
    if (_tab.index == 1) {
      final term = _query.trim();
      if (term.length >= 2 && _foodTerm != term && !_foodLoading) {
        _runFood(term);
      }
    }
  }

  Future<void> _loadInitial() async {
    final id = await UserService.instance.currentId();
    final pop = await HomeRepository.instance.populerAramalar(limit: 6);
    final hist = await SearchHistory.instance.list();
    // Ana sayfadaki kategorilerle aynı: mekanı olanlar, en çok mekana göre.
    List<Category> cats = const [];
    try {
      final all = await HomeRepository.instance.kategoriler();
      // one_cikan_kategoriler'de mekan_sayisi yok (hepsi 0); bu durumda
      // curated sırayı koru. Aksi halde (fallback /kategoriler) mekanı
      // olanları mekan sayısına göre sırala.
      final hasCounts = all.any((c) => c.mekanSayisi > 0);
      cats = hasCounts
          ? (all.where((c) => c.mekanSayisi > 0).toList()
              ..sort((a, b) => b.mekanSayisi.compareTo(a.mekanSayisi)))
          : all;
    } catch (_) {
      cats = const [];
    }

    if (!mounted) return;
    setState(() {
      _userId = id;
      if (pop.isNotEmpty) _popular = pop;
      _history = hist;
      _categories = cats;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _placeCancel?.cancel('modal kapandı');
    _foodCancel?.cancel('modal kapandı');
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _typeScroll.dispose();
    _placeScroll.dispose();
    _foodScroll.dispose();
    _routeAnim?.removeStatusListener(_onRouteAnim);
    _fieldFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  // --- Arama alanı odağı ------------------------------------------------------

  final FocusNode _fieldFocus = FocusNode(debugLabel: 'arama-alani');
  Animation<double>? _routeAnim;
  bool _autoFocused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anim = ModalRoute.of(context)?.animation;
    if (anim != _routeAnim) {
      _routeAnim?.removeStatusListener(_onRouteAnim);
      _routeAnim = anim;
      anim?.addStatusListener(_onRouteAnim);
      if (anim?.status == AnimationStatus.completed) _onRouteAnim(anim!.status);
    }
  }

  /// Modal girişi bitince (ekranda tam görünür) bir kez klavyeyi açar; modal
  /// kapanmaya başlayınca odağı hemen bırakır.
  void _onRouteAnim(AnimationStatus s) {
    if (!mounted) return;
    setState(() {}); // canRequestFocus güncellensin
    if (s == AnimationStatus.reverse || s == AnimationStatus.dismissed) {
      if (_fieldFocus.hasFocus) _fieldFocus.unfocus();
      return;
    }
    if (s != AnimationStatus.completed || _autoFocused) return;
    // Sesli aramadan gelindiyse klavye açılmasın (sonuçlar tam ekranda
    // görünsün); kutuya dokununca açılır.
    if ((widget.initialQuery ?? '').trim().isNotEmpty) return;
    // Rota ilk karede animasyonu henüz bağlanmadan "completed" görünebiliyor;
    // bu yüzden karar bir sonraki karede yeniden kontrol edilir ve bayrak
    // yalnız odak gerçekten istendiğinde kalkar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoFocused || !_canFocus(context)) return;
      _autoFocused = true;
      _fieldFocus.requestFocus();
    });
  }

  /// Alan odak alabilir mi: modal en üstte VE giriş animasyonu bitmiş.
  bool _canFocus(BuildContext context) {
    final r = ModalRoute.of(context);
    if (r == null) return true;
    return r.isCurrent && r.animation?.status == AnimationStatus.completed;
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    final term = value.trim();
    if (term.length < 2) {
      _placeCancel?.cancel('kısa sorgu');
      _foodCancel?.cancel('kısa sorgu');
      setState(() {
        _placeItems = const [];
        _foodItems = const [];
        _placeLoading = false;
        _foodLoading = false;
        _foodTerm = null;
        _placeHasMore = false;
        _foodHasMore = false;
      });
      return;
    }
    setState(() {
      _placeLoading = true;
      _foodTerm = null; // yeni terim → yemekler tekrar yüklenecek
    });
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runMekan(term);
      if (_tab.index == 1) _runFood(term); // yemekler sekmesindeyken de yükle
    });
  }

  /// Mekanlar sekmesi (tab=mekan). Önceki isteği iptal eder.
  Future<void> _runMekan(String term) async {
    _placeCancel?.cancel('yeni arama');
    final token = CancelToken();
    _placeCancel = token;
    if (mounted) setState(() => _placeLoading = true);
    try {
      final r = await HomeRepository.instance.aramaMekan(
        term,
        userId: _userId,
        limit: 20,
        cancelToken: token,
        lat: _lat,
        lng: _lng,
        sort: _mekanSort,
        filtreler: _placeFilters.toList(),
        ozellikler: _placeOzellikler.toList(),
        type: _type.slug,
        bolge: _placeBolge,
      );
      if (!mounted || _controller.text.trim() != term) return;
      setState(() {
        _renewSearchScope(term);
        _placeItems = r.items;
        _placeHasMore = r.hasMore;
        _placeNextPage = r.nextPage;
        _placeLoading = false;
      });
      _fillPlaces();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (!mounted) return;
      setState(() {
        _placeItems = const [];
        _placeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _placeItems = const [];
        _placeLoading = false;
      });
    }
  }

  /// Yemekler sekmesi (tab=yemek). Önceki isteği iptal eder.
  /// Yemek araması yalnız `type=mekan` ile geçerlidir (diğer tiplerde sunucu
  /// 422 döner) — bu yüzden tip uygun değilse hiç istek atılmaz.
  Future<void> _runFood(String term) async {
    if (!_type.yemekVar) return;
    _foodCancel?.cancel('yeni arama');
    final token = CancelToken();
    _foodCancel = token;
    if (mounted) setState(() => _foodLoading = true);
    try {
      final r = await HomeRepository.instance.aramaYemek(
        term,
        userId: _userId,
        limit: 20,
        cancelToken: token,
        lat: _lat,
        lng: _lng,
        sort: _foodSort,
        filtreler: _foodFilters.toList(),
        ozellikler: _foodOzellikler.toList(),
        bolge: _foodBolge,
      );
      if (!mounted || _controller.text.trim() != term) return;
      setState(() {
        _foodItems = r.items;
        _foodHasMore = r.hasMore;
        _foodNextPage = r.nextPage;
        _foodTerm = term;
        _foodLoading = false;
      });
      _fillFoods();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (!mounted) return;
      setState(() {
        _foodItems = const [];
        _foodTerm = term;
        _foodLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _foodItems = const [];
        _foodTerm = term;
        _foodLoading = false;
      });
    }
  }

  Future<void> _loadMorePlaces() async {
    if (_placeMoreLoading || !_placeHasMore || _placeNextPage == null) return;
    final term = _query.trim();
    if (term.length < 2) return;
    setState(() => _placeMoreLoading = true);
    try {
      final r = await HomeRepository.instance.aramaMekan(
        term,
        userId: _userId,
        page: _placeNextPage!,
        limit: 20,
        lat: _lat,
        lng: _lng,
        sort: _mekanSort,
        filtreler: _placeFilters.toList(),
        ozellikler: _placeOzellikler.toList(),
        type: _type.slug,
        bolge: _placeBolge,
      );
      if (!mounted) return;
      setState(() {
        _placeItems = [..._placeItems, ...r.items];
        _placeHasMore = r.hasMore;
        _placeNextPage = r.nextPage;
        _placeMoreLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _placeMoreLoading = false);
    }
  }

  Future<void> _loadMoreFoods() async {
    if (!_type.yemekVar) return;
    if (_foodMoreLoading || !_foodHasMore || _foodNextPage == null) return;
    final term = _query.trim();
    if (term.length < 2) return;
    setState(() => _foodMoreLoading = true);
    try {
      final r = await HomeRepository.instance.aramaYemek(
        term,
        userId: _userId,
        page: _foodNextPage!,
        limit: 20,
        lat: _lat,
        lng: _lng,
        sort: _foodSort,
        filtreler: _foodFilters.toList(),
        ozellikler: _foodOzellikler.toList(),
        bolge: _foodBolge,
      );
      if (!mounted) return;
      setState(() {
        _foodItems = [..._foodItems, ...r.items];
        _foodHasMore = r.hasMore;
        _foodNextPage = r.nextPage;
        _foodMoreLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _foodMoreLoading = false);
    }
  }

  bool get _isSearching => _query.trim().length >= 2;

  void _clear() {
    _placeCancel?.cancel('temizlendi');
    _foodCancel?.cancel('temizlendi');
    setState(() {
      _controller.clear();
      _query = '';
      _placeItems = const [];
      _foodItems = const [];
      _placeLoading = false;
      _foodLoading = false;
      _foodTerm = null;
      _placeHasMore = false;
      _foodHasMore = false;
    });
  }

  /// Bir terimi arama kutusuna yazıp aramayı tetikler (çip/öneri dokunuşları).
  void _applyTerm(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    _onQueryChanged(term);
  }

  /// Terimi yerel "Son Aramalar" listesine ekler (kullanıcı aramayı onayladı).
  Future<void> _commitHistory(String term) async {
    final t = term.trim();
    if (t.length < 2) return;
    final hist = await SearchHistory.instance.add(t);
    if (!mounted) return;
    setState(() => _history = hist);
  }

  Future<void> _removeHistory(String term) async {
    final hist = await SearchHistory.instance.remove(term);
    if (!mounted) return;
    setState(() => _history = hist);
  }

  Future<void> _clearHistory() async {
    await SearchHistory.instance.clear();
    if (!mounted) return;
    setState(() => _history = const []);
  }

  /// Yemekler sekmesi sıralama (tek seçim).
  Future<void> _openFoodSort() async {
    final r = await _showSortSheet(_foodSortOptions, _foodSortsEff);
    if (r == null || !mounted || _sameList(r, _foodSortsEff)) return;
    setState(() => _foodSorts = r);
    final term = _query.trim();
    if (term.length >= 2) _runFood(term);
  }

  /// Mekanlar sekmesi sıralama (tek seçim).
  Future<void> _openPlaceSort() async {
    final r = await _showSortSheet(_placeSortOptions, _placeSortsEff);
    if (r == null || !mounted || _sameList(r, _placeSortsEff)) return;
    setState(() => _placeSorts = r);
    final term = _query.trim();
    if (term.length >= 2) _runMekan(term);
  }

  static bool _sameList(List<String> a, List<String> b) =>
      a.length == b.length &&
      Iterable.generate(a.length).every((i) => a[i] == b[i]);

  /// Sıralama paneli — TEK seçim (mekan listesi ekranındaki "Sırala" ile
  /// aynı davranış). Bir kritere dokununca panel kapanır ve `[kriter]` döner;
  /// kapatılırsa null. (Çoklu sıralama kaldırıldı; `siralar=` gönderilmez,
  /// yalnız `sort=` kullanılır.)
  Future<List<String>?> _showSortSheet(
    List<({String v, String label, String short, String? group})> options,
    List<String> current,
  ) {
    final selected = current.isEmpty ? null : current.first;
    return showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
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
            for (final o in options)
              ListTile(
                title: Text(
                  o.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: o.v == selected ? AppColors.primary : AppColors.ink,
                  ),
                ),
                trailing: o.v == selected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                selected: o.v == selected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(ctx, [o.v]);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Yemekler sekmesi filtre seçimi (bottom sheet, /filtreler).
  /// `/filtreler` için tip: arama `mekan` tipinde restoran filtrelerini kullanır.
  String get _filterType =>
      _type == _SearchType.mekan ? 'restoran' : _type.slug;

  /// Özellikler (Teras, Bahçe…) restoran odaklıdır ve `/filtreler`
  /// `meta.ozellikler` tipe göre süzülmez → yalnız `mekan` tipinde gösterilir
  /// (kategori ekranındaki tip modu davranışıyla aynı).
  List<Filter> get _visibleOzellikler =>
      _type == _SearchType.mekan ? _allOzellikler : const [];

  /// Filtre + özellik listelerini (tip bazlı) bir kez çeker.
  Future<void> _ensureFilterLists() async {
    if (_allFilters.isNotEmpty || _allOzellikler.isNotEmpty) return;
    // Filtre id'leri tipe özeldir (FILTRELER_TIP_BAZLI.md).
    final f = await HomeRepository.instance.filtreler(type: _filterType);
    _allFilters = f.filtreler;
    _allOzellikler = f.ozellikler;
  }

  Future<void> _openFoodFilter() async {
    await _ensureFilterLists();
    if (!mounted) return;
    if (_allFilters.isEmpty &&
        _visibleOzellikler.isEmpty &&
        _bolgeler.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Filtre bulunamadı')));
      return;
    }
    // Liste ekranlarıyla aynı modal: Filtreler | Bölge sekmeleri.
    final result = await showFilterSheet(
      context,
      filters: _allFilters,
      selected: _foodFilters,
      ozellikler: _visibleOzellikler,
      selectedOzellikler: _foodOzellikler,
      bolgeler: _bolgeler,
      selectedBolge: _foodBolge,
    );
    if (result != null && mounted) {
      setState(() {
        _foodFilters
          ..clear()
          ..addAll(result.filters);
        _foodOzellikler
          ..clear()
          ..addAll(result.ozellikler);
        _foodBolge = result.bolge;
      });
      final term = _query.trim();
      if (term.length >= 2) _runFood(term);
    }
  }

  /// Mekanlar sekmesi filtre seçimi (ortak `showFilterSheet`).
  Future<void> _openPlaceFilter() async {
    await _ensureFilterLists();
    if (!mounted) return;
    if (_allFilters.isEmpty &&
        _visibleOzellikler.isEmpty &&
        _bolgeler.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Filtre bulunamadı')));
      return;
    }
    // Liste ekranlarıyla aynı modal: Filtreler | Bölge sekmeleri.
    final result = await showFilterSheet(
      context,
      filters: _allFilters,
      selected: _placeFilters,
      ozellikler: _visibleOzellikler,
      selectedOzellikler: _placeOzellikler,
      bolgeler: _bolgeler,
      selectedBolge: _placeBolge,
    );
    if (result != null && mounted) {
      setState(() {
        _placeFilters
          ..clear()
          ..addAll(result.filters);
        _placeOzellikler
          ..clear()
          ..addAll(result.ozellikler);
        _placeBolge = result.bolge;
      });
      final term = _query.trim();
      if (term.length >= 2) _runMekan(term);
    }
  }

  /// Kategoriye dokununca arama modalını kapatıp kategori detayını açar.
  void _openCategory(Category c) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(
      MaterialPageRoute(
        builder: (_) => CategoryScreen(categoryId: c.id, title: c.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: GestureDetector(
        // Boş bir yere dokununca klavyeyi kapat.
        onTap: dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: _isSearching
                    ? _resultsView()
                    : ListView(
                        // Kaydırınca da klavye kapansın.
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          if (_history.isNotEmpty) ...[
                            _historyHeader(),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _history
                                  .take(3) // yalnızca son 3 arama
                                  .map(
                                    (s) => _chip(
                                      s,
                                      Icons.history,
                                      onRemove: () => _removeHistory(s),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 26),
                          ],
                          _sectionTitle('Popüler Aramalar'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _popular
                                .map((s) => _chip(s, Icons.trending_up))
                                .toList(),
                          ),
                          const SizedBox(height: 26),
                          _kedyHeader(),
                          const SizedBox(height: 12),
                          _kedyGrid(),
                          const SizedBox(height: 26),
                          _sectionTitle('Kategoriler'),
                          const SizedBox(height: 14),
                          _categoryRow(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Arama sonuçları görünümü (q >= 2). Üstte tip seçici; `mekan` tipinde
  /// Mekanlar/Yemekler sekmeleri, diğer tiplerde (plaj/mesire/otopark) QR menü
  /// olmadığı için sekme yok — doğrudan mekan listesi (ARAMA_TIP_BAZLI.md).
  Widget _resultsView() {
    // Yemek sekmesi olmayan tiplerde (plaj/mesire/otopark) doğrudan liste.
    if (!_type.yemekVar) return _placesTab();
    return Column(
      children: [
        _searchTabs(),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [_placesTab(), _foodsTab()],
          ),
        ),
      ],
    );
  }

  /// Mekan tipi seçici — yatay hap listesi (Mekan seçili gelir). Sağ kenar
  /// yumuşatılır (kaydırılabilir olduğu belli olsun); kaydırmaya başlayınca
  /// hafif titreşim verilir.
  Widget _typeSelector() {
    return SizedBox(
      height: 36,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // Kaydırma başladığında bir kez hafif titreşim.
          if (n is ScrollStartNotification) HapticFeedback.lightImpact();
          if (n is ScrollMetricsNotification || n is ScrollUpdateNotification) {
            final m = n.metrics;
            final atEnd = m.pixels >= m.maxScrollExtent - 2;
            if (atEnd != _typeAtEnd) {
              // Sona gelindiyse fade'i kaldır (build sırasında setState olmasın).
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _typeAtEnd = atEnd);
              });
            }
          }
          return false;
        },
        child: ShaderMask(
          // Son öğe silik görünsün → daha fazla seçenek olduğunu ima eder.
          // Sona kaydırılınca silikleştirme kalkar.
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Colors.white,
              _typeAtEnd ? Colors.white : Colors.transparent,
            ],
            stops: const [0.0, 0.82, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: ListView.separated(
            controller: _typeScroll,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: _SearchType.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = _SearchType.values[i];
              final active = t == _type;
              return GestureDetector(
                key: _typeKeys[t],
                onTap: () => _changeType(t),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        t.icon,
                        size: 14,
                        color: active ? Colors.white : AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Tip değişti: seçili filtreler ve özellikler tipe özel olduğu için
  /// sıfırlanır, listeler yeniden çekilir ve arama tekrar çalıştırılır.
  void _changeType(_SearchType t) {
    if (t == _type) return;
    HapticFeedback.selectionClick();
    _revealType(t);
    setState(() {
      _type = t;
      _placeFilters.clear();
      _foodFilters.clear();
      _allFilters = const [];
      _placeOzellikler.clear();
      _foodOzellikler.clear();
      _allOzellikler = const [];
      _placeItems = const [];
      _foodItems = const [];
      _foodTerm = '';
      // Yemek sekmesi olmayan tipe geçilirken Mekanlar sekmesine dön.
      if (!t.yemekVar && _tab.index != 0) _tab.index = 0;
    });
    final term = _query.trim();
    if (term.length >= 2) {
      _runMekan(term);
      if (t.yemekVar && _tab.index == 1) _runFood(term);
    }
  }

  /// Segment tarzı sekme çubuğu (kaymalı TabBarView ile senkron).
  Widget _searchTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(9),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.ink,
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Mekanlar'),
          Tab(text: 'Yemekler'),
        ],
      ),
    );
  }

  Widget _searchSpinner() => const Center(
    child: SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.primary,
      ),
    ),
  );

  Widget _emptyResults() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 44, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            '"${_query.trim()}" için sonuç bulunamadı',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );

  Widget _moreSpinner() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
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
  );

  Widget _placesTab() {
    return Column(
      children: [
        _placeToolbar(),
        _filterChips(
          _placeFilters,
          _placeOzellikler,
          _placeBolge,
          () => setState(() => _placeBolge = null),
          () {
            final term = _query.trim();
            if (term.length >= 2) _runMekan(term);
          },
        ),
        Expanded(child: _placesContent()),
      ],
    );
  }

  /// Seçili filtre ve özellikleri ikonsuz badge olarak gösterir; her
  /// badge'deki × ile o filtre/özellik kaldırılır ve [onChanged] çağrılır
  /// (kategori listelemesindeki davranışla aynı).
  Widget _filterChips(
    Set<int> filters,
    Set<int> ozellikler,
    int? bolge,
    VoidCallback clearBolge,
    VoidCallback onChanged,
  ) {
    // Seçili id'leri (bölge + filtre + özellik) ad + kaynak kümesiyle eşle.
    // Bölge çipi id = -1 ile işaretlenir.
    final chips = <({int id, String name, bool ozellik})>[
      if (bolge != null)
        (id: -1, name: _bolgeAdi(bolge) ?? 'Bölge', ozellik: false),
    ];
    for (final f in _allFilters) {
      if (filters.contains(f.id)) {
        chips.add((id: f.id, name: f.name, ozellik: false));
      }
    }
    for (final f in _visibleOzellikler) {
      if (ozellikler.contains(f.id)) {
        chips.add((id: f.id, name: f.name, ozellik: true));
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in chips)
              GestureDetector(
                onTap: () {
                  if (f.id == -1) {
                    clearBolge();
                    onChanged();
                    return;
                  }
                  setState(() {
                    if (f.ozellik) {
                      ozellikler.remove(f.id);
                    } else {
                      filters.remove(f.id);
                    }
                  });
                  onChanged();
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
                        f.name,
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
      ),
    );
  }

  Widget _placeToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _sortSummary(_placeSortsEff, _placeSortOptions),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
          GestureDetector(
            onTap: _openPlaceSort,
            child: _sfBtn(Icons.swap_vert, svg: AppIcons.sort),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openPlaceFilter,
            child: _sfBtn(
              Icons.filter_list,
              svg: AppIcons.filter,
              active:
                  _placeFilters.isNotEmpty ||
                  _placeOzellikler.isNotEmpty ||
                  _placeBolge != null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placesContent() {
    if (_placeLoading) return _searchSpinner();
    final items = _visiblePlaceItems;
    if (items.isEmpty) {
      // Bölge süzmesi sürerken (sonraki sayfalar çekiliyor) boş deme.
      return (_placeBolge != null && (_placeHasMore || _placeMoreLoading))
          ? _searchSpinner()
          : _emptyResults();
    }
    return ListView.separated(
      controller: _placeScroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: items.length + (_placeMoreLoading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i >= items.length) return _moreSpinner();
        final r = items[i];
        // Pro "Listeleme": ekranda görünen mekan sonuçları (yalnız Mekanlar
        // sekmesi; yemek kartları sayılmaz — ISTATISTIK-OLAYLARI-MOBIL.md §1).
        return TrackImpression(
          scope: _searchScope,
          placeId: r.place.id,
          position: i,
          child: _resultTile(r),
        );
      },
    );
  }

  /// Arama sonuçlarının görünme kapsamı. Yeni terim/tip/filtre durumunda
  /// yenilenir (o aramada her mekan bir kez sayılır). `kaynak_id` aranan metin
  /// (≤ 32 karakter); filtre/özellik seçiliyse gönderilmez.
  ImpressionScope _searchScope = ImpressionScope(kaynak: 'arama');
  String _searchScopeKey = '';

  void _renewSearchScope(String term) {
    final filtered =
        _placeFilters.isNotEmpty ||
        _placeOzellikler.isNotEmpty ||
        _placeBolge != null;
    final key = '$term|${_type.slug}|$filtered';
    if (key == _searchScopeKey) return;
    _searchScopeKey = key;
    final id = term.length > 32 ? term.substring(0, 32) : term;
    _searchScope = ImpressionScope(
      kaynak: 'arama',
      kaynakId: filtered ? null : id,
    );
  }

  Widget _foodsTab() {
    // Toolbar (sırala + filtrele) her durumda üstte kalsın; içerik altında.
    return Column(
      children: [
        _foodToolbar(),
        _filterChips(
          _foodFilters,
          _foodOzellikler,
          _foodBolge,
          () => setState(() => _foodBolge = null),
          () {
            final term = _query.trim();
            if (term.length >= 2) _runFood(term);
          },
        ),
        Expanded(child: _foodsContent()),
      ],
    );
  }

  Widget _foodsContent() {
    final term = _query.trim();
    // Bu terim için yemekler henüz yüklenmediyse (sekmeye yeni geçildi) veya
    // yükleniyorsa spinner göster — yanlış "sonuç yok" göstermemek için.
    if (_foodLoading || (_foodTerm != term && term.length >= 2)) {
      return _searchSpinner();
    }
    final groups = _foodGroups;
    if (groups.isEmpty) {
      return (_foodBolge != null && (_foodHasMore || _foodMoreLoading))
          ? _searchSpinner()
          : _emptyResults();
    }
    return ListView.separated(
      controller: _foodScroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: groups.length + (_foodMoreLoading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) =>
          i >= groups.length ? _moreSpinner() : _foodGroupCard(groups[i]),
    );
  }

  // "+N ürün daha" ile açılan işletme kartları (mekan id).
  final Set<int> _expandedFood = {};

  /// İşletme ([_FoodGroup]) kartı: üstte işletme (dokununca işletme detayı),
  /// altta en iyi eşleşen ürün (dokununca ürün modalı). Aynı işletmenin diğer
  /// eşleşen ürünleri "+N ürün daha" ile kartın içinde açılır.
  Widget _foodGroupCard(_FoodGroup g) {
    final p = g.mekan;
    final km = _km(g.best.mesafeM);
    final meta = [
      if (km.isNotEmpty) km,
      if (g.best.ilce.isNotEmpty)
        g.best.ilce
      else if (p.subtitle.isNotEmpty)
        p.subtitle,
    ].join(' · ');
    final expanded = _expandedFood.contains(p.id);
    final others = g.others;
    final more = g.moreCount;
    final img = p.thumb(ThumbSize.square);

    void openMekan() {
      // Arama modalı kapatılmaz: detay üstüne açılır, geri dönünce sonuçlar
      // durur. Odak önce bırakılır (dönüşte klavye kendiliğinden açılmasın).
      dismissKeyboard();
      _commitHistory(_query);
      widget.onOpenDetail?.call(p);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // İşletme satırı → işletme detayı.
          Semantics(
            button: true,
            label: '${p.name} işletmesini aç',
            child: InkWell(
              onTap: openMekan,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: img.isNotEmpty
                            ? NetImage(img)
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const AppSvgIcon(
                                  AppIcons.pin,
                                  size: 11,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    meta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
          // En iyi eşleşen ürün (+ açıldıysa diğerleri) → ürün modalı.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _foodItemRow(g.best, g),
                  if (expanded)
                    for (final o in others) ...[
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 12,
                        endIndent: 12,
                        color: Color(0x14120C63),
                      ),
                      _foodItemRow(o, g),
                    ],
                  if (others.isNotEmpty || more > 0)
                    _moreToggle(g, expanded, others.length, more),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ürün satırı: görsel + ad (aranan kısım vurgulu) + fiyat / beğeni.
  /// Dokununca ürün modalı (menüdeki ürün paneliyle aynı) açılır; modalın
  /// altındaki işletme satırı işletme detayına götürür.
  Widget _foodItemRow(FoodResult f, _FoodGroup g) {
    return Semantics(
      button: true,
      label: '${f.urun} ürününü aç',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          dismissKeyboard();
          _commitHistory(_query);
          final p = g.mekan;
          final km = _km(f.mesafeM);
          showMenuItemSheet(
            context,
            f.toMenuUrun(),
            mekanAdi: p.name,
            mekanAlt: [
              if (f.ilce.isNotEmpty) f.ilce,
              if (km.isNotEmpty) km,
            ].join(' · '),
            onOpenMekan: () => widget.onOpenDetail?.call(p),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: f.gorsel.isNotEmpty
                      ? NetImage(f.gorsel)
                      : const ColoredBox(
                          color: Colors.white,
                          child: Icon(
                            Icons.restaurant_menu,
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
                    _highlighted(f.urun),
                    if (f.begeni > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 12,
                            color: AppColors.heart,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${f.begeni}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (f.fiyat.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  '${f.fiyat} ₺',
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "+N ürün daha" / "Daha az göster" satırı. Sunucu toplam sayıyı
  /// bildiriyor ama ürünleri göndermediyse yalnız sayı yazılır.
  Widget _moreToggle(_FoodGroup g, bool expanded, int shown, int more) {
    final canExpand = shown > 0;
    final label = expanded
        ? 'Daha az göster'
        : '+${shown + more} eşleşen ürün daha';
    return InkWell(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      onTap: canExpand
          ? () {
              HapticFeedback.selectionClick();
              setState(() {
                if (!_expandedFood.remove(g.mekan.id)) {
                  _expandedFood.add(g.mekan.id);
                }
              });
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            if (canExpand)
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  /// Ürün adı; aranan metnin geçtiği kısım kalın + marka renginde.
  Widget _highlighted(String name) {
    const base = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
    );
    final q = _norm(_foodTerm ?? _query);
    final n = _norm(name);
    final i = q.isEmpty ? -1 : n.indexOf(q);
    // _norm yalnız harf dönüşümü yapar, uzunluk değişmez → indeksler geçerli.
    if (i < 0 || n.length != name.length) {
      return Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: name.substring(0, i)),
          TextSpan(
            text: name.substring(i, i + q.length),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          TextSpan(text: name.substring(i + q.length)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String get _foodSortLabel => _sortSummary(_foodSortsEff, _foodSortOptions);

  Widget _foodToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _foodSortLabel,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
          GestureDetector(
            onTap: _openFoodSort,
            child: _sfBtn(Icons.swap_vert, svg: AppIcons.sort),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openFoodFilter,
            child: _sfBtn(
              Icons.filter_list,
              svg: AppIcons.filter,
              active:
                  _foodFilters.isNotEmpty ||
                  _foodOzellikler.isNotEmpty ||
                  _foodBolge != null,
            ),
          ),
        ],
      ),
    );
  }

  /// Sırala/Filtrele butonu — mekan listesi ekranıyla aynı ikonlar (SVG).
  Widget _sfBtn(IconData icon, {bool active = false, String? svg}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: active ? AppColors.primary : AppColors.line),
      ),
      alignment: Alignment.center,
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

  Widget _resultTile(SearchResult r) {
    final p = r.place;
    final loc = [p.sehir, p.ilce].where((s) => s.trim().isNotEmpty).join(' · ');
    // Konum verildiyse mesafe alt yazının başına eklenir.
    final metaText = [
      _km(r.mesafeM),
      loc,
    ].where((s) => s.isNotEmpty).join(' · ');
    return GestureDetector(
      onTap: () {
        // Modal açık kalır (bkz. yemek sonucu) → geri dönünce sonuçlar durur.
        dismissKeyboard(); // bkz. _foodTile: arama alanı odağı hatırlanmasın
        _commitHistory(_query);
        widget.onOpenDetail?.call(
          p.toPlace(subtitle: loc.isNotEmpty ? loc : 'Restoran'),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 56,
                height: 56,
                child: p.thumb(ThumbSize.square).isNotEmpty
                    ? NetImage(p.thumb(ThumbSize.square))
                    : Container(
                        color: AppColors.primarySoft,
                        child: const Icon(
                          Icons.restaurant_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (p.verified) ...[
                        const SizedBox(width: 4),
                        const VerifiedTick(size: 13),
                      ],
                    ],
                  ),
                  if (metaText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            metaText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (r.matchedProducts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Menü: ${r.matchedProducts.take(3).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                  if (r.matchedOzellikler.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Özellik: ${r.matchedOzellikler.take(3).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Ara',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              // Mekan tipi seçici — başlık ile kapat butonu arasında.
              Expanded(child: _typeSelector()),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.ink,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _fieldFocus,
                    // autofocus YOK: odak, modal ekrana tam yerleşince verilir
                    // (bkz. _onRouteAnim). Eskiden autofocus ilk karede,
                    // modal daha ekranın altındayken klavyeyi açıyordu.
                    //
                    // Alan yalnız modal ekranda tam görünür ve en üstteyken
                    // odak alabilir. Detay üstte açıkken, modal açılırken ya da
                    // kapanırken (ekran dışında, görünmez) odak alamaz; aksi
                    // halde görünmeyen bir modalın alanı klavyeyi açıyordu
                    // ("arama sayfası yerine klavye geldi").
                    canRequestFocus: _canFocus(context),
                    textInputAction: TextInputAction.search,
                    onChanged: _onQueryChanged,
                    onSubmitted: _commitHistory,
                    decoration: InputDecoration(
                      hintText: _type.hint,
                      hintStyle: const TextStyle(color: AppColors.muted),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _clear,
                  child: const Icon(
                    Icons.cancel,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, {bool link = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          t,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (link)
          const Text(
            'Tümü',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }

  Widget _historyHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Son Aramalar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        GestureDetector(
          onTap: _clearHistory,
          child: const Text(
            'Temizle',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, IconData icon, {VoidCallback? onRemove}) {
    return GestureDetector(
      onTap: () => _applyTerm(label),
      child: Container(
        padding: EdgeInsets.only(
          left: 13,
          right: onRemove != null ? 8 : 13,
          top: 9,
          bottom: 9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.close,
                  size: 15,
                  color: AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kedyHeader() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Center(child: KedyIcon(size: 18, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kedy Tavsiyeleri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_type.label} için akıllı öneriler',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }

  /// Kedy tavsiyeleri — seçili mekan tipine göre değişir. Karta dokununca
  /// metin Kedy'ye mesaj olarak gönderilir.
  List<(IconData, String)> get _kedyTips => switch (_type) {
    _SearchType.mekan => const [
      (Icons.work_outline, 'Sessiz çalışma kafeleri'),
      (Icons.umbrella, 'Yağmurlu güne uygun'),
      (Icons.favorite_border, 'İlk buluşma için'),
      (Icons.attach_money, 'Bütçe dostu lezzetler'),
    ],
    _SearchType.mesire => const [
      (Icons.outdoor_grill_outlined, 'Mangal yapılabilen alanlar'),
      (Icons.family_restroom, 'Çocuklu aileler için mesire'),
      (Icons.directions_walk, 'Yürüyüş parkuru olan yerler'),
      (Icons.landscape_outlined, 'Manzarası güzel piknik alanı'),
    ],
    _SearchType.otopark => const [
      (Icons.garage_outlined, 'Yakınımdaki kapalı otopark'),
      (Icons.access_time, '7/24 açık otopark'),
      (Icons.attach_money, 'Ucuz otopark seçenekleri'),
      (Icons.layers_outlined, 'Katlı otopark nerede'),
    ],
    _SearchType.plaj => const [
      (Icons.waves, 'Sakin koylar'),
      (Icons.money_off, 'Ücretsiz halk plajları'),
      (Icons.beach_access_outlined, 'Şezlong olan plajlar'),
      (Icons.family_restroom, 'Çocuklu aileler için plaj'),
    ],
  };

  Widget _kedyGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 66,
      ),
      itemCount: _kedyTips.length,
      itemBuilder: (_, i) {
        final tip = _kedyTips[i];
        return GestureDetector(
          onTap: () => showKedyChat(context, initialMessage: tip.$2),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(tip.$1, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _categoryRow() {
    // Ana sayfayla aynı kaynak: /kategoriler.
    if (_categories.isEmpty) return const SizedBox(height: 86);
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = _categories[i];
          return GestureDetector(
            onTap: () => _openCategory(c),
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: CategoryIcon(
                        icon: c.icon,
                        id: c.id,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Yemek araması: bir işletme + o işletmenin eşleşen ürünleri.
class _FoodGroup {
  _FoodGroup(FoodResult first) : mekan = first.mekan, best = first;

  final Place mekan;

  /// Ada göre en iyi eşleşen ürün (kartta gösterilen).
  FoodResult best;
  double _bestScore = double.negativeInfinity;

  final List<FoodResult> _items = [];
  final Set<int> _ids = {};

  /// Sunucunun bildirdiği toplam eşleşen ürün sayısı (gruplu yanıtta).
  int serverCount = 0;

  /// Kart açılınca gösterilecek en fazla diğer ürün sayısı.
  static const int maxOthers = 5;

  void add(FoodResult f, double score) {
    // Aynı ürün (sayfalar arası tekrar) bir kez sayılır.
    if (f.urunId > 0 && !_ids.add(f.urunId)) return;
    _items.add(f);
    if (score > _bestScore) {
      _bestScore = score;
      best = f;
    }
  }

  int get _total => serverCount > _items.length ? serverCount : _items.length;

  /// En iyi ürün dışındaki eşleşen ürünler (en fazla [maxOthers]).
  List<FoodResult> get others => [
    for (final f in _items)
      if (!identical(f, best)) f,
  ].take(maxOthers).toList();

  /// Listede olmayan (gösterilmeyen) ek eşleşen ürün sayısı.
  int get moreCount {
    final n = _total - 1 - others.length;
    return n > 0 ? n : 0;
  }
}
