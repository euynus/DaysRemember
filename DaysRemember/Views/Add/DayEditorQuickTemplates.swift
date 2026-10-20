import SwiftUI

/// A sideways row of the template covers, scrolled to the chosen one.
struct DayEditorQuickTemplates: View {
    let photo: PhotoStyle
    let photoData: Data?
    let tint: Color
    var onSelect: (PhotoStyle) -> Void = { _ in }
    @ScaledMetric(relativeTo: .caption) private var coverSwatchWidth: CGFloat = 80

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(PhotoStyle.pickerOptions, id: \.self) { preset in
                        let selected = DayEditorView.isTemplateSelected(preset, photo: photo, photoData: photoData)
                        Button {
                            onSelect(preset)
                        } label: {
                            VStack(spacing: 7) {
                                MiniPolaroid(selected: selected, tint: tint) {
                                    FlatCover(style: preset)
                                        .frame(width: 64, height: 64)
                                }
                                Text(preset.displayName)
                                    .font(Theme.sans(12, weight: .medium, relativeTo: .caption))
                                    .foregroundStyle(selected ? Theme.ink : Theme.ink2)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: coverSwatchWidth)
                        }
                        .buttonStyle(PressScale(scale: 0.95))
                        .accessibilityLabel("选择\(preset.displayName)封面")
                        .accessibilityIdentifier("cover-quick-template.\(preset.rawValue)")
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                        .id(preset.assetName)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("dayCoverQuickTemplates")
            .onChange(of: photoData == nil ? photo.assetName : nil, initial: true) { _, asset in
                if let asset { proxy.scrollTo(asset, anchor: .center) }
            }
        }
    }
}
