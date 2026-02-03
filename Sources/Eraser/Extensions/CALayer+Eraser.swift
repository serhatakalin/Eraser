//
//  CALayer+Eraser.swift
//  Eraser
//
//  Created by Serhat Akalin
//

import UIKit

extension CALayer {

    func disableAnimations() {
        actions = [
            "onOrderIn": NSNull(),
            "onOrderOut": NSNull(),
            "sublayers": NSNull(),
            "contents": NSNull(),
            "position": NSNull(),
            "bounds": NSNull(),
        ]
    }
}
