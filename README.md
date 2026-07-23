# Quota — macOS 메뉴바 Claude 사용량 표시 앱

맥 메뉴바에 Claude 사용량을 아이콘 + `NN%`로 상시 표시하고, 클릭하면 5시간 한도·7일
한도·요금 상태를 보여주는 팝오버가 열리는 메뉴바 앱입니다. (RunCat 스타일)

<img src="design/design_handoff_quota_menubar/reference_popup.png" width="360" alt="popover reference" />

## 아이콘 6종
설정에서 택1 — **Hamster**(기본, 볼이 쓸수록 쪼그라듦) / Donut / Ring / Eclipse(잠식 원반)
/ Battery / Liquid. 색상 코딩 켜짐 시 사용량 3단계(초록 <50 · 주황 <80 · 빨강 ≥80)로
색이 바뀌고, 90% 이상이면 아이콘이 맥동합니다. (Hamster는 항상 단색)

## 빌드 & 실행
```bash
# 개발 실행(.app 번들 생성 후 실행 — 알림/OAuth/Keychain 동작에 번들 필요)
./scripts/make_app.sh debug
open Quota.app

# 아이콘/팝오버 레퍼런스 PNG만 렌더 (화면 녹화 권한 불필요)
swift build && QUOTA_SNAPSHOT=/tmp/quota_snaps ./.build/debug/Quota
```
> `swift run`으로 맨 바이너리를 직접 실행하면 UserNotifications가 앱 번들을 요구해
> 크래시합니다. 항상 `.app` 번들로 실행하세요.

## 구조
```
Sources/Quota/
  QuotaApp.swift            @main (Settings 씬은 비어 있음 — UI는 상태바+팝오버)
  App/AppDelegate.swift     NSStatusItem + NSPopover + 설정창 관리
  App/SnapshotRenderer.swift 오프스크린 PNG QA 렌더러(QUOTA_SNAPSHOT)
  Views/UsageIconCanvas.swift 아이콘 6종 Canvas 렌더러(makeStage 공식 이식)
  Views/MenuBarIconView.swift 상태바 아이콘+% (다크/라이트 적응, 맥동)
  Views/PopoverView.swift   라이트 팝오버 308px
  Views/SettingsView.swift  아이콘·색상·폴링·알림·계정
  Models/…                  Preferences, UsageState, UsageModel(폴링/알림)
  Services/…                Config, Credentials(Keychain), UsageAPIClient, AuthService(PKCE), TimeText
```

## 데이터 소스 & 인증
- **인증 우선순위**: 자체 OAuth 로그인 토큰(Keychain) → 없으면 Claude Code CLI 토큰
  (Keychain `Claude Code-credentials` 또는 `~/.claude/.credentials.json`) 자동 감지.
- **엔드포인트**: `GET https://api.anthropic.com/api/oauth/usage` (5시간·주간·모델별 %).
- **폴링**: 기본 300초, 최소 180초. 429 시 지수 백오프.
- **토큰은 각자 Keychain에만 저장**, 외부 서버로 절대 전송하지 않습니다.

## ⚠️ 배포 전 반드시 알아둘 것 (비공식 도구)
- Claude **구독(Pro/Max) 한도에는 공식 API가 없습니다.** 위 엔드포인트는 **비공개**이며
  예고 없이 변경·차단될 수 있습니다.
- 자체 OAuth는 Claude Code의 client_id/User-Agent를 사용 → **공식 클라이언트 사칭 성격의
  ToS 회색지대**입니다. 공개 배포·사용은 본인 책임입니다.
- **Phase 0(미완):** `Services/Config.swift`의 `oauthClientID`·`userAgent`·토큰 URL과
  `UsageAPIClient.parse()`의 필드명은 **실제 oauth/usage 응답을 캡처해 확정해야** 합니다
  (현재는 CLI 토큰 fallback 경로 + 유연 디코딩으로 동작하도록 작성). 로그인 안 된 상태에서는
  샘플 데이터로 UI가 렌더됩니다.

## 배포(Phase 5, 미완)
파일로 공유하려면 Developer ID 서명 + notarization 필요(안 하면 Gatekeeper 차단).
`scripts/make_app.sh`는 로컬 개발용 ad-hoc 서명까지만 합니다.
