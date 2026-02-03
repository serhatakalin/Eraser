//
//  UIImage+Eraser.swift
//  Eraser
//
//  Created by Serhat Akalin
//

import UIKit

extension UIImage {

    func mask(withImage image: UIImage, andBlendmode blendmode: CGBlendMode) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return self }
        let rect = CGRect(origin: .zero, size: size)
        draw(in: rect, blendMode: .normal, alpha: 1.0)
        image.draw(in: CGRect(origin: .zero, size: image.size), blendMode: blendmode, alpha: 1.0)
        context.setBlendMode(blendmode)
        guard let resultImage = UIGraphicsGetImageFromCurrentImageContext() else { return self }
        return resultImage
    }
}
