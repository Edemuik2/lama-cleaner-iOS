//
//  DrawingView.swift
//  Lama-Cleaner-iOS
//
//  Created by 間嶋大輔 on 2023/12/27.
//  Modified for Apple Clean Up Neon Glow Effect
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

    // Кастомные слои для эффекта Apple Intelligence Clean Up
    private let gradientLayer = CAGradientLayer()
    private let strokeMaskLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGlowBrush()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlowBrush()
    }

    private func setupGlowBrush() {
        backgroundColor = .clear

        // 1. Слой свечения (создает неоновую тень вокруг кисти)
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.shadowColor = UIColor(red: 0.8, green: 0.2, blue: 1.0, alpha: 1.0).cgColor // Фиолетово-розовое свечение
        glowLayer.shadowRadius = 15
        glowLayer.shadowOpacity = 1.0
        glowLayer.shadowOffset = .zero
        layer.addSublayer(glowLayer)

        // 2. Градиентный слой (анимированная плазма)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        
        let color1 = UIColor(red: 1.0, green: 0.2, blue: 0.8, alpha: 1.0).cgColor // Неоновый розовый
        let color2 = UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1.0).cgColor // Фиолетовый
        let color3 = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0).cgColor // Голубой
        let color4 = UIColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 1.0).cgColor // Желтый

        gradientLayer.colors = [color1, color2, color3, color4]

        // Анимация переливания цветов
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = [color1, color2, color3, color4]
        animation.toValue = [color4, color1, color2, color3]
        animation.duration = 1.5
        animation.autoreverses = true
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "colorsChange")

        layer.addSublayer(gradientLayer)

        // 3. Слой-маска (вырезает градиент по форме рисунка)
        strokeMaskLayer.fillColor = UIColor.white.cgColor
        gradientLayer.mask = strokeMaskLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        glowLayer.frame = bounds
        strokeMaskLayer.frame = bounds
        updatePath()
    }

    func setLineWidth(_ width: CGFloat) {
        lineWidth = width
    }
    
    func setInpaintMode(mode: InpaintingMode) {
        self.mode = mode
        updatePath()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let startPoint = touch.location(in: self)
        currentLine = Line(points: [startPoint], lineWidth: lineWidth)
        updatePath()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let newPoint = touch.location(in: self)
        currentLine?.points.append(newPoint)
        updatePath()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let completedLine = currentLine {
            lines.append(completedLine)
        }
        currentLine = nil
        updatePath()
        delegate?.drawingViewDidFinishDrawing(self)
    }

    // Главная функция генерации красивой кисти
    private func updatePath() {
        let combinedPath = CGMutablePath()

        for line in lines {
            let linePath = CGMutablePath()
            guard let firstPoint = line.points.first else { continue }
            linePath.move(to: firstPoint)
            for point in line.points.dropFirst() {
                linePath.addLine(to: point)
            }
            // Конвертируем линию в сплошной закрашенный контур
            let strokedPath = linePath.copy(strokingWithWidth: line.lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
            combinedPath.addPath(strokedPath)
        }

        if let currentLine = currentLine {
            let linePath = CGMutablePath()
            guard let firstPoint = currentLine.points.first else { return }
            linePath.move(to: firstPoint)
            for point in currentLine.points.dropFirst() {
                linePath.addLine(to: point)
            }
            let strokedPath = linePath.copy(strokingWithWidth: currentLine.lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
            combinedPath.addPath(strokedPath)
        }
        
        if mode == .cropROI {
            let boundingRect = calculateBoundingRect()
            let rectPath = CGPath(rect: boundingRect, transform: nil)
            let strokedRect = rectPath.copy(strokingWithWidth: 2.0, lineCap: .square, lineJoin: .miter, miterLimit: 10)
            combinedPath.addPath(strokedRect)
        }

        strokeMaskLayer.path = combinedPath
        glowLayer.path = combinedPath
        glowLayer.fillColor = UIColor.white.withAlphaComponent(0.3).cgColor
    }

    // Эта функция остается нетронутой — она генерирует Ч/Б маску для нейросети
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
        let normalizeRect = CGRect(x: drawingArea.minX / bounds.width, y: drawingArea.minY / bounds.height, width: drawingArea.width / bounds.width, height: drawingArea.height / bounds.height)
        return normalizeRect
    }
    
    private func calculateBoundingRect() -> CGRect {
        guard var minX = lines.flatMap({ $0.points.map({ $0.x }) }).min(),
              var maxX = lines.flatMap({ $0.points.map({ $0.x }) }).max(),
              var minY = lines.flatMap({ $0.points.map({ $0.y }) }).min(),
              var maxY = lines.flatMap({ $0.points.map({ $0.y }) }).max()
        else { return CGRect.zero }
        var boundingRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let margin:CGFloat = lineWidth * 1.5
        boundingRect = CGRect(x: minX - margin, y: minY - margin, width: maxX - minX + margin * 2, height: maxY - minY + margin * 2)
        if boundingRect.minX < 0 {
            boundingRect.origin.x = 0
        }
        
        if boundingRect.minY < 0 {
            boundingRect.origin.y = 0
        }
        if boundingRect.maxX > bounds.maxX {
            boundingRect.size.width = bounds.maxX - boundingRect.minX
        }
        if boundingRect.maxY > bounds.maxY {
            boundingRect.size.height = bounds.maxY - boundingRect.minY
        }
        return boundingRect
    }

    func clearDrawing() {
        lines.removeAll()
        currentLine = nil
        updatePath()
    }
}
