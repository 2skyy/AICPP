import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aicpp/main.dart';
import 'package:aicpp/models/policy_item.dart';
import 'package:aicpp/models/user_profile.dart';
import 'package:aicpp/screens/chat_screen.dart';
import 'package:aicpp/screens/home_shell.dart';
import 'package:aicpp/screens/main_screen.dart';
import 'package:aicpp/screens/policy_detail_screen.dart';
import 'package:aicpp/screens/profile_setup_screen.dart';
import 'package:aicpp/screens/report_screen.dart';
import 'package:aicpp/services/policy_api_service.dart';
import 'package:aicpp/widgets/policy_list_sheet.dart';
import 'package:aicpp/widgets/toss_chip_selector.dart';

UserProfile sampleProfile({List<String> interestedRegions = const []}) => UserProfile(
      name: '홍길동',
      email: 'test@example.com',
      birthDate: DateTime(2000, 1, 1),
      gender: '남성',
      school: '한국대학교',
      gpa: 4.0,
      enrollmentStatus: '재학',
      region: '서울특별시',
      interestedRegions: interestedRegions,
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

    await tester.pumpWidget(const MyApp());

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

  testWidgets('Completing signup and profile setup reaches the main screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
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
    await tester.tap(find.descendant(of: selectors.at(1), matching: find.text('재학')));
    await tester.ensureVisible(
        find.descendant(of: selectors.at(2), matching: find.text('서울특별시')));
    await tester.tap(find.descendant(of: selectors.at(2), matching: find.text('서울특별시')));
    await tester.ensureVisible(
        find.descendant(of: selectors.at(3), matching: find.text('부산광역시')));
    await tester.tap(find.descendant(of: selectors.at(3), matching: find.text('부산광역시')));
    await tester.pump();

    await tester.ensureVisible(find.text('완료'));
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(find.textContaining('환영해요'), findsOneWidget);
    expect(find.text('네이버 지도 연동 예정'), findsOneWidget);
    expect(find.text('부산광역시'), findsOneWidget);
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

  testWidgets('Bottom navigation switches between map, chat, and profile tabs',
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

    await tester.tap(find.text('채팅'));
    await tester.pumpAndSettle();
    expect(find.text('정책 어시스턴트'), findsOneWidget);

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
    expect(find.text('관심지역'), findsOneWidget);
    expect(find.text('부산광역시'), findsOneWidget);
  });

  testWidgets(
      'Adding/removing an interested region on the map syncs to the profile tab',
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

    // Add 제주특별자치도 from the map screen's region picker.
    await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(TossChipSelector), matching: find.text('제주특별자치도')));
    await tester.pump();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('부산광역시'), findsOneWidget);
    expect(find.text('제주특별자치도'), findsOneWidget);

    // Remove 부산광역시 from the map screen's region picker.
    await tester.tap(find.text('지도'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(TossChipSelector), matching: find.text('부산광역시')));
    await tester.pump();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('부산광역시'), findsNothing);
    expect(find.text('제주특별자치도'), findsOneWidget);
  });

  testWidgets(
      'Managing interested regions from the profile tab syncs to the map',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: HomeShell(profile: sampleProfile(interestedRegions: const ['부산광역시'])),
    ));

    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    expect(find.text('부산광역시'), findsOneWidget);

    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();
    expect(find.text('관심지역 관리'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(TossChipSelector), matching: find.text('제주특별자치도')));
    await tester.pump();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(find.text('부산광역시'), findsOneWidget);
    expect(find.text('제주특별자치도'), findsOneWidget);
  });

  testWidgets(
      'Chat screen shows matched policies returned by the policy API',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
            'youthPolicyList': [
              {'plcyNm': '청년월세지원'},
              {'plcyNm': '역세권청년주택'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        profile: sampleProfile(),
        policyApiService: PolicyApiService(client: mockClient),
      ),
    ));

    await tester.tap(find.text('내 지역 청년 주거지원이 궁금해요'));
    await tester.pumpAndSettle();

    expect(find.textContaining('"주거" 관련 신청 가능한 정책 2건이 있어요'), findsOneWidget);
    expect(find.textContaining('청년월세지원'), findsOneWidget);
    expect(find.textContaining('역세권청년주택'), findsOneWidget);
    expect(find.textContaining('컨텍스트: 서울특별시'), findsOneWidget);
  });

  testWidgets(
      'Chat rejects meaningless input without calling the policy API',
      (WidgetTester tester) async {
    var callCount = 0;
    final mockClient = MockClient((request) async {
      callCount++;
      throw Exception('should not be called');
    });

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        profile: sampleProfile(),
        policyApiService: PolicyApiService(client: mockClient),
      ),
    ));

    await tester.enterText(find.byType(TextField), '.');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(callCount, 0);
    expect(
        find.text('질문을 이해하지 못했어요. 주거, 취업, 창업, 교육, 복지 같은 키워드를 포함해서 다시 질문해주세요.'),
        findsOneWidget);
  });

  testWidgets(
      'Chat falls back to profile-matched policies when no known keyword is found',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      expect(request.url.queryParameters['name'], '서울특별시');
      return http.Response(
        jsonEncode({
          'result': {
            'youthPolicyList': [
              {'plcyNm': '청년 종합지원'},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        profile: sampleProfile(),
        policyApiService: PolicyApiService(client: mockClient),
      ),
    ));

    await tester.enterText(find.byType(TextField), '나이 조건에 맞는 정책 알려줘');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.textContaining('서울특별시에서 내 조건에 맞는 정책 1건이 있어요'), findsOneWidget);
    expect(find.textContaining('청년 종합지원'), findsOneWidget);
  });

  testWidgets(
      'Chat screen shows a friendly error when the policy server is unreachable',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      throw Exception('Connection refused');
    });

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        profile: sampleProfile(),
        policyApiService: PolicyApiService(client: mockClient),
      ),
    ));

    await tester.tap(find.text('내 지역 청년 주거지원이 궁금해요'));
    await tester.pumpAndSettle();

    expect(find.text('정책 서버에 연결할 수 없어요. 백엔드가 실행 중인지 확인해주세요.'), findsOneWidget);
  });

  testWidgets('Chat starts a new conversation and restores it from history',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'result': {
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
      home: ChatScreen(
        profile: sampleProfile(),
        policyApiService: PolicyApiService(client: mockClient),
      ),
    ));

    // History icon is disabled until a conversation is archived.
    expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.history)).onPressed,
        isNull);

    await tester.tap(find.text('내 지역 청년 주거지원이 궁금해요'));
    await tester.pumpAndSettle();
    expect(find.text('내 지역 청년 주거지원이 궁금해요'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_comment_outlined));
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
  });

  testWidgets('Policy list sheet shows results and opens the detail page on tap',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
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

  testWidgets('Report tab shows the matching gauge, category donut, and deadline list',
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
                'lclsfNm': '주거',
                'sprtTrgtMinAge': '19',
                'sprtTrgtMaxAge': '34',
                'aplyYmd': '20260101 ~ 20261231',
              },
              {
                'plcyNo': '2',
                'plcyNm': '고령자 지원금',
                'lclsfNm': '복지',
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

    await tester.tap(find.text('청년월세지원'));
    await tester.pumpAndSettle();
    expect(find.text('정책 상세'), findsOneWidget);
  });

  testWidgets('GPA field blocks values above 4.5 and rounds to two decimals',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProfileSetupScreen(name: '홍길동', email: 'test@example.com'),
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
