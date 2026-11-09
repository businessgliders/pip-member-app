import AVFoundation
import SwiftUI
import UIKit

/// Runs the capture session off the main thread and hands back a photo.
nonisolated final class CameraSession: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera.session")
    private var isConfigured = false
    private var completion: (@Sendable (UIImage?) -> Void)?

    /// Front camera first (it's a profile photo), then any camera, including an external one.
    private static func pickDevice() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first { $0.position == .front }
            ?? discovery.devices.first
    }

    static var hasCamera: Bool { pickDevice() != nil }

    /// Returns false when there's no camera to use.
    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                if !self.isConfigured {
                    guard let device = Self.pickDevice(),
                          let input = try? AVCaptureDeviceInput(device: device) else {
                        continuation.resume(returning: false)
                        return
                    }
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .photo
                    if self.session.canAddInput(input) { self.session.addInput(input) }
                    if self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }
                    self.session.commitConfiguration()
                    self.isConfigured = true
                }
                if !self.session.isRunning { self.session.startRunning() }
                continuation.resume(returning: true)
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func capture(_ completion: @escaping @Sendable (UIImage?) -> Void) {
        queue.async {
            self.completion = completion
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        completion?(image)
        completion = nil
    }
}

/// Camera preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

/// Full-screen "Take Photo": a round viewfinder, a shutter, and distinct states when the
/// camera is off in Settings or there's no camera.
struct CameraCaptureView: View {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    private enum Status { case starting, running, denied, unavailable }

    @State private var camera = CameraSession()
    @State private var status: Status = .starting
    @State private var isCapturing = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Theme.fixedInk.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Theme.cream)
                            .frame(width: 44, height: 44)
                            .background(Theme.cream.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()
                content
                Spacer()
            }
        }
        .environment(\.colorScheme, .dark)
        .task { await begin() }
        .onDisappear { camera.stop() }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .starting, .running:
            VStack(spacing: 40) {
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    CameraPreview(session: camera.session)
                        .frame(width: side, height: side)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.cream.opacity(0.35), lineWidth: 1))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 40)
                .opacity(status == .running ? 1 : 0.3)

                Button(action: shoot) {
                    ZStack {
                        Circle().fill(Theme.cream).frame(width: 64, height: 64)
                        Circle().strokeBorder(Theme.cream, lineWidth: 3).frame(width: 78, height: 78)
                    }
                    .opacity(isCapturing ? 0.5 : 1)
                }
                .buttonStyle(PressableCardStyle())
                .disabled(status != .running || isCapturing)
                .accessibilityLabel("Take photo")
                .sensoryFeedback(.impact(weight: .light), trigger: isCapturing) { _, new in new }
            }
        case .denied:
            message(
                icon: "camera",
                title: "camera is off",
                text: "Allow camera access for Pilates in Pink™ in Settings to take a photo here.",
                action: ("OPEN SETTINGS", {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                })
            )
        case .unavailable:
            message(
                icon: "camera.badge.ellipsis",
                title: "no camera found",
                text: "Choose a photo from your library instead.",
                action: ("BACK", onCancel)
            )
        }
    }

    private func message(icon: String, title: String, text: String, action: (String, () -> Void)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.cream)
            AuthTitle(text: title)
            AuthCaption(text: text)
            Button(action.0, action: action.1)
                .buttonStyle(CreamPillButtonStyle())
                .padding(.top, 16)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: 460)
    }

    private func begin() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { status = .denied; return }
        default:
            status = .denied
            return
        }
        status = await camera.start() ? .running : .unavailable
    }

    private func shoot() {
        isCapturing = true
        camera.capture { image in
            Task { @MainActor in
                isCapturing = false
                if let image { onCapture(image) }
            }
        }
    }
}
