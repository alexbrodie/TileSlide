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

extension UIImage {
    // Returns a version of this image rotate by the specified amount
    public func rotate(degrees: CGFloat) -> UIImage {
        // Calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        rotatedViewBox.transform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
        let rotatedSize: CGSize = rotatedViewBox.frame.size

        UIGraphicsBeginImageContext(rotatedSize)

        // Create the bitmap context
        let bitmap: CGContext = UIGraphicsGetCurrentContext()!

        // Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)

        // Rotate the image context
        bitmap.rotate(by: (degrees * CGFloat.pi / 180))

        // Now, draw the rotated/scaled image into the context
        bitmap.scaleBy(x: 1.0, y: -1.0)
        bitmap.draw(cgImage!, in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!

        UIGraphicsEndImageContext()

        return newImage
    }
    
    // Returns a version of this image cropped by the specified area
    public func crop(rect: CGRect) -> UIImage {
        var rect = rect
        rect.origin.x *= scale
        rect.origin.y *= scale
        rect.size.width *= scale
        rect.size.height *= scale
        
        let imageRef = cgImage!.cropping(to: rect)
        return UIImage(cgImage: imageRef!, scale: scale, orientation: imageOrientation)
    }
}

extension CGSize {
    // The aspect ratio of this size
    public var aspect: CGFloat {
        get { return width / height }
    }
}

extension CGRect {
    // The middle point in the rect
    public var mid: CGPoint {
        get { return CGPoint(x: midX, y: midY) }
    }
    
    // Returns the largest rectangle with the specified aspect ratio that
    // fits within this which is centered horizontally or vertically
    public func middleWithAspect(_ aspect: CGFloat) -> CGRect {
        if width / height > aspect {
            // I'm wider given the same height, shorter given same width
            // Scale foo by (height / foo.height) to fit within:
            // newWidth = foo.width * (height / foo.height)
            //          = height * aspect
            // newHeight = foo.height * (height / foo.height)
            //           = height
            let newWidth = height * aspect
            let newX = minX + (width - newWidth) * 0.5
            return CGRect(x: newX, y: minY, width: newWidth, height: height)
        } else {
            // Parent is skinnier given same height, taller given same width
            // Scale img by (width / foo.width) to fit within
            // newWidth = foo.width * (width / foo.width)
            //          = width
            // newHeight = foo.height * (width / foo.width)
            //           = width / aspect
            let newHeight = width / aspect
            let newY = minY + (height - newHeight) * 0.5
            return CGRect(x: minX, y: newY, width: width, height: newHeight)
        }
    }
    
    // Returns a version of this rectangle inflated by the specified amount
    public func inflate(_ size: CGFloat) -> CGRect {
        return inflate(x: size, y: size);
    }

    // Returns a version of this rectangle inflated by the specified amount
    public func inflate(x: CGFloat, y: CGFloat) -> CGRect {
        return CGRect(x: minX - x,
                      y: minY - y,
                      width: width + 2 * x,
                      height: height + 2 * y);
    }
}

// A slider board is a grid of tiles, one of which is denoted as "empty".
// In addition to a (column, row) coordinates, the various positions in
// the grid are given an index reading left to right, top to bottom.
// Tiles are then identified by their "ordinal" - the name we give to the
// index of the solved position of the tile.
class SliderBoard {
    struct Coordinate {
        let column: Int
        let row: Int
    }
    
    // The number of columns of tiles (immutable)
    public let columns: Int
    // THe number of rows of tiles (immutable)
    public let rows: Int
    // The identifier for the special empty tile
    public let emptyOrdinal: Int
    // The current position index of each ordinal, i.e. the current column
    // and row position of a tile is indexToCoordinate(tiles[ordinal])
    public private(set) var ordinalPositions: [Int]
    // Inner value used to cache results of isSolved
    private var isSolvedResult: Bool?
    
    public init() {
        columns = 0
        rows = 0
        emptyOrdinal = -1
        ordinalPositions = []
    }

    public init(columns inColumns: Int,
                row inRows: Int,
                emptyTileOrdinal inEmptyTileOrdinal: Int) {
        columns = inColumns
        rows = inRows
        emptyOrdinal = inEmptyTileOrdinal
        ordinalPositions = Array(0..<(inColumns * inRows))
    }
    
    public var isSolved: Bool {
        get {
            if isSolvedResult == nil {
                isSolvedResult = calculateIsSolved()
            }
            return isSolvedResult!
        }
    }
    
    // Convert a position from index to coordinate form
    public func indexToCoordinate(_ index: Int) -> Coordinate {
        return Coordinate(column: index % columns, row: index / columns)
    }
    
    // Convert a position from coordinate to index form
    public func coordinateToIndex(_ coordinate: Coordinate) -> Int {
        return coordinateToIndex(column: coordinate.column, row: coordinate.row)
    }

    // Convert a position from coordinate to index form
    public func coordinateToIndex(column: Int, row: Int) -> Int {
        return column + row * columns
    }
    
    // Convinence method to get the position for an ordinal in coordinate form
    public func getOrdinalCoordinate(_ ordinal: Int) -> Coordinate {
        return indexToCoordinate(ordinalPositions[ordinal])
    }
    
    // The inverse of ordinalPositions, it returns a value such that
    // ordinalPositions[returnValue] == index
    public func getOrdinalAtPosition(_ index: Int) -> Int {
        // For now this a rarish operation and on small collections, so do
        // linear search rather than bothering with managing a reverse lookup
        return ordinalPositions.firstIndex(of: index)!
    }
    
    // Satisfies the specialty need to find what (if any) tile is at a position
    // offset relative to the empty tile and swap positions with the empty tile.
    // Returns the ordinal of the tile swapped with empty if it could swap.
    public func swapWithEmpty(horizontalOffset: Int, verticalOffset: Int) -> Int? {
        let emptyPosIdx = ordinalPositions[emptyOrdinal]
        let emptyCoord = indexToCoordinate(emptyPosIdx)
        let column = emptyCoord.column + horizontalOffset
        guard 0 <= column && column < columns else { return nil }
        let row = emptyCoord.row + verticalOffset
        guard 0 <= row && row < rows else { return nil }
        let otherPosIdx = coordinateToIndex(column: column, row: row)
        let otherOrd = getOrdinalAtPosition(otherPosIdx)
        ordinalPositions.swapAt(emptyOrdinal, otherOrd)
        isSolvedResult = nil
        return otherOrd
    }
    
    private func calculateIsSolved() -> Bool {
        for i in 0..<ordinalPositions.count {
            guard i == ordinalPositions[i] else {
                return false
            }
        }
        return true
    }
}

class SliderScene: SKScene, ObservableObject {
    
    private class TileNode : SKSpriteNode {
        // The board that contans this tile
        var board: BoardNode { get { parent as! BoardNode } }
        // The identifier for the tile in the board
        var ordinal: Int = -1
        // The label containing the tile number associate with this
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
    }
    
    private enum Stage {
        case uninitialized
        case transition
        case playing
        case solved
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

    // MARK: UI State
    // What phase of gameplay we are in
    private var stage: Stage = .uninitialized
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

        if stage == .playing && settings.enableTiltToSlide {
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
            var node: SKNode? = atPoint(location)

            switch stage {
            case .playing:
                // Walk ancestors until we get a tile
                while node != nil {
                    if let tile = node! as? TileNode {
                        // Move the tile the touch was in
                        if trySlideTile(tile) {
                            break
                        }
                    }
                    node = node!.parent
                }
            case .solved:
                setup()
            default:
                break
            }
        }
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
        settings.$tileNumberColor.sink { [weak self] value in
            self?.forEachTile { (board, tile) in
                tile.label?.fontColor = UIColor(value)
            }
        }.store(in: &cancellableBag)
        settings.$tileNumberFontSize.sink { [weak self] value in
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
            impactFeedback!.impactOccurred(intensity: 0.3)
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
        setupBoard(texture: SKTexture(imageNamed: "sample"), columns: 4, rows: 3)
    }
    
    private func cleanupBoard() {
        // Fade out and remove old stuff
        enumerateChildNodes(withName: nodeNameBoard) { (board, stop) in
            board.run(.fadeOut(withDuration: self.settings.speedFactor * 0.25)) {
                board.removeFromParent()
            }
        }
        currentBoard = nil
    }
    
    private func setupBoard(texture: SKTexture?, columns: Int, rows: Int) {
        stage = .transition
        
        cleanupBoard()
        
        let rect = frame.middleWithAspect(texture?.size().aspect ?? 1)
        let board = createBoard(columns: columns, rows: rows, texture: texture, rect: rect)
        shuffle(board)

        let subBoard = createSubBoard(columns: 3, rows: 3, tile: board.tiles[3])
        shuffle(subBoard, count: 2)
        
        addChild(board)

        revealTiles(board)
        revealTiles(subBoard)

        run(.wait(forDuration: settings.speedFactor * 1.5)) { [weak self] () in
            self?.stage = .playing
        }
    }
    
    private func solved(_ board: BoardNode) {
        stage = .transition

        let duration = settings.speedFactor * 0.25
        
        // For each tile, remove the chrome to reveal the image, and make sure
        // that it's full visible (especially for the "empty" tile)
        for tile in board.tiles {
            tile.label?.run(.fadeOut(withDuration: duration))
            tile.crop?.maskNode?.run(.scale(to: tile.size, duration: duration))
            tile.run(.fadeIn(withDuration: duration))
        }

        // See if an ancestor is a tile
        if let tile = tileAncestorOf(board) {
            tile.label?.run(.fadeIn(withDuration: duration))
        }

        // Pause for a second (intentionally without speedFactor multiplier) before
        // officially moving from transition to solved which will allow input
        run(.wait(forDuration: 1.0)) { [weak self] () in
            self?.stage = .solved
        }
    }
    
    // MARK: BoardNode methods
    
    private func createBoard(columns: Int, rows: Int, texture: SKTexture?, rect: CGRect) -> BoardNode {
        let model = SliderBoard(columns: columns,
                                row: rows,
                                emptyTileOrdinal: columns * rows - 1)
        
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
    
    private func createSubBoard(columns: Int, rows: Int, tile: TileNode) -> BoardNode {
        // Create board with same size, position and texture as the tile's content sprite
        let node = tile.content!
        let board = createBoard(columns: columns, rows: rows, texture: node.texture, rect: node.frame)
        // For now we assume we're doing this before all ancestors are added to tree
        // so no graceful animations
        board.zPosition = node.zPosition
        board.alpha = node.alpha
        node.parent!.addChild(board)
        node.removeFromParent()
        tile.content = board
        tile.label?.alpha = 0
        return board
    }
    
    // Builds a tile that is populated but not attached to anything
    private func createTile(_ board: BoardNode, texture: SKTexture?, ordinal: Int) -> TileNode {
        let coord = board.model.indexToCoordinate(ordinal)
        let rect = computeTileRect(board, ordinal: ordinal)
        
        var contentNode: SKSpriteNode
        if let tex = texture {
            let subTexRect = CGRect(
                x: CGFloat(coord.column) / CGFloat(board.model.columns),
                y: CGFloat(board.model.rows - coord.row - 1) / CGFloat(board.model.rows),
                width: 1.0 / CGFloat(board.model.columns),
                height: 1.0 / CGFloat(board.model.rows))
            let subTex = SKTexture(rect: subTexRect, in: tex)
            contentNode = SKSpriteNode(texture: subTex, size: rect.size)
        } else {
            let color = ordinal % 2 == 0 ? SKColor.black : SKColor.red
            contentNode = SKSpriteNode(color: color, size: rect.size)
        }
        contentNode.name = nodeNameTileContent

        let labelNode = SKLabelNode(text: String(format: "%d", 1 + ordinal))
        labelNode.name = nodeNameLabel
        labelNode.fontColor = UIColor(settings.tileNumberColor)
        labelNode.fontName = settings.tileNumberFontFace
        labelNode.fontSize = rect.height * CGFloat(settings.tileNumberFontSize)
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = .center
        labelNode.zPosition = 1
        
        let margin = min(rect.width, rect.height) * -0.5 * settings.tileMarginSize
        let cropRect = rect.inflate(margin)
        
        let cropNode = SKCropNode()
        cropNode.name = nodeNameCrop
        //crop.position = CGPoint(x: cropRect.midX, y: cropRect.midY)
        cropNode.maskNode = SKSpriteNode(color: .black, size: cropRect.size)
        
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
            tile.run(.move(to: newPos, duration: settings.speedFactor * 0.125)) { [weak self] () in
                self?.impactOccurred()
            }
        } else {
            tile.position = newPos
        }
    }
    
    // Shuffle the board
    private func shuffle(_ board: BoardNode) {
        shuffle(board, count: 10 * board.model.columns * board.model.rows)
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
    // the empty slot by swapping the two's tile position (with animations)
    private func slideToEmpty(_ board: BoardNode, horizontalOffset: Int, verticalOffset: Int) -> Bool {
        if let ordinal = board.model.swapWithEmpty(horizontalOffset: horizontalOffset, verticalOffset: verticalOffset) {
            updateTilePosition(board, ordinal: ordinal)
            if board.model.isSolved {
                solved(board)
            }
            return true
        } else {
            return false
        }
    }
    
    // Moves the specified tile if possible
    private func trySlideTile(_ tile: TileNode) -> Bool {
        let m = tile.board.model
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
    
    // MARK: Node Lookup

    // Enumerate all the TileNode in the visual tree
    private func forEachTile(closure: (BoardNode, TileNode) -> Void) {
        for child in children {
            forEachTile(board: child, closure: closure)
        }
    }
    
    // Enumerate all the TileNode in the visual tree under the provided board
    private func forEachTile(board: SKNode, closure: (BoardNode, TileNode) -> Void) {
        if let board = board as? BoardNode {
            for tile in board.tiles {
                closure(board, tile)
                forEachTile(board: tile.content!, closure: closure)
            }
        }
    }
    
    // Returns the TileNode ancestor of the provided node if any
    private func tileAncestorOf(_ node: SKNode) -> TileNode? {
        var ancestor = node.parent
        while ancestor != nil {
            if let tile = ancestor as? TileNode {
                return tile
            }
            ancestor = ancestor?.parent
        }
        return nil
    }
}
