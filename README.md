# AICPP (모아폴리)

청년정책 지도앱. 로그인/회원가입/프로필 입력을 거쳐, 지도·리포트·프로필 3개 탭과 어디서나 떠 있는 채팅 어시스턴트(폴리)로 온통청년(청년정책) 데이터를 보여주는 Flutter 앱과 이를 감싸는 FastAPI 백엔드(`BE/`)로 구성되어 있습니다.

## 화면 흐름

```
로그인 ──(로그인)──────────────────► 메인 (하단 탭: 지도 / 리포트 / 프로필 + 우측 하단 💬 폴리)
  │
  └─(회원가입)─► 회원가입 ─► 프로필 입력 ─► 메인 (하단 탭: 지도 / 리포트 / 프로필 + 우측 하단 💬 폴리)
                                              ├─ 지도 탭 ─(마커 탭)──► 정책 목록 바텀시트 ─► 정책 상세
                                              ├─ 프로필 탭 ─(수정)──► 프로필 수정
                                              ├─ 프로필 탭 ─(관심지역 관리)──► 관심지역 관리 화면
                                              ├─ 프로필 탭 ─(로그아웃)──► 로그아웃 확인 → 로그인
                                              └─ 어느 화면에서든 ─(💬 폴리)──► 채팅 패널 (현재 화면 위에 오버레이)
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
- 성별 / 재학상태(재학·휴학·졸업·졸업유예) / 지역 / 관심지역(복수 선택) / 관심사(복수 선택, 선택 사항): 칩 선택 UI
- 관심사는 `lib/constants/interests.dart`(주거·취업·창업·교육·복지·문화·건강·금융·참여)에서 고르며, 리포트 탭의 추천 뉴스에 쓰입니다
- 학교: 텍스트 입력
- 학점: 4.5 초과 입력 차단, 소수 셋째 자리부터는 자동 반올림하여 둘째 자리까지 표시 (`lib/utils/gpa_input_formatter.dart`, 프로필 수정 화면과 공용)

### 메인 — 하단 탭 (`lib/screens/home_shell.dart`)
로그인/회원가입 완료 후 진입하는 화면. 하단에 지도 / 리포트 / 프로필 3개 탭이 있고, 우측 하단에는 탭과 무관하게 항상 떠 있는 채팅 버튼(💬 폴리)이 있습니다.

- **지도** (`lib/screens/main_screen.dart`)
  - 네이버 지도에 "지역"은 파란 핀, "관심지역"은 주황 핀으로 표시 (범례 포함), 각 핀 캡션에 오늘 신청 가능한 정책 건수 표시 (`○○ · N건`, 조회 실패 시 `○○ (조회 실패)`)
  - 지도 우측 상단에 확대/축소(+/-) 버튼 (우측 하단은 폴리 버튼 자리라 겹치지 않게 위로 옮김)
  - 핀을 탭하면 해당 지역 정책 목록 바텀시트(`lib/widgets/policy_list_sheet.dart`)가 열리고, 마감임박순/최신등록순/**지원금액 많은 순**으로 정렬 가능(`PolicyItem.supportAmount`가 지원내용 텍스트에서 금액을 정규식으로 뽑아 비교). 카드를 탭하면 정책 상세 화면(`lib/screens/policy_detail_screen.dart`)에서 지원대상/신청기간/지원내용/신청방법 확인 및 "신청 페이지로 이동" 가능
  - 제목 옆 위치추가 아이콘으로 관심지역을 바로 추가/삭제 가능 — 이 변경은 프로필 탭에도 그대로 반영됨. 이미 선택된 "지역"(거주지역)은 관심지역 목록에서 자물쇠 아이콘과 함께 체크된 채로 잠겨 다시 선택/해제할 수 없음 (`lib/widgets/toss_chip_selector.dart`의 `disabled` 옵션)
  - 네이버 지도는 Android/iOS 네이티브 SDK 기반이라 macOS 데스크톱·웹에서는 지원되지 않음 → 해당 플랫폼에서는 안내 문구가 있는 플레이스홀더로 대체
- **리포트** (`lib/screens/report_screen.dart`)
  - 거주지역 + 관심지역의 정책을 모아 매칭 자격 충족률(도넛 게이지, 자격 되는 건수 ÷ 전체 건수), 카테고리 분포(도넛 차트, **매칭된 정책만으로 계산해서 항상 100%**), 마감임박 정책 타임라인(D-day 배지)을 보여줌
  - 하단에 "추천 뉴스" 섹션: 프로필의 관심사를 기반으로 백엔드가 뉴스를 추천 (아래 "폴리 · 채팅/뉴스 AI" 참고). 관심사가 없으면 설정을 유도하는 문구와 링크 표시
  - 관심지역이 하나도 없으면 관심지역 추가를 유도하는 빈 상태 화면 노출
- **프로필** (`lib/screens/profile_screen.dart`)
  - 이름·이메일(아바타), 나이·성별·학교·학점·재학상태·지역, 관심지역(칩) + "관리" 링크 → 관심지역 관리 화면(`lib/screens/interested_region_screen.dart`, 거주지역은 잠금 처리)
  - 우측 상단 연필 아이콘 → 프로필 수정 화면 (`lib/screens/edit_profile_screen.dart`)
    - 이름/이메일/생년월일(캘린더)/성별/학교/학점/재학상태/지역/관심사 수정 가능
  - 하단 "로그아웃" → 확인 다이얼로그 후 로그인 화면으로 이동 (스택 초기화)

### 폴리 — 플로팅 채팅 어시스턴트 (`lib/widgets/chat_panel.dart`)
- 탭이 아니라 `HomeShell` 우측 하단에 항상 떠 있는 버튼입니다. 탭하면 현재 보고 있는 화면(지도/리포트/프로필/정책 상세 등 어디든)은 그대로 둔 채 작은 채팅 패널이 그 위에 오버레이로 뜹니다.
- 이걸 가능하게 하려고 `HomeShell`이 자체 중첩 `Navigator`를 가지고 있습니다 — 탭 안에서 일어나는 화면 전환(정책 상세, 관심지역 관리, 프로필 수정 등)은 전부 이 중첩 Navigator 안에서만 일어나서, 바깥의 폴리 버튼/패널을 덮지 않습니다. 로그아웃만 예외로 `Navigator.of(context, rootNavigator: true)`를 써서 앱 전체(HomeShell 포함)를 로그인 화면으로 교체합니다.
- 대화 이력 저장/복원 가능 ("새 대화"로 현재 대화를 이력에 보관, "대화 이력" 아이콘으로 이전 대화 다시 열기). 패널을 닫아도 대화 내용은 유지되고, 로그아웃하면 초기화됩니다.
- **실제 Claude API로 자연어 응답을 생성합니다** (아래 "백엔드" 참고) — 규칙 기반 키워드 추출은 백엔드가 관련 정책을 찾아오는 1차 검색에만 쓰이고, 최종 답변은 Claude가 그 정책 데이터만 근거로 생성합니다.

`UserProfile` (`lib/models/user_profile.dart`)은 나이를 직접 저장하지 않고 `birthDate`(생년월일)만 저장하며, `age`는 거기서 계산되는 getter입니다. `interestedRegions`(지역)와 `interests`(주제 관심사)는 별개 필드입니다. `copyWith`로 일부 필드만 갱신할 수 있습니다.

## 백엔드 (`BE/`)

FastAPI 서버. 정부의 [온통청년](https://www.youthcenter.go.kr) 청년정책 Open API를 감싸는 프록시 기능에 더해, Claude(Anthropic API)와 NewsAPI를 엮은 두 개의 AI 기능을 제공합니다.

### 정책 검색 — `GET /api/ontong-policy/search`
- `name`(정책명 → `plcyNm`)과 `topic`(정책키워드 → `plcyKywdNm`) 두 파라미터가 실제 정부 API에서 동작하는 것으로 확인된 필터입니다. `query`/`keyword`/`business_type`/`region_code`는 코드는 남아있지만 정부 API가 인식하지 못해 무시됩니다 (`BE/app/api/endpoints/ontong_policy_endpoint.py`, `BE/app/services/ontong_policy_service.py` 참고).
- `BE/.env`에 `ONTONG_API_KEY`를 넣어야 동작합니다 ([공공데이터포털](https://www.data.go.kr)에서 발급).
- 지역(zipCd) 단위 필터링은 전국 약 256개 법정동 코드 테이블이 필요해 아직 구현하지 않았고, 대신 지역명을 `plcyNm`으로 검색하는 방식(정책명에 지역명이 포함된 경우만 매칭)을 실용적 근사치로 쓰고 있습니다.
- 정부 API가 간헐적으로 느리거나 502를 내는 걸 반복적으로 확인해서, `PolicyApiService.search()`는 실패 시 한 번 자동 재시도합니다. 그래도 실패하면 앱에 "조회 실패"로 표시됩니다 — 대부분 몇 초 뒤 재시도하면 해결되는 정부 API 쪽의 일시적 문제입니다.

### 채팅(폴리) — `POST /api/chat/ask`
- 질문 + 프로필(지역/재학상태/나이)을 받아서: (1) `BE/app/services/keyword_extractor.py`의 주제 키워드 사전으로 질문에서 키워드를 찾아 `topic` 검색, 없으면 거주지역으로 검색 → (2) 검색된 정책(오늘 기준 신청 가능한 것만) + 프로필을 Claude에게 근거로 주고 "이 안에서만 답하라"고 지시 → (3) 생성된 답변을 반환 (`BE/app/services/chat_service.py`)
- 검색된 정책의 URL을 Claude가 직접 만들지 않고, 실제 검색 결과에서 그대로 매핑해서 반환하므로 잘못된 링크가 생기지 않습니다.

### 추천 뉴스 — `GET /api/news/recommendations?interests=주거&interests=취업`
- 관심사로 NewsAPI(`/v2/everything`, `language=ko`)에서 뉴스 후보 20건을 가져온 뒤, Claude에게 그 후보 목록 + 관심사를 주고 가장 관련 있는 걸 최대 5개 고르게 합니다 (`BE/app/services/news_service.py`). Claude는 후보의 인덱스와 추천 이유만 반환하고, 실제 제목/URL/출처는 원본 기사에서 그대로 매핑합니다 (역시 URL 환각 방지).
- `BE/.env`에 `NEWSAPI_KEY`도 필요합니다 ([newsapi.org](https://newsapi.org)에서 발급, 무료 플랜은 최근 1개월 기사만 검색 가능).

### 공통
- 위 두 AI 기능 모두 `BE/.env`의 `ANTHROPIC_API_KEY`가 필요합니다 ([console.anthropic.com](https://console.anthropic.com)에서 발급 — claude.ai 채팅 구독과는 별개로 과금되는 API 크레딧이 있어야 동작합니다).
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
- 지도/리포트/폴리 채팅의 데이터를 보려면 백엔드(`BE/`)가 `127.0.0.1:8000`에서 함께 떠 있어야 합니다. 백엔드 없이 실행하면 각 화면에 연결 실패 안내가 표시됩니다.
- 폴리 채팅과 추천 뉴스는 백엔드가 떠 있어도 `BE/.env`에 유효한 `ANTHROPIC_API_KEY`(크레딧 포함)가 없으면 "AI 응답 생성에 실패했어요" 에러가 뜹니다.

## 테스트

```bash
# Flutter (40개)
flutter analyze
flutter test

# 백엔드 (17개)
cd BE && source venv/bin/activate && python3 -m unittest discover -s tests -v
```

## 현재 상황 요약 (2026-07-17 기준)

- 프론트엔드(Flutter) + 백엔드(FastAPI, `BE/`)가 모두 존재하며, 지도/리포트/채팅이 실제 온통청년 정책 데이터 + Claude + NewsAPI를 백엔드 경유로 가져옵니다. 다만 회원가입/프로필 데이터 자체는 여전히 서버에 저장되지 않고 앱 메모리 상에서만 유지됩니다 (앱을 완전히 재시작하면 사라짐).
- 로그인은 실제 인증 없이, 입력한 이메일 앞부분을 임시 이름으로 사용해 메인 화면으로 이동하는 임시 동작입니다. 지역은 기본값(서울특별시), 생년월일·관심지역·관심사 등은 비어있는 상태로 시작합니다. 실제 로그인 API가 생기면 이 부분을 교체해야 합니다.
- 카카오톡/구글/iCloud 로그인 버튼은 UI만 있고 실제 기능은 없습니다.
- 폴리 채팅과 추천 뉴스는 진짜 Claude API로 동작하지만, **API 크레딧이 없으면 실패**합니다. 크레딧은 claude.ai 구독과 무관하게 [console.anthropic.com](https://console.anthropic.com)에서 별도로 충전해야 합니다.
- 정책 목록/마커/리포트는 모두 오늘 날짜 기준으로 신청 가능한(`PolicyItem.isCurrentlyOpen`) 정책만 필터링해서 보여줍니다. 지역 필터링은 정책명 검색으로 근사하는 수준이라, 지역명이 정책명에 없으면 실제로는 그 지역 정책이어도 안 잡힐 수 있습니다.
- "지원금액 많은 순" 정렬은 지원내용 자유 텍스트에서 정규식으로 금액을 뽑아내는 방식이라, 텍스트에 금액이 명시되지 않은 정책(예: "임대주택 제공")은 정렬에서 맨 뒤로 밀립니다.
- 관심지역/관심사는 지도·프로필 탭 어디서 추가/삭제해도 서로 동기화되지만, `HomeShell`이 메모리에서만 들고 있는 상태라 로그아웃하거나 앱을 재시작하면 초기화됩니다.
- 네이버 지도 Client ID는 발급받아 로컬(`config/naver_map.local.json`, 커밋 안 됨)에 등록되어 있고, iOS 시뮬레이터에서 실제 지도·핀·줌 컨트롤까지 동작 확인을 완료했습니다.
- `flutter analyze`, `flutter test`(40개), 백엔드 `unittest`(17개) 모두 통과하는 상태입니다.

### 다음에 이어서 할 만한 것
- 회원가입/로그인/프로필을 실제로 저장하는 백엔드 연동 (현재 백엔드는 온통청년/Claude/NewsAPI 프록시 기능만 있음), 실제 이메일 인증
- 카카오톡/구글/iCloud 소셜 로그인 실제 연동
- 지역(zipCd) 기반 정확한 필터링 — 법정동 코드 테이블을 구축해서 정책명 검색 근사치를 대체
- 백엔드의 나머지 파라미터(`query`/`keyword`/`business_type`/`region_code`)가 정부 API에서 무시되는 문제 — 필요해지면 올바른 파라미터명으로 교체
- 지원금액 정규식 파싱의 정확도 개선 (현재는 만원/억원 단위만 지원, 다른 표기는 놓칠 수 있음)
- 로그인 시 실제 사용자 프로필을 불러와 메인 화면에 반영 (현재는 임시 프로필)
- Android 에뮬레이터 환경 구성 (현재는 iOS로만 테스트됨)
