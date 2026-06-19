import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  int _activeCat = 0;
  Place? _selected;
  Set<Marker> _markers = {};

  static const CameraPosition _initial = CameraPosition(
    target: LatLng(40.9875, 29.0270),
    zoom: 14.5,
  );

  // Kadıköy çevresini POI'lerden arındıran sade harita stili
  static const String _mapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]}
]''';

  List<Place> get _filtered {
    if (_activeCat == 0) return MockData.mapPlaces;
    final cat = MockData.mapCategories[_activeCat].label.toLowerCase();
    return MockData.mapPlaces.where((p) => p.tags.contains(cat)).toList();
  }

  @override
  void initState() {
    super.initState();
    _rebuildMarkers();
  }

  Future<void> _rebuildMarkers() async {
    final markers = <Marker>{};
    for (final p in _filtered) {
      final active = identical(p, _selected);
      final icon = await _priceMarker(p.price, active);
      markers.add(Marker(
        markerId: MarkerId(p.name),
        position: LatLng(p.lat, p.lng),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        onTap: () {
          setState(() => _selected = p);
          _rebuildMarkers();
          _controller?.animateCamera(
              CameraUpdate.newLatLng(LatLng(p.lat, p.lng)));
        },
      ));
    }
    if (mounted) setState(() => _markers = markers);
  }

  /// Fiyat etiketli (hap) marker'ı canvas ile çizip bitmap'e dönüştürür.
  Future<BitmapDescriptor> _priceMarker(String price, bool active) async {
    const double ratio = 3; // keskinlik için
    const double fontSize = 13;
    const double padH = 12, padV = 7;

    final tp = TextPainter(
      text: TextSpan(
        text: price,
        style: TextStyle(
          fontSize: fontSize * ratio,
          fontWeight: FontWeight.w800,
          color: active ? Colors.white : AppColors.primary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final w = tp.width + padH * 2 * ratio;
    final h = tp.height + padV * 2 * ratio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(h / 2),
    );

    // gölge
    canvas.drawRRect(
      rrect.shift(Offset(0, 2 * ratio)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // zemin
    canvas.drawRRect(
      rrect,
      Paint()..color = active ? AppColors.primary : Colors.white,
    );
    tp.paint(canvas, Offset(padH * ratio, padV * ratio));

    final img = await recorder
        .endRecording()
        .toImage(w.ceil(), h.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: ratio,
    );
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
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) => _controller = c,
            onTap: (_) {
              if (_selected != null) {
                setState(() => _selected = null);
                _rebuildMarkers();
              }
            },
          ),
          _topBar(),
          _categoryPills(),
          _locateButton(),
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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Konum · ',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  Text('Kadıköy, İstanbul',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryPills() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: MockData.mapCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final c = MockData.mapCategories[i];
            return CategoryPill(
              icon: c.icon,
              label: c.label,
              active: _activeCat == i,
              onTap: () {
                setState(() {
                  _activeCat = i;
                  _selected = null;
                });
                _rebuildMarkers();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _locateButton() {
    return Positioned(
      right: 16,
      bottom: _selected != null ? 200 : 26,
      child: GestureDetector(
        onTap: () => _controller?.animateCamera(
            CameraUpdate.newCameraPosition(_initial)),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: AppShadows.soft,
          ),
          child: const Icon(Icons.my_location, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _bottomCard(Place p) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 26,
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
            SizedBox(width: 120, height: 130, child: NetImage(p.image)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const Icon(Icons.star_rounded,
                            size: 15, color: AppColors.star),
                        const SizedBox(width: 3),
                        Text(p.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${p.category} · ${p.distance}',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p.price,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
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
