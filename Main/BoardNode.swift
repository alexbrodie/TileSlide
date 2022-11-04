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
    
    static let nodeName = "brd"
    
    private let clickSound = SKAction.playSoundFileNamed("Click.wav", waitForCompletion: false)
    
    // Generator for feedback, e.g. haptics
    private var impactFeedback: UIImpactFeedbackGenerator? = nil
    
    // The current state of the board
    var model: SliderBoard
    // Each child tile indexed by ordinal
    var tiles: [TileNode]
    // Convinence accessor for the empty tile from the above collection
    var emptyTile: TileNode {
        get { return tiles[model.emptyOrdinal] }
    }
    
    var settings: SliderSettings {
        get {
            return SliderSettings() // TODO! BUGBUG
        }
    }
    
    public init(model: SliderBoard, texture: SKTexture?, rect: CGRect) {
        self.model = model
        self.tiles = []
        super.init(texture: nil, color: .clear, size: rect.size)
        self.position = rect.mid
        self.name = BoardNode.nodeName
        
        for ordinal in 0..<model.ordinalPositions.count {
            let rect = computeTileRect(ordinal)
            let tile = TileNode(model: model, ordinal: ordinal, texture: texture, rect: rect)
            self.addChild(tile)
            self.tiles.append(tile)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Reveal tiles in the board by waiting for the specified delay
    // and then starting each tile's entrance during the stagger timeframe
    // which each last duration.
    public func revealTiles() {
        let delay: TimeInterval = 0.25
        let stagger: TimeInterval = 1.0
        let duration: TimeInterval = 0.5
        let solvedReveal: TimeInterval = 0.5
        
        if model.isSolved {
            for tile in tiles {
                tile.run(.fadeIn(withDuration: solvedReveal))
            }
        } else {
            for tile in tiles {
                if tile.ordinal != model.emptyOrdinal {
                    let speedFactor = settings.speedFactor;
                    let tilePercentile = CGFloat(tile.ordinal) / CGFloat(model.ordinalPositions.count - 1)
                    tile.setScale(0.9)
                    tile.run(.sequence([
                        .wait(forDuration: speedFactor * (delay + stagger * tilePercentile)),
                        .group([
                            .scale(to: 1, duration: speedFactor * duration),
                            .fadeIn(withDuration: speedFactor * duration),
                        ]),
                        ]))
                }
            }
        }
    }
    
    public func cleanup() {
        run(.fadeOut(withDuration: self.settings.speedFactor * 0.25)) {
            self.removeFromParent()
        }
    }
    
    // Shuffle the board
    public func shuffle() {
        shuffle(10 * model.columns * model.rows)
    }
    
    // Shuffles the board by making count moves
    public func shuffle(_ count: Int) {
        let oldIsPaused = isPaused
        isPaused = true
        defer { isPaused = oldIsPaused }
        
        var shuffleCount: Int = 0
        var lastDirection: Int = 42  // Something out of bounds [-2,5]
        
        while shuffleCount < count {
            let direction = Int.random(in: 0..<4) // NESW
            
            var slid: Bool = false

            // Disallow the reverse of the previous - no left then right or up then down.
            // Values were chosen such that this means not a difference of 2
            if abs(direction - lastDirection) != 2 {
                switch direction {
                case 0: slid = slideUp()
                case 1: slid = slideRight()
                case 2: slid = slideDown()
                case 3: slid = slideLeft()
                default: assert(false, "unexpected direction")
                }
            }

            if slid {
                lastDirection = direction
                shuffleCount += 1
            }
        }
    }
    
    // Move one tile left into empty slot if possible
    public func slideLeft() -> Bool {
        return slideToEmpty(horizontalOffset: 1, verticalOffset: 0)
    }
    
    // Move one tile right into empty slot if possible
    public func slideRight() -> Bool {
        return slideToEmpty(horizontalOffset: -1, verticalOffset: 0)
    }
    
    // Move one tile up into empty slot if possible
    public func slideUp() -> Bool {
        return slideToEmpty(horizontalOffset: 0, verticalOffset: 1)
    }
    
    // Move one tile down into empty slot if possible
    public func slideDown() -> Bool {
        return slideToEmpty(horizontalOffset: 0, verticalOffset: -1)
    }
    
    private func slideToEmpty(horizontalOffset: Int, verticalOffset: Int) -> Bool {
        let wasSolved = model.isSolved
        if let ordinal = model.swapWithEmpty(horizontalOffset: horizontalOffset, verticalOffset: verticalOffset) {
            updateTilePosition(ordinal)
            if model.isSolved {
                solved()
            } else if wasSolved {
                unsolved()
            }
            return true
        } else {
            return false
        }
    }
    
    // Update the position of the node to match its model
    private func updateTilePosition(_ ordinal: Int) {
        let tile = tiles[ordinal]
        let newPos = computeTileRect(ordinal).mid

        if !isPaused {
            // Animate the tile position
            let moveDuration = settings.speedFactor * 0.125
            let clickLeadIn = 0.068 // empirically derived magic number
            let hapticLeadIn = 0.028 // empirically derived magic number
            tile.run(.group([
                .move(to: newPos, duration: moveDuration),
                .sequence([
                    .wait(forDuration: Double.maximum(moveDuration - hapticLeadIn, 0)),
                    .run { self.impactOccurred() },
                ]),
                .sequence([
                    .wait(forDuration: Double.maximum(moveDuration - clickLeadIn, 0)),
                    clickSound,
                ]),
            ]))
        } else {
            tile.position = newPos
        }
    }
    
    // Called when the board enters the solved state - inverse of unsolved
    private func solved() {
        let duration: TimeInterval = settings.speedFactor * 0.25
        
        // For each tile, remove the chrome to reveal the image, and make sure
        // that it's full visible (especially for the "empty" tile)
        for tile in tiles {
            tile.label?.run(.fadeOut(withDuration: duration))
            tile.crop?.maskNode?.run(.scale(to: tile.size, duration: duration))
        }
        
        // We assume the empty tile was never altered from its initial
        // hidden state and correct size/position from createTile
        emptyTile.run(.fadeIn(withDuration: duration))
        
        if let tile: TileNode = firstAncestorOfType() {
            if !tile.board.model.isSolved {
                // self is newly solved sub-board whose parent board isn't
                // solved, i.e. it has become an active tile
                tile.label?.run(.fadeIn(withDuration: duration))
            }
        }
    }
    
    // Called when the board enters the unsolved state - inverse of solved
    private func unsolved() {
        let duration: TimeInterval = settings.speedFactor * 0.25

        // Reveal each non-empty tile and add a margin around each via crop
        for tile in tiles {
            if tile.ordinal != model.emptyOrdinal {
                tile.label?.run(.fadeIn(withDuration: duration))
                if let crop = tile.crop {
                    let margin = min(tile.size.width, tile.size.height) * settings.tileMarginSize
                    let cropSize = CGSize(width: tile.size.width - margin, height: tile.size.height - margin)
                    crop.maskNode?.run(.scale(to: cropSize, duration: duration))
                }
            }
        }

        emptyTile.run(.fadeOut(withDuration: duration))

        if let tile: TileNode = firstAncestorOfType() {
            // self is an unsolved sub-board of a tile which we
            // want to hide the label for
            tile.label?.run(.fadeOut(withDuration: duration))
        }
    }
    
    // Get the rectangle for the given grid coordinate
    private func computeTileRect(_ ordinal: Int) -> CGRect {
        let coord = model.getOrdinalCoordinate(ordinal)
        let bounds = CGRect(x: size.width * -0.5, y: size.height * -0.5, width: size.width, height: size.height)
        let tileWidth = bounds.width / CGFloat(model.columns)
        let tileHeight = bounds.height / CGFloat(model.rows)
        let x = bounds.minX + CGFloat(coord.column) * tileWidth
        let y = bounds.maxY - CGFloat(coord.row + 1) * tileHeight
        return CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
    }
    
    private func impactOccurred() {
        if settings.enableHaptics {
            if impactFeedback == nil {
                impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            }
            impactFeedback!.impactOccurred(intensity: 0.3)
        }
    }
}
