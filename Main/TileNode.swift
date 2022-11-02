//
//  TileNode.swift
//  TileSlide
//
//  Created by Alex Brodie on 10/30/22.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Foundation
import SpriteKit

class TileNode : SKSpriteNode {
    // The board that contans this tile
    var board: BoardNode {
        get { parent as! BoardNode }
    }

    // The identifier for the tile in the board
    var ordinal: Int = -1
    // The label containing the number/glyph associate with this
    var label: SKLabelNode?
    // The crop node used to implement margins
    var crop: SKCropNode?
    // The content (non-chrome) visual (BoardNode or image sprite)
    var content: SKSpriteNode?
}
