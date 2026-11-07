import AVFoundation
import SwiftUI
import UIKit

/// The bundled welcome loop and its poster (the video's first frame).
enum WelcomeVideo {
    static let url = Bundle.main.url(forResource: "welcome_loop", withExtension: "mp4")
    static let poster: UIImage? = Bundle.main.path(forResource: "welcome_poster", ofType: "jpg")
        .flatMap { UIImage(contentsOfFile: $0) }

    /// Natural size of the video in pixels.
    static let size = CGSize(width: 720, height: 1280)
    /// Centre and glyph height of the neon "P" in the first frame, in video pixels.
    static let neonCenter = CGPoint(x: 325, y: 550)
    static let neonHeight: CGFloat = 436

    /// Where the neon "P" lands on screen when the video aspect-fills `container`,
    /// expressed as the square frame a `LogoMark` would need to cover it.
    static func neonFrame(in container: CGSize) -> CGRect {
        guard container.width > 0, container.height > 0 else { return .zero }
        let scale = max(container.width / size.width, container.height / size.height)
        let originX = (container.width - size.width * scale) / 2
        let originY = (container.height - size.height * scale) / 2
        let center = CGPoint(x: originX + neonCenter.x * scale, y: originY + neonCenter.y * scale)
        // LogoMark's stem spans 704 of its 768 units.
        let side = neonHeight * scale * LogoGeometry.canvas / (LogoGeometry.stemBottom - LogoGeometry.stemTop)
        return CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }
}

/// Full-bleed poster with the muted loop on top. The player only appears once its first frame
/// has rendered (identical to the poster), so there's never a black flash.
/// With `isActive` false the video pauses; when calm motion is on, only the poster shows.
struct WelcomeVideoBackground: View {
    var isActive: Bool
    @Environment(\.calmMotion) private var calm

    var body: some View {
        ZStack {
            Color(hex: 0xB0386A) // wall pink, under the poster while it decodes
            if let poster = WelcomeVideo.poster {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
            }
            if !calm, let url = WelcomeVideo.url {
                LoopingVideoView(url: url, isPlaying: isActive)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// AVQueuePlayer + AVPlayerLooper in an AVPlayerLayer, aspect-fill, muted, no controls.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    var isPlaying: Bool

    func makeUIView(context: Context) -> LoopingPlayerView {
        LoopingPlayerView(url: url)
    }

    func updateUIView(_ view: LoopingPlayerView, context: Context) {
        view.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ view: LoopingPlayerView, coordinator: ()) {
        view.stop()
    }
}

final class LoopingPlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var readyObservation: NSKeyValueObservation?
    private var wantsPlaying = false

    init(url: URL) {
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false

        // Never interrupt the member's music, never show up in Now Playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        player.isMuted = true
        player.allowsExternalPlayback = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.audiovisualBackgroundPlaybackPolicy = .pauses
        player.actionAtItemEnd = .advance

        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        looper = AVPlayerLooper(player: player, templateItem: item)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        // Hidden until the first frame is on screen; the poster underneath matches it.
        playerLayer.opacity = 0
        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            let ready = layer.isReadyForDisplay
            Task { @MainActor in
                guard let self, ready else { return }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.playerLayer.opacity = 1
                CATransaction.commit()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setPlaying(_ playing: Bool) {
        guard playing != wantsPlaying else { return }
        wantsPlaying = playing
        if playing { player.play() } else { player.pause() }
    }

    func stop() {
        wantsPlaying = false
        player.pause()
        readyObservation?.invalidate()
        readyObservation = nil
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        playerLayer.player = nil
    }
}
