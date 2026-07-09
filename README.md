# AICPP

Flutter 앱. 로그인/회원가입/프로필 입력을 거쳐 네이버 지도로 지역 정보를 보여주는 흐름을 구현 중입니다.

## 화면 흐름

```
로그인 ──(로그인)──────────────────► 메인 (지도)
  │
  └─(회원가입)─► 회원가입 ─► 프로필 입력 ─► 메인 (지도)
```

### 로그인 (`lib/screens/login_screen.dart`)
- 이메일/비밀번호 입력, 토스 스타일 UI
- 카카오톡/구글/iCloud 로그인 아이콘 (자리만 마련 — 탭하면 "준비 중" 안내만 뜨고 실제 연동은 안 됨)
- 화면 맨 아래에 "회원가입" 링크
- 로그인을 누르면 실제 인증 없이 바로 메인 화면으로 이동 (아래 "현재 상태" 참고)

### 회원가입 (`lib/screens/signup_screen.dart`)
- 이름 / 이메일 / 비밀번호 / 비밀번호 확인
- 이메일 형식, 비밀번호 8자 이상, 비밀번호 일치 여부를 제출 시점에 검증
- 백엔드 없이 로컬 형식 검증만 수행 (이메일이 실제 존재하는지는 확인 불가)

### 프로필 입력 (`lib/screens/profile_setup_screen.dart`)
- 생년월일: 달력에서 선택 → 만 나이 자동 계산
- 성별 / 재학상태(재학·휴학·졸업·졸업유예) / 지역 / 관심지역(복수 선택): 칩 선택 UI
- 학교: 텍스트 입력
- 학점: 4.5 초과 입력 차단, 소수 셋째 자리부터는 자동 반올림하여 둘째 자리까지 표시

### 메인 (`lib/screens/main_screen.dart`)
- 네이버 지도에 "지역"은 파란 핀, "관심지역"은 주황 핀으로 표시 (범례 포함)
- 지도 우측 하단에 확대/축소(+/-) 버튼
- 네이버 지도는 Android/iOS 네이티브 SDK 기반이라 macOS 데스크톱·웹에서는 지원되지 않음 → 해당 플랫폼에서는 안내 문구가 있는 플레이스홀더로 대체

## 네이버 지도 설정

1. [Naver Cloud Platform 콘솔](https://console.ncloud.com)에서 Maps > Dynamic Map Application을 등록하고 Client ID를 발급받습니다.
   - Android 패키지 이름 / iOS Bundle ID: `com.aicpp.aicpp`
2. `config/naver_map.local.json.example`을 참고해 `config/naver_map.local.json` 파일을 만들고 Client ID를 채워 넣습니다. (이 파일은 `.gitignore`에 등록되어 있어 커밋되지 않습니다.)
3. 실행할 때 아래처럼 `--dart-define-from-file`로 넘겨야 지도가 실제로 표시됩니다.

```bash
flutter run -d "iPhone 17" --dart-define-from-file=config/naver_map.local.json
```

키를 넘기지 않고 실행하면 앱은 정상 작동하지만 지도 자리에는 플레이스홀더만 표시됩니다.

## 실행 환경

- 네이버 지도 플러그인(`flutter_naver_map`)이 Android/iOS만 지원하므로, **반드시 iOS 시뮬레이터(또는 Android 에뮬레이터/실기기)로 실행해야** 전체 기능을 확인할 수 있습니다.
- macOS 데스크톱 타깃은 이 프로젝트에 구성되어 있지 않습니다.
- iOS 시뮬레이터는 직접 부팅한 뒤 (`open -a Simulator`) 위 실행 명령을 사용해주세요.

## 테스트

```bash
flutter analyze
flutter test
```

## 현재 상황 요약 (2026-07-10 기준)

- **프론트엔드(Flutter)만 존재**하며 백엔드(FastAPI 등)는 아직 없습니다. 회원가입/프로필 데이터는 서버로 전송되지 않고 화면 간 이동에만 쓰입니다.
- 로그인은 실제 인증 없이, 입력한 이메일 앞부분을 임시 이름으로 사용해 메인 화면으로 이동하는 임시 동작입니다. 지역은 기본값(서울특별시), 관심지역은 빈 목록으로 설정되어 지도에는 집 핀 하나만 표시됩니다. 실제 로그인 API가 생기면 이 부분을 교체해야 합니다.
- 카카오톡/구글/iCloud 로그인 버튼은 UI만 있고 실제 OAuth 연동은 되어 있지 않습니다.
- 네이버 지도 Client ID는 발급받아 로컬(`config/naver_map.local.json`, 커밋 안 됨)에 등록되어 있고, iOS 시뮬레이터에서 실제 지도·핀·줌 컨트롤까지 동작 확인을 완료했습니다.
- `flutter analyze`, `flutter test` 모두 통과하는 상태입니다.

### 다음에 이어서 할 만한 것
- FastAPI(또는 다른) 백엔드 연동 — 회원가입/로그인/프로필 저장, 실제 이메일 인증
- 카카오톡/구글/iCloud 소셜 로그인 실제 연동
- 로그인 시 실제 사용자 프로필을 불러와 메인 화면에 반영
- Android 에뮬레이터 환경 구성 (현재는 iOS로만 테스트됨)
