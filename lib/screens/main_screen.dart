import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../config/naver_map_config.dart';
import '../constants/regions.dart';
import '../models/user_profile.dart';
import '../services/policy_api_service.dart';
import '../theme/toss_colors.dart';
import '../widgets/policy_list_sheet.dart';
import '../widgets/toss_button.dart';
import '../widgets/toss_chip_selector.dart';
import '../widgets/web_region_map.dart';

const _homeRegionColor = TossColors.primary;
const _interestedRegionColor = Color(0xFFFF8B3D);

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.profile,
    this.onInterestedRegionsChanged,
    this.onProfileUpdated,
    this.policyApiService,
  });

  final UserProfile profile;
  final ValueChanged<List<String>>? onInterestedRegionsChanged;
  final ValueChanged<UserProfile>? onProfileUpdated;
  final PolicyApiService? policyApiService;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final _policyApi = widget.policyApiService ?? PolicyApiService();
  NaverMapController? _mapController;
  late Set<String> _interestedRegions =
      widget.profile.interestedRegions.toSet();
  final Map<String, int> _policyCounts = {};

  UserProfile get profile => widget.profile;

  Set<String> get _allRegions => {profile.region, ..._interestedRegions};

  @override
  void initState() {
    super.initState();
    // 네이티브는 NaverMap의 onMapReady(_onMapReady)에서 로딩을 시작하지만,
    // WebRegionMap엔 그런 "지도 준비 완료" 콜백이 없어서 여기서 직접 불러야
    // 웹에서도 지역 라벨에 건수가 뜬다.
    if (kIsWeb) unawaited(_loadPolicyCounts());
  }

  Future<void> _loadPolicyCounts() async {
    final regions = _allRegions;
    final entries = await Future.wait(regions.map((region) async {
      try {
        // totalCount from the API includes closed/not-yet-open policies, so
        // fetch enough pages to count only ones open as of today.
        final result = await _policyApi.searchAllPages(region: region, size: 50);
        final openCount = result.items.where((item) => item.isCurrentlyOpen).length;
        return MapEntry(region, openCount);
      } on PolicyApiException {
        return MapEntry(region, -1);
      }
    }));
    if (!mounted) return;
    setState(() => _policyCounts
      ..clear()
      ..addEntries(entries));
    await _refreshMarkers();
  }

  String _captionFor(String region) {
    final count = _policyCounts[region];
    if (count == null) return region;
    if (count < 0) return '$region (조회 실패)';
    return '$region · $count건';
  }

  /// Only used by [WebRegionMap] (web has no Naver SDK) — mirrors the same
  /// 지역/관심지역 color split the native markers use below.
  Map<String, Color> get _webRegionColors => {
        for (final region in _allRegions)
          region: region == profile.region ? _homeRegionColor : _interestedRegionColor,
      };

  Map<String, String> get _webRegionLabels =>
      {for (final region in _allRegions) region: _captionFor(region)};

  Set<NMarker> _buildMarkers() {
    return {
      for (final region in _allRegions)
        NMarker(
          id: region == profile.region ? 'home_$region' : 'interest_$region',
          position: kRegionCoordinates[region]!,
          iconTintColor: region == profile.region ? _homeRegionColor : _interestedRegionColor,
          caption: NOverlayCaption(text: _captionFor(region)),
        )..setOnTapListener((_) => _openPolicyListSheet(region)),
    };
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    await controller.addOverlayAll(_buildMarkers());
    setState(() => _mapController = controller);
    unawaited(_loadPolicyCounts());
  }

  Future<void> _refreshMarkers() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.clearOverlays(type: NOverlayType.marker);
    await controller.addOverlayAll(_buildMarkers());
  }

  void _openPolicyListSheet(String region) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PolicyListSheet(
        region: region,
        profile: profile,
        onProfileUpdated: (updated) => widget.onProfileUpdated?.call(updated),
        policyApiService: _policyApi,
      ),
    );
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
                    label: '관심지역 (최대 2개)',
                    options: kRegions,
                    selected: {...updated, profile.region},
                    disabled: {
                      profile.region,
                      // 너무 많은 관심지역을 고르면 지도/리포트에 정보가 한꺼번에
                      // 몰려 보여서 2개로 제한한다 — 다 채웠으면 나머지는 잠근다.
                      if (updated.length >= 2)
                        ...kRegions.where((r) => !updated.contains(r)),
                    },
                    multiSelect: true,
                    onToggle: (region) => setSheetState(() {
                      if (updated.contains(region)) {
                        updated.remove(region);
                      } else if (updated.length < 2) {
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
    unawaited(_loadPolicyCounts());
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
              if (kIsWeb || (naverMapClientId.isNotEmpty && isNaverMapSupportedPlatform))
                const _MapLegend(),
              if (kIsWeb || (naverMapClientId.isNotEmpty && isNaverMapSupportedPlatform))
                const SizedBox(height: 12),
              Expanded(
                // 네이버 지도 SDK는 웹을 지원하지 않아서, 웹에서만 실제 인터랙티브
                // 지도(OpenStreetMap 기반 WebRegionMap)로 대체한다. 네이티브
                // (iOS/Android)는 아래 분기 그대로 실제 네이버 지도를 쓴다.
                child: kIsWeb
                    ? WebRegionMap(
                        regionColors: _webRegionColors,
                        regionLabels: _webRegionLabels,
                        onRegionTap: _openPolicyListSheet,
                      )
                    : (naverMapClientId.isEmpty || !isNaverMapSupportedPlatform
                        ? _NaverMapPlaceholder(
                            homeRegion: profile.region,
                            interestedRegions: _interestedRegions.toList(),
                            unsupportedPlatform: !isNaverMapSupportedPlatform,
                            onRegionTap: _openPolicyListSheet,
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
                                    activeLayerGroups: [],
                                    lightness: 0.7,
                                  ),
                                  onMapReady: _onMapReady,
                                ),
                                Positioned(
                                  right: 12,
                                  top: 12,
                                  child: NaverMapZoomControlWidget(
                                    mapController: _mapController,
                                  ),
                                ),
                              ],
                            ),
                          )),
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
        _LegendItem(color: _homeRegionColor, label: '내 지역'),
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
    required this.homeRegion,
    required this.interestedRegions,
    required this.onRegionTap,
    this.unsupportedPlatform = false,
  });

  final String homeRegion;
  final List<String> interestedRegions;
  final ValueChanged<String> onRegionTap;
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
                ? '네이버 지도는 Android/iOS에서만 지원돼요\n아래 지역을 눌러 정책을 확인해보세요'
                : 'Naver Cloud Platform Client ID를 등록하면\n이 자리에 실제 지도가 표시됩니다',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: TossColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _RegionChip(
                label: homeRegion,
                color: _homeRegionColor,
                onTap: () => onRegionTap(homeRegion),
              ),
              for (final region in interestedRegions)
                _RegionChip(
                  label: region,
                  color: _interestedRegionColor,
                  onTap: () => onRegionTap(region),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: Icon(Icons.circle, size: 10, color: color),
      backgroundColor: Colors.white,
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}
