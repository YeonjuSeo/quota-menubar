import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: UsageModel
    @ObservedObject var prefs: Preferences

    private let intervals = [180, 300, 600, 900]

    var body: some View {
        Form {
            Section("아이콘") {
                Picker("스타일", selection: Binding(
                    get: { prefs.iconConcept },
                    set: { prefs.iconConcept = $0 }
                )) {
                    ForEach(IconConcept.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                // Live preview of the current selection at three usage levels.
                HStack(spacing: 18) {
                    ForEach([20, 60, 95], id: \.self) { p in
                        VStack(spacing: 6) {
                            UsageIconCanvas(concept: prefs.iconConcept, percent: p,
                                            scheme: .light, colorCoding: prefs.colorCoding)
                            .frame(width: 34, height: 32)
                            Text("\(p)%").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                Toggle("사용량 3단계 색상", isOn: $prefs.colorCoding)
                    .disabled(!prefs.iconConcept.supportsColorCoding)
                Toggle("퍼센트 텍스트 표시", isOn: $prefs.showPercent)
                Toggle("90% 이상일 때 아이콘 맥동", isOn: $prefs.pulseWhenCritical)
                Picker("아이콘 기준 지표", selection: Binding(
                    get: { prefs.menuBarMetric },
                    set: { prefs.menuBarMetric = $0 }
                )) {
                    ForEach(MenuBarMetric.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
            }

            Section("업데이트") {
                Picker("폴링 간격", selection: $prefs.pollIntervalSeconds) {
                    ForEach(intervals, id: \.self) { s in
                        Text(s < 600 ? "\(s / 60)분\(s % 60 == 0 ? "" : "")" : "\(s / 60)분").tag(s)
                    }
                }
                Text("최소 3분 — 더 짧으면 서버가 요청을 제한합니다.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("25/50/75/90% 도달 알림", isOn: $prefs.notifyThresholds)
            }

            Section("계정") {
                accountRow
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 460)
    }

    @ViewBuilder private var accountRow: some View {
        switch model.loadState {
        case .loaded(.oauthLogin):
            LabeledContent("상태", value: "로그인됨 (OAuth)")
            Button("로그아웃") { model.signOut() }
        case .loaded(.claudeCodeCLI):
            LabeledContent("상태", value: "Claude Code 계정 사용 중")
            Button("이 앱 계정으로 로그인") { Task { await model.signIn() } }
        default:
            LabeledContent("상태", value: "로그아웃됨")
            Button("Claude 계정으로 로그인") { Task { await model.signIn() } }
        }
    }
}
