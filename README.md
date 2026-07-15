# AICPP (모아폴리)

청년정책 지도앱. 로그인/회원가입/프로필 입력을 거쳐, 지도·리포트·채팅·프로필 4개 탭으로 온통청년(청년정책) 데이터를 보여주는 Flutter 앱과 이를 감싸는 FastAPI 백엔드(`BE/`)로 구성되어 있습니다.

## 화면 흐름

```
로그인 ──(로그인)──────────────────► 메인 (하단 탭: 지도 / 리포트 / 채팅 / 프로필)
  │
  └─(회원가입)─► 회원가입 ─► 프로필 입력 ─► 메인 (하단 탭: 지도 / 리포트 / 채팅 / 프로필)
                                              ├─ 지도 탭 ─(마커 탭)──► 정책 목록 바텀시트 ─► 정책 상세
                                              ├─ 프로필 탭 ─(수정)──► 프로필 수정
                                              ├─ 프로필 탭 ─(관심지역 관리)──► 관심지역 관리 화면
                                              └─ 프로필 탭 ─(로그아웃)──► 로그아웃 확인 → 로그인
```

### 로그인 (`lib/screens/login_screen.dart`)
- 이메일/비밀번호 입력, 토스 스타일 UI
- 카카오톡/구글/iCloud 로그인 아이콘 (자리만 마련 — 탭하면 "준비 중" 안내만 뜨고 실제 연동은 안 됨)
- 화면 맨 아래에 "회원가입" 링크
- 로그인을 누르면 실제 인증 없이 바로 메인 화면(하단 탭)으로 이동 (아래 "현재 상황 요약" 참고)

### 회원가입 (`lib/screens/signup_screen.dart`)
- 이름 / 이메일 / 비밀번호 / 비밀번호 확인
- 이메일 형식, 비밀번호 8자 이상, 비밀번호 일치 여부를 제출 시점에 검증
- 백엔드 없이 로컬 형식 검증만 수행 (이메일이 실제 존재하는지는 확인 불가)

### 프로필 입력 (`lib/screens/profile_setup_screen.dart`)
- 생년월일: 달력에서 선택 → 만 나이 자동 계산 (`lib/utils/age.dart`)
- 성별 / 재학상태(재학·휴학·졸업·졸업유예) / 지역 / 관심지역(복수 선택): 칩 선택 UI
- 학교: 텍스트 입력
- 학점: 4.5 초과 입력 차단, 소수 셋째 자리부터는 자동 반올림하여 둘째 자리까지 표시 (`lib/utils/gpa_input_formatter.dart`, 프로필 수정 화면과 공용)

### 메인 — 하단 탭 (`lib/screens/home_shell.dart`)
로그인/회원가입 완료 후 진입하는 화면. 하단에 지도 / 리포트 / 채팅 / 프로필 4개 탭이 있습니다.

- **지도** (`lib/screens/main_screen.dart`)
  - 네이버 지도에 "지역"은 파란 핀, "관심지역"은 주황 핀으로 표시 (범례 포함), 각 핀 캡션에 오늘 신청 가능한 정책 건수 표시 (`○○ · N건`, 조회 실패 시 `○○ (조회 실패)`)
  - 핀을 탭하면 해당 지역 정책 목록 바텀시트(`lib/widgets/policy_list_sheet.dart`)가 열리고, 마감임박순/최신등록순/내게 맞는 것만 정렬 가능. 카드를 탭하면 정책 상세 화면(`lib/screens/policy_detail_screen.dart`)에서 지원대상/신청기간/지원내용/신청방법 확인 및 "신청 페이지로 이동" 가능
  - 지도 우측 하단에 확대/축소(+/-) 버튼
  - 제목 옆 위치추가 아이콘으로 관심지역을 바로 추가/삭제 가능 — 이 변경은 프로필 탭에도 그대로 반영됨. 이미 선택된 "지역"(거주지역)은 관심지역 목록에서 자물쇠 아이콘과 함께 체크된 채로 잠겨 다시 선택/해제할 수 없음 (`lib/widgets/toss_chip_selector.dart`의 `disabled` 옵션)
  - 네이버 지도는 Android/iOS 네이티브 SDK 기반이라 macOS 데스크톱·웹에서는 지원되지 않음 → 해당 플랫폼에서는 안내 문구가 있는 플레이스홀더로 대체
- **리포트** (`lib/screens/report_screen.dart`)
  - 거주지역 + 관심지역의 정책을 모아 매칭 자격 충족률(도넛 게이지), 카테고리 분포(도넛 차트), 마감임박 정책 타임라인(D-day 배지)을 보여줌
  - 관심지역이 하나도 없으면 관심지역 추가를 유도하는 빈 상태 화면 노출
- **채팅** (`lib/screens/chat_screen.dart`) — 정책 어시스턴트
  - 빈 상태에서는 추천 질문 칩 노출, 탭하면 바로 전송. 대화 이력 저장/복원 가능 ("새 대화"로 현재 대화를 이력에 보관, "대화 이력" 아이콘으로 이전 대화 다시 열기)
  - 사용자/어시스턴트 말풍선 구조이며, 어시스턴트 응답에는 "컨텍스트: 지역 · 재학상태 · 나이" 태그가 붙음
  - **LLM 없이 규칙 기반 키워드 추출로 질문을 처리** (`lib/utils/keyword_extractor.dart`): 주거·취업·창업·교육·복지 등 정책 주제 키워드 사전에서 질문에 포함된 키워드를 찾아 백엔드의 `topic`(정책키워드, `plcyKywdNm`) 검색으로 연결. 키워드가 없지만 질문처럼 보이면(2자 이상 + 한글/영문 포함) 거주지역 + 프로필 조건(연령 등)으로 폴백 검색하고, "." "1" 같은 의미 없는 입력은 API 호출 없이 바로 안내 메시지 반환
  - `lib/utils/chat_context.dart`에는 프로필 기반 컨텍스트 라벨(`buildUserContextLabel`, 사용 중)과 추후 진짜 LLM을 붙일 때 쓸 시스템 프롬프트(`buildSystemPrompt`, 아직 미사용)가 준비되어 있음
- **프로필** (`lib/screens/profile_screen.dart`)
  - 이름·이메일(아바타), 나이·성별·학교·학점·재학상태·지역, 관심지역(칩) + "관리" 링크 → 관심지역 관리 화면(`lib/screens/interested_region_screen.dart`, 거주지역은 잠금 처리)
  - 우측 상단 연필 아이콘 → 프로필 수정 화면 (`lib/screens/edit_profile_screen.dart`)
    - 이름/이메일/생년월일(캘린더)/성별/학교/학점/재학상태/지역 수정 가능
  - 하단 "로그아웃" → 확인 다이얼로그 후 로그인 화면으로 이동 (스택 초기화)

`UserProfile` (`lib/models/user_profile.dart`)은 나이를 직접 저장하지 않고 `birthDate`(생년월일)만 저장하며, `age`는 거기서 계산되는 getter입니다. `copyWith`로 일부 필드만 갱신할 수 있습니다.

## 백엔드 (`BE/`)

FastAPI로 만든 얇은 프록시 서버로, 정부의 [온통청년](https://www.youthcenter.go.kr) 청년정책 Open API를 감싸서 앱에 필요한 형태로 내려줍니다.

- `POST`가 아니라 `GET /api/ontong-policy/search` 하나만 있고, `name`(정책명 → `plcyNm`)과 `topic`(정책키워드 → `plcyKywdNm`) 두 파라미터가 실제 정부 API에서 동작하는 것으로 확인된 필터입니다. `query`/`keyword`/`business_type`/`region_code`는 코드는 남아있지만 정부 API가 인식하지 못해 무시됩니다 (`BE/app/api/endpoints/ontong_policy_endpoint.py`, `BE/app/services/ontong_policy_service.py` 참고).
- `BE/.env`에 `ONTONG_API_KEY`를 넣어야 동작합니다 (`.gitignore`에 등록되어 커밋되지 않음, [공공데이터포털](https://www.data.go.kr)에서 온통청년 API 키 발급).
- 지역(zipCd) 단위 필터링은 전국 약 256개 법정동 코드 테이블이 필요해 아직 구현하지 않았고, 대신 지역명을 `plcyNm`으로 검색하는 방식(정책명에 지역명이 포함된 경우만 매칭)을 실용적 근사치로 쓰고 있습니다.
- 실행:
  ```bash
  cd BE
  source venv/bin/activate
  uvicorn main:app --reload
  ```
- 테스트:
  ```bash
  cd BE
  source venv/bin/activate
  python3 -m unittest discover -s tests -v
  ```
- 앱은 `lib/config/api_config.dart`의 `policyApiBaseUrl`(기본 `http://127.0.0.1:8000`)로 백엔드를 호출합니다. iOS 시뮬레이터에서 로컬 HTTP 호출이 가능하도록 `ios/Runner/Info.plist`에 `localhost`/`127.0.0.1` ATS 예외를 추가해뒀습니다.
- 정부 API가 간헐적으로 느리거나 타임아웃되는 걸 확인해서, `PolicyApiService.search()`는 실패 시 한 번 자동 재시도합니다.

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
- 지도/리포트/채팅 탭의 정책 데이터를 보려면 백엔드(`BE/`)가 `127.0.0.1:8000`에서 함께 떠 있어야 합니다. 백엔드 없이 실행하면 각 탭에 연결 실패 안내가 표시됩니다.

## 테스트

```bash
# Flutter
flutter analyze
flutter test

# 백엔드
cd BE && source venv/bin/activate && python3 -m unittest discover -s tests -v
```

## 현재 상황 요약 (2026-07-15 기준)

- 프론트엔드(Flutter) + 백엔드(FastAPI, `BE/`)가 모두 존재하며, 지도/리포트/채팅 탭이 실제 온통청년 정책 데이터를 백엔드 경유로 가져옵니다. 다만 회원가입/프로필 데이터 자체는 여전히 서버에 저장되지 않고 앱 메모리 상에서만 유지됩니다 (앱을 완전히 재시작하면 사라짐).
- 로그인은 실제 인증 없이, 입력한 이메일 앞부분을 임시 이름으로 사용해 메인 화면으로 이동하는 임시 동작입니다. 지역은 기본값(서울특별시), 생년월일·관심지역 등은 비어있는 상태로 시작합니다. 실제 로그인 API가 생기면 이 부분을 교체해야 합니다.
- 카카오톡/구글/iCloud 로그인 버튼은 UI만 있고 실제 기능은 없습니다.
- 채팅 탭은 진짜 LLM이 아니라 **규칙 기반 키워드 추출**로 동작합니다 (위 "채팅" 섹션 참고). `buildSystemPrompt`는 실제 LLM을 붙일 때를 대비해 준비만 해둔 상태로 아직 사용되지 않습니다.
- 정책 목록/마커/리포트는 모두 오늘 날짜 기준으로 신청 가능한(`PolicyItem.isCurrentlyOpen`) 정책만 필터링해서 보여줍니다. 지역 필터링은 정책명 검색으로 근사하는 수준이라, 지역명이 정책명에 없으면 실제로는 그 지역 정책이어도 안 잡힐 수 있습니다.
- 관심지역은 지도/프로필 탭 어디서 추가/삭제해도 서로 동기화되지만, `HomeShell`이 메모리에서만 들고 있는 상태라 로그아웃하거나 앱을 재시작하면 초기화됩니다.
- 네이버 지도 Client ID는 발급받아 로컬(`config/naver_map.local.json`, 커밋 안 됨)에 등록되어 있고, iOS 시뮬레이터에서 실제 지도·핀·줌 컨트롤까지 동작 확인을 완료했습니다.
- `flutter analyze`, `flutter test`(34개), 백엔드 `unittest`(5개) 모두 통과하는 상태입니다.

### 다음에 이어서 할 만한 것
- 회원가입/로그인/프로필을 실제로 저장하는 백엔드 연동 (현재 백엔드는 온통청년 프록시 기능만 있음), 실제 이메일 인증
- 카카오톡/구글/iCloud 소셜 로그인 실제 연동
- 채팅에 진짜 LLM 연동 (Claude API 등) — 키워드 추출 방식은 1차 개선일 뿐, 자연어 이해 수준으로 가려면 필요
- 지역(zipCd) 기반 정확한 필터링 — 법정동 코드 테이블을 구축해서 정책명 검색 근사치를 대체
- 백엔드의 나머지 파라미터(`query`/`keyword`/`business_type`/`region_code`)가 정부 API에서 무시되는 문제 — 필요해지면 올바른 파라미터명으로 교체
- 로그인 시 실제 사용자 프로필을 불러와 메인 화면에 반영 (현재는 임시 프로필)
- Android 에뮬레이터 환경 구성 (현재는 iOS로만 테스트됨)
