import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../config/naver_map_config.dart';
import '../constants/regions.dart';
import '../models/user_profile.dart';
import '../theme/toss_colors.dart';
import '../widgets/toss_button.dart';
import '../widgets/toss_chip_selector.dart';

const _homeRegionColor = TossColors.primary;
const _interestedRegionColor = Color(0xFFFF8B3D);

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.profile,
    this.onInterestedRegionsChanged,
  });

  final UserProfile profile;
  final ValueChanged<List<String>>? onInterestedRegionsChanged;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  NaverMapController? _mapController;
  late Set<String> _interestedRegions =
      widget.profile.interestedRegions.toSet();

  UserProfile get profile => widget.profile;

  Set<NMarker> _buildMarkers() {
    return {
      NMarker(
        id: 'home_${profile.region}',
        position: kRegionCoordinates[profile.region]!,
        iconTintColor: _homeRegionColor,
        caption: NOverlayCaption(text: profile.region),
      ),
      for (final region in _interestedRegions)
        NMarker(
          id: 'interest_$region',
          position: kRegionCoordinates[region]!,
          iconTintColor: _interestedRegionColor,
          caption: NOverlayCaption(text: region),
        ),
    };
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    await controller.addOverlayAll(_buildMarkers());
    setState(() => _mapController = controller);
  }

  Future<void> _refreshMarkers() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.clearOverlays(type: NOverlayType.marker);
    await controller.addOverlayAll(_buildMarkers());
  }

  Future<void> _openRegionPicker() async {
    final updated = Set<String>.from(_interestedRegions);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '관심지역 추가',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TossColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TossChipSelector(
                    label: '관심지역 (복수 선택 가능)',
                    options: kRegions,
                    selected: updated,
                    multiSelect: true,
                    onToggle: (region) => setSheetState(() {
                      if (updated.contains(region)) {
                        updated.remove(region);
                      } else {
                        updated.add(region);
                      }
                    }),
                  ),
                  const SizedBox(height: 24),
                  TossButton(
                    label: '완료',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    setState(() => _interestedRegions = updated);
    widget.onInterestedRegionsChanged?.call(updated.toList());
    await _refreshMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TossColors.background,
        elevation: 0,
        foregroundColor: TossColors.textPrimary,
        title: Text('${profile.name}님, 환영해요'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '관심지역 지도',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: TossColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openRegionPicker,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    color: TossColors.primary,
                    tooltip: '관심지역 추가',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (naverMapClientId.isNotEmpty && isNaverMapSupportedPlatform)
                const _MapLegend(),
              if (naverMapClientId.isNotEmpty && isNaverMapSupportedPlatform)
                const SizedBox(height: 12),
              Expanded(
                child: naverMapClientId.isEmpty || !isNaverMapSupportedPlatform
                    ? _NaverMapPlaceholder(
                        regions: _interestedRegions.toList(),
                        unsupportedPlatform: !isNaverMapSupportedPlatform,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            NaverMap(
                              options: const NaverMapViewOptions(
                                initialCameraPosition: NCameraPosition(
                                  target: NLatLng(36.5, 127.8),
                                  zoom: 6.5,
                                ),
                              ),
                              onMapReady: _onMapReady,
                            ),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: NaverMapZoomControlWidget(
                                mapController: _mapController,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LegendItem(color: _homeRegionColor, label: '지역'),
        SizedBox(width: 16),
        _LegendItem(color: _interestedRegionColor, label: '관심지역'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: TossColors.textSecondary),
        ),
      ],
    );
  }
}

class _NaverMapPlaceholder extends StatelessWidget {
  const _NaverMapPlaceholder({
    required this.regions,
    this.unsupportedPlatform = false,
  });

  final List<String> regions;
  final bool unsupportedPlatform;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TossColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 48, color: TossColors.textSecondary),
          const SizedBox(height: 12),
          const Text(
            '네이버 지도 연동 예정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: TossColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            unsupportedPlatform
                ? '네이버 지도는 Android/iOS에서만 지원돼요\n지금 실행 중인 플랫폼에서는 표시되지 않습니다'
                : 'Naver Cloud Platform Client ID를 등록하면\n이 자리에 실제 지도가 표시됩니다',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: TossColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: regions
                .map((region) => Chip(
                      label: Text(region),
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
