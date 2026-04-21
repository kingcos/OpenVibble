import Foundation
import ImageIO
import CoreGraphics
import Combine

@MainActor
public final class GIFPlayer: ObservableObject {
    @Published public private(set) var currentImage: CGImage?

    private var sources: [CGImageSource] = []
    private var activeSourceIdx: Int = 0
    private var currentFrameIdx: Int = 0
    private var frameTimer: Timer?
    private var variantSwitchAt: Date?
    private let variantDwell: TimeInterval = 5.0
    private var isRunning: Bool = false

    public init() {}

    public func load(urls: [URL]) {
        stop()
        sources = urls.compactMap { url -> CGImageSource? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return CGImageSourceCreateWithData(data as CFData, nil)
        }
        activeSourceIdx = 0
        currentFrameIdx = 0
        variantSwitchAt = sources.count > 1 ? Date().addingTimeInterval(variantDwell) : nil
        renderCurrentFrame()
    }

    public func start() {
        guard !isRunning, !sources.isEmpty else { return }
        isRunning = true
        scheduleNextFrame()
    }

    public func stop() {
        isRunning = false
        frameTimer?.invalidate()
        frameTimer = nil
    }

    // Timer is kept on MainActor; relying on release to invalidate when the player
    // instance is torn down. Callers that want deterministic shutdown should call stop().

    private func renderCurrentFrame() {
        guard let source = currentSource() else {
            currentImage = nil
            return
        }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return }
        let idx = currentFrameIdx % frameCount
        guard let image = CGImageSourceCreateImageAtIndex(source, idx, nil) else { return }
        currentImage = image
    }

    private func scheduleNextFrame() {
        guard isRunning, let source = currentSource() else { return }
        let delay = frameDelay(source: source, index: currentFrameIdx)
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advance()
            }
        }
    }

    private func advance() {
        guard isRunning, let source = currentSource() else { return }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return }
        let nextIdx = currentFrameIdx + 1
        let wrapping = nextIdx >= frameCount
        currentFrameIdx = wrapping ? 0 : nextIdx

        if wrapping, sources.count > 1, let switchAt = variantSwitchAt, Date() >= switchAt {
            activeSourceIdx = (activeSourceIdx + 1) % sources.count
            currentFrameIdx = 0
            variantSwitchAt = Date().addingTimeInterval(variantDwell)
        }

        renderCurrentFrame()
        scheduleNextFrame()
    }

    private func currentSource() -> CGImageSource? {
        guard !sources.isEmpty else { return nil }
        return sources[activeSourceIdx % sources.count]
    }

    private func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let gif = props[kCGImagePropertyGIFDictionary as String] as? [String: Any]
        else { return 0.1 }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime as String] as? Double
        let raw = unclamped ?? clamped ?? 0.1
        // Browsers enforce a min delay to prevent runaway animations.
        return raw < 0.02 ? 0.1 : raw
    }
}
