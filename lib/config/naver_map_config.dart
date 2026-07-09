import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

/// flutter_naver_map only ships native implementations for Android and iOS.
bool get isNaverMapSupportedPlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);
