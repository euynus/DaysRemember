import SwiftUI

/// Every template cover at a larger size, in a sheet.
struct DayEditorTemplateGallery: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let photo: PhotoStyle
    let photoData: Data?
    let tint: Color
    var onSelect: (PhotoStyle) -> Void = { _ in }
    var onClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("模板插图")
                    .font(Theme.sans(18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("dayCoverTemplateGalleryTitle")
                Spacer(minLength: 8)
                Button {
                    onClose()
                } label: {
                    Label("关闭", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
                .accessibilityIdentifier("closeDayCoverTemplateGallery")
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 10)

            RowDivider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                              alignment: .leading, spacing: 22) {
                        ForEach(PhotoStyle.pickerOptions, id: \.self) { preset in
                            template(preset)
                                .id(preset.assetName)
                        }
                    }
                    .padding(22)
                }
                .accessibilityIdentifier("dayCoverTemplateGallery")
                .onAppear {
                    if photoData == nil {
                        proxy.scrollTo(photo.assetName, anchor: .center)
                    }
                }
            }
        }
        .background(Theme.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func template(_ preset: PhotoStyle) -> some View {
        let selected = DayEditorView.isTemplateSelected(preset, photo: photo, photoData: photoData)
        return Button {
            onSelect(preset)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Color.clear
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay { FlatCover(style: preset).padding(14) }
                    .background(tint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(selected ? Theme.ink : .clear, lineWidth: 2.5)
                    }
                HStack(alignment: .top, spacing: 8) {
                    Text(preset.displayName)
                        .font(Theme.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Theme.accent)
                        .opacity(selected ? 1 : 0)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.98))
        .accessibilityLabel("选择\(preset.displayName)封面")
        .accessibilityIdentifier("cover-template.\(preset.rawValue)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
