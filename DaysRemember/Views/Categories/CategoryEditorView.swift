import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DayStore

    private let category: CategoryDefinition?
    @State private var name: String
    @State private var icon: String
    @State private var colorToken: CategoryColorToken

    init(category: CategoryDefinition? = nil) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _icon = State(initialValue: category?.icon ?? "tag")
        _colorToken = State(initialValue: category?.colorToken ?? .terracotta)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Curated SF Symbols suited to anniversaries / life events — a visual grid
    /// replaces raw symbol-name entry so the icon can never come out blank.
    private static let iconChoices = [
        "heart", "house", "airplane", "briefcase", "sparkles", "star",
        "gift", "birthday.cake", "graduationcap", "book", "cup.and.saucer", "fork.knife",
        "camera", "music.note", "gamecontroller", "leaf", "pawprint", "figure.run",
        "dumbbell", "mappin.and.ellipse", "sun.max", "moon.stars", "flame", "drop",
        "balloon.2", "party.popper", "crown", "bell", "flag", "tag",
    ]

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    preview
                    form
                    iconPicker
                    colorPicker
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var navBar: some View {
        HStack {
            Button("取消") { dismiss() }
                .font(Theme.sans(15, weight: .medium, relativeTo: .body))
                .foregroundStyle(Theme.ink2)
                .buttonStyle(.plain)
                .navTextButton()
            Spacer()
            Text(category == nil ? "新建分类" : "编辑分类")
                .font(Theme.serif(17, weight: .semibold, relativeTo: .headline))
            Spacer()
            Button("保存", action: save)
                .font(Theme.sans(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(Theme.terracotta)
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .navTextButton()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var preview: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(colorToken.color)
                .frame(width: 50, height: 50)
                .background(colorToken.soft, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? "分类名称" : name)
                    .font(Theme.serif(20, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
                Text(colorToken.label)
                    .font(Theme.sans(12, relativeTo: .caption))
                    .foregroundStyle(colorToken.color)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var form: some View {
        InsetCard(radius: 18) {
            FormRow(label: "名称", isLast: true) {
                TextField("例如：朋友", text: $name)
                    .font(Theme.sans(14, relativeTo: .body))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
            }
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "图标")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
                      spacing: 10) {
                ForEach(Self.iconChoices, id: \.self) { symbol in
                    let selected = icon == symbol
                    Button {
                        if !selected { Haptics.selection() }
                        icon = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(selected ? colorToken.color : Theme.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(selected ? colorToken.soft : Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(selected ? colorToken.color.opacity(0.3) : Theme.hairline,
                                                  lineWidth: selected ? 1.5 : 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("图标 \(symbol)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "颜色")
            FlowLayout(spacing: 8) {
                ForEach(CategoryColorToken.allCases) { token in
                    Button { colorToken = token } label: {
                        HStack(spacing: 6) {
                            Circle().fill(token.color).frame(width: 10, height: 10)
                            Text(token.label)
                        }
                        .font(Theme.sans(13, weight: .medium, relativeTo: .body))
                        .foregroundStyle(colorToken == token ? token.color : Theme.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(colorToken == token ? token.soft : Theme.card)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(colorToken == token ? token.color.opacity(0.24) : Theme.hairline,
                                              lineWidth: 0.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func save() {
        if var category {
            category.name = name
            category.icon = icon
            category.colorToken = colorToken
            store.updateCategory(category)
        } else {
            store.addCategory(name: name, icon: icon, colorToken: colorToken)
        }
        Haptics.success()
        dismiss()
    }
}
