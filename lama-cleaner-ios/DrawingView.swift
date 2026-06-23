//
//  DrawingView.swift
//  Lama-Cleaner-iOS
//
//  Created by 間嶋大輔 on 2023/12/27.
//  Modified for Apple Clean Up Exact Neon Glow Effect
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

    // Кастомные слои для эффекта плазмы (Apple Clean Up)
    private let outerGlowLayer = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    private let gradientMaskLayer = CAShapeLayer()
    private let innerCoreLayer = CAShapeLayer()
    private let roiLayer = CAShapeLayer()

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

        // 1. Внешнее свечение (создает мягкий светящийся ореол вокруг кисти)
        outerGlowLayer.fillColor = UIColor.clear.cgColor
        outerGlowLayer.lineCap = .round
        outerGlowLayer.lineJoin = .round
        outerGlowLayer.strokeColor = UIColor.white.withAlphaComponent(0.1).cgColor
        outerGlowLayer.shadowColor = UIColor(red: 0.8, green: 0.2, blue: 1.0, alpha: 1.0).cgColor // Фиолетово-розовое свечение
        outerGlowLayer.shadowRadius = 15
        outerGlowLayer.shadowOpacity = 1.0
        outerGlowLayer.shadowOffset = .zero
        layer.addSublayer(outerGlowLayer)

        // 2. Градиентный слой (полупрозрачная переливающаяся основа)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        
        let color1 = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1.0).cgColor // Голубой
        let color2 = UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1.0).cgColor // Фиолетовый
        let color3 = UIColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0).cgColor // Малиновый
        let color4 = UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0).cgColor // Желтый

        gradientLayer.colors = [color1, color2, color3, color4, color1]
        gradientLayer.opacity = 0.75 // Делаем кисть полупрозрачной, чтобы видеть фото под ней

        // Плавная анимация переливания цветов
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = [color1, color2, color3, color4, color1]
        animation.toValue = [color2, color3, color4, color1, color2]
        animation.duration = 2.0
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "colorsChange")

        // Маска, которая придает градиенту форму нарисованной линии
        gradientMaskLayer.fillColor = UIColor.clear.cgColor
        gradientMaskLayer.strokeColor = UIColor.black.cgColor
        gradientMaskLayer.lineCap = .round
        gradientMaskLayer.lineJoin = .round
        gradientLayer.mask = gradientMaskLayer
        
        layer.addSublayer(gradientLayer)

        // 3. Внутреннее светящееся ядро (создает эффект яркой плазмы внутри кисти)
        innerCoreLayer.fillColor = UIColor.clear.cgColor
        innerCoreLayer.strokeColor = UIColor.white.withAlphaComponent(0.6).cgColor
        innerCoreLayer.lineCap = .round
        innerCoreLayer.lineJoin = .round
        innerCoreLayer.shadowColor = UIColor.white.cgColor
        innerCoreLayer.shadowRadius = 5
        innerCoreLayer.shadowOpacity = 1.0
        innerCoreLayer.shadowOffset = .zero
        layer.addSublayer(innerCoreLayer)
        
        // 4. Слой для отрисовки рамки в режиме Crop ROI
        roiLayer.fillColor = UIColor.clear.cgColor
        roiLayer.strokeColor = UIColor.yellow.withAlphaComponent(0.8).cgColor
        roiLayer.lineWidth = 2.0
        layer.addSublayer(roiLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientMaskLayer.frame = bounds
        outerGlowLayer.frame = bounds
        innerCoreLayer.frame = bounds
        roiLayer.frame = bounds
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

    // Эта функция теперь строит правильную векторную линию для красивого отображения
    private func updatePath() {
        let path = CGMutablePath()

        for line in lines {
            guard let firstPoint = line.points.first else { continue }
            path.move(to: firstPoint)
            for point in line.points.dropFirst() {
                path.addLine(to: point)
            }
        }

        if let currentLine = currentLine {
            guard let firstPoint = currentLine.points.first else { return }
            path.move(to: firstPoint)
            for point in currentLine.points.dropFirst() {
                path.addLine(to: point)
            }
        }

        let cgPath = path.copy()
        
        // Применяем форму линии ко всем слоям эффекта
        outerGlowLayer.path = cgPath
        outerGlowLayer.lineWidth = lineWidth
        
        gradientMaskLayer.path = cgPath
        gradientMaskLayer.lineWidth = lineWidth
        
        innerCoreLayer.path = cgPath
        innerCoreLayer.lineWidth = lineWidth * 0.35 // Ядро тоньше основной кисти
        
        // Отрисовка прямоугольника для режима Crop ROI
        if mode == .cropROI {
            let boundingRect = calculateBoundingRect()
            let rectPath = CGPath(rect: boundingRect, transform: nil)
            roiLayer.path = rectPath
        } else {
            roiLayer.path = nil
        }
    }

    // Эта функция 100% нетронута — она генерирует Ч/Б маску для нейросети
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
