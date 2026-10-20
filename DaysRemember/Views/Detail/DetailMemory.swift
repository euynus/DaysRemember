import SwiftUI

/// The day's note and place, or a prompt to write them.
struct DetailMemory: View {
    let day: Day
    var onWrite: () -> Void = {}

    var body: some View {
        let note = day.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = day.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty && location.isEmpty {
            Button { onWrite() } label: {
                Label("写下这一天的记忆", systemImage: "plus")
                    .font(Theme.sans(15, weight: .heavy))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(PressableTileStyle())
            .accessibilityIdentifier("detail.writeMemory")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("记忆")
                    .font(Theme.sans(12, weight: .heavy))
                    .foregroundStyle(Theme.memoryInk)
                if !note.isEmpty {
                    Text(verbatim: note)
                        .font(Theme.sans(18, weight: .bold))
                        .lineSpacing(5)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                if !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.memoryInk)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.memory, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
