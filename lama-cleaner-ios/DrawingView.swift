//
//  DrawingView.swift
//  Lama-Cleaner-iOS
//
//  Created by 間嶋大輔 on 2023/12/27.
//

import Foundation
import UIKit

struct Line {
    var points: [CGPoint]
    var lineWidth: CGFloat
}

protocol DrawingViewDelegate: AnyObject {
    func drawingViewDidFinishDrawing(_ drawingView: DrawingView)
}

class DrawingView: UIView {
    weak var delegate: DrawingViewDelegate?
    private var mode: InpaintingMode = .wholeImage
    private var lines: [Line] = []
    private var currentLine: Line?
    private var lineWidth: CGFloat = 10

    // MARK: - Plasma animation state
    private var displayLink: CADisplayLink?
    private var glowPhase: CGFloat = 0.0

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Public API

    func setLineWidth(_ width: CGFloat) {
        lineWidth = width
    }

    func setInpaintMode(mode: InpaintingMode) {
        self.mode = mode
    }

    // MARK: - Touch handling (logic unchanged)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let startPoint = touch.location(in: self)
        currentLine = Line(points: [startPoint], lineWidth: lineWidth)
        startPlasmaAnimation()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let newPoint = touch.location(in: self)
        currentLine?.points.append(newPoint)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let completedLine = currentLine {
            lines.append(completedLine)
        }
        currentLine = nil
        setNeedsDisplay()
        delegate?.drawingViewDidFinishDrawing(self)
    }

    // MARK: - Plasma animation

    private func startPlasmaAnimation() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tickPlasma))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func tickPlasma() {
        glowPhase += 0.05
        if glowPhase > .pi * 2 { glowPhase -= .pi * 2 }
        setNeedsDisplay()
    }

    // MARK: - Mask image for AI (COMPLETELY UNCHANGED)

    func getImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: bounds.size))

        for line in lines {
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(line.lineWidth)
            context.setLineCap(.round)

            guard let firstPoint = line.points.first else { continue }
            context.move(to: firstPoint)

            for point in line.points.dropFirst() {
                context.addLine(to: point)
            }

            context.strokePath()
        }

        if let currentLine = currentLine {
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(currentLine.lineWidth)
            context.setLineCap(.round)

            guard let firstPoint = currentLine.points.first else { return nil }
            context.move(to: firstPoint)

            for point in currentLine.points.dropFirst() {
                context.addLine(to: point)
            }

            context.strokePath()
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    func getNormalizedDrawingArea() -> CGRect {
        let drawingArea = calculateBoundingRect()
        return CGRect(
            x: drawingArea.minX / bounds.width,
            y: drawingArea.minY / bounds.height,
            width: drawingArea.width / bounds.width,
            height: drawingArea.height / bounds.height
        )
    }

    // MARK: - Plasma visual draw

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        backgroundColor = .clear

        // Smooth breathing pulse: oscillates between 0.72 and 1.0
        let pulse = 0.72 + 0.28 * sin(glowPhase)

        for line in lines {
            drawPlasmaStroke(line, in: context, pulse: pulse)
        }
        if let current = currentLine {
            drawPlasmaStroke(current, in: context, pulse: pulse)
        }

        if mode == .cropROI {
            let boundingRect = calculateBoundingRect()
            context.setStrokeColor(
                UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.85 * pulse).cgColor
            )
            context.setLineWidth(2.0)
            context.addRect(boundingRect)
            context.strokePath()
        }
    }

    /// Draws one line with 5 concentric passes:
    /// outermost diffuse halo → wide cyan → mid cyan → bright near-white → white-hot core
    private func drawPlasmaStroke(_ line: Line, in context: CGContext, pulse: CGFloat) {
        guard !line.points.isEmpty else { return }
        let w = line.lineWidth

        // (widthMultiplier, R, G, B, alpha)
        // Outer passes first so inner passes paint on top
        let passes: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (5.0, 0.05, 0.45, 1.00, 0.06),  // very wide diffuse blue halo
            (3.2, 0.00, 0.70, 1.00, 0.13),  // wide cyan bloom
            (1.9, 0.00, 0.88, 1.00, 0.32),  // mid cyan glow
            (1.1, 0.50, 0.96, 1.00, 0.62),  // bright ice-blue inner ring
            (0.4, 1.00, 1.00, 1.00, 0.92),  // white-hot plasma core
        ]

        for (widthMul, r, g, b, a) in passes {
            let path = buildPath(for: line)
            context.addPath(path)
            context.setStrokeColor(UIColor(red: r, green: g, blue: b, alpha: a * pulse).cgColor)
            context.setLineWidth(w * widthMul)
            context.setLineCap(.round)
            context.strokePath()
        }
    }

    private func buildPath(for line: Line) -> CGPath {
        let path = CGMutablePath()
        guard let first = line.points.first else { return path }
        path.move(to: first)
        for pt in line.points.dropFirst() {
            path.addLine(to: pt)
        }
        return path
    }

    // MARK: - Bounding rect (logic unchanged)

    private func calculateBoundingRect() -> CGRect {
        guard let minX = lines.flatMap({ $0.points.map(\.x) }).min(),
              let maxX = lines.flatMap({ $0.points.map(\.x) }).max(),
              let minY = lines.flatMap({ $0.points.map(\.y) }).min(),
              let maxY = lines.flatMap({ $0.points.map(\.y) }).max()
        else { return .zero }

        let margin: CGFloat = lineWidth * 1.5
        var r = CGRect(
            x: minX - margin,
            y: minY - margin,
            width:  (maxX - minX) + margin * 2,
            height: (maxY - minY) + margin * 2
        )
        if r.minX < 0           { r.origin.x = 0 }
        if r.minY < 0           { r.origin.y = 0 }
        if r.maxX > bounds.maxX { r.size.width  = bounds.maxX - r.minX }
        if r.maxY > bounds.maxY { r.size.height = bounds.maxY - r.minY }
        return r
    }

    // MARK: - Clear

    func clearDrawing() {
        lines.removeAll()
        currentLine = nil
        displayLink?.invalidate()
        displayLink = nil
        glowPhase = 0.0
        setNeedsDisplay()
    }
}
