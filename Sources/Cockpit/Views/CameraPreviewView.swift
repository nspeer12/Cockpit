import SwiftUI
import AVFoundation

/// SwiftUI NSViewRepresentable wrapping AVCaptureVideoPreviewLayer
/// with holographic scanning overlays.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    let showOverlay: Bool

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.session = session
        view.showOverlay = showOverlay
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.session = session
        nsView.showOverlay = showOverlay
    }
}

final class CameraPreviewNSView: NSView {
    var session: AVCaptureSession? {
        didSet {
            previewLayer.session = session
        }
    }

    var showOverlay = true {
        didSet {
            scanningLine.isHidden = !showOverlay
            topBracket.isHidden = !showOverlay
            bottomBracket.isHidden = !showOverlay
            liveBadge.isHidden = !showOverlay
        }
    }

    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let scanningLine = CALayer()
    private let topBracket = CAShapeLayer()
    private let bottomBracket = CAShapeLayer()
    private let liveBadge = CATextLayer()
    private var displayLink: CVDisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupLayers() {
        // Preview layer
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.cornerRadius = 12
        previewLayer.masksToBounds = true
        layer?.addSublayer(previewLayer)

        // Scanning line
        scanningLine.backgroundColor = CGColor(red: 0, green: 1, blue: 1, alpha: 0.3)
        scanningLine.shadowColor = CGColor(red: 0, green: 1, blue: 1, alpha: 0.6)
        scanningLine.shadowRadius = 8
        scanningLine.shadowOpacity = 1
        scanningLine.shadowOffset = .zero
        previewLayer.addSublayer(scanningLine)

        // Corner brackets
        topBracket.strokeColor = CGColor(red: 0, green: 1, blue: 1, alpha: 0.6)
        topBracket.fillColor = nil
        topBracket.lineWidth = 2
        previewLayer.addSublayer(topBracket)

        bottomBracket.strokeColor = CGColor(red: 0.5, green: 0, blue: 1, alpha: 0.6)
        bottomBracket.fillColor = nil
        bottomBracket.lineWidth = 2
        previewLayer.addSublayer(bottomBracket)

        // LIVE badge
        liveBadge.string = "● LIVE"
        liveBadge.fontSize = 11
        liveBadge.foregroundColor = CGColor(red: 0, green: 1, blue: 0.5, alpha: 1)
        liveBadge.alignmentMode = .right
        liveBadge.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        liveBadge.cornerRadius = 4
        liveBadge.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        previewLayer.addSublayer(liveBadge)
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height

        previewLayer.frame = bounds

        // Scanning line (full width, 2px tall)
        scanningLine.frame = CGRect(x: 0, y: 0, width: w, height: 2)

        // Corner brackets
        let bracketLen: CGFloat = 30
        let path = CGMutablePath()
        // Top-left
        path.move(to: CGPoint(x: 8, y: 8 + bracketLen))
        path.addLine(to: CGPoint(x: 8, y: 8))
        path.addLine(to: CGPoint(x: 8 + bracketLen, y: 8))
        // Top-right
        path.move(to: CGPoint(x: w - 8 - bracketLen, y: 8))
        path.addLine(to: CGPoint(x: w - 8, y: 8))
        path.addLine(to: CGPoint(x: w - 8, y: 8 + bracketLen))
        topBracket.path = path
        topBracket.frame = bounds

        // Bottom brackets
        let bPath = CGMutablePath()
        bPath.move(to: CGPoint(x: 8, y: h - 8 - bracketLen))
        bPath.addLine(to: CGPoint(x: 8, y: h - 8))
        bPath.addLine(to: CGPoint(x: 8 + bracketLen, y: h - 8))
        bPath.move(to: CGPoint(x: w - 8 - bracketLen, y: h - 8))
        bPath.addLine(to: CGPoint(x: w - 8, y: h - 8))
        bPath.addLine(to: CGPoint(x: w - 8, y: h - 8 - bracketLen))
        bottomBracket.path = bPath
        bottomBracket.frame = bounds

        // LIVE badge top-right
        liveBadge.frame = CGRect(x: w - 70, y: h - 28, width: 62, height: 20)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startScanAnimation()
    }

    private func startScanAnimation() {
        let anim = CABasicAnimation(keyPath: "position.y")
        anim.fromValue = 0
        anim.toValue = bounds.height
        anim.duration = 2.5
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        scanningLine.add(anim, forKey: "scan")
    }
}
