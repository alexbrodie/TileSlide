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
    public init(midX: CGFloat, midY: CGFloat, width: CGFloat, height: CGFloat) {
        self.init(x: midX - 0.5 * width,
                  y: midY - 0.5 * height,
                  width: width,
                  height: height)
    }
    
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
    // on each side
    public func inflate(_ size: CGFloat) -> CGRect {
        return inflate(x: size, y: size);
    }

    // Returns a version of this rectangle inflated by the specified amount
    // on each side
    public func inflate(x: CGFloat, y: CGFloat) -> CGRect {
        
        return CGRect(x: minX - x,
                      y: minY - y,
                      width: width + 2 * x,
                      height: height + 2 * y);
    }
    
    // Multiply the dimensions by the specified amount maintaining center coord
    public func scale(_ amount: CGFloat) -> CGRect {
        return CGRect(midX: midX,
                      midY: midY,
                      width: width * amount,
                      height: height * amount)
    }
    
    // Normalize the input relative to self such that
    // A is to R a (0,0,1,1) is to A.normalize(R) and
    // as B is to B.denormalize(A.normalize(R)).
    public func normalize(_ r: CGRect) -> CGRect {
        return CGRect(x: (r.minX - minX) / width,
                      y: (r.minY - minY) / height,
                      width: r.width / width,
                      height: r.height / height)
    }
    
    // Denormalize the input relative to self, i.e. the
    // inverse of normalize.
    public func denormalize(_ r: CGRect) -> CGRect {
        return CGRect(x: minX + r.minX * width,
                      y: minY + r.minY * width,
                      width: r.width * width,
                      height: r.height * height)
    }
}
