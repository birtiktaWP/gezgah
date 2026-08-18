import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
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
          _bottomBar(),
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

  /// Alt bar — durak sayısı + (varsa) mesafe/süre. Dokununca durak listesi
  /// bottom sheet'i açılır.
  Widget _bottomBar() {
    final parts = <String>['${_noktalar.length} durak'];
    final m = widget.rota.toplamMesafeM;
    final s = widget.rota.toplamSureSn;
    if (m != null) {
      parts.add(m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '$m m');
    }
    if (s != null) {
      final dk = (s / 60).round();
      parts.add(dk >= 60 ? '${dk ~/ 60} sa ${dk % 60} dk' : '$dk dk');
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: GestureDetector(
              onTap: _openStopList,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_up,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Haritadaki durakların listesi (görsel + ad). En çok 5 görünür, kalan
  /// görünmez kaydırma. Bir öğeye dokununca harita o koordinata odaklanır.
  void _openStopList() {
    final items = _stopItems();
    if (items.isEmpty) return;
    const rowH = 72.0;
    final visible = items.length > 5 ? 5 : items.length;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Duraklar (${items.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            SizedBox(
              height: visible * rowH,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, indent: 76, color: AppColors.line),
                itemBuilder: (_, i) => _stopListRow(items[i], rowH),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _stopListRow(_MapStop it, double height) {
    return InkWell(
      onTap: () => _focusStop(it),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: Text('${it.sira}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: it.image.isNotEmpty
                      ? NetImage(it.image)
                      : Container(
                          color: AppColors.primarySoft,
                          child: const Icon(Icons.place,
                              color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(it.name.isEmpty ? 'Durak' : it.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.my_location,
                  size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  /// Durak listesi öğelerini (koordinatlı) üretir; görsel için önce durak
  /// fotoğrafı, sonra mekan görseli kullanılır.
  List<_MapStop> _stopItems() {
    final list = <_MapStop>[];
    if (widget.rota.duraklar.isNotEmpty) {
      for (final d in widget.rota.duraklar) {
        final mk = d.mekan;
        if (mk == null || !mk.hasCoord) continue;
        final img = d.gorseller.isNotEmpty ? d.gorseller.first.url : mk.image;
        list.add(_MapStop(
          sira: d.sira,
          durakId: d.durakId,
          postId: mk.id,
          name: mk.name,
          image: img,
          lat: mk.lat!,
          lng: mk.lng!,
        ));
      }
    }
    if (list.isEmpty) {
      for (final n in _noktalar) {
        list.add(_MapStop(
          sira: n.sira,
          durakId: n.durakId,
          postId: n.postId,
          name: n.name,
          image: '',
          lat: n.lat!,
          lng: n.lng!,
        ));
      }
    }
    return list;
  }

  Future<void> _focusStop(_MapStop it) async {
    Navigator.pop(context); // listeyi kapat
    await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(it.lat, it.lng), 16.5));
    // Marker bilgi balonunu aç (id, _buildMarkers ile aynı).
    try {
      await _controller
          ?.showMarkerInfoWindow(MarkerId('durak_${it.durakId}_${it.postId}'));
    } catch (_) {}
  }
}

/// Harita durak listesi öğesi (dahili).
class _MapStop {
  final int sira;
  final int durakId;
  final int postId;
  final String name;
  final String image;
  final double lat;
  final double lng;
  const _MapStop({
    required this.sira,
    required this.durakId,
    required this.postId,
    required this.name,
    required this.image,
    required this.lat,
    required this.lng,
  });
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
