# MyToDoBar

개인용 macOS 메뉴바 TODO 앱입니다. 메뉴바에서 오늘 할 일을 기록하고, 전체 보기에서 날짜별 TODO와 제목을 붙인 메모를 관리합니다.

## Features

- 메뉴바에서 오늘 TODO 추가, 완료 전환, 날짜별 자동 분리
- 월간 달력과 전체·미완료·완료 필터
- 달력 상단에서 가까운 마감 순으로 예정 일정 추가·수정·삭제
- 날짜별로 제목과 게시 경로가 다른 메모 여러 개 작성
- 설정한 GitHub 저장소와 브랜치에 메모를 Markdown으로 게시
- Fine-grained PAT를 macOS Keychain에 보관
- `SMAppService` 기반 로그인 시 자동 실행
- 달력에서 토요일은 파랑, 일요일과 대한민국 공휴일은 빨강으로 표시

달력은 매년 반복되는 양력 공휴일과 [한국천문연구원 2026년 월력요항](https://www.kasi.re.kr/kor/post/newsMaterial/32031)의 설·추석·대체공휴일·선거일을 반영합니다. 연도별 음력·임시 공휴일은 해당 연도의 공식 월력요항 데이터 추가가 필요합니다.

## Requirements

- macOS 14+
- Swift 6.2+
- 전체 Xcode 설치 권장

재현 가능한 빌드와 앱 번들 실행·서명·배포를 위해 전체 Xcode를 설치하고 활성 개발자 경로로 선택합니다.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -license
```

## Development

```bash
swift build
swift test
swift run MyToDoBar
```

전체 Xcode가 준비되면 `Package.swift`를 Xcode로 열어 개발할 수 있습니다.

`SMAppService` 로그인 자동 실행을 포함한 실제 앱 번들은 다음 명령으로 생성합니다.

```bash
./scripts/build-app.sh
open dist/MyToDoBar.app
```

스크립트는 기본적으로 로컬 실행용 ad-hoc 서명을 사용합니다. `SMAppService` 로그인 항목을 실제 등록하려면 Apple Development 또는 Developer ID 인증서를 `CODESIGN_IDENTITY`로 지정해야 합니다.

서명된 번들에서 등록과 즉시 해제를 점검하려면 다음 진단 모드를 사용합니다. 기존에 등록된 상태는 변경하지 않습니다.

```bash
open -n -W dist/MyToDoBar.app --args --verify-launch-at-login
cat /tmp/mytodobar-launch-at-login-diagnostic.txt
```

TODO 데이터는 `~/Library/Application Support/MyToDoBar/todos.json`, 예정 일정은 같은 폴더의 `schedules.json`, 날짜별 메모는 `daily-logs.json`에 저장됩니다. 손상된 TODO 또는 일정 JSON을 발견하면 원본 보호를 위해 해당 데이터의 쓰기를 중단하고 오류를 표시합니다.

## Upcoming Schedules

전체 보기의 달력 위 `다가오는 일정`에서 제목, 날짜와 시간을 입력해 일정을 등록합니다. 일정은 가장 가까운 마감 순으로 정렬되며, 세 개를 초과하면 목록 안에서 세로로 스크롤할 수 있습니다. 카드를 누르면 제목과 마감시간을 수정하거나 일정을 삭제할 수 있습니다.

마감시간이 지난 일정은 예정 목록에서 자동으로 숨겨지지만 `schedules.json`에는 보존됩니다. 현재 버전은 macOS 알림과 반복 일정을 지원하지 않습니다.

## GitHub Publishing

GitHub 게시를 사용하려면 설정에서 저장소 URL, 브랜치와 해당 저장소에 접근 가능한 Fine-grained personal access token을 입력합니다. 브랜치를 비우면 `main`을 사용합니다. 게시 경로는 메모 편집기에서 메모별로 지정하며 비우면 저장소 루트를 사용합니다. 토큰에는 저장소의 `Contents: Read and write` 권한이 필요하며, 토큰은 macOS Keychain에만 저장됩니다.

- 파일명: `메모 제목.md`
- 동일 파일명이 존재하면 `메모 제목-2.md`, `메모 제목-3.md`
- 동일 메모 재게시 시 기존 파일 업데이트
- 제목이나 게시 경로 변경 시 기존 원격 파일 이동
- GitHub에서 직접 수정된 파일은 SHA 충돌을 표시하고 덮어쓰지 않음
- 앱에서 메모를 삭제해도 GitHub 파일은 보존

로그인 시 자동 실행은 `ServiceManagement.SMAppService`를 사용합니다. 실제 등록과 해제는 코드 서명된 앱 번들에서 검증해야 하며, 기본 상태는 꺼짐입니다.

## Structure

- `Sources/MyToDoBarCore`: UI와 분리된 TODO, 달력, 대한민국 공휴일 로직
- `Sources/MyToDoBarKit`: JSON 저장소, GitHub 게시, Keychain, 로그인 자동 실행
- `Sources/MyToDoBar`: SwiftUI 메뉴바 앱과 화면
- `Tests/MyToDoBarCoreTests`: 날짜, 월간 달력, 공휴일 로직 테스트
- `Tests/MyToDoBarTests`: 저장 복원, 오류 보호, GitHub 게시, Keychain, 자동 실행 테스트
- `docs/product-spec.md`: 인터뷰에서 확정한 MVP 명세
