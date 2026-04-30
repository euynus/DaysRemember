import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header.padding(.bottom, 18)
                    sampleCard.padding(.bottom, 22)
                    section("提前提醒") {
                        ToggleRow(label: "提前 7 天", on: $settings.notifPre7)
                        ToggleRow(label: "提前 3 天", on: $settings.notifPre3)
                        ToggleRow(label: "提前 1 天", on: $settings.notifPre1)
                        ToggleRow(label: "当天", on: $settings.notifDay0, isLast: true)
                    }
                    section("提醒时间") {
                        ValueRow(label: "每日提醒时间", value: "上午 9:00")
                        ValueRow(label: "重要日子提醒", value: "提前 1 天", isLast: true)
                    }
                    section("智能提醒") {
                        ToggleRow(label: "时光回忆", sub: "一年前的今天发生了什么", on: $settings.memoryEnabled)
                        ToggleRow(label: "纪念日时刻", sub: "发现日子背后的连接", on: $settings.momentsEnabled, isLast: true)
                    }
                    section("勿扰") {
                        ToggleRow(label: "夜间勿扰", sub: "22:00 — 8:00 静音", on: $settings.quietHours, isLast: true)
                    }
                    quote
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }

    private var topBar: some View {
        HStack {
            Color.clear.frame(width: 18, height: 18)
            Spacer()
            Text("提醒").font(Theme.serif(17, weight: .semibold))
            Spacer()
            Color.clear.frame(width: 18, height: 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("不会忘记的提醒")
                .font(Theme.serif(26, weight: .semibold))
            Text("提前几天告诉你，让重要的日子从容到来。")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.muted)
                .lineSpacing(13 * 0.6)
        }
        .padding(.top, 10)
        .padding(.horizontal, 4)
    }

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Theme.terracotta)
                    Text("时")
                        .font(Theme.serif(14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)
                Text("时光")
                    .font(Theme.sans(12, weight: .semibold))
                Spacer()
                Text("9:00").font(Theme.sans(11)).foregroundStyle(Theme.muted)
            }
            Text("蜜月旅行还有 7 天")
                .font(Theme.serif(14, weight: .semibold))
            Text("开始打包行李吧 · 京都 · 8月23日")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(12 * 0.5)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.bottom, 18)
    }

    private var quote: some View {
        Text("\u{201C}每一个被记得的日子，都是一份温柔的提醒。\u{201D}")
            .font(Theme.serif(12).italic())
            .lineSpacing(12 * 0.6)
            .foregroundStyle(Theme.ink2)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.terracottaSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 12)
    }
}
