# 치지직 풀영상 다운로더 for macOS (Apple Silicon)

이 프로젝트는 Qt GUI를 사용하지 않는 SwiftUI 앱 프런트엔드입니다. 실제 치지직 영상 처리에는 원본 오픈소스 프로젝트의 headless downloader를 사용합니다.

## 현재 제공물
- macOS용 SwiftUI 앱 소스
- 첫 실행 시 오픈소스 엔진과 `uv` 런타임을 앱 지원 폴더에 자동 설치하는 흐름
- URL 입력, 화질 선택, 저장 폴더 선택, 작업 로그 UI
- GitHub Actions에서 macOS ARM64 앱 번들을 빌드하는 워크플로

## 빌드
macOS 13 이상 및 Xcode 15 이상이 필요합니다.
1. 이 폴더를 Xcode에서 엽니다 (`Package.swift`).
2. 대상 기기를 `My Mac`으로 선택합니다.
3. Product > Archive 또는 Release 빌드를 실행합니다.

또는 GitHub 저장소에 올린 뒤 Actions의 `Build macOS app` 워크플로를 실행하면 `.app`과 zip 아티팩트를 생성합니다.

## 엔진 출처 및 라이선스
다운로드 엔진은 https://github.com/honey720/chzzk-vod-downloader-v2 의 `scripts/headless_download.py`를 런타임에 가져와 사용합니다. 해당 프로젝트는 GPL-3.0 라이선스입니다. 이 앱은 원 프로젝트의 공식 제품이 아니며, 원 개발자와 제휴하지 않습니다.

## 중요
이 대화의 실행 환경은 macOS가 아니므로 서명/공증된 실행용 `.app` 바이너리를 여기서 직접 빌드할 수 없습니다. 제공 파일은 macOS에서 빌드할 수 있는 소스 프로젝트입니다. 첫 실행 시 인터넷 연결이 필요합니다. 연령/멤버십 제한 영상은 계정 쿠키 등 별도 인증이 필요할 수 있으며, 권한이 있는 영상만 저장하세요.
