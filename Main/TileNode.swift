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

    static let nodeName = "til"
    static let nodeNameLabel = "lbl"
    static let nodeNameCrop = "crp"
    static let nodeNameContent = "con"

    // The board that contans this tile
    var board: BoardNode {
        get { parent as! BoardNode }
    }

    // The identifier for the tile in the board
    var ordinal: Int
    // The label containing the number/glyph associate with this
    var label: SKLabelNode?
    // The crop node used to implement margins
    var crop: SKCropNode?
    // The content (non-chrome) visual (BoardNode or image sprite)
    var content: SKSpriteNode?
    
    // Builds a tile that is populated but not attached to anything
    public init(model: SliderBoard, ordinal: Int, texture: SKTexture?, rect: CGRect) {
        self.ordinal = ordinal
        super.init(texture: nil, color: .clear, size: rect.size)
        self.name = TileNode.nodeName
        self.alpha = 0
        self.position = rect.mid
        
        let coord = model.indexToCoordinate(ordinal)
        
        // TODO!! BUGBUG - route correct settings here
        let settings = SliderSettings()
        settings.tileLabelColor = .green
        
        var contentNode: SKSpriteNode
        if let tex = texture {
            let texRect = tex.textureRect()
            let subTexRect = CGRect(
                x: texRect.minX + texRect.width * CGFloat(coord.column) / CGFloat(model.columns),
                y: texRect.minY + texRect.height * CGFloat(model.rows - coord.row - 1) / CGFloat(model.rows),
                width: texRect.width / CGFloat(model.columns),
                height: texRect.height / CGFloat(model.rows))
            let subTex = SKTexture(rect: subTexRect, in: tex)
            contentNode = SKSpriteNode(texture: subTex, size: rect.size)
        } else {
            let color = ordinal % 2 == 0 ? SKColor.black : SKColor.red
            contentNode = SKSpriteNode(color: color, size: rect.size)
        }
        contentNode.name = TileNode.nodeNameContent
        
        let labelText = settings.tileLabelType.glyphFor(
            columns: model.columns,
            rows: model.rows,
            ordinal: ordinal)
        let labelNode = SKLabelNode(text: labelText)
        labelNode.name = TileNode.nodeNameLabel
        labelNode.alpha = 0
        labelNode.fontColor = UIColor(settings.tileLabelColor)
        labelNode.fontName = settings.tileLabelFont
        labelNode.fontSize = rect.height * CGFloat(settings.tileLabelSize)
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = .center
        labelNode.zPosition = 1
        
        let cropNode = SKCropNode()
        cropNode.name = TileNode.nodeNameCrop
        cropNode.maskNode = SKSpriteNode(color: .black, size: rect.size)
        
        self.label = labelNode
        self.crop = cropNode
        self.content = contentNode

        cropNode.addChild(contentNode)
        cropNode.addChild(labelNode)
        self.addChild(cropNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Moves the specified tile if possible
    public func slide() -> Bool {
        let m = board.model
        guard !m.isSolved else { return false }
        let emptyCoord = m.getOrdinalCoordinate(m.emptyOrdinal)
        let tileCoord = m.getOrdinalCoordinate(ordinal)
        if tileCoord.column == emptyCoord.column {
            let verticalMoves = tileCoord.row - emptyCoord.row
            if verticalMoves < 0 {
                // Shift down emptyCoord.row - currentRow times
                for _ in verticalMoves...(-1) {
                    let slid = board.slideDown()
                    assert(slid, "Couldn't slide down")
                }
                return true
            } else if verticalMoves > 0 {
                // Shift up currentRow - emptyCoord.row times
                for _ in 1...verticalMoves {
                    let slid = board.slideUp()
                    assert(slid, "Couldn't slide up")
                }
                return true
            }
        } else if tileCoord.row == emptyCoord.row {
            let horizontalMoves = tileCoord.column - emptyCoord.column
            if horizontalMoves < 0 {
                // Shift right emptyCoord.column - currentColumn times
                for _ in horizontalMoves...(-1) {
                    let slid = board.slideRight()
                    assert(slid, "Couldn't slide right")
                }
                return true
            } else if horizontalMoves > 0 {
                // Shift left currentColumn - emptyCoord.column times
                for _ in 1...horizontalMoves {
                    let slid = board.slideLeft()
                    assert(slid, "Couldn't slide left")
                }
                return true
            }
        }
        // Can't move
        return false
    }
    
    public func createSubBoard(model: SliderBoard) -> BoardNode {
        // Create board with same size, position and texture as the tile's content sprite
        let node = content!
        let subBoard = BoardNode(model: model, texture: node.texture, rect: node.frame)
        // If the content is already being shown then we need to show the new board
        // before we remove the old content. Otherwise, we'll rely on revealTiles
        if !node.isHidden {
            for tile in subBoard.tiles {
                tile.alpha = 1
            }
        }
        subBoard.zPosition = node.zPosition
        subBoard.alpha = node.alpha
        node.parent!.addChild(subBoard)
        node.removeFromParent()
        content = subBoard
        return subBoard
    }
}
