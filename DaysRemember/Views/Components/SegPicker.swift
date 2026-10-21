import SwiftUI

struct SegPicker<Value: Hashable>: View {
    /// What VoiceOver calls the control; the segments say what each choice is.
    let title: String
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize(horizontal: true, vertical: false)
    }
}
