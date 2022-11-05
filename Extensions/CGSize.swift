//
//  extension_CGSize.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/14/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Foundation
import CoreGraphics

extension CGSize {
    // The aspect ratio of this size
    public var aspect: CGFloat {
        get { return width / height }
    }
    
    // Multiply each dimension by the specified amount
    public func scale(_ amount: CGFloat) -> CGSize {
        return CGSize(width: width * amount, height: height * amount)
    }
}
