# AICPP (모아폴리)

청년정책 지도앱. 로그인/회원가입/프로필 입력을 거쳐, 지도·리포트·프로필 3개 탭과 어디서나 떠 있는 채팅 어시스턴트(폴리)로 온통청년(청년정책) 데이터를 보여주는 Flutter 앱과 이를 감싸는 FastAPI 백엔드(`BE/`)로 구성되어 있습니다. 백엔드는 정부 API 실시간 조회에 더해, 별도로 구축한 지원금액 추출 파이프라인의 결과를 Supabase에서 가져와 보강합니다. 스크랩한 정책은 마감 D-7/D-3/D-1에 기기 로컬 알림으로 리마인드해주고, 웹으로도 빌드해서 배포할 수 있습니다.

**웹 데모**: 백엔드([Render](https://aicpp.onrender.com)) + 프론트([Vercel](https://aicpp-mu.vercel.app))가 실제로 배포돼 있어 설치 없이 바로 접속해볼 수 있습니다 (둘 다 무료 플랜 — 아래 "웹으로 빌드/배포" 참고).

## 화면 흐름

```
로그인 ──(로그인)──────────────────► 메인 (하단 탭: 지도 / 리포트 / 프로필 + 우측 하단 💬 폴리)
  │
  └─(회원가입)─► 회원가입 ─► 프로필 입력 ─(저장 완료)─► 로그인 ──(로그인)──► 메인 (하단 탭: 지도 / 리포트 / 프로필 + 우측 하단 💬 폴리)
                                                                             ├─ 지도 탭 ─(마커/지역 탭)──► 정책 목록 바텀시트 ─► 정책 상세
                                                                             ├─ 프로필 탭 ─(수정)──► 프로필 수정
                                                                             ├─ 프로필 탭 ─(로그아웃)──► 로그아웃 확인 → 로그인
                                                                             └─ 지도/리포트 탭 ─(💬 폴리)──► 채팅 패널 (현재 화면 위에 오버레이, 프로필 탭엔 없음)
```

### 로그인 (`lib/screens/login_screen.dart`)
- 이메일/비밀번호 입력, 토스 스타일 UI
- 카카오톡/구글/Apple 로그인 버튼 — 아이콘은 실제 브랜드 SVG(`assets/icons/google_logo.svg`: 구글 공식 4색 로고, `assets/icons/kakaotalk_logo.svg`: 카카오톡 실제 앱 아이콘, `flutter_svg`로 렌더링)를 쓰지만, 탭하면 "준비 중" 안내만 뜨고 **실제 소셜 로그인 연동은 아직 안 됨** (각 사 개발자 콘솔에서 앱 등록/자격증명 발급이 필요 — 아래 "다음에 이어서 할 만한 것" 참고)
- 화면 맨 아래에 "회원가입" 링크
- **실제 Supabase Auth로 로그인합니다** (`lib/services/auth_api_service.dart` → 백엔드 `POST /api/v1/auth/login`). 성공하면 저장된 프로필을 조회해서(`GET /api/v1/profile`), 있으면 메인 화면으로, 없으면 프로필 입력 화면으로 이동합니다.

### 회원가입 (`lib/screens/signup_screen.dart`)
- 이름 / 이메일 / 비밀번호 / 비밀번호 확인
- 이메일 형식, 비밀번호 8자 이상, 비밀번호 일치 여부를 제출 시점에 검증
- **실제 Supabase Auth에 계정을 생성합니다** (`POST /api/v1/auth/signup`) — 이 프로젝트는 이메일 확인을 요구하도록 설정돼 있는데, 데모에서 실제 메일함을 거치지 않도록 가입 직후 서버가 관리자 API로 즉시 확인 처리한 뒤 바로 로그인 세션을 돌려줍니다 (`BE/app/services/auth_service.py`).

### 프로필 입력 (`lib/screens/profile_setup_screen.dart`)
- 생년월일: 달력에서 선택 → 만 나이 자동 계산 (`lib/utils/age.dart`)
- 성별 / 재학상태 / 지역 / 관심지역(**최대 2개**) / 관심사(복수 선택, 선택 사항): 칩 선택 UI
  - 관심지역에서는 이미 "지역"으로 고른 곳이 자물쇠 아이콘과 함께 잠겨 다시 선택할 수 없고, 2개를 다 채우면 나머지도 같은 방식으로 잠깁니다 — 너무 많이 고르면 지도·리포트에 정보가 한꺼번에 몰려 보이는 걸 막기 위함 (`lib/widgets/toss_chip_selector.dart`의 `disabled` 옵션, 지도 탭의 관심지역 추가 시트에도 동일하게 적용)
  - 성별을 "남성"으로 고르면 바로 아래에 **병역** 선택지(군필/미필/공익/면제)가 나타납니다(여성이면 안 보이고 값도 저장 안 됨) — 정부 정책 중 병역 조건을 확인하는 것들이 있어서 프로필에 데이터만 우선 받아두는 단계이고, 실제 정책 매칭에는 아직 안 씀 (구조화된 API 필드가 없어서 텍스트 키워드 매칭이 필요함 — 아래 "다음에 이어서 할 만한 것" 참고)
  - 재학상태에 **"해당없음"**을 추가했습니다 — 대학에 다니지 않는 사용자를 위한 옵션으로, 고르면 학교/학점 입력 필드 자체가 사라지고 입력해뒀던 값도 지워집니다. 학교 입력란 바로 아래에 "대학에 다니지 않는다면, 아래 재학상태에서 '해당없음'을 선택하면 학교·학점 입력을 건너뛸 수 있어요" 안내를 넣어서, 학교 입력란부터 마주치는 사용자가 재학상태까지 내려가보기 전에 미리 알 수 있게 했습니다 (프로필 수정 화면에도 동일하게 적용)
- 관심사는 `lib/constants/interests.dart`(주거·취업·창업·교육·**복지·문화**·건강·금융·국제교류, 9개 — 복지와 문화는 별개 관심사로 분리)에서 고르며, 리포트 탭의 추천 뉴스·챗봇 컨텍스트뿐 아니라 지도 탭 정책 목록의 "관심사 매칭" 필터/뱃지에도 쓰입니다
- 학교: 전국 4년제 대학교(234개, `lib/constants/universities.dart`, 위키백과 기준) 자동완성 입력(`lib/widgets/toss_autocomplete_field.dart`) — 목록에 없는 학교명도 직접 입력 가능
- 학점: 4.5 초과 입력 차단, 소수 셋째 자리부터는 자동 반올림하여 둘째 자리까지 표시 (`lib/utils/gpa_input_formatter.dart`, 프로필 수정 화면과 공용)
- 가구원수 + 월소득(만원 단위)을 입력하면 2026년 기준중위소득(보건복지부 고시, `lib/constants/median_income.dart`) 대비 비율을 자동 계산해서 보여줍니다 (`UserProfile.incomePercent`) — 소득 구간을 직접 고르지 않고 실제 소득 정보로부터 역산하는 방식입니다
- "완료"를 누르면 **실제로 백엔드에 저장됩니다** (`lib/services/profile_api_service.dart` → `POST/PATCH /api/v1/profile` + `PATCH /api/v1/profile/interest-regions`). 지역은 화면에선 "서울특별시" 같은 한글 이름으로 고르지만, 백엔드 `regions` 테이블은 숫자 코드(예: 서울 `11`)로 FK 제약이 걸려 있어서 `lib/constants/regions.dart`의 `kRegionCodeByName`/`kRegionNameByCode`로 저장 직전/조회 직후에 변환합니다. 프로필 수정 화면(`edit_profile_screen.dart`)도 동일하게 저장됩니다.
- 저장 후에는 바로 메인으로 들어가지 않고 **로그인 화면으로 돌아갑니다** — 방금 입력한 정보를 메모리에서 그대로 이어쓰는 대신, 실제로 로그인해서 방금 저장된 프로필을 서버에서 다시 불러오는 걸 확인시키기 위함입니다.

### 메인 — 하단 탭 (`lib/screens/home_shell.dart`)
로그인/회원가입 완료 후 진입하는 화면. 하단에 지도 / 리포트 / 프로필 3개 탭이 있고, 지도·리포트 탭에서는 우측 하단에 항상 떠 있는 채팅 버튼(💬 폴리)이 있습니다 (프로필 탭에서는 빠져있음).

- **지도** (`lib/screens/main_screen.dart`)
  - 네이버 지도에 "내 지역"은 파란 핀, "관심지역"은 주황 핀으로 표시 (범례 포함), 각 핀 캡션에 오늘 신청 가능한 정책 건수 표시 (`○○ · N건`, 조회 실패 시 `○○ (조회 실패)`)
  - 지도 배경은 washed-out 처리(`lightness: 0.7`, 건물 레이어 끔)해서 도로/지명은 흐리게, 마커는 도드라지게 보이도록 단순화했습니다
  - 지도 우측 상단에 확대/축소(+/-) 버튼 (우측 하단은 폴리 버튼 자리라 겹치지 않게 위로 옮김)
  - 네이버 지도는 Android/iOS 네이티브 SDK 기반이라 웹에서는 지원되지 않습니다. 그래서 **웹 빌드는 `flutter_map` + OpenStreetMap 타일로 만든 별도 지도(`lib/widgets/web_region_map.dart`)를 씁니다** — `kIsWeb`으로 분기해서 네이티브 코드는 그대로 두고 웹에서만 이걸 씁니다. 오른쪽 상단 +/- 확대·축소 버튼, 지역명·건수 2줄 마커, 트랙패드 회전 제스처 비활성화(회전만 끄지 않으면 지구본을 돌리는 것처럼 보이는 문제가 있었음)까지 네이티브 지도와 비슷한 사용감을 맞췄습니다. macOS 데스크톱 타깃은 이 프로젝트에 구성돼 있지 않습니다.
  - 핀(웹은 지도 마커)을 탭하면 해당 지역 정책 목록 바텀시트(`lib/widgets/policy_list_sheet.dart`)가 열립니다
    - 목록은 기본적으로 **회원이 실제로 자격 되는 정책만**(나이·소득 조건 충족, `PolicyItem.matchesProfile`) 보여줍니다 — 이 안에서 카테고리 칩과 "내 관심사만" 칩으로 더 좁혀볼 수 있고, 마감임박순/최신등록순/지원금액 많은 순 정렬도 가능합니다
      - 카테고리 칩은 **회원가입/프로필/프로필 수정/리포트가 전부 같이 쓰는 `kInterests`(9개: 주거·취업·창업·교육·복지·문화·건강·금융·국제교류)** 그대로입니다 — 예전엔 정부 API의 자체 분류(`lclsfNm`, 일자리/주거/교육/복지문화/참여권리 5개)를 따로 썼는데, 그중 "참여권리"는 관심사 어디에도 대응이 안 되고 "일자리"도 취업/창업으로 안 갈려서 화면마다 다른 카테고리 체계가 보이는 문제가 있었습니다. 지금은 정부의 `mclsfNm`(중분류, 예: 취업·창업·미래역량강화·주택 및 거주지·청년국제교류 등)을 `kInterests` 9개로 직접 매핑하고(`PolicyItem.categoryLabel`, 실제 정책 약 2,649건 전수 조사로 검증), 어느 관심사에도 안 맞는 중분류(청년참여/정책인프라구축/권익보호 등 참여권리 계열)는 카테고리 없음으로 남겨서 "참여권리" 자체가 더 이상 존재하지 않습니다. "취약계층 및 금융지원"/"문화활동 및 생활지원"처럼 한 중분류가 두 개념을 같이 이름 붙인 경우만 텍스트 키워드로 갈라 판단합니다(안 갈리면 복지가 기본값). 100% 정확한 구분은 아닙니다.
    - "내 관심사만"을 켜면 프로필 관심사와 겹치는 정책에 "관심사: 주거" 같은 뱃지가 카드에 뜹니다 (`PolicyItem.matchingInterests`) — 안 켜져 있을 땐 뱃지도 안 뜹니다
    - 지원금액은 **Supabase 파이프라인이 사람 검토까지 마친 정확한 값(`PolicyItem.preciseSupportAmount`)이 있는 정책만** 표시합니다 — 예전엔 없으면 지원내용 텍스트를 정규식으로 추정해 "(추정)"이라고 표시했지만, 검증 안 된 숫자를 실제 결정에 쓰일 화면에 보여주는 게 위험하다고 판단해 규칙을 바꿨습니다. 그래서 지금은 지원금액이 아예 안 보이는 카드도 있습니다 (아직 파이프라인이 안 훑은 최근 등록 정책 등)
  - 카드를 탭하면 정책 상세 화면(`lib/screens/policy_detail_screen.dart`)에서 지원대상/신청기간/지원금액/지원내용/신청방법 확인, 스크랩(북마크) 토글, "신청 페이지로 이동" 가능
    - 신청기간은 정해진 기간이 없는 상시/연중 모집 정책도 "상시모집"으로 통일해서 표시하고, 사업기간(시작일~종료일)이 있는 경우 정확한 범위로 계산합니다
    - **스크랩하면 마감 D-7/D-3/D-1에 기기 로컬 알림이 예약됩니다** (아래 "마감 리마인더" 참고), 스크랩 해제하면 예약도 취소됩니다
  - 제목 옆 위치추가 아이콘으로 관심지역을 바로 추가/삭제 가능
- **리포트** (`lib/screens/report_screen.dart`)
  - 거주지역 + 관심지역의 정책을 모아 매칭 자격 충족률(도넛 게이지, 나이·소득 조건까지 반영해 자격 되는 건수 ÷ 전체 건수), 카테고리 분포(도넛 차트, 매칭된 정책만으로 계산 — `categoryLabel`로 정규화된 값을 쓰기 때문에 같은 카테고리의 다른 표기가 따로 집계되지 않고, 위 지도 탭과 같은 로직이라 복지/문화도 여기서 자동으로 나뉘어 집계됩니다), 마감임박 정책 타임라인(D-day 배지)을 보여줌
  - 충족률이 100%가 아니면 그 아래에 이유를 구체적으로 보여줍니다 — "회원님 나이(만 26세) 기준으로 나이 조건이 맞지 않는 정책 N건", "회원님 소득(중위소득 약 85%) 기준으로 소득 조건이 맞지 않는 정책 N건", 소득 정보 미입력 시 입력 유도 문구까지. "해당 정책 N건 보기" 링크를 누르면 실제로 어떤 정책들이 안 맞는지 목록을 바텀시트로 볼 수 있고, 탭하면 정책 상세로 이동합니다
  - 하단 "추천 뉴스" 섹션: 프로필의 관심사를 기반으로 백엔드가 뉴스를 추천하며, 추천 개수가 매칭된 정책 건수에 맞춰 동적으로 조정됩니다. 관심사가 없으면 설정을 유도하는 문구와 링크 표시
  - 관심지역이 하나도 없으면 관심지역 추가를 유도하는 빈 상태 화면 노출
- **프로필** (`lib/screens/profile_screen.dart`)
  - 이름·이메일(아바타), 나이·성별·(남성이면)병역·학교·학점·재학상태·지역, 기준중위소득 구간
  - 관심사(칩) + "관리" 링크 → 프로필 수정 화면
  - 스크랩한 정책 건수 + 화살표 → 스크랩 목록 화면(`lib/screens/scrapped_policies_screen.dart`)
  - 우측 상단 연필 아이콘 → 프로필 수정 화면 (`lib/screens/edit_profile_screen.dart`)
    - 이름/이메일/생년월일(캘린더)/성별/병역(남성일 때만)/학교(자동완성)/학점/재학상태("해당없음" 포함)/지역/관심사/가구원수/월소득 수정 가능
  - 하단 "로그아웃" → 확인 다이얼로그 후 로그인 화면으로 이동 (스택 초기화)
  - 관심지역 섹션은 뺐습니다 — 지도 탭에서 이미 지역별로 색/건수를 충분히 구분해서 보여주기 때문에 중복이라 판단 (코드는 삭제하지 않고 주석으로만 남겨뒀습니다)

### 폴리 — 플로팅 채팅 어시스턴트 (`lib/widgets/chat_panel.dart`)
- 탭이 아니라 `HomeShell` 우측 하단에 떠 있는 버튼입니다(지도·리포트 탭에서만, 프로필 탭엔 없음). 탭하면 화면 위쪽 여백만 남기고 아래로 화면 높이의 2/3만큼, 좌우로는 대칭 여백을 두고 채팅 패널이 오버레이로 뜹니다. 닫기는 같은 버튼(열려있을 땐 X 아이콘으로 바뀜)으로만 하고, 패널 헤더에는 닫기 버튼이 따로 없습니다.
- 이걸 가능하게 하려고 `HomeShell`이 자체 중첩 `Navigator`를 가지고 있습니다 — 탭 안에서 일어나는 화면 전환(정책 상세, 관심지역 관리, 프로필 수정 등)은 전부 이 중첩 Navigator 안에서만 일어나서, 바깥의 폴리 버튼/패널을 덮지 않습니다. 로그아웃만 예외로 `Navigator.of(context, rootNavigator: true)`를 써서 앱 전체(HomeShell 포함)를 로그인 화면으로 교체합니다.
- 대화 이력 저장/복원 가능 (헤더의 펜/사각형 아이콘으로 현재 대화를 이력에 보관하고 새 대화 시작, 시계 아이콘으로 이전 대화 다시 열기). 패널을 닫아도 대화 내용은 유지되고, 로그아웃하면 초기화됩니다.
- **실제 Claude API로 자연어 응답을 생성합니다** (아래 "백엔드" 참고) — 규칙 기반 키워드 추출은 백엔드가 관련 정책을 찾아오는 1차 검색에만 쓰이고, 최종 답변은 Claude가 그 정책 데이터만 근거로 생성합니다.
- Claude에게 넘기는 사용자 정보는 지역·관심지역·재학상태·나이·성별·학교·학점·소득분위·스크랩한 정책까지 포함합니다 — "내가 스크랩한 정책 신청기간이 언제까지야?" 같은 질문에도 실제 근거를 갖고 답할 수 있습니다.
- 답변에 마크다운 문법(#, **, ` 등)이 섞여 나오지 않도록 시스템 프롬프트 지시 + 코드 단의 정규식 스트리핑(`BE/app/services/markdown_utils.py`)을 이중으로 적용합니다.
- 말투는 존댓말로 고정합니다 — 원래 "친근하고"라고만 지시했더니 반말이 섞여 나오는 경우가 있어서, "존댓말로만, 반말은 섞지 말고" 식으로 시스템 프롬프트를 더 명시적으로 바꿨습니다 (`BE/app/services/chat_service.py`).

### 마감 리마인더 — 로컬 푸시 알림 (`lib/services/notification_service.dart`)
- 정책을 스크랩하면 신청 마감일 기준 **D-7/D-3/D-1 오전 9시**에 알림 3건이 예약되고, 스크랩 해제하면 취소됩니다 (`flutter_local_notifications` + `timezone`, 시간대는 `Asia/Seoul` 고정).
- **Firebase/서버 없이 기기 로컬 알림으로만 구현**했습니다 — 마감일은 스크랩하는 순간 이미 클라이언트가 알고 있는 값이라 서버가 나중에 뭔가를 판단해서 보내줘야 할 이유가 없고, 이 기능 하나 때문에 푸시 인프라를 새로 두는 게 오버스펙이라고 판단했습니다. 서버가 먼저 알아서 보내야 하는 알림(신규 정책 공지 등)이 생기면 그때는 Firebase Cloud Messaging 같은 실제 푸시가 필요합니다.
- 알림 권한 요청/예약/취소 전체가 try-catch로 감싸져 있어서, 권한 거부나 플랫폼 미지원 등으로 실패해도 스크랩 자체(앱의 핵심 기능)는 절대 안 막히고 조용히 알림만 안 갑니다.
- Android는 예약 알림에 필요한 매니페스트 리시버/권한(`RECEIVE_BOOT_COMPLETED` 등)과 Gradle desugaring 설정이 추가로 필요해서 `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`에 반영했습니다. **다만 이 환경엔 Android SDK가 없어서 실제 Android 빌드로는 검증 못 했고**, iOS 시뮬레이터 빌드로만 확인했습니다 (아래 "다음에 이어서 할 만한 것" 참고).

`UserProfile` (`lib/models/user_profile.dart`)은 나이를 직접 저장하지 않고 `birthDate`(생년월일)만 저장하며, `age`는 거기서 계산되는 getter입니다. `interestedRegions`(지역)와 `interests`(주제 관심사), `scrappedPolicies`(스크랩한 정책), `householdSize`/`monthlyIncome`(소득분위 계산용), `militaryServiceStatus`(병역, 남성만)는 각각 별개 필드입니다. `copyWith`로 일부 필드만 갱신할 수 있습니다.

## 백엔드 (`BE/`)

FastAPI 서버. 정부의 [온통청년](https://www.youthcenter.go.kr) 청년정책 Open API를 감싸는 프록시 기능에, 오프라인 지원금액 추출 파이프라인(Supabase) 연동과 Claude(Anthropic API) + NewsAPI를 엮은 AI 기능을 더했습니다. 회원 인증/프로필은 SQLAlchemy + Alembic으로 관리하는 별도 스키마(`BE/app/models/`, `BE/alembic/`)에 저장되고, 나머지(정책 검색/채팅/뉴스)는 기존 `/api/...` 경로를 그대로 씁니다.

### 회원 인증 & 프로필 — `/api/v1/auth`, `/api/v1/profile`
- `POST /api/v1/auth/signup`, `POST /api/v1/auth/login`: 이메일/비밀번호를 Supabase Auth(GoTrue)에 그대로 위임합니다 (`BE/app/api/clients/supabase_auth.py`, `BE/app/services/auth_service.py`) — 비밀번호 해싱/세션 발급/토큰 갱신을 직접 구현하지 않습니다. 가입 직후 서버가 관리자 API로 이메일 확인을 즉시 처리해서 데모에서 실제 메일함 확인 없이 바로 로그인 세션을 받습니다.
- `GET /api/v1/auth/me`, `DELETE /api/v1/auth/session`: 현재 세션 조회/로그아웃(세션 폐기).
- `GET/POST/PATCH /api/v1/profile`, `GET/PATCH/DELETE /api/v1/profile/interest-regions`: 프로필과 관심지역을 각각 `public.user_profiles`/`public.user_interest_regions` 테이블에 저장·조회합니다. 인증은 `Authorization: Bearer <supabase-access-token>` 헤더로 하며, 백엔드가 Supabase의 `/auth/v1/user`에 그 토큰을 그대로 넘겨 검증합니다(`BE/app/core/auth.py`). `user_profiles.interests`(Postgres 텍스트 배열, 마이그레이션 `20260721_0004`)에 프로필의 관심사(주제)도 같이 저장됩니다 — 지역과 달리 참조 테이블이 없는 자유 문자열 배열이라 코드 변환 없이 그대로 오갑니다.
- 프로필이 없는 계정(가입 직후)은 GET이 404, PATCH도 404를 돌려주므로, 앱은 PATCH가 404면 POST(생성)로 자동 폴백합니다.
- `SUPABASE_URL`/`SUPABASE_ANON_KEY`가 설정 안 됐으면 signup/login/me가 503을, Supabase 자체가 응답 없으면 502를 반환합니다(raw 500 대신) — Render에 이 환경변수들을 빼먹고 배포했다가 겪은 문제라 명시적으로 처리해뒀습니다.
- **주의 — Supabase 기본 이메일 발송 rate limit**: `admin_confirm_email`로 확인 절차 자체는 우회하지만, Supabase는 `POST /auth/v1/signup` 호출 시점에 일단 확인 이메일을 보내려고 시도하고 그 발송 자체가 무료 플랜의 낮은 rate limit(짧은 시간에 회원가입이 여러 번 몰리면 "email rate limit exceeded" 429)에 걸립니다. 데모처럼 여러 명이 짧은 시간에 가입할 상황이면 Supabase 대시보드 → Authentication → Sign In/Providers → Email → **"Confirm email" 토글을 꺼두는 걸 권장**합니다 — 꺼도 사용자 경험(가입 즉시 로그인 가능)은 지금과 동일하고, 이메일 발송 자체가 없어져서 이 rate limit에 안 걸립니다. 실사용자가 늘면 커스텀 SMTP 등록으로 근본적으로 해결 가능합니다.

### 정책 검색 — `GET /api/ontong-policy/search`
- `name`(정책명 → `plcyNm`), `topic`(정책키워드 → `plcyKywdNm`), `region`(지역 → `zipCd`) 파라미터가 실제 정부 API에서 동작하는 것으로 확인된 필터입니다. `region`은 시도명을 받아 `BE/app/constants/region_codes.py`(실제 API 응답에서 추출한 254개 법정동 코드 테이블)로 `zipCd` 목록으로 변환합니다. `query`/`keyword`/`business_type`/`region_code`는 코드는 남아있지만 정부 API가 인식하지 못해 무시됩니다.
- `BE/.env`에 `ONTONG_API_KEY`를 넣어야 동작합니다 ([공공데이터포털](https://www.data.go.kr)에서 발급).
- 정부 API가 간헐적으로 느리거나 502/503/504를 내는 걸 반복적으로 확인해서, `PolicyApiService.search()`는 실패 시(연결 실패 및 5xx 응답 모두) 한 번 자동 재시도합니다. 그래도 실패하면 앱에 "조회 실패"로 표시됩니다.
- 응답을 반환하기 전에 아래 "지원금액 파이프라인 연동" 섹션의 Supabase 데이터를 `plcyNo` 기준으로 병합합니다.

### 지원금액 파이프라인 연동 (Supabase)
- 별도로 구축한 오프라인 배치 파이프라인(온통청년 전체 정책 수집 → 정규식+LLM으로 지원금액 추출 → 사람 검토 → Supabase `policies` 테이블 적재, 2,646건 기준)의 결과를 백엔드가 실시간 API 응답에 병합합니다 (`BE/app/services/policy_amount_service.py`, `BE/app/services/ontong_policy_service.py`).
- **하이브리드 구조**: 정책 검색 자체는 그대로 온통청년 실시간 API를 쓰고, Supabase는 그 위에 정확한 지원금액(`sprtAmtKrw` 등)만 얹습니다. Supabase 연결이 실패하거나 해당 정책이 아직 파이프라인에 없어도 예외 없이 빈 값으로 넘어가서, 실시간 정책 조회 자체는 항상 정상 동작합니다. 프론트엔드는 이 값이 없는 정책은 지원금액을 아예 표시하지 않습니다 (위 "지도" 섹션 참고).
- `BE/.env`에 `DB_URL`(Supabase Postgres 연결 문자열)이 필요합니다. 연결은 `get_shared_policy_amount_service()`로 프로세스 생애주기 동안 하나만 만들어 재사용합니다 (아래 "성능 개선" 참고).
- Supabase의 데이터는 스냅샷이라, 신규/변경된 정책을 반영하려면 파이프라인을 주기적으로 재실행해야 합니다 (현재는 수동 실행, 자동화는 미구현).
- Supabase는 항상 켜져 있는 클라우드 서비스라 별도로 "실행"할 필요는 없지만, 무료 플랜은 장기간 미사용 시 자동 일시정지될 수 있습니다 — 그 경우에도 위 하이브리드 설계 덕분에 앱은 정상 동작하고, 지원금액이 없는 정책은 그냥 안 보일 뿐입니다.

### 채팅(폴리) — `POST /api/chat/ask`
- 질문 + 프로필(지역/관심지역/재학상태/나이/성별/학교/학점/소득분위/스크랩한 정책)을 받아서: (1) `BE/app/services/keyword_extractor.py`의 주제 키워드 사전으로 질문에서 키워드를 찾아 `topic` 검색, 없으면 거주지역으로 검색 → (2) 검색된 정책(오늘 기준 신청 가능한 것만) + 스크랩한 정책 + 프로필 전체를 Claude에게 근거로 주고 "이 안에서만 답하라"고 지시 → (3) 생성된 답변을 마크다운 제거 후 반환 (`BE/app/services/chat_service.py`)
- 검색된 정책의 URL을 Claude가 직접 만들지 않고, 실제 검색 결과에서 그대로 매핑해서 반환하므로 잘못된 링크가 생기지 않습니다.
- 단순 조회형 작업이라 Claude의 확장 사고(thinking)를 명시적으로 꺼서 응답 속도를 개선했습니다 (아래 "성능 개선" 참고).

### 추천 뉴스 — `GET /api/news/recommendations?interests=주거&interests=취업&count=3`
- 관심사로 NewsAPI(`/v2/everything`, `language=ko`)에서 뉴스 후보 20건을 가져온 뒤, Claude에게 그 후보 목록 + 관심사를 주고 가장 관련 있는 걸 `count`개(기본 5개, 최대 20개) 고르게 합니다 (`BE/app/services/news_service.py`). `count`는 리포트 탭에서 매칭된 정책 건수를 그대로 넘겨서, 뉴스 개수가 정책 개수와 맞춰지도록 씁니다. Claude는 후보의 인덱스와 추천 이유만 반환하고, 실제 제목/URL/출처는 원본 기사에서 그대로 매핑합니다 (역시 URL 환각 방지). 이유 텍스트도 마크다운을 제거해서 반환합니다.
- `BE/.env`에 `NEWSAPI_KEY`도 필요합니다 ([newsapi.org](https://newsapi.org)에서 발급, 무료 플랜은 최근 1개월 기사만 검색 가능).

### 성능 개선
백엔드 응답이 느리다는 문제를 실측(curl 타이밍 측정)으로 추적해서 두 가지 원인을 고치고 재측정했습니다.

| 항목 | 이전 | 이후 | 개선 |
|---|---|---|---|
| 정책 검색 1페이지 | 평균 3.32초 | 평균 1.31초 | 약 60% 단축 (-2.0초) |
| 지도 지역 조회 (3페이지 순차) | 9.27초 | 평균 3.2초 | 약 65% 단축 (-6.0초) |
| 챗봇 LLM 호출 자체 | 11.0~11.7초 | 8.2~9.0초 | 약 25~30% 단축 (-2.5~3초) |

- **DB 커넥션 재사용**: 정책 검색/챗봇 모두 요청마다 Supabase에 새 커넥션을 맺고 있어서 커넥션 수립 자체(~2.3초)가 매번 반복됐습니다. `get_shared_policy_amount_service()`(`lru_cache`)로 프로세스 생애주기 동안 커넥션을 하나만 만들어 재사용하도록 고쳤습니다.
- **불필요한 확장 사고(thinking) 비활성화**: 챗봇이 목록에서 근거를 찾아 답하는 단순 조회 작업인데도 Claude가 눈에 안 보이는 "thinking" 토큰을 150~330개씩 추가로 생성하고 있었습니다. `thinking={"type": "disabled"}`로 꺼서 개선했습니다 (뉴스 큐레이션 쪽도 안전하게 같이 꺼뒀지만, 원래도 thinking을 안 쓰고 있어서 효과는 불확실).
- Claude API 자체의 응답 생성 시간은 호출마다 변동이 커서(같은 조건에서도 8~15초까지 편차), 전체 `/api/chat/ask` 응답시간은 위 개선을 다 적용해도 여전히 들쭉날쭉합니다 — 이 변동은 저희가 통제할 수 없는 부분입니다.

### 공통
- 채팅/뉴스 기능은 `BE/.env`의 `ANTHROPIC_API_KEY`가 필요합니다 ([console.anthropic.com](https://console.anthropic.com)에서 발급 — claude.ai 채팅 구독과는 별개로 과금되는 API 크레딧이 있어야 동작합니다).
- 지원금액 파이프라인 연동은 `DB_URL`(Supabase)이 필요하지만, 없어도 정책 검색 자체는 정상 동작하고 지원금액만 안 보일 뿐입니다.
- 회원 인증/프로필 저장은 `DB_URL` + `SUPABASE_URL` + `SUPABASE_ANON_KEY`(Supabase 대시보드에서 발급하는 publishable/anon key) + `SUPABASE_SECRET_KEY`(secret/service_role key, 가입 직후 이메일 자동 확인용)가 모두 필요합니다. `DB_URL`도 그 스키마(`user_profiles` 등)가 이미 Alembic으로 만들어진 같은 Supabase 프로젝트를 가리켜야 합니다. 이 중 하나라도 비어있으면 로그인/프로필 관련 요청이 401/503(설정 자체가 없으면 502/503, 있는데 틀리면 401)으로 실패합니다 — 실제로 로컬/Render 양쪽에서 `SUPABASE_ANON_KEY`가 빠져 겪은 문제라 예시로 남겨둡니다. Supabase 대시보드에서 발급받은 키를 그대로 쓰면 이름이 `SUPABASE_PUBLISHABLE_KEY`로 보일 수 있는데, 코드가 읽는 변수명은 `SUPABASE_ANON_KEY`이니 그 이름으로 등록해야 합니다 (`SUPABASE_JWKS_URL`도 예전 방식의 흔적일 뿐 지금 코드는 안 읽습니다) — 즉 Supabase 관련으로는 딱 3개(`SUPABASE_URL`/`SUPABASE_ANON_KEY`/`SUPABASE_SECRET_KEY`)만 있으면 됩니다.
- `BE/example.env`를 참고해서 `BE/.env`를 채우세요. DB 스키마 자체를 처음부터 만들어야 한다면 `cd BE && alembic upgrade head`.
- 로컬 실행:
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

키를 넘기지 않고 실행하면 앱은 정상 작동하지만 지도 자리에는 (탭 가능한) 플레이스홀더만 표시됩니다.

## 웹으로 빌드/배포

관객/심사위원이 각자 휴대폰으로 접속해서 써보는 데모처럼 설치 없이 여러 사람에게 빠르게 보여줘야 할 때 이 방식을 씁니다 (반대로 네이티브 앱 배포는 iOS는 유료 개발자 계정 + 심사 대기, Android도 APK 설치 마찰이 있어 더 느립니다). 지도만 위에서 설명한 대로 `flutter_map` 기반으로 바뀌고, 나머지 기능(정책 조회/필터, 리포트, 폴리 채팅, 프로필)은 네이티브와 동일하게 동작합니다.

**지금 실제로 떠 있는 주소**: 백엔드 https://aicpp.onrender.com , 프론트 https://aicpp-mu.vercel.app (둘 다 Render/Vercel 무료 플랜)

1. **백엔드 배포 (Render)** — [render.com](https://render.com) 가입 → New Web Service → 이 저장소 연결 → **Root Directory를 반드시 `BE`로 설정** (`BE/render.yaml`로 Blueprint 배포도 가능하지만, 대시보드에서 수동으로 만들 땐 이 설정을 빼먹기 쉬워서 `requirements.txt`를 못 찾아 빌드가 실패합니다). Build Command `pip install -r requirements.txt`, Start Command `uvicorn main:app --host 0.0.0.0 --port $PORT`. `ANTHROPIC_API_KEY`/`ONTONG_API_KEY`/`NEWSAPI_KEY`/`DB_URL`/`SUPABASE_URL`/`SUPABASE_ANON_KEY`/`SUPABASE_SECRET_KEY` 7개를 환경변수로 등록 — 값이 비어있으면 배포는 성공해도 해당 기능만 500/401 에러가 나므로, 배포 후 꼭 값이 채워졌는지 눈 아이콘으로 확인하세요 (특히 `SUPABASE_ANON_KEY`는 Supabase 대시보드 표기가 "publishable key"로 바뀌어서 빠뜨리기 쉽습니다). Python 버전은 `BE/.python-version`(3.12.3)으로 고정해뒀습니다 (Render 기본값이 아직 라이브러리 호환이 덜 된 최신 버전이라 직접 지정 안 하면 실패할 수 있음). CORS는 이미 전체 허용(`*`)이라 별도 설정 불필요. 무료 플랜은 오래 안 쓰면 슬립 상태가 되고 첫 요청에 최대 50초 정도 걸립니다.
2. **프론트엔드 빌드** — 배포된 백엔드 주소를 빌드 시점에 넘겨서 정적 파일을 만듭니다.
   ```bash
   flutter build web --dart-define=API_BASE_URL=https://aicpp.onrender.com
   ```
3. **프론트엔드 배포 (Vercel)** — 저장소를 연결해서 자동 빌드시키면 안 됩니다 (Vercel은 Flutter를 모르는 프레임워크라 빌드가 실패합니다). 위에서 미리 빌드해둔 `build/web` 폴더를 정적 파일 그대로 올려야 합니다.
   ```bash
   npm install -g vercel   # 처음 한 번만
   vercel build/web --prod
   ```
   Vercel CLI에 로그인 안 돼 있으면 처음 실행 시 브라우저로 로그인 절차를 안내해줍니다. 배포마다 새 URL(`aicpp-xxxxx-2sky.vercel.app`)이 생기지만, 고정 별칭(`aicpp-mu.vercel.app`)이 항상 최신 배포를 가리키므로 공유는 그 주소로 하면 됩니다.

## 실행 환경

- 네이버 지도 플러그인(`flutter_naver_map`)이 Android/iOS만 지원하므로, **네이버 지도 자체까지 확인하려면 iOS 시뮬레이터(또는 Android 에뮬레이터/실기기)로 실행**해야 합니다. 웹은 지도가 `flutter_map`/OpenStreetMap으로 자동 대체되어 실제 지도가 뜨고, 나머지 기능은 네이티브와 동일하게 동작합니다.
- macOS 데스크톱 타깃은 이 프로젝트에 구성되어 있지 않습니다.
- iOS 시뮬레이터는 직접 부팅한 뒤 (`open -a Simulator`) 위 실행 명령을 사용해주세요.
- 지도/리포트/폴리 채팅의 데이터를 보려면 백엔드(`BE/`)가 `127.0.0.1:8000`에서 함께 떠 있어야 합니다 (또는 `--dart-define=API_BASE_URL=...`로 배포된 백엔드를 가리키게 할 수 있습니다). 백엔드 없이 실행하면 각 화면에 연결 실패 안내가 표시됩니다.
- 폴리 채팅과 추천 뉴스는 백엔드가 떠 있어도 `BE/.env`(또는 배포 환경변수)에 유효한 `ANTHROPIC_API_KEY`(크레딧 포함)가 없으면 "AI 응답 생성에 실패했어요" 에러가 뜹니다.

## 테스트

```bash
# Flutter (89개)
flutter analyze
flutter test

# 백엔드 (46개)
cd BE && source venv/bin/activate && python3 -m unittest discover -s tests -v
```

## 현재 상황 요약 (2026-07-21 기준)

- 프론트엔드(Flutter) + 백엔드(FastAPI, `BE/`)가 모두 존재하며, 지도/리포트/채팅이 실제 온통청년 정책 데이터 + Supabase(지원금액) + Claude + NewsAPI를 백엔드 경유로 가져옵니다.
- **회원가입/로그인/프로필/관심지역이 이제 실제로 서버에 저장됩니다** (Supabase Auth + SQLAlchemy/Alembic 스키마, `/api/v1/auth`·`/api/v1/profile`). 로그아웃 후 다시 로그인해도 저장된 프로필이 그대로 불러와집니다 — 다만 기기에 세션을 저장하지는 않아서, **앱을 재시작하면 다시 로그인은 해야 합니다** (자동 로그인 유지는 미구현). 실제로 배포된 Render 백엔드에 로그인 → 프로필/관심지역 저장 → 완전히 새 세션으로 재로그인까지 curl로 검증 완료했습니다.
- 프로필 수정 화면에서 바꾼 값(성별/학교/학점/소득 등)은 폴리 채팅에도 즉시 반영됩니다 — 매 질문마다 그 시점의 최신 프로필을 그대로 백엔드에 보내기 때문입니다(캐시 없음). 실제 Claude 호출로 학점 값만 다르게 보내 답변이 각각 다르게 나오는 것까지 확인했습니다.
- 회원가입 완료(프로필 입력까지) 후에는 바로 메인으로 들어가지 않고 로그인 화면으로 돌아가서 다시 로그인해야 메인으로 넘어갑니다 — 방금 입력한 정보가 실제로 서버에 저장되고 다시 불러와지는지를 사용자도 매번 확인하게 되는 흐름입니다.
- **주의**: Supabase 기본 이메일 발송 rate limit 때문에 짧은 시간에 회원가입을 여러 번 시도하면 "email rate limit exceeded"로 실패할 수 있습니다 (위 "회원 인증 & 프로필" 섹션 참고, "Confirm email" 토글을 꺼두면 해결).
- 스크랩(저장한 정책)과 채팅 이력은 아직 이 새 백엔드에 연동되지 않았습니다 — 로그인 세션 동안만 앱 메모리에 유지되고, 로그아웃/재시작하면 사라집니다.
- 카카오톡/구글/Apple 로그인 버튼은 아이콘만 실제 브랜드로 교체됐고, 실제 소셜 로그인 기능은 아직 없습니다 (각 사 개발자 계정/자격증명 발급 필요).
- 폴리 채팅과 추천 뉴스는 진짜 Claude API로 동작하지만, **API 크레딧이 없으면 실패**합니다. 크레딧은 claude.ai 구독과 무관하게 [console.anthropic.com](https://console.anthropic.com)에서 별도로 충전해야 합니다.
- 정책 목록/마커/리포트는 모두 오늘 날짜 기준으로 신청 가능한(`PolicyItem.isCurrentlyOpen`) 정책만 필터링해서 보여주고, 지도 탭의 정책 목록은 추가로 나이·소득 자격이 되는 정책만 기본으로 보여줍니다 (카테고리/관심사 칩으로 더 좁힐 수 있음). 지역 필터링은 `zipCd` 기반이라 정책명에 지역명이 없어도 정확히 매칭됩니다.
- "지원금액 많은 순" 정렬 및 지원금액 표시는 Supabase 파이프라인이 검증한 값이 있는 정책에서만 동작합니다 — 정규식 추정치 폴백은 검증 안 된 숫자를 화면에 확정치처럼 보여줄 위험이 있어 없앴습니다.
- 관심지역/관심사(주제) 둘 다 이제 실제로 백엔드에 저장됩니다 — 관심지역은 `PATCH /api/v1/profile/interest-regions`, 관심사는 `user_profiles.interests` 컬럼(2026-07-21 추가된 Alembic 마이그레이션 `20260721_0004`)에 프로필과 함께 저장됩니다. 둘 다 로그아웃 후 재로그인해도 유지됩니다.
- 스크랩한 정책은 마감 D-7/D-3/D-1에 기기 로컬 알림으로 리마인드됩니다 (Firebase 없이 `flutter_local_notifications`로 구현, iOS 시뮬레이터에서만 빌드 검증 완료 — 위 "마감 리마인더" 참고).
- 네이버 지도 Client ID는 발급받아 로컬(`config/naver_map.local.json`, 커밋 안 됨)에 등록되어 있고, iOS 시뮬레이터에서 실제 지도·핀·줌 컨트롤까지 동작 확인을 완료했습니다.
- **웹은 실제로 배포되어 있습니다** (https://aicpp-mu.vercel.app , 백엔드 https://aicpp.onrender.com) — 지도만 `flutter_map`/OpenStreetMap 기반으로 대체되고 나머지 기능은 네이티브와 동일하게 동작합니다. 둘 다 무료 플랜이라 트래픽이 몰리면(대략 동시 30명 이상) 정부 API·NewsAPI 호출 제한이나 Render 무료 인스턴스의 단일 프로세스 한계로 느려질 수 있습니다.
- 정책 카테고리(`categoryLabel`)는 이제 프로필 관심사(`kInterests`, 9개)와 완전히 같은 taxonomy입니다 — 지도 카테고리 칩/리포트 카테고리 도넛/회원가입·프로필의 관심사 선택이 전부 같은 9개를 씁니다. "참여권리"는 더 이상 존재하지 않습니다 (위 "지도" 섹션 참고).
- `flutter analyze`, `flutter test`(89개), 백엔드 `unittest`(46개) 모두 통과하는 상태입니다.

### 다음에 이어서 할 만한 것
- 스크랩(저장한 정책), 채팅 이력을 새 `/api/v1` 백엔드에 실제로 저장 — DB 스키마(`user_saved_policies`, `chat_conversations` 등)는 이미 있지만 그 위 API 엔드포인트가 아직 없음
- Supabase 대시보드에서 "Confirm email" 토글을 꺼서 데모 중 회원가입이 몰릴 때 이메일 rate limit(429)에 걸리지 않게 하기 (위 "회원 인증 & 프로필" 섹션 참고) — 대시보드 접근 권한이 있는 사람이 해야 함
- 자동 로그인 유지(세션을 기기에 저장) — 지금은 로그아웃 없이 앱만 재시작해도 다시 로그인해야 함
- 카카오톡/구글/Apple 소셜 로그인 실제 연동 — 각 사 개발자 콘솔에서 앱 등록/자격증명 발급 필요 (Supabase Auth를 쓰면 구글/애플은 표준 지원, 카카오는 커스텀 OIDC 설정 추가 필요)
- 병역 여부를 실제 정책 매칭에 반영 — 정부 API에 구조화된 필드가 없어서 정책 설명 텍스트 키워드 매칭이 필요한데, 정확도가 불확실해 일단 프로필 입력만 반영해둔 상태
- 지원금액 파이프라인 자동 재실행(크론/스케줄러) — 현재는 수동 실행이라 신규 정책은 지원금액이 아예 안 보임
- `match_from_db.py`의 `job_cd`/`school_cd` 매칭 코드표가 일부만 채워져 있어, 취업/학력 조건 기반 정밀 매칭은 아직 보수적으로만 판단함 (나이/소득/지역은 정확)
- 마감 리마인더 알림을 실제 Android 기기/에뮬레이터와 iOS 실기기에서 검증 (지금은 iOS 시뮬레이터 빌드 확인만 완료, Android SDK가 없는 환경이라 Android 쪽은 매니페스트/Gradle 설정만 문서 그대로 반영하고 실빌드 검증은 못 함), 알림 탭 시 해당 정책 상세로 바로 이동하는 것도 미구현
- 웹 트래픽이 실제로 늘어나면 Render를 유료 플랜으로 올리거나(무료는 단일 프로세스 + 슬립) NewsAPI를 유료 플랜으로 바꾸는 것 검토 (지금은 데모 규모 기준으로만 검증함)
