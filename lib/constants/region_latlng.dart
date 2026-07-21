import 'package:latlong2/latlong.dart';

/// Same coordinates as [kRegionCoordinates] in `regions.dart`, just typed for
/// `latlong2`/`flutter_map` instead of `flutter_naver_map`'s `NLatLng` — used
/// by the web fallback map, which can't use the native Naver SDK.
const Map<String, LatLng> kRegionLatLng = {
  '서울특별시': LatLng(37.5665, 126.9780),
  '부산광역시': LatLng(35.1796, 129.0756),
  '대구광역시': LatLng(35.8714, 128.6014),
  '인천광역시': LatLng(37.4563, 126.7052),
  '광주광역시': LatLng(35.1595, 126.8526),
  '대전광역시': LatLng(36.3504, 127.3845),
  '울산광역시': LatLng(35.5384, 129.3114),
  '세종특별자치시': LatLng(36.4801, 127.2890),
  '경기도': LatLng(37.4138, 127.5183),
  '강원특별자치도': LatLng(37.8228, 128.1555),
  '충청북도': LatLng(36.6357, 127.4917),
  '충청남도': LatLng(36.5184, 126.8000),
  '전북특별자치도': LatLng(35.7175, 127.1530),
  '전라남도': LatLng(34.8161, 126.4629),
  '경상북도': LatLng(36.4919, 128.8889),
  '경상남도': LatLng(35.4606, 128.2132),
  '제주특별자치도': LatLng(33.4996, 126.5312),
};
