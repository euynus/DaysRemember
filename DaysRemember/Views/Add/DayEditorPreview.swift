import SwiftUI

/// The draft as it would look on the feed; a photo cover can be dragged to reframe it.
struct DayEditorPreview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let date: Date
    let recurring: Bool
    let solar: Bool
    let photo: PhotoStyle
    let photoData: Data?
    @Binding var coverFocusX: Double
    @Binding var coverFocusY: Double
    let tint: Color
    @State private var dragStartX: Double?
    @State private var dragStartY: Double?

    var body: some View {
        Group {
            if photoData == nil {
                summary
            } else {
                PhotoTile(style: photo, imageData: photoData,
                          focusX: coverFocusX, focusY: coverFocusY,
                          flat: true, cornerRadius: 26)
                    .frame(height: 200)
            }
        }
            .frame(minHeight: photoData == nil ? 150 : 200)
            .background(tint, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            // Lists and square widgets crop a photo narrower than this preview does, so a sideways
            // drag can change only them; the inset shows that crop.
            .overlay(alignment: .bottomTrailing) {
                if photoData != nil {
                    PhotoTile(style: photo, imageData: photoData, focusX: coverFocusX, focusY: coverFocusY,
                              flat: true, cornerRadius: 3, maximumPixelSize: 256)
                        .frame(width: 44, height: 51)
                        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white, lineWidth: 2) }
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
            // Only a photo can be reframed; otherwise the preview must not swallow scrolling.
            .gesture(focusDrag, including: photoData != nil ? .all : .subviews)
            .modifier(CoverFramingAccessibility(hasPhoto: photoData != nil, x: $coverFocusX, y: $coverFocusY))
    }

    /// The day as it would look on the feed, from the current draft.
    private var summary: some View {
        let draft = Day(id: "editor-preview", title: title, date: date, recurring: recurring,
                        lunar: !solar, category: .life, photo: photo)
        let info = DayInfo.compute(draft, today: Today.date)
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? String(localized: "给这一天起个名字", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : name)
                    .font(Theme.sans(18, weight: .heavy))
                    .foregroundStyle(name.isEmpty ? Theme.onPastel : Theme.ink)
                    .lineLimit(2)
                Text(recurring ? String(localized: "\(CNDate.short(info.displayDate)) · 每年", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                     : CNDate.full(info.displayDate))
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.onPastel)
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if !info.isToday { CountLabel(info: info) }
                    CountValue(info: info, size: 48)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                FlatCover(style: photo)
                    .frame(width: 112, height: 112)
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var focusDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard photoData != nil else { return }
                if dragStartX == nil {
                    dragStartX = coverFocusX
                    dragStartY = coverFocusY
                }
                let startX = dragStartX ?? coverFocusX
                let startY = dragStartY ?? coverFocusY
                coverFocusX = clamp(startX - Double(value.translation.width / 200))
                coverFocusY = clamp(startY - Double(value.translation.height / 200))
            }
            .onEnded { _ in
                dragStartX = nil
                dragStartY = nil
            }
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
