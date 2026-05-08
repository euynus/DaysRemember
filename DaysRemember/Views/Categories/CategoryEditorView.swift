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

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    preview
                    form
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
            FormRow(label: "名称") {
                TextField("例如：朋友", text: $name)
                    .font(Theme.sans(14, relativeTo: .body))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
            }
            FormRow(label: "图标", isLast: true) {
                TextField("SF Symbol", text: $icon)
                    .font(Theme.sans(14, relativeTo: .body))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
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
                        .foregroundStyle(colorToken == token ? Theme.bg : Theme.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(colorToken == token ? Theme.ink : Theme.card)
                        .clipShape(Capsule())
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
        dismiss()
    }
}
