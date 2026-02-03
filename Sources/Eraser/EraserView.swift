//
//  EraserView.swift
//  Eraser
//
//  Created by Serhat Akalin
//

import Foundation
import UIKit
import CoreImage

/// A view that displays an image and allows the user to erase or draw on it via a mask.
/// Configure with `configure(with:)` before use. Use `mode` to switch between erase and draw.
public final class EraserView: UIView {

    /// The image used as the foreground (top) content. Set via `configure(with:)` or `configure(foreground:background:)`.
    public private(set) var sourceImage: UIImage?

    /// Optional background (bottom) image. When set, foreground is shown on top and erasing reveals this image.
    public private(set) var backgroundImage: UIImage?

    /// Current tool: erase (reveal) or draw (mask).
    public var mode: DrawTool = .erase

    /// Callback when undo/redo availability changes. Use to enable/disable toolbar buttons.
    public var onUndoRedoStateChanged: ((_ canUndo: Bool, _ canRedo: Bool) -> Void)?

    /// Stroke width for both erase and draw.
    public var lineWidth: CGFloat = 0 {
        didSet {
            shapeLayer.lineWidth = lineWidth
        }
    }

    private var originalMaskImage: CGImage?
    private var maskImage: UIImage? {
        didSet { setNeedsDisplay() }
    }
    private var firstMaskPrepared = true
    private var maskLayer = CALayer()
    private var renderer: UIGraphicsImageRenderer?
    private var path = UIBezierPath()
    private var pathCopy = UIBezierPath()
    private var currentPt = CGPoint.zero
    private var prevPt1 = CGPoint.zero
    private var prevPt2 = CGPoint.zero
    private var undoStack = [DrawAction]()
    private var redoStack = [DrawAction]()
    private let backgroundLayer = CALayer()
    private let foregroundLayer = CALayer()

    private var sourceSize: CGSize {
        guard let img = sourceImage else { return .zero }
        return img.size
    }

    /// When using two layers, mask is in view bounds; otherwise in source image size.
    private var maskSize: CGSize {
        if backgroundImage != nil, bounds.width > 0, bounds.height > 0 {
            return bounds.size
        }
        return sourceSize
    }

    private lazy var shapeLayer: CAShapeLayer = {
        let sl = CAShapeLayer()
        sl.lineWidth = lineWidth
        sl.fillColor = UIColor.clear.cgColor
        sl.strokeColor = UIColor.clear.cgColor
        sl.lineCap = .round
        sl.opacity = 1
        sl.disableAnimations()
        return sl
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        let panRec = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panRec.maximumNumberOfTouches = 1
        addGestureRecognizer(panRec)
    }

    /// Configures the view with a single image (no background). Call once (or when changing image). Required before drawing.
    public func configure(with image: UIImage) {
        configure(foreground: image, background: nil)
    }

    /// Configures with before (bottom) and after (top). User erases the top layer to reveal the bottom. Both images are scaled to fill the view.
    public func configure(foreground afterImage: UIImage, background beforeImage: UIImage) {
        configure(foreground: afterImage, background: beforeImage as UIImage?)
    }

    private func configure(foreground afterImage: UIImage, background beforeImage: UIImage?) {
        sourceImage = afterImage
        backgroundImage = beforeImage
        maskLayer.frame = layer.bounds
        shapeLayer.frame = layer.bounds
        shapeLayer.shouldRasterize = true
        backgroundLayer.removeFromSuperlayer()
        foregroundLayer.removeFromSuperlayer()
        layer.mask = nil
        layer.contents = nil
        if let before = beforeImage {
            backgroundLayer.contents = before.cgImage
            backgroundLayer.contentsGravity = .resizeAspectFill
            backgroundLayer.frame = layer.bounds
            foregroundLayer.contents = afterImage.cgImage
            foregroundLayer.contentsGravity = .resizeAspectFill
            foregroundLayer.frame = layer.bounds
            foregroundLayer.mask = maskLayer
            layer.addSublayer(backgroundLayer)
            layer.addSublayer(foregroundLayer)
        } else {
            layer.contents = afterImage.cgImage
            layer.contentsGravity = .resizeAspectFill
            layer.mask = maskLayer
        }
        layer.addSublayer(shapeLayer)
        initFirstMask()
        originalMaskImage = createFullWhiteMaskImage()
    }

    /// Replaces the foreground (and optional background) and reinitializes the mask.
    public func changeSource(for image: UIImage) {
        if let bg = backgroundImage {
            configure(foreground: image, background: bg)
        } else {
            configure(with: image)
        }
    }

    public override func draw(_ rect: CGRect) {
        guard let sourceImage, var currentMask = maskImage, let ciImage = blurEffectForOverlay(currentMask) else { return }
        if backgroundImage != nil {
            if let cgImage = renderCIImageToCGImage(ciImage) {
                maskLayer.contents = cgImage
            }
        } else {
            let uiImage = UIImage(ciImage: ciImage)
            currentMask = uiImage.mask(withImage: sourceImage, andBlendmode: .destinationIn)
            maskLayer.contents = currentMask.cgImage
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        maskLayer.frame = layer.bounds
        shapeLayer.frame = layer.bounds
        backgroundLayer.frame = layer.bounds
        foregroundLayer.frame = layer.bounds
    }

    @objc private func handlePan(_ gestureRecognizer: UIGestureRecognizer) {
        let pt = gestureRecognizer.location(in: self)
        switch gestureRecognizer.state {
        case .began:
            path.removeAllPoints()
            prevPt1 = pt
            currentPt = pt
        case .changed:
            if pt.distance(to: currentPt) < 3 { return }
            prevPt2 = prevPt1
            prevPt1 = currentPt
            currentPt = pt
            let mid1 = CGPoint.averageOf(pt1: prevPt1, pt2: prevPt2)
            let mid2 = CGPoint.averageOf(pt1: currentPt, pt2: prevPt1)
            path.move(to: mid1)
            path.addQuadCurve(to: mid2, controlPoint: prevPt1)
            shapeLayer.path = path.cgPath
            if mode == .draw {
                drawPoints(fromPoint: prevPt1, toPoint: currentPt, blendMode: .normal)
            } else {
                drawPoints(fromPoint: prevPt1, toPoint: currentPt, blendMode: .clear)
            }
        case .ended, .cancelled, .failed:
            shapeLayer.path = nil
            pathCopy = UIBezierPath(cgPath: path.cgPath)
            addPath(pathCopy, lineWidth: lineWidth)
            if mode == .draw {
                drawPoints(fromPoint: prevPt1, toPoint: prevPt1, blendMode: .normal)
            } else {
                drawPoints(fromPoint: prevPt1, toPoint: prevPt1, blendMode: .clear)
            }
        default:
            break
        }
    }

    private func drawPoints(fromPoint: CGPoint, toPoint: CGPoint, blendMode: CGBlendMode, color: UIColor = .black) {
        let bounds = self.bounds
        let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height)

        UIGraphicsBeginImageContext(bounds.size)
        guard let ctx = UIGraphicsGetCurrentContext(), let _ = maskImage else {
            UIGraphicsEndImageContext()
            return
        }
        maskImage?.draw(in: bounds)
        ctx.move(to: fromPoint)
        ctx.addLine(to: toPoint)
        ctx.concatenate(transform)
        ctx.setLineCap(.round)
        ctx.setLineWidth(lineWidth)
        if mode == .draw {
            ctx.setAlpha(1)
            let strokeColor = backgroundImage != nil ? UIColor.white.cgColor : color.cgColor
            ctx.setFillColor(strokeColor)
            ctx.setStrokeColor(strokeColor)
        } else {
            ctx.setBlendMode(blendMode)
        }
        ctx.strokePath()
        maskImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }

    private func addPath(_ path: UIBezierPath, lineWidth: CGFloat) {
        let action = DrawAction(path: path, mode: mode, lineWidth: lineWidth)
        undoStack.append(action)
        redoStack.removeAll()
        updateUndoStates()
    }

    /// Undoes the last stroke. No-op if nothing to undo.
    public func undo() {
        guard !undoStack.isEmpty else { return }
        let action = undoStack.removeLast()
        redoStack.append(action)
        updateUndoStates()
        maskImage = getMaskedImage(withOriginal: false)
    }

    /// Redoes the last undone stroke. No-op if nothing to redo.
    public func redo() {
        guard !redoStack.isEmpty else { return }
        let action = redoStack.removeLast()
        undoStack.append(action)
        updateUndoStates()
        maskImage = getMaskedImage(withOriginal: false)
    }

    /// Resets the mask to full visibility (no strokes) and clears undo/redo history.
    public func resetToMask() {
        resetHistory()
        maskImage = getMaskedImage(withOriginal: true)
    }

    // MARK: - Private helpers

    private func resetHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoStates()
    }

    private func updateUndoStates() {
        let canUndo = !undoStack.isEmpty
        let canRedo = !redoStack.isEmpty
        onUndoRedoStateChanged?(canUndo, canRedo)
    }

    private func createFullWhiteMaskImage() -> CGImage? {
        guard let sourceImage else { return nil }
        let size = maskSize
        let w = Int(size.width)
        let h = Int(size.height)
        guard w > 0, h > 0, let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 8,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill([CGRect(origin: .zero, size: size)])
        return ctx.makeImage()
    }

    private func getMaskedImage(withOriginal: Bool) -> UIImage? {
        let maskCg = withOriginal ? getFullMaskImage() : getMaskImageWithoutOriginal()
        guard let sourceImage, let sourceCgImage = sourceImage.cgImage, let maskCg else { return nil }
        let maskToUse: CGImage
        if maskCg.width != sourceCgImage.width || maskCg.height != sourceCgImage.height,
           let scaled = scaleMaskImage(maskCg, to: CGSize(width: sourceCgImage.width, height: sourceCgImage.height)) {
            maskToUse = scaled
        } else {
            maskToUse = maskCg
        }
        guard let masked = sourceCgImage.masking(maskToUse) else { return nil }
        return UIImage(cgImage: masked)
    }

    private func scaleMaskImage(_ mask: CGImage, to size: CGSize) -> CGImage? {
        let w = Int(size.width)
        let h = Int(size.height)
        let space = mask.colorSpace ?? CGColorSpaceCreateDeviceGray()
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .default
        ctx.draw(mask, in: CGRect(origin: .zero, size: size))
        return ctx.makeImage()
    }

    private func getFullMaskImage() -> CGImage? {
        guard let originalMaskImage,
              let data = originalMaskImage.dataProvider?.data as? Data else { return nil }
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: pointer, count: data.count)
        defer { pointer.deallocate() }
        guard let space = originalMaskImage.colorSpace,
              let ctx = CGContext(
                  data: pointer,
                  width: originalMaskImage.width,
                  height: originalMaskImage.height,
                  bitsPerComponent: originalMaskImage.bitsPerComponent,
                  bytesPerRow: originalMaskImage.bytesPerRow,
                  space: space,
                  bitmapInfo: originalMaskImage.bitmapInfo.rawValue
              ) else { return nil }
        drawHistory(on: ctx)
        return ctx.makeImage()
    }

    private func getMaskImageWithoutOriginal() -> CGImage? {
        guard let originalMaskImage, let space = originalMaskImage.colorSpace,
              let ctx = CGContext(
                  data: nil,
                  width: originalMaskImage.width,
                  height: originalMaskImage.height,
                  bitsPerComponent: originalMaskImage.bitsPerComponent,
                  bytesPerRow: originalMaskImage.bytesPerRow,
                  space: space,
                  bitmapInfo: originalMaskImage.bitmapInfo.rawValue
              ) else { return nil }
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill([CGRect(origin: .zero, size: sourceSize)])
        drawHistory(on: ctx)
        return ctx.makeImage()
    }

    private func drawHistory(on ctx: CGContext) {
        let height = CGFloat(ctx.height)
        let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        ctx.concatenate(transform)
        ctx.setLineCap(.round)
        for action in undoStack {
            ctx.setLineWidth(action.lineWidth)
            ctx.setStrokeColor(action.mode == .draw ? UIColor.white.cgColor : UIColor.black.cgColor)
            ctx.addPath(action.path.cgPath)
            ctx.strokePath()
        }
    }

    private func initFirstMask() {
        if firstMaskPrepared {
            renderer = UIGraphicsImageRenderer(size: bounds.size)
            guard let renderer else { return }
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(bounds, blendMode: .normal)
                let insetRect = bounds.insetBy(dx: bounds.width, dy: bounds.height)
                UIColor(red: 0, green: 0, blue: 0, alpha: 0).setFill()
                ctx.fill(insetRect)
            }
            firstMaskPrepared = false
            maskImage = image
        } else {
            guard let renderer else { return }
            let image = renderer.image { _ in
                maskImage?.draw(in: bounds)
            }
            maskImage = image
        }
    }

    private func blurEffectForOverlay(_ image: UIImage) -> CIImage? {
        let blurValue: CGFloat = 3.0
        guard let filter = CIFilter(name: "CIGaussianBlur"),
              let beginImage = CIImage(image: image) else { return nil }
        filter.setValue(beginImage, forKey: kCIInputImageKey)
        filter.setValue(blurValue, forKey: kCIInputRadiusKey)
        return filter.outputImage?.cropped(to: beginImage.extent)
    }

    private func renderCIImageToCGImage(_ ciImage: CIImage) -> CGImage? {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        return context.createCGImage(ciImage, from: extent)
    }
}
