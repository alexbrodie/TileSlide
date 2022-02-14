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
        return UIImage.init(cgImage: imageRef!, scale: scale, orientation: imageOrientation)
    }
}

extension CGSize {
    // The aspect ratio of this size
    public var aspect: CGFloat {
        get { return width / height }
    }
}

extension CGRect {
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

class SliderScene: SKScene, ObservableObject {
    
    private class Tile : SKSpriteNode {
        // The original column position the tile occupies
        var originalColumn: Int = -1
        // The original row position the tile occupies
        var originalRow: Int = -1
        // The current column position the tile occupies
        var currentColumn: Int = -1
        // The current row position the tile occupies
        var currentRow: Int = -1
        // The label containing the tile number associate with this
        var label: SKLabelNode?
        // The crop node used to implement margins
        var crop: SKCropNode?
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
    
    // Names for different categories of nodes, useful for childNode and enumerateChildNodes
    private let nodeNameLabel = "labl"
    private let nodeNameTileImage = "timg"
    private let nodeNameTile = "tile"
    private let nodeNameCrop = "crop"

    // # UI State...
    // What phase of gameplay we are in
    private var stage: Stage = .uninitialized
    // Last time that tilting the device slid a tile
    private var lastTiltShift: Date = Date.init()

    // # Board state...
    // The total number of columns
    private var columns: Int = 0
    // The total number or rows
    private var rows: Int = 0
    // The column of the currently unoccupied tile
    private var emptyColumn: Int = -1
    // The row of the currently unoccupied tile
    private var emptyRow: Int = -1
    // A 2D array of tiles indexed by current position
    private var tiles: [[Tile]] = []
    // The aspect ratio of the content backing the tiles, or 0 if unset
    private var tilesContentAspect: CGFloat = 0
    
    // # Connections...
    private var cancellableBag = Set<AnyCancellable>()
    // Generator for feedback, e.g. haptics
    private var impactFeedback: UIImpactFeedbackGenerator? = nil
    // Object to fetch accelerometer/gyro data
    private var motionManager: CMMotionManager? = nil
    
    // # Children...
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
            if let data = motionManager!.deviceMotion {
                // Wait this long between processing tilt slides
                let now = Date.init()
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
                            slid = slideUp()
                        } else if pitch > tiltThreshold {
                            // Positive pitch == tilt backward
                            slid = slideDown()
                        }
                    }
                    
                    if !slid {
                        if roll < -tiltThreshold {
                            // Negative roll == tilt left
                            slid = slideLeft()
                        } else if roll > tiltThreshold {
                            // Positive roll == tilt right
                            slid = slideRight()
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
                    if let tile = node! as? Tile {
                        // Move the tile the touch was in
                        _ = trySlideTile(tile)
                        break
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
            self?.forEachTileNumberLabel { (label, tile) in
                label.fontColor = UIColor(value)
            }
        }.store(in: &cancellableBag)
        settings.$tileNumberFontSize.sink { [weak self] value in
            self?.forEachTileNumberLabel { (label, tile) in
                label.fontSize = tile.size.height * CGFloat(value)
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
                impactFeedback = UIImpactFeedbackGenerator.init(style: .medium)
            }
            impactFeedback!.impactOccurred(intensity: 0.3)
        }
    }
    
    private func makeDebugText() {
        let size = CGSize.init(width: frame.width, height: frame.height * 0.03)
        
        let label = SKLabelNode.init(text: "Debug\nText")
        label.fontSize = size.height * 0.75
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.fontColor = .black
        label.position = CGPoint.init(x: size.width * -0.45, y: 0)
        
        let parent = SKSpriteNode.init(color: UIColor.init(red: 1, green: 1, blue: 1, alpha: 0.5), size: size)
        parent.position = CGPoint.init(x: 0, y: frame.minY + size.height)
        parent.zPosition = 1000
        
        parent.addChild(label)
        addChild(parent)
        
        debugText = label
    }
    
    private func setup() {
        setup(texture: SKTexture.init(imageNamed: "sample"), columns: 4, rows: 3)
    }
    
    private func cleanup() {
        setup(texture: nil, columns: 0, rows: 0)
    }
    
    private func setup(texture: SKTexture?, columns newColumns: Int, rows newRows: Int) {
        stage = .transition
        
        let speedFactor = settings.speedFactor
        
        // Fade out and remove old stuff
        enumerateChildNodes(withName: nodeNameTile) { (tile, stop) in
            tile.run(.fadeOut(withDuration: speedFactor * 0.25)) {
                tile.removeFromParent()
            }
        }

        // Reset board state
        columns = newColumns
        rows = newColumns
        emptyColumn = columns - 1
        emptyRow = rows - 1
        tiles.removeAll()
        tilesContentAspect = texture?.size().aspect ?? 0
        
        // Build nodes for each tile (initially hidden)
        for c in 0..<columns {
            tiles.append([])
            for r in 0..<rows {
                let tile = createTile(texture: texture, column: c, row: r)
                tile.alpha = 0
                addChild(tile)
                tiles[c].append(tile)
            }
        }
        
        shuffle()

        // Reveal tiles
        for col in tiles {
            for tile in col {
                if tile.currentColumn != emptyColumn || tile.currentRow != emptyRow {
                    let tilePercentile = CGFloat(tile.originalColumn + tile.originalRow * columns) / CGFloat(columns * rows - 1)
                    tile.setScale(0.9)
                    tile.run(.sequence([
                        .wait(forDuration: speedFactor * (0.25 + tilePercentile)),
                        .group([
                            .scale(to: 1, duration: speedFactor * 0.5),
                            .fadeIn(withDuration: speedFactor * 0.5),
                        ]),
                        ]))
                }
            }
        }
        
        run(.wait(forDuration: speedFactor * 1.5)) { [weak self] () in
            self?.stage = .playing
        }
    }
    
    private func solved() {
        stage = .transition

        let duration = settings.speedFactor * 0.25
        
        // For each tile, remove the chrome to reveal the image
        for col in tiles {
            for tile in col {
                tile.label?.run(.fadeOut(withDuration: duration))
                tile.crop?.maskNode?.run(.scale(to: tile.size, duration: duration))
            }
        }

        // Show the empty tile to complete the puzzle
        let emptyTile = tiles[emptyColumn][emptyRow]
        emptyTile.run(.sequence([
                SKAction.fadeAlpha(to: 1, duration: duration),
                SKAction.wait(forDuration: 1.0 /* intentionally without speedFactor multiplier */),
            ])) { [weak self] () in
                self?.stage = .solved
            }
    }
    
    // Get the rectangle for the given grid coordinate
    private func getTileRect(column: Int, row: Int) -> CGRect {
        var bounds: CGRect = frame
        if tilesContentAspect > 0 {
            bounds = bounds.middleWithAspect(tilesContentAspect)
        }
        let tileWidth = bounds.width / CGFloat(columns)
        let tileHeight = bounds.height / CGFloat(rows)
        let x = bounds.minX + CGFloat(column) * tileWidth
        let y = bounds.maxY - CGFloat(row + 1) * tileHeight
        return CGRect.init(x: x, y: y, width: tileWidth, height: tileHeight)
    }
    
    // Builds a tile that is populated but not attached to anything
    private func createTile(texture: SKTexture?, column: Int, row: Int) -> Tile {
        let rect = getTileRect(column: column, row: row)
        let tileNumber = column + row * columns
        
        var imageNode: SKSpriteNode
        if let tex = texture {
            let subTexRect = CGRect.init(x: CGFloat(column) / CGFloat(columns),
                                         y: CGFloat(rows - row - 1) / CGFloat(rows),
                                         width: 1.0 / CGFloat(columns),
                                         height: 1.0 / CGFloat(rows))
            let subTex = SKTexture.init(rect: subTexRect, in: tex)
            imageNode = SKSpriteNode.init(texture: subTex, size: rect.size)
        } else {
            let color = tileNumber % 2 == 0 ? SKColor.black : SKColor.red
            imageNode = SKSpriteNode.init(color: color, size: rect.size)
        }
        imageNode.name = nodeNameTileImage

        let labelNode = SKLabelNode.init(text: String(format: "%d", 1 + tileNumber))
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
        
        let tileNode = Tile.init(color: .init(white: 0, alpha: 0), size: rect.size)
        tileNode.name = nodeNameTile
        tileNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        tileNode.position = CGPoint(x: rect.midX, y: rect.midY)
        tileNode.originalColumn = column
        tileNode.originalRow = row
        tileNode.currentColumn = column
        tileNode.currentRow = row
        tileNode.label = labelNode
        tileNode.crop = cropNode

        cropNode.addChild(imageNode)
        cropNode.addChild(labelNode)
        tileNode.addChild(cropNode)
        
        return tileNode
    }
    
    private func forEachTileNumberLabel(_ closure: (SKLabelNode, SKSpriteNode) -> Void) {
        for child in children {
            if let tile = child as? Tile {
                if let label = tile.label {
                    closure(label, tile)
                }
            }
        }
    }
    
    // Shuffle the board
    private func shuffle() {
        shuffle(10 * columns * rows)
    }
    
    // Shuffles the board by making count moves
    private func shuffle(_ count: Int) {
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
    
    // Moves the specified tile if possible
    private func trySlideTile(_ tile: Tile) -> Bool {
        if tile.currentColumn == emptyColumn {
            let verticalMoves = tile.currentRow - emptyRow
            if verticalMoves < 0 {
                // Shift down emptyRow - currentRow times
                for _ in verticalMoves...(-1) {
                    let slid = slideDown()
                    assert(slid, "Couldn't slide down")
                }
                return true
            } else if verticalMoves > 0 {
                // Shift up currentRow - emptyRow times
                for _ in 1...verticalMoves {
                    let slid = slideUp()
                    assert(slid, "Couldn't slide up")
                }
                return true
            }
        } else if tile.currentRow == emptyRow {
            let horizontalMoves = tile.currentColumn - emptyColumn
            if horizontalMoves < 0 {
                // Shift right emptyColumn - currentColumn times
                for _ in horizontalMoves...(-1) {
                    let slid = slideRight()
                    assert(slid, "Couldn't slide right")
                }
                return true
            } else if horizontalMoves > 0 {
                // Shift left currentColumn - emptyColumn times
                for _ in 1...horizontalMoves {
                    let slid = slideLeft()
                    assert(slid, "Couldn't slide left")
                }
                return true
            }
        }

        // Can't move
        return false
    }
    
    // Move one tile left into empty slot if possible
    private func slideLeft() -> Bool {
        return slideToEmpty(column: emptyColumn + 1, row: emptyRow)
    }
    
    // Move one tile right into empty slot if possible
    private func slideRight() -> Bool {
        return slideToEmpty(column: emptyColumn - 1, row: emptyRow)
    }
    
    // Move one tile up into empty slot if possible
    private func slideUp() -> Bool {
        return slideToEmpty(column: emptyColumn, row: emptyRow + 1)
    }
    
    // Move one tile down into empty slot if possible
    private func slideDown() -> Bool {
        return slideToEmpty(column: emptyColumn, row: emptyRow - 1)
    }

    // Move the specified tile into empty slot
    private func slideToEmpty(column: Int, row: Int) -> Bool {
        if column < 0 || columns <= column || row < 0 || rows <= row {
            // Can't move in this direction
            return false
        }
        
        let tile = tiles[column][row]
        let emptyTile = tiles[emptyColumn][emptyRow]
        // Move the specified tile into the empty area
        setTilePosition(tile: tile, column: emptyColumn, row: emptyRow)
        // And the empty tile gets swapped into the other location
        setTilePosition(tile: emptyTile, column: column, row: row)
        emptyColumn = column
        emptyRow = row
        
        // Figure out the new tile position (for the visible one)
        let newRect = getTileRect(column: tile.currentColumn, row: tile.currentRow)
        let newX = newRect.midX
        let newY = newRect.midY

        if !isPaused {
            // Animate the tile position
            tile.run(.move(to: CGPoint(x: newX, y: newY), duration: settings.speedFactor * 0.125)) { [weak self] () in
                self?.impactOccurred()
            }
        } else {
            tile.position = CGPoint(x: newX, y: newY)
        }
        
        if isSolved() {
            solved()
        }
        
        return true
    }
    
    private func setTilePosition(tile: Tile, column: Int, row: Int) {
        tile.currentColumn = column
        tile.currentRow = row
        tiles[column][row] = tile
    }
    
    // Returns true iff the puzzle has been solved
    private func isSolved() -> Bool {
        for c in 0..<columns {
            for r in 0..<rows {
                let tile = tiles[c][r]
                assert(tile.currentColumn == c)
                assert(tile.currentRow == r)
                if tile.originalColumn != c || tile.originalRow != r {
                    return false
                }
            }
        }
        
        return true
    }
}
