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
    
    
    // Get the rectangle for the given grid coordinate
    public func computeTileRect(_ ordinal: Int) -> CGRect {
        let coord = model.getOrdinalCoordinate(ordinal)
        let bounds = CGRect(x: size.width * -0.5, y: size.height * -0.5, width: size.width, height: size.height)
        let tileWidth = bounds.width / CGFloat(model.columns)
        let tileHeight = bounds.height / CGFloat(model.rows)
        let x = bounds.minX + CGFloat(coord.column) * tileWidth
        let y = bounds.maxY - CGFloat(coord.row + 1) * tileHeight
        return CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
    }
    
}
