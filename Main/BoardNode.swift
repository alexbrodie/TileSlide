//
//  BoardNode.swift
//  TileSlide
//
//  Created by Alex Brodie on 10/30/22.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Combine
import Foundation
import SpriteKit

protocol BoardNodeDelegate: AnyObject {
    func boardSolved(_ board: BoardNode)
}

class BoardNode: SKSpriteNode {
    // By convention nodes of this type use this default name
    static let nodeName = "brd"
    
    private var settingsConnections = Set<AnyCancellable>()
    public var settings: SliderSettings { didSet { onSettingsReplaced() } }

    // The current state of the board
    var model: SliderBoard
    // Each child tile indexed by ordinal
    var tiles: [TileNode]
    // Convinence accessor for the empty tile from the above collection
    var emptyTile: TileNode {
        get { return tiles[model.emptyOrdinal] }
    }
    
    // Click sound used when tiles move into position
    private let clickSound = SKAction.playSoundFileNamed("Click.wav", waitForCompletion: false)
    
    // Generator for feedback, e.g. haptics
    private var impactFeedback: UIImpactFeedbackGenerator? = nil
    
    //MARK: - Construction and destruction
    
    public init(settings: SliderSettings,
                model: SliderBoard,
                texture: SKTexture?,
                rect: CGRect) {
        self.settings = settings
        self.model = model
        self.tiles = []
        super.init(texture: nil, color: .clear, size: rect.size)
        //super.init(texture: texture, color: .clear, size: rect.size)
        self.position = rect.mid
        self.name = BoardNode.nodeName

        // These are the bounds of the board with some padding along each edge
        let bounds = CGRect(midX: 0, midY: 0, width: rect.size.width, height: rect.size.height)
        let normEdgeSize = settings.boardPaddingSize / 2
        
        // Normalized rectangles
        let normEdgeRects: [CGRect] = [
            CGRect(x: 0,                y: 0,                   width: 1,               height: normEdgeSize),
            CGRect(x: 0,                y: 1 - normEdgeSize,    width: 1,               height: normEdgeSize),
            CGRect(x: 0,                y: normEdgeSize,        width: normEdgeSize,    height: 1 - 2 * normEdgeSize),
            CGRect(x: 1 - normEdgeSize, y: normEdgeSize,        width: normEdgeSize,    height: 1 - 2 * normEdgeSize)
        ]
        
        // Copose the padding fill from texture cutouts based on normEdgeRects
        for normRect in normEdgeRects {
            let subTex = subTexture(texture: texture, normRect: normRect)
            let nodeRect = bounds.denormalize(normRect)
            let edgeNode = SKSpriteNode(texture: subTex, size: nodeRect.size)
            edgeNode.position = nodeRect.mid
            self.addChild(edgeNode)
        }

        for ordinal in 0..<model.ordinalPositions.count {
            let normRect = computeNormalizedTileRect(ordinal)
            let subTex = subTexture(texture: texture, normRect: normRect)
            let nodeRect = bounds.denormalize(normRect)
            let tile = TileNode(settings: settings,
                                model: model,
                                ordinal: ordinal,
                                texture: subTex,
                                rect: nodeRect)
            self.addChild(tile)
            self.tiles.append(tile)
        }
        
        // Set up initial sinks
        onSettingsReplaced()
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
                    let speedFactor = settings.speedFactor
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
    
    //MARK: - Tile movement
    
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
        let bounds = CGRect(midX: 0, midY: 0, width: size.width, height: size.height)
        let newPos = bounds.denormalize(computeNormalizedTileRect(ordinal)).mid

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
            if !tile.parentBoard.model.isSolved {
                // self is newly solved sub-board whose parent board isn't
                // solved, i.e. it has become an active tile
                tile.label?.run(.fadeIn(withDuration: duration))
            }
        }
        
        // Notifiy ancestor node of solve
        if let delegate: BoardNodeDelegate = firstAncestorOfType() {
            delegate.boardSolved(self)
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
    
    //MARK: - Layout
        
    // Get the rectangle for the given grid coordinate
    private func computeNormalizedTileRect(_ ordinal: Int) -> CGRect {
        let coord = model.getOrdinalCoordinate(ordinal)
        let padding = settings.boardPaddingSize
        let bounds = CGRect(x: padding / 2, y: padding / 2, width: 1 - padding, height: 1 - padding)
        let tileWidth = bounds.width / CGFloat(model.columns)
        let tileHeight = bounds.height / CGFloat(model.rows)
        let x = bounds.minX + CGFloat(coord.column) * tileWidth
        let y = bounds.maxY - CGFloat(coord.row + 1) * tileHeight
        return CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
    }

    //MARK: - Utilities

    public var isSolved: Bool {
        get { return model.isSolved }
    }
    
    public func isRecursivelySolved() -> Bool {
        guard isSolved else { return false }
        for tile in tiles {
            if let child = tile.childBoard {
                guard child.isRecursivelySolved() else { return false }
            }
        }
        return true
    }
    
    // Generate haptics appropriate for a collision
    private func impactOccurred() {
        if settings.enableHaptics {
            if impactFeedback == nil {
                impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            }
            impactFeedback!.impactOccurred(intensity: 0.3)
        }
    }
    
    // Creates a texture cutout from a sub-rect of another texture
    private func subTexture(texture: SKTexture?, normRect: CGRect) -> SKTexture? {
        guard let texture = texture else { return nil }
        let subRect = texture.textureRect().denormalize(normRect)
        return SKTexture(rect: subRect, in: texture)
    }

    // Called when the settings property is set so that we can
    // reset sinks for our manual bindings
    private func onSettingsReplaced() {
        // Clear old sinks
        for o in settingsConnections {
            o.cancel()
        }
        settingsConnections.removeAll()
        // Set up new sinks
        settings.$tileLabelType.sink { [weak self] value in
            guard let s = self else { return }
            let col = s.model.columns, row = s.model.rows
            for tile in s.tiles {
                tile.label?.text = value.glyphFor(
                    columns: col,
                    rows: row,
                    ordinal: tile.ordinal)
            }
        }.store(in: &settingsConnections)
        settings.$tileLabelColor.sink { [weak self] value in
            for tile in self?.tiles ?? [] {
                tile.label?.fontColor = UIColor(value)
            }
        }.store(in: &settingsConnections)
        settings.$tileLabelFont.sink { [weak self] value in
            for tile in self?.tiles ?? [] {
                tile.label?.fontName = value
            }
        }.store(in: &settingsConnections)
        settings.$tileLabelSize.sink { [weak self] value in
            for tile in self?.tiles ?? [] {
                tile.label?.fontSize = tile.size.height * CGFloat(value)
            }
        }.store(in: &settingsConnections)
        // Apply seame settings to child boards too
        for t in tiles {
            t.childBoard?.settings = settings
        }
    }
    
}
