import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'detail_screen.dart';

/// Rotayı uygulama içi haritada gösterir (rota-app-ici-harita.md):
/// sıralı marker'lar + yol çizgisi (encoded polyline varsa onu, yoksa düz çizgi)
/// + markera dokununca mekan detayı.
Future<void> openRouteMap(BuildContext context, GeziRota rota) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => RouteMapScreen(rota: rota)),
  );
}

class RouteMapScreen extends StatefulWidget {
  final GeziRota rota;
  const RouteMapScreen({super.key, required this.rota});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _controller;

  List<RotaNokta> get _noktalar => widget.rota.koordinatlar;

  Set<Marker> _buildMarkers() {
    return {
      for (final n in _noktalar)
        Marker(
          markerId: MarkerId('durak_${n.durakId}_${n.postId}'),
          position: LatLng(n.lat!, n.lng!),
          infoWindow: InfoWindow(
            title: n.name.isEmpty ? '${n.sira}. Durak' : '${n.sira}. ${n.name}',
            snippet: n.postId > 0 ? 'Detayı aç' : null,
            onTap: n.postId > 0 ? () => _openMekan(n) : null,
          ),
        ),
    };
  }

  Set<Polyline> _buildPolylines() {
    // Yol-takipli polyline varsa onu çöz; yoksa noktaları düz çizgiyle bağla.
    final enc = widget.rota.polyline;
    final points = enc.isNotEmpty
        ? _decodePolyline(enc)
        : [for (final n in _noktalar) LatLng(n.lat!, n.lng!)];
    if (points.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('rota'),
        color: AppColors.primary,
        width: 4,
        points: points,
      ),
    };
  }

  void _openMekan(RotaNokta n) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          place: Place(
            id: n.postId,
            name: n.name,
            category: '',
            subtitle: '',
            rating: 0,
            distance: '',
            price: '',
            image: '',
            lat: n.lat!,
            lng: n.lng!,
          ),
        ),
      ),
    );
  }

  /// Tüm noktaları (varsa polyline dahil) ekrana sığdır.
  Future<void> _fitBounds() async {
    final c = _controller;
    if (c == null) return;
    final pts = <LatLng>[
      for (final n in _noktalar) LatLng(n.lat!, n.lng!),
      if (widget.rota.polyline.isNotEmpty) ..._decodePolyline(widget.rota.polyline),
    ];
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      await c.animateCamera(
          CameraUpdate.newLatLngZoom(pts.first, 15));
      return;
    }
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  @override
  Widget build(BuildContext context) {
    final first = _noktalar.first;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(first.lat!, first.lng!),
              zoom: 13,
            ),
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 6),
            onMapCreated: (c) {
              _controller = c;
              _fitBounds();
            },
          ),
          _topBar(),
          if (widget.rota.toplamMesafeM != null ||
              widget.rota.toplamSureSn != null)
            _ozetChip(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _circleBtn(Icons.chevron_left, () => Navigator.pop(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 44,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.search,
                  ),
                  child: Text(
                    widget.rota.baslik.isEmpty
                        ? 'Rota Haritası'
                        : widget.rota.baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.search,
        ),
        child: Icon(icon, color: AppColors.ink),
      ),
    );
  }

  Widget _ozetChip() {
    final parts = <String>[];
    final m = widget.rota.toplamMesafeM;
    final s = widget.rota.toplamSureSn;
    if (m != null) {
      parts.add(m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '$m m');
    }
    if (s != null) {
      final dk = (s / 60).round();
      parts.add(dk >= 60 ? '${dk ~/ 60} sa ${dk % 60} dk' : '$dk dk');
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: AppShadows.listTile,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(parts.join('  ·  '),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google encoded polyline → LatLng listesi (bağımsız decoder; ek paket yok).
List<LatLng> _decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0;
  final len = encoded.length;
  int lat = 0, lng = 0;
  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
