import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../constants/regions.dart';
import '../models/user_profile.dart';

class ProfileApiException implements Exception {
  ProfileApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileApiService {
  ProfileApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 저장된 프로필을 불러온다. 아직 프로필을 완성하지 않은 계정(가입 직후)이면
  /// 백엔드가 404를 돌려주는데, 이 경우 예외 대신 null을 반환해서 호출부가
  /// "프로필 설정 화면으로 보내야 함"을 자연스럽게 처리할 수 있게 한다.
  Future<UserProfile?> fetchProfile(String accessToken, {required String email}) async {
    http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$policyApiBaseUrl/api/v1/profile'), headers: _headers(accessToken))
          // Render 무료 플랜 콜드스타트(최대 50초)를 감안한 여유 있는 타임아웃.
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ProfileApiException('서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.');
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ProfileApiException(_extractErrorDetail(response.body) ?? '프로필을 불러오지 못했어요.');
    }

    final regions = await getInterestedRegions(accessToken);
    return _fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      accessToken,
      email: email,
      interestedRegions: regions,
    );
  }

  /// [profile]의 핵심 필드를 저장한다. 아직 프로필이 없는 계정(가입 직후)이면
  /// PATCH가 404를 돌려주므로, 그 경우에만 생성(POST)으로 다시 시도한다.
  Future<UserProfile> saveProfile(String accessToken, UserProfile profile) async {
    final body = jsonEncode(_toJson(profile));
    http.Response response;
    try {
      response = await _client
          .patch(
            Uri.parse('$policyApiBaseUrl/api/v1/profile'),
            headers: _headers(accessToken),
            body: body,
          )
          // Render 무료 플랜 콜드스타트(최대 50초)를 감안한 여유 있는 타임아웃.
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 404) {
        response = await _client
            .post(
              Uri.parse('$policyApiBaseUrl/api/v1/profile'),
              headers: _headers(accessToken),
              body: body,
            )
            // Render 무료 플랜 콜드스타트(최대 50초)를 감안한 여유 있는 타임아웃.
          .timeout(const Duration(seconds: 60));
      }
    } catch (_) {
      throw ProfileApiException('서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ProfileApiException(_extractErrorDetail(response.body) ?? '프로필을 저장하지 못했어요.');
    }
    return _fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      accessToken,
      email: profile.email,
      interestedRegions: profile.interestedRegions,
    );
  }

  Map<String, String> _headers(String accessToken) => {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      };

  Map<String, dynamic> _toJson(UserProfile profile) => {
        'name': profile.name,
        'birth_date': profile.birthDate == null ? null : _formatDate(profile.birthDate!),
        'gender_code': profile.gender,
        'residence_region_code': kRegionCodeByName[profile.region] ?? profile.region,
        'school_name': profile.school.isEmpty ? null : profile.school,
        'gpa': profile.gpa > 0 ? profile.gpa : null,
        'education_status_code': profile.enrollmentStatus,
        'military_service_status_code': profile.militaryServiceStatus,
        'household_member_count': profile.householdSize,
        'annual_income_amount':
            profile.monthlyIncome == null ? null : profile.monthlyIncome! * 10000 * 12,
        'profile_completed': true,
      };

  UserProfile _fromJson(
    Map<String, dynamic> json,
    String accessToken, {
    required String email,
    List<String> interestedRegions = const [],
  }) {
    final birthDateStr = json['birth_date'] as String?;
    final regionCode = json['residence_region_code'] as String?;
    return UserProfile(
      name: json['name'] as String? ?? '',
      email: email,
      birthDate: birthDateStr == null ? null : DateTime.parse(birthDateStr),
      gender: json['gender_code'] as String? ?? '',
      school: json['school_name'] as String? ?? '',
      gpa: _parseDecimal(json['gpa']),
      enrollmentStatus: json['education_status_code'] as String? ?? '',
      region: regionCode == null ? '' : (kRegionNameByCode[regionCode] ?? regionCode),
      interestedRegions: interestedRegions,
      householdSize: (json['household_member_count'] as num?)?.toInt(),
      monthlyIncome: (json['annual_income_amount'] as num?) == null
          ? null
          : ((json['annual_income_amount'] as num).toInt() / 10000 / 12).round(),
      militaryServiceStatus: json['military_service_status_code'] as String?,
      accessToken: accessToken,
    );
  }

  /// 관심지역 목록을 불러온다. 실패하면(예: 아직 프로필이 없음) 빈 목록을
  /// 반환해서 호출부가 별도 처리 없이 이어갈 수 있게 한다.
  Future<List<String>> getInterestedRegions(String accessToken) async {
    http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('$policyApiBaseUrl/api/v1/profile/interest-regions'),
            headers: _headers(accessToken),
          )
          // Render 무료 플랜 콜드스타트(최대 50초)를 감안한 여유 있는 타임아웃.
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      return const [];
    }
    if (response.statusCode != 200) return const [];
    final codes = (jsonDecode(response.body)['region_codes'] as List).cast<String>();
    return codes.map((code) => kRegionNameByCode[code] ?? code).toList();
  }

  /// 관심지역 전체 목록을 통째로 교체한다(추가/삭제 구분 없이 최신 선택으로 덮어씀).
  /// 실패해도 화면은 로컬 상태로 계속 동작해야 하므로, 호출부가 조용히 무시할
  /// 수 있게 예외를 던지되 UI를 막지는 않는다.
  Future<List<String>> saveInterestedRegions(String accessToken, List<String> regions) async {
    final codes = regions.map((name) => kRegionCodeByName[name] ?? name).toList();
    http.Response response;
    try {
      response = await _client
          .patch(
            Uri.parse('$policyApiBaseUrl/api/v1/profile/interest-regions'),
            headers: _headers(accessToken),
            body: jsonEncode({'region_codes': codes}),
          )
          // Render 무료 플랜 콜드스타트(최대 50초)를 감안한 여유 있는 타임아웃.
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ProfileApiException('서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.');
    }

    if (response.statusCode != 200) {
      throw ProfileApiException(_extractErrorDetail(response.body) ?? '관심지역을 저장하지 못했어요.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final resultCodes = (decoded['region_codes'] as List).cast<String>();
    return resultCodes.map((code) => kRegionNameByCode[code] ?? code).toList();
  }

  /// 백엔드가 `Decimal` 필드(gpa 등)를 JSON 숫자가 아니라 문자열로 직렬화해서
  /// 보내므로("4.00"), 숫자/문자열 둘 다 안전하게 처리한다.
  double _parseDecimal(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String? _extractErrorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      // Not JSON — fall through to the generic message.
    }
    return null;
  }
}
