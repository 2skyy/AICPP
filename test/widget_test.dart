import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aicpp/main.dart';
import 'package:aicpp/models/policy_item.dart';
import 'package:aicpp/models/user_profile.dart';
import 'package:aicpp/screens/home_shell.dart';
import 'package:aicpp/screens/main_screen.dart';
import 'package:aicpp/screens/policy_detail_screen.dart';
import 'package:aicpp/screens/profile_setup_screen.dart';
import 'package:aicpp/screens/report_screen.dart';
import 'package:aicpp/screens/scrapped_policies_screen.dart';
import 'package:aicpp/services/auth_api_service.dart';
import 'package:aicpp/services/chat_api_service.dart';
import 'package:aicpp/services/news_api_service.dart';
import 'package:aicpp/services/notification_service.dart';
import 'package:aicpp/services/policy_api_service.dart';
import 'package:aicpp/services/profile_api_service.dart';
import 'package:aicpp/widgets/chat_panel.dart';
import 'package:aicpp/widgets/policy_list_sheet.dart';
import 'package:aicpp/widgets/toss_chip_selector.dart';

UserProfile sampleProfile({
  List<String> interestedRegions = const [],
  List<String> interests = const [],
  int? householdSize,
  int? monthlyIncome,
  List<PolicyItem> scrappedPolicies = const [],
}) =>
    UserProfile(
      name: '홍길동',
      email: 'test@example.com',
      birthDate: DateTime(2000, 1, 1),
      gender: '남성',
      school: '한국대학교',
      gpa: 4.0,
      enrollmentStatus: '재학',
      region: '서울특별시',
      interestedRegions: interestedRegions,
      interests: interests,
      householdSize: householdSize,
      monthlyIncome: monthlyIncome,
      scrappedPolicies: scrappedPolicies,
    );

void main() {
  testWidgets('Login screen shows email/password fields and navigates to signup',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);

    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    expect(find.text('이름'), findsOneWidget);
    expect(find.text('비밀번호 확인'), findsOneWidget);
  });

  testWidgets('Logging in navigates to the main screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authMockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'access_token': 'tok', 'user_id': 'user-1', 'email': 'test@example.com'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final profileMockClient = MockClient((request) async {
      if (request.url.path.endsWith('/interest-regions')) {
        return http.Response('{"region_codes": []}', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(
        jsonEncode({
          'name': '홍길동',
          'birth_date': '2000-01-01',
          'gender_code': '남성',
          'residence_region_code': '11',
          'school_name': '한국대학교',
          'gpa': 4.0,
          'education_status_code': '재학',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MyApp(
      authApiService: AuthApiService(client: authMockClient),
      profileApiService: ProfileApiService(client: profileMockClient),
    ));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.pump();

    await tester.ensureVisible(find.text('로그인'));
    await tester.tap(find.text('로그인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('환영해요'), findsOneWidget);
  });

  testWidgets('Signup shows error when passwords do not match',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '홍길동');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'password456');

    await tester.ensureVisible(find.text('가입하기'));
    await tester.tap(find.text('가입하기'));
    await tester.pump();

    expect(find.text('비밀번호가 일치하지 않아요'), findsOneWidget);
  });

  testWidgets(
      'Completing signup and profile setup returns to login, then logging in reaches the main screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authMockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'access_token': 'tok', 'user_id': 'user-1', 'email': 'test@example.com'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    // 실제 백엔드처럼 관심지역 PATCH 결과를 기억해뒀다가 이후 GET에서 그대로
    // 돌려준다 — 재로그인 후에도 방금 저장한 관심지역이 유지되는지 확인하려면
    // mock이 상태 없이 항상 빈 목록만 주면 안 된다.
    var savedRegionCodes = <String>[];
    final profileMockClient = MockClient((request) async {
      if (request.url.path.endsWith('/interest-regions')) {
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          savedRegionCodes = (body['region_codes'] as List).cast<String>();
        }
        return http.Response(jsonEncode({'region_codes': savedRegionCodes}), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(
        jsonEncode({'name': '홍길동'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MyApp(
      authApiService: AuthApiService(client: authMockClient),
      profileApiService: ProfileApiService(client: profileMockClient),
    ));
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    final signupFields = find.byType(TextField);
    await tester.enterText(signupFields.at(0), '홍길동');
    await tester.enterText(signupFields.at(1), 'test@example.com');
    await tester.enterText(signupFields.at(2), 'password123');
    await tester.enterText(signupFields.at(3), 'password123');
    await tester.ensureVisible(find.text('가입하기'));
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.text('프로필을 완성해주세요'), findsOneWidget);

    final profileFields = find.byType(TextField);
    await tester.tap(profileFields.at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('세)'), findsOneWidget);

    await tester.enterText(profileFields.at(1), '한국대학교');
    await tester.enterText(profileFields.at(2), '4.0');

    final selectors = find.byType(TossChipSelector);
    await tester.tap(find.descendant(of: selectors.at(0), matching: find.text('남성')));
    await tester.pump();

    // Selecting 남성 inserts a 병역 selector right after 성별, shifting every
    // selector after it down by one.
    expect(find.text('병역'), findsOneWidget);
    await tester.tap(find.descendant(of: selectors.at(1), matching: find.text('군필')));
    await tester.tap(find.descendant(of: selectors.at(2), matching: find.text('재학')));
    await tester.ensureVisible(
        find.descendant(of: selectors.at(3), matching: find.text('서울특별시')));
    await tester.tap(find.descendant(of: selectors.at(3), matching: find.text('서울특별시')));
    await tester.ensureVisible(
        find.descendant(of: selectors.at(4), matching: find.text('부산광역시')));
    await tester.tap(find.descendant(of: selectors.at(4), matching: find.text('부산광역시')));
    await tester.pump();

    await tester.ensureVisible(find.text('완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    // 프로필 저장 후 바로 메인으로 가지 않고 로그인 화면으로 돌아와서 다시
    // 로그인해야 메인으로 넘어간다.
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.textContaining('환영해요'), findsNothing);

    final loginFields = find.byType(TextField);
    await tester.enterText(loginFields.at(0), 'test@example.com');
    await tester.enterText(loginFields.at(1), 'password123');
    await tester.pump();
    await tester.ensureVisible(find.text('로그인'));
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(find.textContaining('환영해요'), findsOneWidget);
    expect(find.text('네이버 지도 연동 예정'), findsOneWidget);
    expect(find.text('부산광역시'), findsOneWidget);
  });

  testWidgets(
      'Profile setup computes an income bracket from household size and monthly income',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProfileSetupScreen(name: '홍길동', email: 'test@example.com', accessToken: 'test-token'),
    ));

    expect(find.text('가구원수'), findsOneWidget);
    expect(find.text('월 소득 (만원 단위)'), findsOneWidget);

    await tester.ensureVisible(find.text('4인'));
    await tester.tap(find.text('4인'));
    await tester.pump();

    // 4인 가구 기준중위소득은 월 약 649만원이므로, 649만원을 입력하면 약 100%.
    // TextField 순서: 생년월일(0), 학교(1), 학점(2), 월 소득(3).
    final incomeField = find.byType(TextField).at(3);
    await tester.ensureVisible(incomeField);
    await tester.enterText(incomeField, '649');
    await tester.pump();

    expect(find.textContaining('기준중위소득 약'), findsOneWidget);

    await tester.ensureVisible(find.text('소득구간은 어떻게 계산되나요?'));
    await tester.tap(find.text('소득구간은 어떻게 계산되나요?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('보건복지부'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.textContaining('보건복지부'), findsNothing);
  });

  testWidgets(
      'Profile setup only shows the 병역 selector when 남성 is selected',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProfileSetupScreen(name: '홍길동', email: 'test@example.com', accessToken: 'test-token'),
    ));

    expect(find.text('병역'), findsNothing);

    final selectors = find.byType(TossChipSelector);
    await tester.tap(find.descendant(of: selectors.at(0), matching: find.text('남성')));
    await tester.pump();

    expect(find.text('병역'), findsOneWidget);
    expect(find.text('군필'), findsOneWidget);
    expect(find.text('미필'), findsOneWidget);

    await tester.tap(find.descendant(of: selectors.at(0), matching: find.text('여성')));
    await tester.pump();

    expect(find.text('병역'), findsNothing);
  });

  testWidgets(
      'Profile setup hides and clears school/GPA when 재학상태 is set to 해당없음',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProfileSetupScreen(name: '홍길동', email: 'test@example.com', accessToken: 'test-token'),
    ));

    // TextField 순서: 생년월일(0), 학교(1), 학점(2), 월 소득(3).
    final profileFields = find.byType(TextField);
    await tester.enterText(profileFields.at(1), '한국대학교');
    await tester.enterText(profileFields.at(2), '4.0');
    await tester.pump();

    expect(find.text('한국대학교'), findsOneWidget);

    await tester.ensureVisible(find.text('해당없음'));
    await tester.tap(find.text('해당없음'));
    await tester.pump();

    expect(find.text('학교'), findsNothing);
    expect(find.text('학점 (4.5 만점)'), findsNothing);

    // Switching back shows the fields again, cleared rather than restored.
    await tester.ensureVisible(find.text('재학'));
    await tester.tap(find.text('재학'));
    await tester.pump();

    expect(find.text('학교'), findsOneWidget);
    expect(find.text('한국대학교'), findsNothing);
  });

  testWidgets('Signup blocks submission and shows error for invalid email',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '홍길동');
    await tester.enterText(fields.at(1), 'not-an-email');
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'password123');

    await tester.ensureVisible(find.text('가입하기'));
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.text('올바른 이메일 형식이 아니에요'), findsOneWidget);
    expect(find.text('프로필을 완성해주세요'), findsNothing);
  });

  testWidgets('Main screen lets the user add an interested region',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: MainScreen(
        profile: UserProfile(
          name: '홍길동',
          email: 'test@example.com',
          birthDate: DateTime(2000, 1, 1),
          gender: '남성',
          school: '한국대학교',
          gpa: 4.0,
          enrollmentStatus: '재학',
          region: '서울특별시',
          interestedRegions: [],
        ),
      ),
    ));

    expect(find.text('제주특별자치도'), findsNothing);

    await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
        of: find.byType(TossChipSelector), matching: find.text('제주특별자치도')));
    await tester.pump();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(find.text('제주특별자치도'), findsOneWidget);
  });

  testWidgets('Main screen caps interested regions at 2',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: MainScreen(
        profile: UserProfile(
          name: '홍길동',
          email: 'test@example.com',
          birthDate: DateTime(2000, 1, 1),
          gender: '남성',
          school: '한국대학교',
          gpa: 4.0,
          enrollmentStatus: '재학',
          region: '서울특별시',
          interestedRegions: ['부산광역시', '대구광역시'],
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.text('관심지역 (최대 2개)'), findsOneWidget);

    // 이미 2개가 선택된 상태라 세 번째를 눌러도 잠겨있어 추가되지 않는다.
    await tester.tap(find.descendant(
        of: find.byType(TossChipSelector), matching: find.text('제주특별자치도')));
    await tester.pump();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(find.text('제주특별자치도'), findsNothing);
  });

  testWidgets(
      'Main screen\'s map placeholder region chips open the policy list (web has no real map)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 1},
            'youthPolicyList': [
              {'plcyNm': '청년월세지원'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: MainScreen(
        profile: UserProfile(
          name: '홍길동',
          email: 'test@example.com',
          birthDate: DateTime(2000, 1, 1),
          gender: '남성',
          school: '한국대학교',
          gpa: 4.0,
          enrollmentStatus: '재학',
          region: '서울특별시',
          interestedRegions: const [],
        ),
        policyApiService: PolicyApiService(client: mockClient),
      ),
    ));

    // The test environment has no real Naver map host, so this is the same
    // placeholder that renders on web — its region chips must be tappable so
    // policy browsing isn't blocked when there's no real map to tap into.
    await tester.tap(find.text('서울특별시'));
    await tester.pumpAndSettle();

    expect(find.text('청년월세지원'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches between map, report, and profile tabs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        profile: UserProfile(
          name: '홍길동',
          email: 'test@example.com',
          birthDate: DateTime(2000, 1, 1),
          gender: '남성',
          school: '한국대학교',
          gpa: 4.0,
          enrollmentStatus: '재학',
          region: '서울특별시',
          interestedRegions: ['부산광역시'],
        ),
      ),
    ));

    expect(find.textContaining('환영해요'), findsOneWidget);

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('한국대학교'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃 하시겠어요?'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('로그아웃')));
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요!\n이메일로 로그인해주세요'), findsOneWidget);

    // The floating chat button lives inside HomeShell's nested Navigator
    // scope — logging out must fully replace HomeShell, not just push the
    // login screen underneath it.
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
  });

  testWidgets(
      'Floating chat button opens a panel over the current screen and can be closed',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: HomeShell(profile: sampleProfile())));

    // Chat is not a bottom-nav tab anymore; the map tab stays visible.
    expect(find.text('채팅'), findsNothing);
    expect(find.textContaining('환영해요'), findsOneWidget);
    expect(find.text('정책 어시스턴트'), findsNothing);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    // The panel is open, but the map screen behind it is still there.
    expect(find.text('정책 어시스턴트'), findsOneWidget);
    expect(find.textContaining('환영해요'), findsOneWidget);

    // Closed via the same floating button (now showing an X), not a header
    // close button — the panel header has no close button of its own.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('정책 어시스턴트'), findsNothing);
  });

  testWidgets(
      'Floating chat button persists on a pushed policy detail page',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 1},
            'youthPolicyList': [
              {'plcyNm': '청년월세지원', 'aplyYmd': '20260101 ~ 20261231'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        profile: sampleProfile(interestedRegions: const ['부산광역시']),
        reportPolicyApiService: PolicyApiService(client: mockClient),
      ),
    ));

    await tester.tap(find.text('리포트'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('청년월세지원'));
    await tester.pumpAndSettle();
    expect(find.text('정책 상세'), findsOneWidget);

    // The floating button survives the push onto the detail page — it's no
    // longer covered by it the way a plain Navigator.push would.
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('정책 어시스턴트'), findsOneWidget);
  });

  testWidgets(
      'Scrapping a policy from the report tab shows it under the profile tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 1},
            'youthPolicyList': [
              {'plcyNm': '청년월세지원', 'aplyYmd': '20260101 ~ 20261231'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        profile: sampleProfile(interestedRegions: const ['부산광역시']),
        reportPolicyApiService: PolicyApiService(client: mockClient),
      ),
    ));

    await tester.tap(find.text('리포트'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('청년월세지원'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('1건'), findsOneWidget);

    await tester.tap(find.text('스크랩한 정책'));
    await tester.pumpAndSettle();
    expect(find.text('청년월세지원'), findsOneWidget);
  });

  testWidgets('Cancelling the logout dialog stays on the profile tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(profile: sampleProfile()),
    ));

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('로그아웃 하시겠어요?'), findsNothing);
    expect(find.text('홍길동'), findsOneWidget);
  });

  testWidgets('Editing the profile updates what is shown on the profile tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        profile: UserProfile(
          name: '홍길동',
          email: 'test@example.com',
          birthDate: DateTime(2000, 1, 1),
          gender: '남성',
          school: '한국대학교',
          gpa: 4.0,
          enrollmentStatus: '재학',
          region: '서울특별시',
          interestedRegions: ['부산광역시'],
        ),
      ),
    ));

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('프로필 수정'), findsOneWidget);
    expect(find.text('관심지역'), findsNothing);
    expect(find.text('관심지역 (복수 선택 가능)'), findsNothing);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '김철수');
    await tester.enterText(fields.at(3), '한국과학기술원');
    await tester.pump();

    await tester.tap(fields.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('세)'), findsOneWidget);

    await tester.ensureVisible(find.text('저장'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 수정'), findsNothing);
    expect(find.text('김철수'), findsOneWidget);
    expect(find.text('한국과학기술원'), findsOneWidget);
    expect(find.text('홍길동'), findsNothing);
  });

  testWidgets('Profile tab shows the selected interests, or an empty-state message',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(profile: sampleProfile(interests: ['주거', '취업'])),
    ));

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();

    expect(find.text('관심사'), findsOneWidget);
    expect(find.text('주거'), findsOneWidget);
    expect(find.text('취업'), findsOneWidget);
    expect(find.text('설정된 관심사가 없어요'), findsNothing);
  });

  testWidgets('Profile tab shows an empty-state message when no interests are set',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: HomeShell(profile: sampleProfile())));

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();

    expect(find.text('설정된 관심사가 없어요'), findsOneWidget);
  });

  // 프로필 탭의 관심지역 섹션을 뺐다(지도에서 이미 지역별로 충분히 구분됨).
  // 아래 두 테스트는 그 섹션/관리 진입점을 전제로 하는 시나리오라 지금은 맞지
  // 않지만, 나중에 다시 쓸 수도 있어 주석으로 남겨둔다.
  // testWidgets(
  //     'Adding/removing an interested region on the map syncs to the profile tab',
  //     (WidgetTester tester) async {
  //   tester.view.physicalSize = const Size(400, 1400);
  //   tester.view.devicePixelRatio = 1.0;
  //   addTearDown(tester.view.resetPhysicalSize);
  //   addTearDown(tester.view.resetDevicePixelRatio);

  //   await tester.pumpWidget(MaterialApp(
  //     home: HomeShell(
  //       profile: UserProfile(
  //         name: '홍길동',
  //         email: 'test@example.com',
  //         birthDate: DateTime(2000, 1, 1),
  //         gender: '남성',
  //         school: '한국대학교',
  //         gpa: 4.0,
  //         enrollmentStatus: '재학',
  //         region: '서울특별시',
  //         interestedRegions: ['부산광역시'],
  //       ),
  //     ),
  //   ));

  //   // Add 제주특별자치도 from the map screen's region picker.
  //   await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
  //   await tester.pumpAndSettle();
  //   await tester.tap(find.descendant(
  //       of: find.byType(TossChipSelector), matching: find.text('제주특별자치도')));
  //   await tester.pump();
  //   await tester.tap(find.text('완료'));
  //   await tester.pumpAndSettle();

  //   await tester.tap(find.text('프로필'));
  //   await tester.pumpAndSettle();
  //   expect(find.text('부산광역시'), findsOneWidget);
  //   expect(find.text('제주특별자치도'), findsOneWidget);

  //   // Remove 부산광역시 from the map screen's region picker.
  //   await tester.tap(find.text('지도'));
  //   await tester.pumpAndSettle();
  //   await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
  //   await tester.pumpAndSettle();
  //   await tester.tap(find.descendant(
  //       of: find.byType(TossChipSelector), matching: find.text('부산광역시')));
  //   await tester.pump();
  //   await tester.tap(find.text('완료'));
  //   await tester.pumpAndSettle();

  //   await tester.tap(find.text('프로필'));
  //   await tester.pumpAndSettle();
  //   expect(find.text('부산광역시'), findsNothing);
  //   expect(find.text('제주특별자치도'), findsOneWidget);
  // });

  // testWidgets(
  //     'Managing interested regions from the profile tab syncs to the map',
  //     (WidgetTester tester) async {
  //   tester.view.physicalSize = const Size(400, 1400);
  //   tester.view.devicePixelRatio = 1.0;
  //   addTearDown(tester.view.resetPhysicalSize);
  //   addTearDown(tester.view.resetDevicePixelRatio);

  //   await tester.pumpWidget(MaterialApp(
  //     home: HomeShell(profile: sampleProfile(interestedRegions: const ['부산광역시'])),
  //   ));

  //   await tester.tap(find.text('프로필'));
  //   await tester.pumpAndSettle();
  //   expect(find.text('부산광역시'), findsOneWidget);

  //   // 관심지역 섹션의 "관리"가 첫 번째로 나온다 (관심사 섹션에도 같은 라벨이 있음).
  //   await tester.tap(find.text('관리').first);
  //   await tester.pumpAndSettle();
  //   expect(find.text('관심지역 관리'), findsOneWidget);

  //   await tester.tap(find.descendant(
  //       of: find.byType(TossChipSelector), matching: find.text('제주특별자치도')));
  //   await tester.pump();
  //   await tester.tap(find.text('완료'));
  //   await tester.pumpAndSettle();

  //   expect(find.text('부산광역시'), findsOneWidget);
  //   expect(find.text('제주특별자치도'), findsOneWidget);
  // });

  testWidgets(
      'Chat panel shows the answer returned by the chat API',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/api/chat/ask');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['question'], '내 지역 청년 주거지원이 궁금해요');
      expect((body['profile'] as Map)['region'], '서울특별시');
      return http.Response(
        jsonEncode({
          'answer': '청년월세지원, 역세권청년주택을 신청할 수 있어요.',
          'policies': [
            {'name': '청년월세지원'},
            {'name': '역세권청년주택'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatPanel(
          profile: sampleProfile(),
          onClose: () {},
          chatApiService: ChatApiService(client: mockClient),
        ),
      ),
    ));

    await tester.tap(find.text('내 지역 청년 주거지원이 궁금해요'));
    await tester.pumpAndSettle();

    expect(find.textContaining('청년월세지원, 역세권청년주택을 신청할 수 있어요'), findsOneWidget);
    expect(find.textContaining('컨텍스트: 서울특별시'), findsOneWidget);
  });

  testWidgets(
      'Chat panel sends the user\'s scrapped policies along with the question',
      (WidgetTester tester) async {
    Map<String, dynamic>? sentBody;
    final mockClient = MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'answer': '스크랩하신 정책 기준으로 안내해드릴게요.'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatPanel(
          profile: sampleProfile(
            scrappedPolicies: const [
              PolicyItem(name: '청년월세지원', organization: '국토부', period: '20260101 ~ 20261231'),
            ],
          ),
          onClose: () {},
          chatApiService: ChatApiService(client: mockClient),
        ),
      ),
    ));

    await tester.tap(find.text('내 지역 청년 주거지원이 궁금해요'));
    await tester.pumpAndSettle();

    final scrapped = (sentBody!['profile'] as Map)['scrapped_policies'] as List;
    expect(scrapped, hasLength(1));
    expect(scrapped.single['name'], '청년월세지원');
    expect(scrapped.single['organization'], '국토부');
  });

  testWidgets(
      'Chat panel sends gender/school/gpa/income so the LLM sees the full profile',
      (WidgetTester tester) async {
    Map<String, dynamic>? sentBody;
    final mockClient = MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'answer': '확인해드릴게요.'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatPanel(
          profile: sampleProfile(householdSize: 4, monthlyIncome: 649),
          onClose: () {},
          chatApiService: ChatApiService(client: mockClient),
        ),
      ),
    ));

    await tester.tap(find.text('내 지역 청년 주거지원이 궁금해요'));
    await tester.pumpAndSettle();

    final profile = sentBody!['profile'] as Map;
    expect(profile['gender'], '남성');
    expect(profile['school'], '한국대학교');
    expect(profile['gpa'], 4.0);
    expect(profile['income_percent'], isNotNull);
  });

  testWidgets(
      'Chat panel shows a friendly error when the policy server is unreachable',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      throw Exception('Connection refused');
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatPanel(
          profile: sampleProfile(),
          onClose: () {},
          chatApiService: ChatApiService(client: mockClient),
        ),
      ),
    ));

    await tester.tap(find.text('내 지역 청년 주거지원이 궁금해요'));
    await tester.pumpAndSettle();

    expect(find.text('정책 서버에 연결할 수 없어요. 백엔드가 실행 중인지 확인해주세요.'), findsOneWidget);
  });

  testWidgets('Chat panel starts a new conversation and restores it from history',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'answer': '청년월세지원을 신청할 수 있어요.',
          'policies': [
            {'name': '청년월세지원'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatPanel(
          profile: sampleProfile(),
          onClose: () {},
          chatApiService: ChatApiService(client: mockClient),
        ),
      ),
    ));

    // History icon is disabled until a conversation is archived.
    expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.history)).onPressed,
        isNull);

    await tester.tap(find.text('내 지역 청년 주거지원이 궁금해요'));
    await tester.pumpAndSettle();
    expect(find.text('내 지역 청년 주거지원이 궁금해요'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_square));
    await tester.pumpAndSettle();

    // Conversation was archived and the view reset to the empty state.
    expect(find.text('어떤 정책이 궁금하신가요?'), findsOneWidget);
    expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.history)).onPressed,
        isNotNull);

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.text('대화 이력'), findsOneWidget);
    final historyEntry = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.text('내 지역 청년 주거지원이 궁금해요'));
    expect(historyEntry, findsOneWidget);

    await tester.tap(historyEntry);
    await tester.pumpAndSettle();

    expect(find.text('대화 이력'), findsNothing);
    expect(find.textContaining('청년월세지원'), findsOneWidget);
  });

  group('UserProfile', () {
    test('isScrapped is true once a policy with the same policyNo is added', () {
      const item = PolicyItem(name: '청년월세지원', policyNo: 'P-1');
      final profile = sampleProfile().copyWith(scrappedPolicies: [item]);
      expect(profile.isScrapped(item), isTrue);
      expect(profile.isScrapped(const PolicyItem(name: '다른 정책', policyNo: 'P-2')), isFalse);
    });

    test('isScrapped falls back to comparing by name when policyNo is missing', () {
      const item = PolicyItem(name: '청년월세지원');
      final profile = sampleProfile().copyWith(scrappedPolicies: [item]);
      expect(profile.isScrapped(const PolicyItem(name: '청년월세지원')), isTrue);
    });

    test('incomePercent is null until both household size and income are set', () {
      expect(sampleProfile().incomePercent, isNull);
      expect(sampleProfile(householdSize: 4).incomePercent, isNull);
      expect(sampleProfile(monthlyIncome: 300).incomePercent, isNull);
    });

    test('incomePercent computes roughly 100% at the 4-person median income', () {
      final profile = sampleProfile(householdSize: 4, monthlyIncome: 649);
      expect(profile.incomePercent, inInclusiveRange(99, 101));
    });

    test('incomePercent clamps household sizes above 6 to the 6-person figure', () {
      final sizeSix = sampleProfile(householdSize: 6, monthlyIncome: 500).incomePercent;
      final sizeTen = sampleProfile(householdSize: 10, monthlyIncome: 500).incomePercent;
      expect(sizeTen, sizeSix);
    });

    test('incomeBracketLabel mirrors incomePercent as a readable string', () {
      final profile = sampleProfile(householdSize: 4, monthlyIncome: 649);
      expect(profile.incomeBracketLabel, '기준중위소득 약 ${profile.incomePercent}%');
      expect(sampleProfile().incomeBracketLabel, isNull);
    });
  });

  group('PolicyApiService', () {
    test('search sends region as its own query parameter, not name', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['region'], '서울특별시');
        expect(request.url.queryParameters.containsKey('name'), isFalse);
        return http.Response(
          jsonEncode({'result': {'pagging': {'totCount': 0}, 'youthPolicyList': []}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await PolicyApiService(client: mockClient).search(region: '서울특별시');
    });

    test('searchAllPages pages through results until totalCount is covered', () async {
      var requestedPages = <int>[];
      final mockClient = MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        requestedPages.add(page);
        // 5 total items, 2 per page -> pages 1, 2, 3 (last page has 1 item).
        final itemsOnThisPage = page < 3 ? 2 : 1;
        return http.Response(
          jsonEncode({
            'result': {
              'pagging': {'totCount': 5},
              'youthPolicyList': List.generate(
                itemsOnThisPage,
                (i) => {'plcyNm': '정책 ${(page - 1) * 2 + i + 1}'},
              ),
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await PolicyApiService(client: mockClient)
          .searchAllPages(region: '서울특별시', size: 2, maxPages: 5);

      expect(requestedPages, [1, 2, 3]);
      expect(result.items.length, 5);
      expect(result.totalCount, 5);
    });

    test('searchAllPages stops at maxPages even if more results remain', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'result': {
              'pagging': {'totCount': 100},
              'youthPolicyList': [
                {'plcyNm': '정책'},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await PolicyApiService(client: mockClient)
          .searchAllPages(region: '서울특별시', size: 1, maxPages: 3);

      expect(callCount, 3);
    });

    test('search retries once on a transient 502 and succeeds on the second try', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(jsonEncode({'detail': '온통청년 API 호출 실패'}), 502,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
          jsonEncode({'result': {'pagging': {'totCount': 0}, 'youthPolicyList': []}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await PolicyApiService(client: mockClient).search(region: '서울특별시');

      expect(callCount, 2);
      expect(result.totalCount, 0);
    });

    test('search throws with the detail message when 502 persists after retrying', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'detail': '온통청년 API 호출 실패: 상세 이유'}), 502,
            headers: {'content-type': 'application/json'});
      });

      expect(
        () => PolicyApiService(client: mockClient).search(region: '서울특별시'),
        throwsA(isA<PolicyApiException>().having(
          (e) => e.message,
          'message',
          '온통청년 API 호출 실패: 상세 이유',
        )),
      );
    });
  });

  group('PolicyItem', () {
    test('reads the known youthPolicyList envelope shape', () {
      final items = PolicyItem.listFromResponse({
        'result': {
          'youthPolicyList': [
            {'plcyNm': '청년월세지원', 'plcyExplnCn': '월세 지원', 'sprvsnInstCdNm': '국토부'},
          ],
        },
      });

      expect(items, hasLength(1));
      expect(items.single.name, '청년월세지원');
      expect(items.single.description, '월세 지원');
      expect(items.single.organization, '국토부');
    });

    test('falls back to any string field when known name keys are missing', () {
      final item = PolicyItem.fromJson({'unknownKey': '알 수 없는 정책'});
      expect(item.name, '알 수 없는 정책');
    });

    test('returns an empty list when no known envelope shape matches', () {
      expect(PolicyItem.listFromResponse({'unexpected': 'shape'}), isEmpty);
    });

    test('parses deadline from a "YYYYMMDD ~ YYYYMMDD" apply period', () {
      final item = PolicyItem.fromJson({'plcyNm': '테스트 정책', 'aplyYmd': '20260707 ~ 20260731'});
      expect(item.deadline, DateTime(2026, 7, 31));
    });

    test('parses registeredAt from frstRegDt\'s "YYYY-MM-DD HH:MM:SS" shape', () {
      final item = PolicyItem.fromJson({'plcyNm': '테스트 정책', 'frstRegDt': '2026-07-16 13:39:41'});
      expect(item.registeredAt, DateTime(2026, 7, 16));
    });

    test('sorts newest-registered first using registeredAt', () {
      final items = [
        PolicyItem.fromJson({'plcyNm': '오래된 정책', 'frstRegDt': '2026-01-10 00:00:00'}),
        PolicyItem.fromJson({'plcyNm': '최신 정책', 'frstRegDt': '2026-07-16 13:39:41'}),
      ]..sort((a, b) => b.registeredAt!.compareTo(a.registeredAt!));
      expect(items.first.name, '최신 정책');
    });

    test('falls back to bizPrdBgngYmd~bizPrdEndYmd as a proper range when aplyYmd is missing', () {
      final item = PolicyItem.fromJson({
        'plcyNm': '상시 정책',
        'bizPrdBgngYmd': '20260101',
        'bizPrdEndYmd': '20261231',
      });
      expect(item.period, '20260101 ~ 20261231');
      expect(item.applyStart, DateTime(2026, 1, 1));
      expect(item.deadline, DateTime(2026, 12, 31));
      // Regression check: the start date must not be misread as the
      // deadline, which would make an ongoing policy look already closed.
      expect(item.isCurrentlyOpen, isTrue);
    });

    test('normalizes "연중"/"계속" style bizPrdEtcCn synonyms to a single clear phrase', () {
      expect(PolicyItem.fromJson({'bizPrdEtcCn': '연중'}).period, '상시모집');
      expect(PolicyItem.fromJson({'bizPrdEtcCn': '계속'}).period, '상시모집');
      expect(PolicyItem.fromJson({'bizPrdEtcCn': '상시'}).period, '상시모집');
    });

    test('leaves unrecognized bizPrdEtcCn free text as-is', () {
      final item = PolicyItem.fromJson({'plcyNm': '기타 정책', 'bizPrdEtcCn': '2026. 1. ~ 12.'});
      expect(item.period, '2026. 1. ~ 12.');
      expect(item.deadline, isNull);
      expect(item.isCurrentlyOpen, isTrue);
    });

    test('period is null when neither aplyYmd, bizPrd dates, nor bizPrdEtcCn are present', () {
      final item = PolicyItem.fromJson({'plcyNm': '정보 없는 정책'});
      expect(item.period, isNull);
    });

    test('supportAmount only uses the verified Supabase sprtAmtKrw value, never a text guess', () {
      expect(PolicyItem.fromJson({'sprtAmtKrw': 5000000}).supportAmount, 5000000);
      // Free-text mentions of an amount are never trustworthy enough to show
      // as a real number — only the human-reviewed pipeline value counts.
      expect(PolicyItem.fromJson({'plcySprtCn': '최대 300만원 지원'}).supportAmount, isNull);
      expect(const PolicyItem(name: '이름만 있는 정책').supportAmount, isNull);
    });

    test('supportAmountLabel formats 만원/억원 for display', () {
      expect(PolicyItem.fromJson({'sprtAmtKrw': 150000000}).supportAmountLabel, '1억 5000만원');
      expect(PolicyItem.fromJson({'sprtAmtKrw': 100000000}).supportAmountLabel, '1억원');
      expect(PolicyItem.fromJson({}).supportAmountLabel, isNull);
      expect(PolicyItem.fromJson({'plcySprtCn': '최대 300만원 지원'}).supportAmountLabel, isNull);
    });

    test('reads totCount from the pagination envelope', () {
      final total = PolicyItem.totalCountFromResponse({
        'result': {
          'pagging': {'totCount': 467},
          'youthPolicyList': [
            {'plcyNm': '정책 A'},
          ],
        },
      });
      expect(total, 467);
    });

    test('falls back to item count when pagination info is missing', () {
      final total = PolicyItem.totalCountFromResponse({
        'result': {
          'youthPolicyList': [
            {'plcyNm': '정책 A'},
            {'plcyNm': '정책 B'},
          ],
        },
      });
      expect(total, 2);
    });

    test('matchesProfile is true when the age range covers the user', () {
      final item = PolicyItem.fromJson({
        'plcyNm': '청년 정책',
        'sprtTrgtMinAge': '19',
        'sprtTrgtMaxAge': '34',
      });
      expect(item.matchesProfile(sampleProfile()), isTrue);
    });

    test('matchesProfile is false when the user is outside the age range', () {
      final item = PolicyItem.fromJson({
        'plcyNm': '고령자 정책',
        'sprtTrgtMinAge': '50',
        'sprtTrgtMaxAge': '65',
      });
      expect(item.matchesProfile(sampleProfile()), isFalse);
    });

    test('matchesProfile defaults to true when age bounds are unknown', () {
      final item = PolicyItem.fromJson({'plcyNm': '전연령 정책'});
      expect(item.matchesProfile(sampleProfile()), isTrue);
    });

    test('ageMatches treats "0세 ~ 0세" as no age limit rather than newborns-only', () {
      final item = PolicyItem.fromJson({
        'plcyNm': '전 연령 대상 정책',
        'sprtTrgtMinAge': '0',
        'sprtTrgtMaxAge': '0',
      });
      expect(item.ageMatches(sampleProfile()), isTrue);
    });

    test('maxIncomePercent parses "중위소득 N% 이하" from free-text income info',
        () {
      final item = PolicyItem.fromJson({
        'plcyNm': '전세보증금반환보증 보증료 지원',
        'earnEtcCn': '중위소득 150% 이하 무주택 임차인',
      });
      expect(item.maxIncomePercent, 150);
    });

    test('maxIncomePercent is null when the income text has no percentage',
        () {
      final item = PolicyItem.fromJson({'plcyNm': '정책', 'earnEtcCn': '소득 제한 없음'});
      expect(item.maxIncomePercent, isNull);
    });

    test('matchesProfile is true when the user\'s computed income percent fits the policy\'s',
        () {
      final item = PolicyItem.fromJson({
        'plcyNm': '전세보증금반환보증 보증료 지원',
        'earnEtcCn': '중위소득 150% 이하',
      });
      // 4인 가구 기준중위소득 약 649만원 -> 월 649만원 입력 시 대략 100%.
      final profile = sampleProfile(householdSize: 4, monthlyIncome: 649);
      expect(profile.incomePercent, lessThanOrEqualTo(100));
      expect(item.matchesProfile(profile), isTrue);
    });

    test('matchesProfile is false when the user\'s computed income percent exceeds the policy\'s',
        () {
      final item = PolicyItem.fromJson({
        'plcyNm': '전세보증금반환보증 보증료 지원',
        'earnEtcCn': '중위소득 100% 이하',
      });
      // 같은 4인 가구 기준으로 월 974만원이면 대략 150%.
      final profile = sampleProfile(householdSize: 4, monthlyIncome: 974);
      expect(profile.incomePercent, greaterThan(100));
      expect(item.matchesProfile(profile), isFalse);
    });

    test('matchesProfile defaults to true when income info is unknown on either side',
        () {
      final withNoIncomeCondition = PolicyItem.fromJson({'plcyNm': '정책'});
      expect(
        withNoIncomeCondition.matchesProfile(
          sampleProfile(householdSize: 4, monthlyIncome: 300),
        ),
        isTrue,
      );

      final withIncomeCondition = PolicyItem.fromJson({
        'plcyNm': '정책',
        'earnEtcCn': '중위소득 100% 이하',
      });
      // 가구원수/소득을 입력하지 않았으면 (모름) 계산 자체가 안 되니 통과시킨다.
      expect(withIncomeCondition.matchesProfile(sampleProfile()), isTrue);
    });

    test('isCurrentlyOpen is false once the deadline has passed', () {
      final item = PolicyItem.fromJson({'plcyNm': '마감된 정책', 'aplyYmd': '20200101 ~ 20200131'});
      expect(item.isCurrentlyOpen, isFalse);
    });

    test('isCurrentlyOpen is false before the application period opens', () {
      final farFuture = DateTime.now().add(const Duration(days: 365));
      final ymd = '${farFuture.year}${farFuture.month.toString().padLeft(2, '0')}'
          '${farFuture.day.toString().padLeft(2, '0')}';
      final item = PolicyItem.fromJson({'plcyNm': '예정된 정책', 'aplyYmd': '$ymd ~ $ymd'});
      expect(item.isCurrentlyOpen, isFalse);
    });

    test('isCurrentlyOpen defaults to true when there is no apply period (상시)', () {
      final item = PolicyItem.fromJson({'plcyNm': '상시 정책'});
      expect(item.isCurrentlyOpen, isTrue);
    });

    test('matchingInterests finds interests mentioned in the policy text', () {
      final item = PolicyItem.fromJson({
        'plcyNm': '청년월세지원',
        'plcyExplnCn': '무주택 청년의 주거 안정을 지원합니다',
      });
      expect(
        item.matchingInterests(sampleProfile(interests: const ['주거', '금융'])),
        ['주거'],
      );
      expect(item.matchesInterests(sampleProfile(interests: const ['주거'])), isTrue);
      expect(item.matchesInterests(sampleProfile(interests: const ['금융'])), isFalse);
      expect(item.matchesInterests(sampleProfile()), isFalse);
    });

    test('matchingInterests matches 복지 and 문화 as separate interests', () {
      final item = PolicyItem.fromJson({'plcyNm': '정책', 'plcyExplnCn': '지역 문화 행사 지원'});
      expect(
        item.matchingInterests(sampleProfile(interests: const ['복지', '문화'])),
        ['문화'],
      );
    });

    test('categoryLabel maps mclsfNm directly onto one of the profile\'s 관심사 values', () {
      expect(
        PolicyItem.fromJson({'plcyNm': '정책', 'mclsfNm': '취업'}).categoryLabel,
        '취업',
      );
      expect(
        PolicyItem.fromJson({'plcyNm': '정책', 'mclsfNm': '청년국제교류'}).categoryLabel,
        '국제교류',
      );
      // Comma-separated mclsfNm takes the first value, same as the old
      // lclsfNm handling did.
      expect(
        PolicyItem.fromJson({'plcyNm': '정책', 'mclsfNm': '재직자,권익보호'}).categoryLabel,
        '취업',
      );
      expect(
        PolicyItem.fromJson({'plcyNm': '정책'}).categoryLabel,
        isNull,
      );
    });

    test('categoryLabel has no bucket for civic-participation mclsfNm values (no 참여권리)', () {
      expect(
        PolicyItem.fromJson({'plcyNm': '정책', 'mclsfNm': '청년참여'}).categoryLabel,
        isNull,
      );
      expect(
        PolicyItem.fromJson({'plcyNm': '정책', 'mclsfNm': '정책인프라구축'}).categoryLabel,
        isNull,
      );
    });

    test('categoryLabel splits the ambiguous 취약계층 및 금융지원 mclsfNm by keyword, defaulting to 복지', () {
      expect(
        PolicyItem.fromJson({
          'plcyNm': '청년 대출 이자 지원',
          'mclsfNm': '취약계층 및 금융지원',
        }).categoryLabel,
        '금융',
      );
      // 힌트가 전혀 없거나 복지 신호가 섞여 있으면 복지 쪽을 기본값으로 둔다.
      expect(
        PolicyItem.fromJson({'plcyNm': '정책', 'mclsfNm': '취약계층 및 금융지원'}).categoryLabel,
        '복지',
      );
    });

    test('categoryLabel splits the ambiguous 문화활동 및 생활지원 mclsfNm by keyword, defaulting to 복지', () {
      expect(
        PolicyItem.fromJson({
          'plcyNm': '문화누리카드 지원',
          'mclsfNm': '문화활동 및 생활지원',
        }).categoryLabel,
        '문화',
      );
      expect(
        PolicyItem.fromJson({'plcyNm': '정책', 'mclsfNm': '문화활동 및 생활지원'}).categoryLabel,
        '복지',
      );
    });
  });

  group('NotificationService', () {
    // The plugin has no real OS host in the widget-test environment, so
    // every call below hits its platform channel and fails internally —
    // this only verifies that failure is swallowed (per NotificationService's
    // defensive try/catch) rather than surfacing as an unhandled exception
    // that would otherwise crash whatever scrap/unscrap flow triggered it.
    test('scheduleDeadlineReminders does not throw when the policy has no deadline', () async {
      const policy = PolicyItem(name: '상시 모집 정책');
      await expectLater(
        NotificationService.instance.scheduleDeadlineReminders(policy),
        completes,
      );
    });

    test('scheduleDeadlineReminders does not throw even without a platform host', () async {
      final policy = PolicyItem(
        name: '마감 임박 정책',
        deadline: DateTime.now().add(const Duration(days: 10)),
      );
      await expectLater(
        NotificationService.instance.scheduleDeadlineReminders(policy),
        completes,
      );
    });

    test('cancelDeadlineReminders does not throw even without a platform host', () async {
      const policy = PolicyItem(name: '아무 정책');
      await expectLater(
        NotificationService.instance.cancelDeadlineReminders(policy),
        completes,
      );
    });
  });

  testWidgets('Policy list sheet shows results and opens the detail page on tap',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      // Region searches must use zipCd (via `region`), not a plcyNm title
      // search — a policy titled "청년월세지원" wouldn't mention 서울특별시.
      expect(request.url.queryParameters['region'], '서울특별시');
      expect(request.url.queryParameters.containsKey('name'), isFalse);
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 1},
            'youthPolicyList': [
              {
                'plcyNm': '청년월세지원',
                'plcyExplnCn': '월세를 지원합니다',
                'aplyYmd': '20260101 ~ 20261231',
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PolicyListSheet(
          region: '서울특별시',
          profile: sampleProfile(),
          onProfileUpdated: (_) {},
          policyApiService: PolicyApiService(client: mockClient),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('서울특별시 정책 1건'), findsOneWidget);
    expect(find.text('청년월세지원'), findsOneWidget);

    await tester.tap(find.text('청년월세지원'));
    await tester.pumpAndSettle();

    expect(find.text('정책 상세'), findsOneWidget);
    expect(find.text('월세를 지원합니다'), findsOneWidget);
  });

  testWidgets('Policy list sheet sorts by support amount when that chip is selected',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 2},
            'youthPolicyList': [
              {'plcyNm': '소액 지원금', 'sprtAmtKrw': 100000},
              {'plcyNm': '고액 지원금', 'sprtAmtKrw': 5000000},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PolicyListSheet(
          region: '서울특별시',
          profile: sampleProfile(),
          onProfileUpdated: (_) {},
          policyApiService: PolicyApiService(client: mockClient),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지원금액 많은 순'));
    await tester.pumpAndSettle();

    final cardTitles = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(ListView),
          matching: find.textContaining('지원금'),
        ))
        .map((text) => text.data)
        .toList();
    expect(cardTitles, ['고액 지원금', '소액 지원금']);
  });

  testWidgets('Policy list sheet defaults to policies the user is actually eligible for',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 2},
            'youthPolicyList': [
              {'plcyNm': '중장년 전용 정책', 'sprtTrgtMinAge': '40', 'sprtTrgtMaxAge': '60'},
              {'plcyNm': '청년월세지원', 'sprtTrgtMinAge': '19', 'sprtTrgtMaxAge': '34'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PolicyListSheet(
          region: '서울특별시',
          profile: sampleProfile(),
          onProfileUpdated: (_) {},
          policyApiService: PolicyApiService(client: mockClient),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Age-ineligible policy is excluded from the default list entirely,
    // not just flagged with a badge.
    expect(find.text('서울특별시 정책 1건'), findsOneWidget);
    expect(find.text('청년월세지원'), findsOneWidget);
    expect(find.text('중장년 전용 정책'), findsNothing);
  });

  testWidgets('Policy detail screen notes whether the user\'s age fits the policy',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PolicyDetailScreen(
        policy: const PolicyItem(name: '중장년 전용 정책', minAge: 40, maxAge: 60),
        profile: sampleProfile(),
        onProfileUpdated: (_) {},
      ),
    ));

    expect(find.textContaining('조건에 맞지 않아요'), findsOneWidget);
  });

  testWidgets('Policy list sheet shows category labels and filters by category chip',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 2},
            'youthPolicyList': [
              {'plcyNm': '청년월세지원', 'mclsfNm': '주택 및 거주지'},
              {'plcyNm': '취업역량강화', 'mclsfNm': '미래역량강화'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PolicyListSheet(
          region: '서울특별시',
          profile: sampleProfile(),
          onProfileUpdated: (_) {},
          policyApiService: PolicyApiService(client: mockClient),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Both cards show their normalized category label, plus the matching
    // filter chip above — so each label text appears twice (chip + card).
    expect(find.text('주거'), findsNWidgets(2));
    // '교육･직업훈련' normalizes down to '교육'.
    expect(find.text('교육'), findsNWidgets(2));
    expect(find.text('전체'), findsOneWidget);

    await tester.tap(find.text('주거').first);
    await tester.pumpAndSettle();

    expect(find.text('청년월세지원'), findsOneWidget);
    expect(find.text('취업역량강화'), findsNothing);
    // Only the filter chip remains once the card for the other category is gone.
    expect(find.text('주거'), findsNWidgets(2));

    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();

    expect(find.text('청년월세지원'), findsOneWidget);
    expect(find.text('취업역량강화'), findsOneWidget);
  });

  testWidgets('Policy list sheet badges and filters policies matching the user\'s interests',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 2},
            'youthPolicyList': [
              {'plcyNm': '청년월세지원', 'plcyExplnCn': '무주택 청년의 주거 안정을 지원합니다'},
              {'plcyNm': '취업역량강화', 'plcyExplnCn': '취업 준비생을 위한 프로그램'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PolicyListSheet(
          region: '서울특별시',
          profile: sampleProfile(interests: const ['주거']),
          onProfileUpdated: (_) {},
          policyApiService: PolicyApiService(client: mockClient),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The badge doesn't show until the user actually turns on "내 관심사만".
    expect(find.text('관심사: 주거'), findsNothing);

    await tester.tap(find.text('내 관심사만'));
    await tester.pumpAndSettle();

    expect(find.text('청년월세지원'), findsOneWidget);
    expect(find.text('취업역량강화'), findsNothing);
    expect(find.text('관심사: 주거'), findsOneWidget);
  });

  testWidgets('Policy list sheet shows the connection error message on failure',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      throw Exception('Connection refused');
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PolicyListSheet(
          region: '서울특별시',
          profile: sampleProfile(),
          onProfileUpdated: (_) {},
          policyApiService: PolicyApiService(client: mockClient),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('정책 서버에 연결할 수 없어요. 백엔드가 실행 중인지 확인해주세요.'), findsOneWidget);
  });

  testWidgets('Policy detail screen shows the policy fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PolicyDetailScreen(
        policy: PolicyItem(
          name: '청년월세지원',
          description: '월세를 지원합니다',
          period: '20260101 ~ 20261231',
          supportContent: '월 20만원',
          applyMethod: '온라인 신청',
          minAge: 19,
          maxAge: 34,
        ),
      ),
    ));

    expect(find.text('청년월세지원'), findsOneWidget);
    expect(find.text('만 19세 ~ 34세'), findsOneWidget);
    expect(find.text('20260101 ~ 20261231'), findsOneWidget);
    expect(find.text('월 20만원'), findsOneWidget);
    expect(find.text('온라인 신청'), findsOneWidget);

    // No profile passed in, so there's nothing to scrap into — the button
    // shouldn't show at all rather than silently doing nothing.
    expect(find.byIcon(Icons.bookmark_border), findsNothing);
    expect(find.byIcon(Icons.bookmark), findsNothing);
  });

  testWidgets('Policy detail screen toggles the scrap button and reports it upward',
      (WidgetTester tester) async {
    const policy = PolicyItem(name: '청년월세지원', policyNo: 'P-1');
    UserProfile? updatedProfile;

    await tester.pumpWidget(MaterialApp(
      home: PolicyDetailScreen(
        policy: policy,
        profile: sampleProfile(),
        onProfileUpdated: (updated) => updatedProfile = updated,
      ),
    ));

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(updatedProfile?.isScrapped(policy), isTrue);

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pump();

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(updatedProfile?.isScrapped(policy), isFalse);
  });

  testWidgets('Scrapped policies screen lists saved policies and un-scraps them',
      (WidgetTester tester) async {
    const policy = PolicyItem(name: '청년월세지원', policyNo: 'P-1', period: '20260101 ~ 20261231');
    UserProfile? updatedProfile;

    await tester.pumpWidget(MaterialApp(
      home: ScrappedPoliciesScreen(
        profile: sampleProfile().copyWith(scrappedPolicies: const [policy]),
        onProfileUpdated: (updated) => updatedProfile = updated,
      ),
    ));

    expect(find.text('청년월세지원'), findsOneWidget);
    expect(find.text('아직 스크랩한 정책이 없어요'), findsNothing);

    await tester.tap(find.byTooltip('스크랩 해제'));
    await tester.pumpAndSettle();

    expect(find.text('청년월세지원'), findsNothing);
    expect(find.text('아직 스크랩한 정책이 없어요'), findsOneWidget);
    expect(updatedProfile?.scrappedPolicies, isEmpty);
  });

  testWidgets('Report tab shows the empty state when there are no interested regions',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(
        profile: sampleProfile(),
        onProfileUpdated: (_) {},
      ),
    ));

    expect(find.text('아직 등록된 관심지역이 없어요'), findsOneWidget);
    expect(find.text('관심지역 추가하기'), findsOneWidget);
  });

  testWidgets(
      'Report tab still shows recommended news when there are no interested regions',
      (WidgetTester tester) async {
    // Regression test: the news section used to be nested inside the
    // policy-loading view, so it silently disappeared whenever there were
    // no interested regions (or the policy fetch was stuck/failed) — even
    // though news is keyed off interests, not regions.
    final newsMockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'articles': [
            {'title': '청년 월세 지원 확대', 'url': 'https://news.example.com/1', 'source': '뉴스원'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(
        profile: sampleProfile(interests: const ['주거']),
        onProfileUpdated: (_) {},
        newsApiService: NewsApiService(client: newsMockClient),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('아직 등록된 관심지역이 없어요'), findsOneWidget);
    expect(find.text('추천 뉴스'), findsOneWidget);
    expect(find.text('청년 월세 지원 확대'), findsOneWidget);
  });

  testWidgets(
      'Report tab still shows recommended news when the policy fetch fails',
      (WidgetTester tester) async {
    final policyMockClient = MockClient((request) async {
      throw Exception('Connection refused');
    });
    final newsMockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'articles': [
            {'title': '청년 월세 지원 확대', 'url': 'https://news.example.com/1', 'source': '뉴스원'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(
        profile: sampleProfile(interestedRegions: const ['부산광역시'], interests: const ['주거']),
        onProfileUpdated: (_) {},
        policyApiService: PolicyApiService(client: policyMockClient),
        newsApiService: NewsApiService(client: newsMockClient),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('정책 서버에 연결할 수 없어요. 백엔드가 실행 중인지 확인해주세요.'), findsOneWidget);
    expect(find.text('추천 뉴스'), findsOneWidget);
    expect(find.text('청년 월세 지원 확대'), findsOneWidget);
  });

  testWidgets('Report tab shows the matching gauge, category donut, and deadline list',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      expect(
        ['서울특별시', '부산광역시'].contains(request.url.queryParameters['region']),
        isTrue,
      );
      expect(request.url.queryParameters.containsKey('name'), isFalse);
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 2},
            'youthPolicyList': [
              {
                'plcyNo': '1',
                'plcyNm': '청년월세지원',
                'mclsfNm': '주택 및 거주지',
                'sprtTrgtMinAge': '19',
                'sprtTrgtMaxAge': '34',
                'aplyYmd': '20260101 ~ 20261231',
              },
              {
                'plcyNo': '2',
                'plcyNm': '고령자 지원금',
                'mclsfNm': '취약계층 및 금융지원',
                'sprtTrgtMinAge': '60',
                'sprtTrgtMaxAge': '80',
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(
        profile: sampleProfile(interestedRegions: const ['부산광역시']),
        onProfileUpdated: (_) {},
        policyApiService: PolicyApiService(client: mockClient),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('매칭 자격 충족률'), findsOneWidget);
    expect(find.text('카테고리 분포'), findsOneWidget);
    expect(find.text('마감임박'), findsOneWidget);
    expect(find.text('청년월세지원'), findsOneWidget);
    expect(find.textContaining('D-'), findsOneWidget);

    // The category donut is built only from policies the user actually
    // qualifies for (주거, age-eligible) — not the age-ineligible one (복지).
    expect(find.text('주거'), findsOneWidget);
    expect(find.text('복지'), findsNothing);

    await tester.tap(find.text('청년월세지원'));
    await tester.pumpAndSettle();
    expect(find.text('정책 상세'), findsOneWidget);
  });

  testWidgets(
      'Report tab explains why the match rate is below 100% and hides it at 100%',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 2},
            'youthPolicyList': [
              {
                'plcyNo': '1',
                'plcyNm': '청년월세지원',
                'sprtTrgtMinAge': '19',
                'sprtTrgtMaxAge': '34',
              },
              {
                'plcyNo': '2',
                'plcyNm': '고령자 지원금',
                'sprtTrgtMinAge': '60',
                'sprtTrgtMaxAge': '80',
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(
        profile: sampleProfile(interestedRegions: const ['부산광역시']),
        onProfileUpdated: (_) {},
        policyApiService: PolicyApiService(client: mockClient),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('충족률이 100%가 아닌 이유'), findsOneWidget);
    expect(find.textContaining('나이 조건이 맞지 않는 정책 1건'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('해당 정책 1건 보기'));
    await tester.tap(find.textContaining('해당 정책 1건 보기'));
    await tester.pumpAndSettle();

    expect(find.text('충족 안 되는 정책 1건'), findsOneWidget);
    expect(find.text('고령자 지원금'), findsOneWidget);
    expect(find.textContaining('나이 조건 불충족'), findsOneWidget);

    await tester.tap(find.text('고령자 지원금'));
    await tester.pumpAndSettle();

    expect(find.text('정책 상세'), findsOneWidget);
  });

  testWidgets('Report tab hides the match-gap notice when the match rate is 100%',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 1},
            'youthPolicyList': [
              {'plcyNo': '1', 'plcyNm': '청년월세지원'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(
        profile: sampleProfile(interestedRegions: const ['부산광역시']),
        onProfileUpdated: (_) {},
        policyApiService: PolicyApiService(client: mockClient),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('충족률이 100%가 아닌 이유'), findsNothing);
  });

  testWidgets('Report tab requests exactly as many news articles as matched policies',
      (WidgetTester tester) async {
    final policyMockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'pagging': {'totCount': 1},
            'youthPolicyList': [
              {'plcyNo': '1', 'plcyNm': '청년월세지원'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final requestedCounts = <String?>[];
    final newsMockClient = MockClient((request) async {
      requestedCounts.add(request.url.queryParameters['count']);
      return http.Response(
        jsonEncode({'articles': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(
        profile: sampleProfile(interestedRegions: const ['부산광역시'], interests: const ['주거']),
        onProfileUpdated: (_) {},
        policyApiService: PolicyApiService(client: policyMockClient),
        newsApiService: NewsApiService(client: newsMockClient),
      ),
    ));
    await tester.pumpAndSettle();

    // The initial fetch (before policies load) has no count; once the 1
    // matched policy is known, it re-fetches asking for exactly 1 article.
    expect(requestedCounts.last, '1');
  });

  testWidgets('Report tab shows recommended news when interests are set',
      (WidgetTester tester) async {
    final newsMockClient = MockClient((request) async {
      expect(request.url.path, '/api/news/recommendations');
      expect(request.url.queryParametersAll['interests'], ['주거']);
      return http.Response(
        jsonEncode({
          'articles': [
            {
              'title': '청년 월세 지원 확대',
              'url': 'https://news.example.com/1',
              'source': '뉴스원',
              'reason': '관심사인 주거와 관련된 기사예요.',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    // No interested regions, so _load() never runs — this isolates the news
    // section from policy-matching count (covered by its own tests below).
    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(
        profile: sampleProfile(interests: const ['주거']),
        onProfileUpdated: (_) {},
        newsApiService: NewsApiService(client: newsMockClient),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('추천 뉴스'), findsOneWidget);
    expect(find.text('청년 월세 지원 확대'), findsOneWidget);
    expect(find.text('관심사인 주거와 관련된 기사예요.'), findsOneWidget);
    expect(find.text('뉴스원'), findsOneWidget);
  });

  testWidgets('Report tab prompts to set interests when none are selected',
      (WidgetTester tester) async {
    final policyMockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {'pagging': {'totCount': 0}, 'youthPolicyList': []},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: ReportScreen(
        profile: sampleProfile(interestedRegions: const ['부산광역시']),
        onProfileUpdated: (_) {},
        policyApiService: PolicyApiService(client: policyMockClient),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('관심사를 설정하면 맞춤 뉴스를 볼 수 있어요'), findsOneWidget);
    expect(find.text('관심사 설정하기'), findsOneWidget);
  });

  testWidgets('GPA field blocks values above 4.5 and rounds to two decimals',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProfileSetupScreen(name: '홍길동', email: 'test@example.com', accessToken: 'test-token'),
    ));

    final gpaField = find.byType(TextField).at(2);

    await tester.enterText(gpaField, '4.6');
    await tester.pump();
    expect(tester.widget<TextField>(gpaField).controller!.text, '');

    await tester.enterText(gpaField, '3.876');
    await tester.pump();
    expect(tester.widget<TextField>(gpaField).controller!.text, '3.88');
  });
}
