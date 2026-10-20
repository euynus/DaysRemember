import SwiftUI
import PhotosUI

/// Picks a photo for the cover. A button presents the picker, since `PhotosPicker`'s own label is
/// a `@Sendable` closure that can't read the editor's state.
struct DayEditorPhotoButton: View {
    let photo: PhotoStyle
    let photoData: Data?
    let coverFocusX: Double
    let coverFocusY: Double
    let tint: Color
    /// The editor clears it when a template is chosen instead.
    @Binding var pickerItem: PhotosPickerItem?
    /// The editor holds saving while a photo loads.
    @Binding var isLoadingPhoto: Bool
    /// The picked photo, downsampled and recompressed.
    var onLoad: (Data) -> Void = { _ in }
    var onFailure: () -> Void = {}
    @State private var showPhotoPicker = false

    var body: some View {
        Button {
            showPhotoPicker = true
        } label: {
            HStack(spacing: 8) {
                if let data = photoData {
                    MiniPolaroid(selected: true, tint: tint) {
                        PhotoTile(style: photo, imageData: data, focusX: coverFocusX, focusY: coverFocusY,
                                  flat: true, cornerRadius: 4, maximumPixelSize: 192)
                            .frame(width: 32, height: 32)
                    }
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(Theme.symbol(20))
                        .frame(minWidth: 40, minHeight: 40)
                }
                Text("照片")
                    .font(Theme.sans(14, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.ink2)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("选择相册封面")
        .accessibilityIdentifier("dayCoverPhotoPicker")
        .accessibilityAddTraits(photoData != nil ? [.isSelected] : [])
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images,
                      photoLibrary: .shared())
        .overlay { if isLoadingPhoto { ProgressView() } }
        .task(id: pickerItem) {
            guard let item = pickerItem else { isLoadingPhoto = false; return }
            isLoadingPhoto = true
            defer { if !Task.isCancelled { isLoadingPhoto = false } }
            do {
                let data = try await item.loadTransferable(type: Data.self)
                onLoad(try await CoverPhotoImport.cover(from: data))
            } catch {
                guard !Task.isCancelled else { return }
                onFailure()
            }
        }
    }
}
