//
//  BoardNode.swift
//  TileSlide
//
//  Created by Alex Brodie on 10/30/22.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Foundation
import SpriteKit

class BoardNode : SKSpriteNode {
    // The current state of the board
    var model = SliderBoard()
    // Each child tile indexed by ordinal
    var tiles: [TileNode] = []
    // Convinence accessor for the empty tile from the above collection
    var emptyTile: TileNode {
        get { return tiles[model.emptyOrdinal] }
    }
}
