import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/region_latlng.dart';
import '../theme/toss_colors.dart';

const _minZoom = 5.0;
const _maxZoom = 12.0;

/// Real interactive map (OpenStreetMap via `flutter_map`) shown on web, where
/// the native Naver Maps SDK used by [main_screen.dart] isn't available.
/// Native platforms are untouched — this widget is web-only.
class WebRegionMap extends StatefulWidget {
  const WebRegionMap({
    super.key,
    required this.regionColors,
    required this.regionLabels,
    required this.onRegionTap,
  });

  /// Fill color per region shown on the map. Regions not present here don't
  /// get a marker at all (matches the native map only pinning 지역/관심지역).
  final Map<String, Color> regionColors;

  /// Label text (e.g. "서울특별시 · 49건") shown on each region's marker.
  final Map<String, String> regionLabels;

  final ValueChanged<String> onRegionTap;

  @override
  State<WebRegionMap> createState() => _WebRegionMapState();
}

class _WebRegionMapState extends State<WebRegionMap> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final targetZoom = (camera.zoom + delta).clamp(_minZoom, _maxZoom);
    _mapController.move(camera.center, targetZoom);
  }

  @override
  Widget build(BuildContext context) {
    final markers = [
      for (final entry in widget.regionColors.entries)
        if (kRegionLatLng[entry.key] case final point?)
          Marker(
            point: point,
            width: 86,
            height: 36,
            child: _RegionMarker(
              label: widget.regionLabels[entry.key] ?? entry.key,
              color: entry.value,
              onTap: () => widget.onRegionTap(entry.key),
            ),
          ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(36.5, 127.8),
              initialZoom: 6.5,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              // 트랙패드 두 손가락 제스처가 회전으로 인식돼서 지구본을 돌리는
              // 것처럼 보이는 문제가 있어, 회전만 빼고 나머지 제스처는 그대로 둔다.
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.aicpp.aicpp',
              ),
              MarkerLayer(markers: markers),
              // OpenStreetMap 이용 정책상 출처 표기는 지워도 안 되지만, 눈에 덜
              // 띄게 최소한의 크기로만 둔다.
              const SimpleAttributionWidget(
                source: Text('© OpenStreetMap', style: TextStyle(fontSize: 9)),
              ),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _ZoomControl(
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onZoomIn,
            icon: const Icon(Icons.add, size: 20),
            color: TossColors.textPrimary,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
          ),
          const Divider(height: 1),
          IconButton(
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove, size: 20),
            color: TossColors.textPrimary,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _RegionMarker extends StatelessWidget {
  const _RegionMarker({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // "서울특별시 · 49건" 형태의 라벨을 지역명/건수 두 줄로 나눠서, 좁은
    // 마커 안에서도 둘 다 뚜렷하게 보이게 한다.
    final parts = label.split(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              parts.first,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            if (parts.length > 1)
              Text(
                parts[1],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
