import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/toss_colors.dart';

/// Fractional (0~1) center position of each region's lily pad within the
/// available canvas — a loose, hand-placed approximation of Korea's shape
/// (not real geographic projection), spaced out enough that 17 differently
/// sized bubbles don't overlap.
const _regionPositions = <String, Offset>{
  '인천광역시': Offset(0.16, 0.22),
  '서울특별시': Offset(0.36, 0.15),
  '경기도': Offset(0.34, 0.32),
  '강원특별자치도': Offset(0.66, 0.14),
  '충청북도': Offset(0.50, 0.34),
  '세종특별자치시': Offset(0.40, 0.46),
  '충청남도': Offset(0.24, 0.44),
  '대전광역시': Offset(0.42, 0.56),
  '경상북도': Offset(0.72, 0.38),
  '대구광역시': Offset(0.62, 0.50),
  '전북특별자치도': Offset(0.26, 0.60),
  '경상남도': Offset(0.58, 0.66),
  '부산광역시': Offset(0.72, 0.70),
  '울산광역시': Offset(0.83, 0.56),
  '광주광역시': Offset(0.18, 0.70),
  '전라남도': Offset(0.32, 0.78),
  '제주특별자치도': Offset(0.26, 0.94),
};

/// Decorative background ripples — purely cosmetic, no data behind them.
const _ripples = <Offset>[
  Offset(0.22, 0.08),
  Offset(0.82, 0.18),
  Offset(0.86, 0.46),
  Offset(0.10, 0.58),
  Offset(0.80, 0.82),
];

const _minPadDiameter = 64.0;
const _maxPadDiameter = 116.0;

/// Pad colors by tier — also shown in [MainScreen]'s legend (`main_screen.dart`),
/// so keep this the single source of truth for both.
const kWebMapHomeColor = TossColors.primary;
const kWebMapInterestedColor = Color(0xFF74C69D);
const kWebMapOtherColor = Color(0xFFB7E4C7);

/// Stylized "연잎(lily pad) 지도" shown on web, where the native Naver Maps
/// SDK used by [main_screen.dart] isn't available. Not a real map (no real
/// geography/zoom) — every region is shown at once as a pad sized by policy
/// count, since that reads more clearly as a small illustration than as a
/// sparse, mostly-empty real map would. Native platforms are untouched.
class WebRegionMap extends StatelessWidget {
  const WebRegionMap({
    super.key,
    required this.regionCounts,
    required this.homeRegion,
    required this.interestedRegions,
    required this.onRegionTap,
  });

  /// Policy count per region; null while still loading, negative if that
  /// region's fetch failed (mirrors [MainScreen._captionFor]'s convention).
  final Map<String, int?> regionCounts;
  final String homeRegion;
  final Set<String> interestedRegions;
  final ValueChanged<String> onRegionTap;

  @override
  Widget build(BuildContext context) {
    final maxCount = regionCounts.values
        .whereType<int>()
        .where((c) => c > 0)
        .fold(0, math.max);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFCFEEF6), Color(0xFFA9D9E6)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                for (final offset in _ripples) _Ripple(offset: offset, w: w, h: h),
                for (final entry in _regionPositions.entries)
                  _LilyPad(
                    region: entry.key,
                    center: entry.value,
                    canvasWidth: w,
                    canvasHeight: h,
                    count: regionCounts[entry.key],
                    maxCount: maxCount,
                    isHome: entry.key == homeRegion,
                    isInterested: interestedRegions.contains(entry.key),
                    onTap: () => onRegionTap(entry.key),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  const _Ripple({required this.offset, required this.w, required this.h});

  final Offset offset;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: w * offset.dx - 40,
      top: h * offset.dy - 14,
      child: IgnorePointer(
        child: Container(
          width: 80,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

double _diameterFor(int? count, int maxCount) {
  if (count == null || count <= 0 || maxCount <= 0) return _minPadDiameter;
  final t = math.sqrt(count / maxCount).clamp(0.0, 1.0);
  return _minPadDiameter + (_maxPadDiameter - _minPadDiameter) * t;
}

class _LilyPad extends StatelessWidget {
  const _LilyPad({
    required this.region,
    required this.center,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.count,
    required this.maxCount,
    required this.isHome,
    required this.isInterested,
    required this.onTap,
  });

  final String region;
  final Offset center;
  final double canvasWidth;
  final double canvasHeight;
  final int? count;
  final int maxCount;
  final bool isHome;
  final bool isInterested;
  final VoidCallback onTap;

  Color get _padColor {
    if (isHome) return kWebMapHomeColor;
    if (isInterested) return kWebMapInterestedColor;
    return kWebMapOtherColor;
  }

  String get _countLabel {
    if (count == null) return '';
    if (count! < 0) return '조회 실패';
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    final diameter = _diameterFor(count, maxCount);
    final left = canvasWidth * center.dx - diameter / 2;
    final top = canvasHeight * center.dy - diameter / 2;

    return Positioned(
      left: left,
      top: top,
      width: diameter,
      height: diameter,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 연잎 잎자루(작은 사선) — 장식용.
            Positioned(
              right: diameter * 0.06,
              top: diameter * 0.02,
              child: Transform.rotate(
                angle: -0.6,
                child: Container(
                  width: 2.5,
                  height: diameter * 0.22,
                  color: _padColor.withValues(alpha: 0.9),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _padColor,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    region.replaceFirst(
                        RegExp(r'(특별자치시|특별자치도|광역시|특별시|도)$'), ''),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isHome ? 14 : 12,
                      fontWeight: isHome ? FontWeight.w800 : FontWeight.w600,
                      color: TossColors.textPrimary,
                    ),
                  ),
                  if (_countLabel.isNotEmpty)
                    Text(
                      _countLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: TossColors.textPrimary.withValues(alpha: 0.65),
                      ),
                    ),
                ],
              ),
            ),
            if (isHome)
              Positioned(
                top: -diameter * 0.42,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/icon/assistant_icon.png',
                    width: diameter * 0.62,
                    height: diameter * 0.62,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
