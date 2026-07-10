import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/api.dart';
import '../data/home_config.dart';
import '../data/location_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

class MapScreen extends StatefulWidget {
  /// Harita açıldığında önceden seçili olacak kategori id'si (opsiyonel).
  final int? initialCategoryId;
  const MapScreen({super.key, this.initialCategoryId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  int _activeCat = 0; // 0 = Tümü, 1.. = _cats[i-1]
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

  Future<void> _init() async {
    final loc = await LocationService.resolve();
    _loc = loc;
    if (loc.real) {
      _center = LatLng(loc.lat, loc.lng);
      if (mounted) setState(() => _myLocation = true);
      _goToUser(); // harita hazırsa konuma git
    }
    // Kategoriler (ana sayfayla aynı: mekanı olanlar, en çok mekana göre).
    try {
      final all = await HomeRepository.instance.kategoriler();
      _cats = all.where((c) => c.mekanSayisi > 0).toList()
        ..sort((a, b) => b.mekanSayisi.compareTo(a.mekanSayisi));
    } catch (_) {
      _cats = const [];
    }
    // Kategori sayfasından gelindiyse o kategoriyi seçili yap.
    final wantId = widget.initialCategoryId;
    if (wantId != null) {
      final idx = _cats.indexWhere((c) => c.id == wantId);
      if (idx != -1) _activeCat = idx + 1; // 0 = Tümü
    }
    await _loadPlaces();
    _updateLabel();
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
    final places =
        await HomeRepository.instance.harita(kategori: _activeCategoryId);
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

  /// Mekanın kategori ikonunu bulur (kategori_ids içinde tanımlı ilk ikon).
  IconData _iconForPlace(ApiPlace p) {
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
                              fontSize: 13, fontWeight: FontWeight.w700)),
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

  Widget _categoryPills() {
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
            return CategoryPill(
              icon: icon,
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
              child: p.image.isNotEmpty
                  ? NetImage(p.image)
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
                            fontSize: 15, fontWeight: FontWeight.w800)),
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
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DetailScreen())),
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
                                    fontWeight: FontWeight.w700,
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
