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
}
