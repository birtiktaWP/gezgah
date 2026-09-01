import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/api.dart';
import '../data/home_config.dart';
import '../data/location_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

class MapScreen extends StatefulWidget {
  /// Harita açıldığında önceden seçili olacak kategori id'si (opsiyonel).
  final int? initialCategoryId;

  /// Harita açıldığında seçili olacak post type (`otopark` | `mesire` | `plaj`).
  /// Verilmezse "Mekan" (restoran) seçili gelir. Tip listesinden açılan liste
  /// ekranından haritaya geçildiğinde aynı tip korunur.
  final String? initialType;

  const MapScreen({super.key, this.initialCategoryId, this.initialType});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// Haritada gösterilecek mekan tipi (KATEGORI_TIP_BAZLI.md).
/// Kategori çipleri ve pinler bu seçime göre değişir.
enum _MapType { mekan, otopark, mesire, plaj }

extension _MapTypeX on _MapType {
  /// API'deki post type slug'ı.
  String get slug => switch (this) {
        _MapType.mekan => 'restoran',
        _MapType.otopark => 'otopark',
        _MapType.mesire => 'mesire',
        _MapType.plaj => 'plaj',
      };

  String get label => switch (this) {
        _MapType.mekan => 'Mekan',
        _MapType.otopark => 'Otopark',
        _MapType.mesire => 'Mesire',
        _MapType.plaj => 'Plaj',
      };

  IconData get icon => switch (this) {
        _MapType.mekan => Icons.restaurant_outlined,
        _MapType.otopark => Icons.local_parking_outlined,
        _MapType.mesire => Icons.park_outlined,
        _MapType.plaj => Icons.beach_access_outlined,
      };
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  int _activeCat = 0; // 0 = Tümü, 1.. = _cats[i-1]
  _MapType _type = _MapType.mekan; // varsayılan: Mekan
  ApiPlace? _selected;
  Set<Marker> _markers = {};

  List<Category> _cats = const [];
  List<ApiPlace> _places = const [];

  ({double lat, double lng, bool real})? _loc;
  bool _myLocation = false; // gerçek konum alındıysa mavi nokta

  // İkon marker cache'i (codePoint + seçili durumuna göre).
  final Map<String, BitmapDescriptor> _iconCache = {};


  static const CameraPosition _initial = CameraPosition(
    target: LatLng(40.9875, 29.0270),
    zoom: 14.5,
  );

  LatLng _center = _initial.target;
  String _locationLabel = 'Konum alınıyor…';
  bool _geocoding = false;

  // Kadıköy çevresini POI'lerden arındıran sade harita stili
  static const String _mapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]}
]''';

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Verilen post type slug'ını tip seçeneğine çevirir (bilinmeyen → Mekan).
  static _MapType _typeFromSlug(String? slug) {
    return switch (slug) {
      'otopark' => _MapType.otopark,
      'mesire' => _MapType.mesire,
      'plaj' => _MapType.plaj,
      _ => _MapType.mekan,
    };
  }

  Future<void> _init() async {
    // Liste ekranından gelen tip (otopark/mesire/plaj) haritada da seçili olsun.
    _type = _typeFromSlug(widget.initialType);
    final loc = await LocationService.resolve();
    _loc = loc;
    if (loc.real) {
      _center = LatLng(loc.lat, loc.lng);
      if (mounted) setState(() => _myLocation = true);
      _goToUser(); // harita hazırsa konuma git
    }
    await _loadCategories();
    // Kategori sayfasından gelindiyse o kategoriyi seçili yap.
    final wantId = widget.initialCategoryId;
    if (wantId != null) {
      var idx = _cats.indexWhere((c) => c.id == wantId);
      // Listede yoksa (alt kategori / mekan sayısı 0), tam listeden bulup öne
      // ekle ki sekme her zaman mevcut ve seçili gelsin.
      if (idx == -1) {
        try {
          final all = await HomeRepository.instance.kategoriler();
          final found = all.where((c) => c.id == wantId).toList();
          if (found.isNotEmpty) {
            _cats = [found.first, ..._cats];
            idx = 0;
          }
        } catch (_) {}
      }
      if (idx != -1) _activeCat = idx + 1; // 0 = Tümü
    }
    await _loadPlaces();
    _updateLabel();
  }

  /// Seçili tipe ait kategori çiplerini yükler.
  ///
  /// Mekan (restoran) tipinde ana sayfayla aynı kaynak kullanılır (öne çıkan
  /// kategoriler; ikonları HomeConfig'te tanımlı). Diğer tiplerde
  /// `GET /kategoriler/tip/{type}` kullanılır — plaj/mesire'de boş döner ve
  /// çip barı hiç gösterilmez (KATEGORI_TIP_BAZLI.md).
  Future<void> _loadCategories() async {
    try {
      if (_type == _MapType.mekan) {
        final all = await HomeRepository.instance.kategoriler();
        // `mekan_sayisi` yalnız bazı uçlarda gelir (öne çıkan kategoriler ucu
        // döndürmez). Sayı bilgisi olan varsa ona göre süz + sırala.
        final withCount = all.where((c) => c.mekanSayisi > 0).toList();
        if (withCount.isNotEmpty) {
          withCount.sort((a, b) => b.mekanSayisi.compareTo(a.mekanSayisi));
          _cats = withCount;
        } else {
          _cats = all;
        }
      } else {
        // Uç zaten `mekan_sayisi` azalan sıralı döner.
        _cats = await HomeRepository.instance.kategorilerTip(_type.slug);
      }
    } catch (_) {
      _cats = const [];
    }
  }

  /// Tip seçimi değişti: kategorileri ve harita pinlerini yenile.
  Future<void> _changeType(_MapType t) async {
    if (t == _type) return;
    setState(() {
      _type = t;
      _activeCat = 0;
      _cats = const [];
      _selected = null;
    });
    await _loadCategories();
    if (!mounted) return;
    setState(() {});
    await _loadPlaces();
  }

  /// Mekan tipi seçim sheet'i (Mekan / Otopark / Mesire / Plaj).
  void _openTypeSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
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
                    borderRadius: BorderRadius.circular(999)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Göster',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              for (final t in _MapType.values)
                Column(
                  children: [
                    ListTile(
                      leading: Icon(t.icon,
                          color: t == _type
                              ? AppColors.primary
                              : AppColors.muted),
                      title: Text(t.label,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t == _type
                                  ? AppColors.primary
                                  : AppColors.ink)),
                      trailing: t == _type
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _changeType(t);
                      },
                    ),
                    if (t != _MapType.values.last)
                      const Divider(
                          height: 1, thickness: 1, color: AppColors.line),
                  ],
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  int? get _activeCategoryId =>
      _activeCat == 0 ? null : _cats[_activeCat - 1].id;

  /// Kullanıcının gerçek konumuna kamerayı taşır (konum + harita hazırsa).
  void _goToUser() {
    final loc = _loc;
    final c = _controller;
    if (loc != null && loc.real && c != null) {
      c.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(loc.lat, loc.lng), zoom: 15),
      ));
    }
  }

  Future<void> _loadPlaces() async {
    // Mekan (restoran) tipinde `type` gönderilmez → sunucu varsayılanı korunur.
    final places = await HomeRepository.instance.harita(
      kategori: _activeCategoryId,
      type: _type == _MapType.mekan ? null : _type.slug,
    );
    if (!mounted) return;
    setState(() {
      _places = places;
      _selected = null;
    });
    _rebuildMarkers();
  }

  Future<void> _rebuildMarkers() async {
    final markers = <Marker>{};
    for (final p in _places) {
      final isSel = identical(p, _selected);
      final icon = await _markerIcon(_iconForPlace(p), isSel);
      markers.add(Marker(
        markerId: MarkerId(p.id.toString()),
        position: LatLng(p.lat!, p.lng!),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: isSel ? 2 : 1,
        onTap: () {
          setState(() => _selected = p);
          _rebuildMarkers();
          _controller?.animateCamera(
              CameraUpdate.newLatLng(LatLng(p.lat!, p.lng!)));
        },
      ));
    }
    if (mounted) setState(() => _markers = markers);
  }

  /// Mekanın harita ikonunu belirler.
  /// 1) API'den gelen işletmeye özel `custom_ikon` doluysa onu,
  /// 2) yoksa kategori ikonunu (kategori_ids içinde tanımlı ilk ikon),
  /// 3) o da yoksa varsayılanı kullanır.
  IconData _iconForPlace(ApiPlace p) {
    final custom = HomeConfig.customIconFor(p.customIcon);
    if (custom != null) return custom;
    for (final id in p.categoryIds) {
      final ic = HomeConfig.categoryIcons[id];
      if (ic != null) return ic;
    }
    return Icons.restaurant;
  }

  Future<BitmapDescriptor> _markerIcon(IconData icon, bool active) async {
    final key = '${icon.codePoint}_$active';
    final cached = _iconCache[key];
    if (cached != null) return cached;
    final desc = await _buildPin(icon, active);
    _iconCache[key] = desc;
    return desc;
  }

  /// Yuvarlak konum işaretçisi — beyaz kenarlı, içinde kategori ikonu.
  Future<BitmapDescriptor> _buildPin(IconData icon, bool active) async {
    const double ratio = 3;
    final double rBase = (active ? 22 : 18) * ratio;
    final double r = rBase * 0.8; // daire %20 küçük
    final double border = 3 * ratio;
    final double size = (r + border) * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    // gölge
    canvas.drawCircle(
      center.translate(0, 1.5 * ratio),
      r + border,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // beyaz kenar
    canvas.drawCircle(center, r + border, Paint()..color = Colors.white);
    // iç daire
    canvas.drawCircle(center, r,
        Paint()..color = active ? AppColors.primary2 : AppColors.primary);

    // kategori ikonu (beyaz) — %10 küçük
    final iconSize = rBase * 1.15 * 0.9;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    );
    tp.layout();
    tp.paint(canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    final img =
        await recorder.endRecording().toImage(size.ceil(), size.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: ratio,
    );
  }

  Future<void> _updateLabel() async {
    if (_geocoding) return;
    _geocoding = true;
    final label = await LocationService.cityDistrict(
        _center.latitude, _center.longitude,
        districtFirst: true);
    _geocoding = false;
    if (!mounted || label == null) return;
    setState(() => _locationLabel = label);
  }

  String _distanceText(ApiPlace p) {
    final loc = _loc;
    if (loc == null || !p.hasCoord) return p.cityDistrict;
    final m =
        LocationService.distanceMeters(loc.lat, loc.lng, p.lat!, p.lng!);
    return LocationService.format(m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initial,
            style: _mapStyle,
            markers: _markers,
            myLocationEnabled: _myLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // Google logosunu sistem çubuğunun üstüne taşı (kaldırılamaz).
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 6),
            onMapCreated: (c) {
              _controller = c;
              _goToUser(); // konum önceden geldiyse ona git
            },
            onCameraMove: (pos) => _center = pos.target,
            onCameraIdle: _updateLabel,
            onTap: (_) {
              if (_selected != null) {
                setState(() => _selected = null);
                _rebuildMarkers();
              }
            },
          ),
          _topBar(),
          _categoryPills(),
          if (_selected != null) _bottomCard(_selected!),
        ],
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: AppShadows.soft,
                ),
                child: const Icon(Icons.chevron_left, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppShadows.soft,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text('Konum · ',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.muted)),
                    Flexible(
                      child: Text(_locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Mekan tipi seçimi (Mekan / Otopark / Mesire / Plaj).
            GestureDetector(
              onTap: _openTypeSheet,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: AppShadows.soft,
                ),
                child: const Center(
                  child: AppSvgIcon(AppIcons.filter,
                      size: 17, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryPills() {
    // Bu tipte kategori ataması yoksa (plaj/mesire) çip barını hiç gösterme.
    if (_cats.isEmpty) return const SizedBox.shrink();
    // 0 = Tümü, sonrakiler _cats.
    final count = _cats.length + 1;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final label = i == 0 ? 'Tümü' : _cats[i - 1].name;
            final icon = i == 0
                ? Icons.explore_outlined
                : HomeConfig.iconFor(_cats[i - 1].id);
            final svg = i == 0 ? null : HomeConfig.svgFor(_cats[i - 1].id);
            return CategoryPill(
              icon: icon,
              svg: svg,
              label: label,
              active: _activeCat == i,
              onTap: () {
                if (_activeCat == i) return;
                setState(() => _activeCat = i);
                _loadPlaces();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _bottomCard(ApiPlace p) {
    final loc = [p.sehir, p.ilce].where((s) => s.trim().isNotEmpty).join(' · ');
    // Android sistem/gezinme çubuğunun üstünde kalsın.
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 26 + safeBottom,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 8)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 130,
              child: p.thumb(ThumbSize.square).isNotEmpty
                  ? heroImage(p.id > 0 ? 'map-${p.id}' : null,
                      p.thumb(ThumbSize.square))
                  : Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.restaurant_outlined,
                          color: AppColors.primary, size: 30),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                              loc.isNotEmpty ? loc : 'Konum',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.muted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_distanceText(p),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DetailScreen(
                                      place: p.toPlace(
                                          subtitle:
                                              loc.isNotEmpty ? loc : 'Konum'),
                                      type: _type == _MapType.mekan
                                          ? null
                                          : _type.slug,
                                      heroTag:
                                          p.id > 0 ? 'map-${p.id}' : null))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Detayı Gör',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                        ),
                      ],
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
}
