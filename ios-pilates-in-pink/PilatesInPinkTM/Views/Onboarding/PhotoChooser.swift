import PhotosUI
import SwiftUI
import UIKit

enum MemberPhoto {
    /// Centre square, at most 1024px, as JPEG at 0.8 quality (orientation baked in).
    static func jpeg(from image: UIImage) -> Data? {
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return nil }
        let target = min(side, 1024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
        let scale = target / side
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let squared = renderer.image { _ in
            image.draw(in: CGRect(
                x: (target - drawSize.width) / 2,
                y: (target - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
        return squared.jpegData(compressionQuality: 0.8)
    }

    /// Uploads to `avatars/{uid}/avatar.jpg`, records it with `set_my_photo`, and shows it
    /// everywhere straight away.
    static func upload(_ jpeg: Data, userId: UUID) async throws {
        let service = StudioService()
        let path = try await service.uploadPhoto(jpeg, userId: userId)
        MemberPhotoCache.shared.replace(path: path, with: jpeg)
    }
}

/// "Add a photo": choose from the library (PhotosPicker) or take one with the camera.
struct PhotoChooser: ViewModifier {
    @Binding var isPresented: Bool
    let onPick: (UIImage) -> Void

    @State private var showsLibrary = false
    @State private var showsCamera = false
    @State private var libraryItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Add a photo", isPresented: $isPresented, titleVisibility: .hidden) {
                Button("Choose from Library") { showsLibrary = true }
                Button("Take Photo") { showsCamera = true }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showsLibrary, selection: $libraryItem, matching: .images)
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onPick(image)
                    }
                    libraryItem = nil
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                CameraCaptureView { image in
                    showsCamera = false
                    onPick(image)
                } onCancel: {
                    showsCamera = false
                }
            }
    }
}

extension View {
    func photoChooser(isPresented: Binding<Bool>, onPick: @escaping (UIImage) -> Void) -> some View {
        modifier(PhotoChooser(isPresented: isPresented, onPick: onPick))
    }
}
