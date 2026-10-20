import SwiftUI

/// The day's note. A TextEditor rather than a vertical TextField: Return must start a new line.
struct DayEditorNotes: View {
    @Binding var note: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if note.isEmpty {
                Text("写下这一天的心情…")
                    .font(Theme.sans(16))
                    .foregroundStyle(Theme.muted)
                    .padding(16)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $note)
                .font(Theme.sans(16))
                .foregroundStyle(Theme.ink)
                .tint(Theme.ink)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, minHeight: 92)
                .padding(12)
                .accessibilityLabel("心情笔记")
                .accessibilityIdentifier("dayNoteEditor")
        }
        .background(Theme.card, in: .rect(cornerRadius: 22))
    }
}
