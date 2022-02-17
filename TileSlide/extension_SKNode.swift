//
//  extension_SKNode.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/16/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Foundation
import SpriteKit

extension SKNode {
    // Returns the first ancestor of type T in this node's parent chain (i.e. the deepest
    // in the visual tree closest to self). Note that self is included in this range,
    // and so may be returns. For an exclusive range, just insert parent like
    // node.parent.firstAncestorOfType<SomeNode>().
    public func firstAncestorOfType<T>() -> T? {
        var ancestor: SKNode? = self
        while ancestor != nil {
            if let t = ancestor as? T {
                return t
            }
            ancestor = ancestor!.parent
        }
        return nil
    }
    
    // Returns the last ancestor of type T in this node's parent chain (i.e. the topmost
    // in the visual tree closest to the root). Note that self is included in this range,
    // and so may be returns. For an exclusive range, just insert parent like
    // node.parent.lastAncestorOfType<SomeNode>().
    public func lastAncestorOfType<T>() -> T? {
        var answer: T? = nil
        var ancestor: SKNode? = self
        while ancestor != nil {
            if let t = ancestor as? T {
                answer = t
            }
            ancestor = ancestor!.parent
        }
        return answer
    }
}
