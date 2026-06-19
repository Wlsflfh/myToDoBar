# MyToDoBar

개인용 macOS 메뉴바 TODO 앱입니다. 메뉴바에서 오늘 할 일을 기록하고, 전체 보기에서 날짜별 TODO와 일기·운동 일지를 관리합니다.

## Requirements

- macOS 14+
- Swift 6.2+
- 전체 Xcode 설치 권장

현재 시스템의 활성 개발자 경로가 Command Line Tools라면 Swift 빌드와 테스트는 가능하지만, 앱 번들 실행·서명·배포를 위해 전체 Xcode를 설치하고 선택해야 합니다.

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

TODO 데이터는 `~/Library/Application Support/MyToDoBar/todos.json`, 일기와 운동 기록은 같은 폴더의 `daily-logs.json`에 저장됩니다. 손상된 TODO JSON을 발견하면 원본 보호를 위해 쓰기를 중단하고 메뉴바에 오류를 표시합니다.

로그인 시 자동 실행은 `ServiceManagement.SMAppService`를 사용합니다. 실제 등록과 해제는 코드 서명된 앱 번들에서 검증해야 하며, 기본 상태는 꺼짐입니다.

## Structure

- `Sources/MyToDoBarCore`: UI와 분리된 TODO 모델 및 날짜 로직
- `Sources/MyToDoBarKit`: 로컬 저장소와 로그인 자동 실행 서비스
- `Sources/MyToDoBar`: SwiftUI 메뉴바 앱과 화면
- `Tests/MyToDoBarCoreTests`: 날짜 및 월간 달력 로직 테스트
- `Tests/MyToDoBarTests`: 저장 복원, 오류 보호, 자동 실행 상태 테스트
- `docs/product-spec.md`: 인터뷰에서 확정한 MVP 명세
