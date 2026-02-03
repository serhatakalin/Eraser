//
//  CGPoint+Eraser.swift
//  Eraser
//
//  Created by Serhat Akalin
//

import UIKit
import CoreGraphics

extension CGPoint {

    func distance(to pt: CGPoint) -> CGFloat {
        let dx = pt.x - x
        let dy = pt.y - y
        return sqrt(dx * dx + dy * dy)
    }

    static func averageOf(pt1: CGPoint, pt2: CGPoint) -> CGPoint {
        CGPoint(
            x: (pt1.x + pt2.x) * 0.5,
            y: (pt1.y + pt2.y) * 0.5
        )
    }
}
