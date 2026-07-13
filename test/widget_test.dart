import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aicpp/main.dart';
import 'package:aicpp/models/user_profile.dart';
import 'package:aicpp/screens/chat_screen.dart';
import 'package:aicpp/screens/home_shell.dart';
import 'package:aicpp/screens/main_screen.dart';
import 'package:aicpp/screens/profile_setup_screen.dart';
import 'package:aicpp/widgets/toss_chip_selector.dart';

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
    expect(find.text('안녕하세요!\n이메일로 로그인해주세요'), findsOneWidget);
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
      'Chat screen sends a suggested question and shows the profile context',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
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
      ),
    ));

    expect(find.text('내 지역 청년 주거지원이 궁금해요'), findsOneWidget);

    await tester.tap(find.text('내 지역 청년 주거지원이 궁금해요'));
    await tester.pump();

    expect(find.text('내 지역 청년 주거지원이 궁금해요'), findsOneWidget);
    expect(find.textContaining('컨텍스트: 서울특별시'), findsOneWidget);
    expect(find.textContaining('재학'), findsWidgets);
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
