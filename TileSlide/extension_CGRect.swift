//
//  extension_CGRect.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/14/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Foundation
import CoreGraphics

extension CGRect {
    // The middle point in the rect
    public var mid: CGPoint {
        get { return CGPoint(x: midX, y: midY) }
    }
    
    // Returns the largest rectangle with the specified aspect ratio that
    // fits within this which is centered horizontally or vertically
    public func middleWithAspect(_ aspect: CGFloat) -> CGRect {
        if width / height > aspect {
            // I'm wider given the same height, shorter given same width
            // Scale foo by (height / foo.height) to fit within:
            // newWidth = foo.width * (height / foo.height)
            //          = height * aspect
            // newHeight = foo.height * (height / foo.height)
            //           = height
            let newWidth = height * aspect
            let newX = minX + (width - newWidth) * 0.5
            return CGRect(x: newX, y: minY, width: newWidth, height: height)
        } else {
            // Parent is skinnier given same height, taller given same width
            // Scale img by (width / foo.width) to fit within
            // newWidth = foo.width * (width / foo.width)
            //          = width
            // newHeight = foo.height * (width / foo.width)
            //           = width / aspect
            let newHeight = width / aspect
            let newY = minY + (height - newHeight) * 0.5
            return CGRect(x: minX, y: newY, width: width, height: newHeight)
        }
    }
    
    // Returns a version of this rectangle inflated by the specified amount
    public func inflate(_ size: CGFloat) -> CGRect {
        return inflate(x: size, y: size);
    }

    // Returns a version of this rectangle inflated by the specified amount
    public func inflate(x: CGFloat, y: CGFloat) -> CGRect {
        return CGRect(x: minX - x,
                      y: minY - y,
                      width: width + 2 * x,
                      height: height + 2 * y);
    }
}
