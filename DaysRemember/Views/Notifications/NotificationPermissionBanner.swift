import SwiftUI
import UIKit

/// Shown when the user has denied notification permission — the reminder toggles
/// below would otherwise be silently inert.
struct NotificationPermissionBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(Theme.symbol(16, weight: .semibold))
                .foregroundStyle(Theme.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("通知权限已关闭")
                    .font(Theme.sans(14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("开启后才能收到日子提醒")
                    .font(Theme.sans(12, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Button(action: openSystemSettings) {
                Text("去设置")
                    .font(Theme.sans(14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.notePink, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开系统设置以开启通知")
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
