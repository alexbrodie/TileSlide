//
//  SliderScene.swift
//  TileSlide
//
//  Created by Alexander Brodie on 4/23/19.
//  Copyright © 2019 Alex Brodie. All rights reserved.
//

import Combine
import CoreMotion
import GameplayKit
import SpriteKit
import SwiftUI

class SliderScene: SKScene, ObservableObject {
    
    private class TileNode : SKSpriteNode {
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
        // The content (non-chrome) visual
        var content: SKSpriteNode?
    }
    
    private class BoardNode : SKSpriteNode {
        // The current state of the board
        var model = SliderBoard()
        // Each child tile indexed by ordinal
        var tiles: [TileNode] = []
        // Convinence accessor for the empty tile from the above collection
        var emptyTile: TileNode {
            get { return tiles[model.emptyOrdinal] }
        }
    }
    
    @ObservedObject var settings = SliderSettings() {
        didSet { onSettingsReplaced() }
    }
    
    // MARK: Node Names
    private let nodeNameBoard = "brd"
    private let nodeNameLabel = "lbl"
    private let nodeNameTileContent = "con"
    private let nodeNameTile = "til"
    private let nodeNameCrop = "crp"
    
    private let clickSound = SKAction.playSoundFileNamed("Click.wav", waitForCompletion: false)

    // MARK: UI State
    // Last time that tilting the device slid a tile
    private var lastTiltShift: Date = Date()

    // MARK: Connections
    private var cancellableBag = Set<AnyCancellable>()
    // Generator for feedback, e.g. haptics
    private var impactFeedback: UIImpactFeedbackGenerator? = nil
    // Object to fetch accelerometer/gyro data
    private var motionManager: CMMotionManager? = nil
    
    // MARK: Children
    // The current board
    private var currentBoard: BoardNode? = nil
    // Place to show text for debugging
    private var debugText: SKLabelNode? = nil
    
    override init() {
        super.init(size: CGSize(width: 0, height: 0))
        backgroundColor = .black
        scaleMode = .resizeFill
        onSettingsReplaced()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        //setEnableTiltToSlide(true)
        //makeDebugText()
        setup()
    }
    
    override func update(_ currentTime: TimeInterval) {
        let tiltDelay = 0.5
        let pitchOffset = -0.75
        let tiltThreshold = 0.25

        if settings.enableTiltToSlide {
            if let data = motionManager!.deviceMotion, let board = currentBoard {
                // Wait this long between processing tilt slides
                let now = Date()
                if lastTiltShift + tiltDelay < now {
                    let yaw = data.attitude.yaw
                    let pitch = data.attitude.pitch + pitchOffset
                    let roll = data.attitude.roll
                    debugText?.text = String(format: "Y = %.02f P = %.02f R = %.02f", yaw, pitch, roll)
                    
                    var slid = false
                   
                    // Only process one direction whichever is greatest
                    if abs(pitch) > abs(roll) {
                        if pitch < -tiltThreshold {
                            // Negative pitch == tilt forward
                            slid = slideUp(board)
                        } else if pitch > tiltThreshold {
                            // Positive pitch == tilt backward
                            slid = slideDown(board)
                        }
                    }
                    
                    if !slid {
                        if roll < -tiltThreshold {
                            // Negative roll == tilt left
                            slid = slideLeft(board)
                        } else if roll > tiltThreshold {
                            // Positive roll == tilt right
                            slid = slideRight(board)
                        }
                    }
                    
                    if slid {
                        lastTiltShift = now
                    }
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let location = t.location(in: self)
            _ = handleTouch(atPoint(location))
        }
    }
    
    private func handleTouch(_ node: SKNode) -> Bool {
        // First chance processing - this happens on the descendants first, i.e. the bubble phase
        if let tile = node as? TileNode {
            // Move the tile the touch was in
            if trySlideTile(tile) {
                return true
            }
        }
        
        // Let parents try
        if let parent = node.parent {
            if handleTouch(parent) {
                return true
            }
        }
        
        // Fallback handling - this happens on ancestors first, i.e. the routing phase
        if let tile = node as? TileNode {
            subShuffleTile(tile)
            return true
        }
        
        return false
    }
    
    // Called when the settings property is set so that we can
    // reset sinks for our manual bindings
    private func onSettingsReplaced() {
        // Clear old sinks
        for o in cancellableBag {
            o.cancel()
        }
        cancellableBag.removeAll()
        // Set up new sinks
        settings.$tileLabelType.sink { [weak self] value in
            self?.forEachTile { board, tile in
                tile.label?.text = value.glyphFor(
                    columns: board.model.columns,
                    rows: board.model.rows,
                    ordinal: tile.ordinal)
            }
        }.store(in: &cancellableBag)
        settings.$tileLabelColor.sink { [weak self] value in
            self?.forEachTile { (board, tile) in
                tile.label?.fontColor = UIColor(value)
            }
        }.store(in: &cancellableBag)
        settings.$tileLabelFont.sink { [weak self] value in
            self?.forEachTile { board, tile in
                tile.label?.fontName = value
            }
        }.store(in: &cancellableBag)
        settings.$tileLabelSize.sink { [weak self] value in
            self?.forEachTile { (board, tile) in
                tile.label?.fontSize = tile.size.height * CGFloat(value)
            }
        }.store(in: &cancellableBag)
    }
    
    private func setEnableTiltToSlide(_ enable: Bool) {
        settings.enableTiltToSlide = enable
        if enable {
            startDeviceMotionUpdates()
        } else {
            stopDeviceMotionUpdates()
        }
    }
    
    private func startDeviceMotionUpdates() {
        if motionManager == nil {
            motionManager = CMMotionManager()
        }
        if motionManager!.isDeviceMotionAvailable {
            motionManager!.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        }
    }
    
    private func stopDeviceMotionUpdates() {
        motionManager?.stopDeviceMotionUpdates()
    }
    
    private func impactOccurred() {
        if settings.enableHaptics {
            if impactFeedback == nil {
                impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            }
            impactFeedback!.impactOccurred(intensity: 0.4)
        }
    }
    
    private func makeDebugText() {
        let size = CGSize(width: frame.width, height: frame.height * 0.03)
        
        let label = SKLabelNode(text: "Debug\nText")
        label.fontSize = size.height * 0.75
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.fontColor = .black
        label.position = CGPoint(x: size.width * -0.45, y: 0)
        
        let parent = SKSpriteNode(color: UIColor(red: 1, green: 1, blue: 1, alpha: 0.5), size: size)
        parent.position = CGPoint(x: 0, y: frame.minY + size.height)
        parent.zPosition = 1000
        
        parent.addChild(label)
        addChild(parent)
        
        debugText = label
    }
    
    private func setup() {
        let name = String(format: "Doguillo-%d", Int.random(in: 1...19))
        setupNewBoard(columns: 3, 
                      rows: 3, 
                      emptyOrdinal: 8, 
                      texture: SKTexture(imageNamed: name))
    }
    
    // MARK: BoardNode methods
    
    private func cleanupBoard() {
        // Fade out and remove old stuff
        enumerateChildNodes(withName: nodeNameBoard) { (board, stop) in
            board.run(.fadeOut(withDuration: self.settings.speedFactor * 0.25)) {
                board.removeFromParent()
            }
        }
        currentBoard = nil
    }
    
    private func setupNewBoard(columns: Int, rows: Int, emptyOrdinal: Int, texture: SKTexture?) {
        cleanupBoard()
        let rect = frame.middleWithAspect(texture?.size().aspect ?? 1)
        let board = createBoard(columns: columns, rows: rows, emptyOrdinal: emptyOrdinal, texture: texture, rect: rect)
        shuffle(board)
        addChild(board)
        revealTiles(board)
    }
    
    private func createBoard(columns: Int, rows: Int, emptyOrdinal: Int, texture: SKTexture?, rect: CGRect) -> BoardNode {
        let model = SliderBoard(columns: columns, row: rows, emptyOrdinal: emptyOrdinal)
        
        let board = BoardNode(color: .clear, size: rect.size)
        board.name = nodeNameBoard
        board.position = rect.mid
        board.model = model

        // Build nodes for each tile (initially hidden)
        board.tiles = []
        for ordinal in 0..<model.ordinalPositions.count {
            let tile = createTile(board, texture: texture, ordinal: ordinal)
            board.addChild(tile)
            board.tiles.append(tile)
        }

        return board
    }
    
    private func createSubBoard(tile: TileNode) -> BoardNode {
        // Create board with same size, position and texture as the tile's content sprite
        let node = tile.content!
        let model = tile.board.model
        let board = createBoard(
            columns: model.columns,
            rows: model.rows,
            emptyOrdinal: tile.ordinal,
            texture: node.texture,
            rect: node.frame)
        // If the content is already being shown then we need to show the new board
        // before we remove the old content. Otherwise, we'll rely on
        if !node.isHidden {
            for tile in board.tiles {
                tile.alpha = 1
            }
        }
        board.zPosition = node.zPosition
        board.alpha = node.alpha
        node.parent!.addChild(board)
        node.removeFromParent()
        tile.content = board
        return board
    }
    
    // Builds a tile that is populated but not attached to anything
    private func createTile(_ board: BoardNode, texture: SKTexture?, ordinal: Int) -> TileNode {
        let coord = board.model.indexToCoordinate(ordinal)
        let rect = computeTileRect(board, ordinal: ordinal)
        
        var contentNode: SKSpriteNode
        if let tex = texture {
            let texRect = tex.textureRect()
            let subTexRect = CGRect(
                x: texRect.minX + texRect.width * CGFloat(coord.column) / CGFloat(board.model.columns),
                y: texRect.minY + texRect.height * CGFloat(board.model.rows - coord.row - 1) / CGFloat(board.model.rows),
                width: texRect.width / CGFloat(board.model.columns),
                height: texRect.height / CGFloat(board.model.rows))
            let subTex = SKTexture(rect: subTexRect, in: tex)
            contentNode = SKSpriteNode(texture: subTex, size: rect.size)
        } else {
            let color = ordinal % 2 == 0 ? SKColor.black : SKColor.red
            contentNode = SKSpriteNode(color: color, size: rect.size)
        }
        contentNode.name = nodeNameTileContent
        
        let labelText = settings.tileLabelType.glyphFor(
            columns: board.model.columns,
            rows: board.model.rows,
            ordinal: ordinal)
        let labelNode = SKLabelNode(text: labelText)
        labelNode.name = nodeNameLabel
        labelNode.fontColor = UIColor(settings.tileLabelColor)
        labelNode.fontName = settings.tileLabelFont
        labelNode.fontSize = rect.height * CGFloat(settings.tileLabelSize)
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = .center
        labelNode.zPosition = 1
        
        let cropNode = SKCropNode()
        cropNode.name = nodeNameCrop
        cropNode.maskNode = SKSpriteNode(color: .black, size: rect.size)
        
        let tileNode = TileNode(color: .clear, size: rect.size)
        tileNode.name = nodeNameTile
        tileNode.alpha = 0
        tileNode.position = rect.mid
        tileNode.ordinal = ordinal
        tileNode.label = labelNode
        tileNode.crop = cropNode
        tileNode.content = contentNode

        cropNode.addChild(contentNode)
        cropNode.addChild(labelNode)
        tileNode.addChild(cropNode)
        
        return tileNode
    }
        
    // Reveal tiles in the board by waiting for the specified delay
    // and then starting each tile's entrance during the stagger timeframe
    // which each last duration.
    private func revealTiles(_ board: BoardNode) {
        let delay: TimeInterval = 0.25
        let stagger: TimeInterval = 1.0
        let duration: TimeInterval = 0.5
        let solvedReveal: TimeInterval = 0.5
        
        if board.model.isSolved {
            for tile in board.tiles {
                tile.run(.fadeIn(withDuration: solvedReveal))
            }
        } else {
            for tile in board.tiles {
                if tile.ordinal != board.model.emptyOrdinal {
                    let tilePercentile = CGFloat(tile.ordinal) / CGFloat(board.model.ordinalPositions.count - 1)
                    tile.setScale(0.9)
                    tile.run(.sequence([
                        .wait(forDuration: settings.speedFactor * (delay + stagger * tilePercentile)),
                        .group([
                            .scale(to: 1, duration: settings.speedFactor * duration),
                            .fadeIn(withDuration: settings.speedFactor * duration),
                        ]),
                        ]))
                }
            }
        }
    }
    
    // Called when the board enters the solved state - inverse of unsolved
    private func solved(_ board: BoardNode) {
        let duration: TimeInterval = settings.speedFactor * 0.25
        
        // For each tile, remove the chrome to reveal the image, and make sure
        // that it's full visible (especially for the "empty" tile)
        for tile in board.tiles {
            tile.label?.run(.fadeOut(withDuration: duration))
            tile.crop?.maskNode?.run(.scale(to: tile.size, duration: duration))
        }

        board.emptyTile.run(.fadeIn(withDuration: duration))

        // See if an ancestor is a tile - if so this is sub-board, else topmost
        if let tile: TileNode = board.firstAncestorOfType() {
            if !tile.board.model.isSolved {
                tile.label?.run(.fadeIn(withDuration: duration))
            }
        }

        // Determine if all other boards are solved as well
        let rootBoard: BoardNode = board.lastAncestorOfType()!
        let isFullySolved = forEachBoardAndTile(board: rootBoard) { board in
            return board.model.isSolved
        } onTile: { board, tile in
            return true
        }

        if isFullySolved {
            // This is a temp success screen
            backgroundColor = .white
            
            let w = frame.width * 0.6
            let h = frame.height * 0.6
            let r = CGRect(x: frame.midX - w / 2, y: frame.midY - h / 2, width: w, height: h)
            for _ in 0...10 {
                let n = SKSpriteNode(color: .red, size: CGSize(width: 25, height: 25))
                n.position = CGPoint(x: r.midX, y: r.minY)
                addChild(n)
                let dur = 2.0
                n.run(.group([
                    .fadeOut(withDuration: dur),
                    .move(to: CGPoint(x: lerp(from: r.minX, to: r.maxY, ratio: Double.random(in: 0...1)), y: r.maxY), duration: dur)
                ])) {
                    n.removeFromParent()
                }
            }
        }
    }
    
    private func lerp(from: Double, to: Double, ratio: Double) -> Double {
        return (from * (1 - ratio)) + (to * ratio)
    }
    
    // Called when the board enters the unsolved state - inverse of solved
    private func unsolved(_ board: BoardNode) {
        let duration: TimeInterval = settings.speedFactor * 0.25

        for tile in board.tiles {
            if tile.ordinal != board.model.emptyOrdinal {
                tile.label?.run(.fadeIn(withDuration: duration))
                if let crop = tile.crop {
                    let margin = min(tile.size.width, tile.size.height) * settings.tileMarginSize
                    let cropSize = CGSize(width: tile.size.width - margin, height: tile.size.height - margin)
                    crop.maskNode?.run(.scale(to: cropSize, duration: duration))
                }
            }
        }

        board.emptyTile.run(.fadeOut(withDuration: duration))

        // See if an ancestor is a tile
        if let tile: TileNode = board.firstAncestorOfType() {
            tile.label?.run(.fadeOut(withDuration: duration))
        }
    }
    
    // Gets the size of a crop node in the cropped state (showing margins)
    private func getCropNodeSize(_ tileSize: CGSize) -> CGSize {
        let margin = min(size.width, size.height) * settings.tileMarginSize
        return CGSize(width: size.width - margin, height: size.height - margin)
    }
    
    // Get the rectangle for the given grid coordinate
    private func computeTileRect(_ board: BoardNode, ordinal: Int) -> CGRect {
        let coord = board.model.getOrdinalCoordinate(ordinal)
        let size = board.size
        let bounds = CGRect(x: size.width * -0.5, y: size.height * -0.5, width: size.width, height: size.height)
        let tileWidth = bounds.width / CGFloat(board.model.columns)
        let tileHeight = bounds.height / CGFloat(board.model.rows)
        let x = bounds.minX + CGFloat(coord.column) * tileWidth
        let y = bounds.maxY - CGFloat(coord.row + 1) * tileHeight
        return CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
    }
    
    // Update the position of the node to match its model
    private func updateTilePosition(_ board: BoardNode, ordinal: Int) {
        let tile = board.tiles[ordinal]
        let newPos = computeTileRect(board, ordinal: ordinal).mid

        if !isPaused {
            // Animate the tile position
            let moveDuration = settings.speedFactor * 0.125
            tile.run(.group([
                .move(to: newPos, duration: moveDuration),
                .sequence([
                    .wait(forDuration: Double.maximum(moveDuration - settings.debug * 0.2, 0)),
                    clickSound,
                ])
            ])) { [weak self] in
                self?.impactOccurred()
            }
        } else {
            tile.position = newPos
        }
    }
    
    // Shuffle the board
    private func shuffle(_ board: BoardNode) {
        //shuffle(board, count: 10 * board.model.columns * board.model.rows)
        shuffle(board, count: 2)
    }
    
    // Shuffles the board by making count moves
    private func shuffle(_ board: BoardNode, count: Int) {
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
                case 0: slid = slideUp(board)
                case 1: slid = slideRight(board)
                case 2: slid = slideDown(board)
                case 3: slid = slideLeft(board)
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
    private func slideLeft(_ board: BoardNode) -> Bool {
        return slideToEmpty(board, horizontalOffset: 1, verticalOffset: 0)
    }
    
    // Move one tile right into empty slot if possible
    private func slideRight(_ board: BoardNode) -> Bool {
        return slideToEmpty(board, horizontalOffset: -1, verticalOffset: 0)
    }
    
    // Move one tile up into empty slot if possible
    private func slideUp(_ board: BoardNode) -> Bool {
        return slideToEmpty(board, horizontalOffset: 0, verticalOffset: 1)
    }
    
    // Move one tile down into empty slot if possible
    private func slideDown(_ board: BoardNode) -> Bool {
        return slideToEmpty(board, horizontalOffset: 0, verticalOffset: -1)
    }

    // Move the tile at the specified position offset from the empty tile into
    // the empty slot by swapping the two's tile position (with animations).
    // This is the base operation for any tile movement.
    private func slideToEmpty(_ board: BoardNode, horizontalOffset: Int, verticalOffset: Int) -> Bool {
        let wasSolved = board.model.isSolved
        if let ordinal = board.model.swapWithEmpty(horizontalOffset: horizontalOffset, verticalOffset: verticalOffset) {
            updateTilePosition(board, ordinal: ordinal)
            if board.model.isSolved {
                solved(board)
            } else if wasSolved {
                unsolved(board)
            }
            return true
        } else {
            return false
        }
    }
    
    // Moves the specified tile if possible
    private func trySlideTile(_ tile: TileNode) -> Bool {
        let m = tile.board.model
        guard !m.isSolved else { return false }
        let emptyCoord = m.getOrdinalCoordinate(m.emptyOrdinal)
        let tileCoord = m.getOrdinalCoordinate(tile.ordinal)
        if tileCoord.column == emptyCoord.column {
            let verticalMoves = tileCoord.row - emptyCoord.row
            if verticalMoves < 0 {
                // Shift down emptyCoord.row - currentRow times
                for _ in verticalMoves...(-1) {
                    let slid = slideDown(tile.board)
                    assert(slid, "Couldn't slide down")
                }
                return true
            } else if verticalMoves > 0 {
                // Shift up currentRow - emptyCoord.row times
                for _ in 1...verticalMoves {
                    let slid = slideUp(tile.board)
                    assert(slid, "Couldn't slide up")
                }
                return true
            }
        } else if tileCoord.row == emptyCoord.row {
            let horizontalMoves = tileCoord.column - emptyCoord.column
            if horizontalMoves < 0 {
                // Shift right emptyCoord.column - currentColumn times
                for _ in horizontalMoves...(-1) {
                    let slid = slideRight(tile.board)
                    assert(slid, "Couldn't slide right")
                }
                return true
            } else if horizontalMoves > 0 {
                // Shift left currentColumn - emptyCoord.column times
                for _ in 1...horizontalMoves {
                    let slid = slideLeft(tile.board)
                    assert(slid, "Couldn't slide left")
                }
                return true
            }
        }
        // Can't move
        return false
    }
    
    // Turns a tile into a sub-board if it's not already and then shuffles it
    private func subShuffleTile(_ tile: TileNode) {
        var subBoard = tile.content as? BoardNode
        if subBoard == nil {
            subBoard = createSubBoard(tile: tile)
        }
        shuffle(subBoard!, count: 3)
    }
    
    // MARK: Node Lookup
    
    // Enumerate all the TileNode in the visual tree
    private func forEachTile(_ onTile: (BoardNode, TileNode) -> Void) {
        for child in children {
            _ = forEachBoardAndTile(board: child) { board in
                return true
            } onTile: { board, tile in
                onTile(board, tile)
                return true
            }
        }
    }
    
    // Enumerate all the TileNode in the visual tree under the provided board
    // Callbacks should return true to continue the enumeration. This method
    // evaluates to true if all the callbacks return true and the enumeration
    // completes. If one callback returns false the enumeration is canceled
    // and this method evalues to false
    private func forEachBoardAndTile(board: SKNode,
                                     onBoard: (BoardNode) -> Bool,
                                     onTile: (BoardNode, TileNode) -> Bool) -> Bool {
        guard let board = board as? BoardNode  else {
            return true
        }
        guard onBoard(board) else {
            return false
        }
        for tile in board.tiles {
            guard onTile(board, tile) && forEachBoardAndTile(board: tile.content!, onBoard: onBoard, onTile: onTile) else {
                return false
            }
        }
        return true
    }
}
