//
//  DrawTool.swift
//  Eraser
//
//  Created by Serhat Akalin
//

import UIKit

/// Tool mode for the eraser view: erase (reveal) or draw (mask).
public enum DrawTool: Int {
    case erase = 0
    case draw = 1
}

struct DrawAction {
    let path: UIBezierPath
    let mode: DrawTool
    let lineWidth: CGFloat
}
