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
    public func rotate(degrees: CGFloat) -> UIImage {
        // Calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
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
        bitmap.draw(self.cgImage!, in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!

        UIGraphicsEndImageContext()

        return newImage
    }
    
    public func crop(rect: CGRect) -> UIImage {
        var rect = rect
        rect.origin.x *= self.scale
        rect.origin.y *= self.scale
        rect.size.width *= self.scale
        rect.size.height *= self.scale
        
        let imageRef = self.cgImage!.cropping(to: rect)
        return UIImage.init(cgImage: imageRef!, scale: self.scale, orientation: self.imageOrientation)
    }
}

extension CGRect {
    public func middleWithAspect(_ aspect: CGFloat) -> CGRect {
        if self.width / self.height > aspect {
            // I'm wider given the same height, shorter given same width
            // Scale foo by (self.height / foo.height) to fit within:
            // newWidth = foo.width * (self.height / foo.height)
            //          = self.height * aspect
            // newHeight = foo.height * (self.height / foo.height)
            //           = self.height
            let newWidth = self.height * aspect
            let newX = self.minX + (self.width - newWidth) * 0.5
            return CGRect(x: newX, y: self.minY, width: newWidth, height: self.height)
        } else {
            // Parent is skinnier given same height, taller given same width
            // Scale img by (self.width / foo.width) to fit within
            // newWidth = foo.width * (self.width / foo.width)
            //          = self.width
            // newHeight = foo.height * (self.width / foo.width)
            //           = self.width / aspect
            let newHeight = self.width / aspect
            let newY = self.minY + (self.height - newHeight) * 0.5
            return CGRect(x: self.minX, y: newY, width: self.width, height: newHeight)
        }
    }
    
    public func inflate(_ size: CGFloat) -> CGRect {
        return inflate(x: size, y: size);
    }

    public func inflate(x: CGFloat, y: CGFloat) -> CGRect {
        return CGRect(x: self.minX - x,
                      y: self.minY - y,
                      width: self.width + 2 * x,
                      height: self.height + 2 * y);
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
    let nodeNameLabel = "labl"
    let nodeNameTileImage = "timg"
    let nodeNameTile = "tile"
    let nodeNameCrop = "crop"

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
        self.backgroundColor = .black
        self.scaleMode = .resizeFill
        onSettingsReplaced()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        //self.setEnableTiltToSlide(true)
        //self.makeDebugText()
        self.setup()
    }
    
    override func update(_ currentTime: TimeInterval) {
        let tiltDelay = 0.5
        let pitchOffset = -0.75
        let tiltThreshold = 0.25

        if self.stage == .playing && self.settings.enableTiltToSlide {
            if let data = self.motionManager!.deviceMotion {
                // Wait this long between processing tilt slides
                let now = Date.init()
                if self.lastTiltShift + tiltDelay < now {
                    let yaw = data.attitude.yaw
                    let pitch = data.attitude.pitch + pitchOffset
                    let roll = data.attitude.roll
                    self.debugText?.text = String(format: "Y = %.02f P = %.02f R = %.02f", yaw, pitch, roll)
                    
                    var slid = false
                   
                    // Only process one direction whichever is greatest
                    if abs(pitch) > abs(roll) {
                        if pitch < -tiltThreshold {
                            // Negative pitch == tilt forward
                            slid = self.slideUp()
                        } else if pitch > tiltThreshold {
                            // Positive pitch == tilt backward
                            slid = self.slideDown()
                        }
                    }
                    
                    if !slid {
                        if roll < -tiltThreshold {
                            // Negative roll == tilt left
                            slid = self.slideLeft()
                        } else if roll > tiltThreshold {
                            // Positive roll == tilt right
                            slid = self.slideRight()
                        }
                    }
                    
                    if slid {
                        self.lastTiltShift = now
                    }
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let location = t.location(in: self)
            var node: SKNode? = self.atPoint(location)

            switch self.stage {
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
    
    private func onSettingsReplaced() {
        // Clear old sinks
        for o in cancellableBag {
            o.cancel()
        }
        cancellableBag.removeAll()
        // Set up new sinks
        self.settings.$tileNumberColor.sink { value in
            self.forEachTileNumberLabel { (label, tile) in
                label.fontColor = UIColor(value)
            }
        }.store(in: &cancellableBag)
        self.settings.$tileNumberFontSize.sink { value in
            self.forEachTileNumberLabel { (label, tile) in
                label.fontSize = tile.size.height * CGFloat(value)
            }
        }.store(in: &cancellableBag)
    }
    
    private func setEnableTiltToSlide(_ enable: Bool) {
        self.settings.enableTiltToSlide = enable
        if enable {
            self.startDeviceMotionUpdates()
        } else {
            self.stopDeviceMotionUpdates()
        }
    }
    
    private func startDeviceMotionUpdates() {
        if self.motionManager == nil {
            self.motionManager = CMMotionManager()
        }
        if self.motionManager!.isDeviceMotionAvailable {
            self.motionManager!.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        }
    }
    
    private func stopDeviceMotionUpdates() {
        self.motionManager?.stopDeviceMotionUpdates()
    }
    
    private func impactOccurred() {
        if self.settings.enableHaptics {
            if self.impactFeedback == nil {
                self.impactFeedback = UIImpactFeedbackGenerator.init(style: .medium)
            }
            if #available(iOS 13.0, *) {
                self.impactFeedback!.impactOccurred(intensity: 0.3)
            } else {
                self.impactFeedback!.impactOccurred()
            }
        }
    }
    
    private func makeDebugText() {
        let size = CGSize.init(width: self.frame.width, height: self.frame.height * 0.03)
        
        let label = SKLabelNode.init(text: "Debug\nText")
        label.fontSize = size.height * 0.75
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.fontColor = .black
        label.position = CGPoint.init(x: size.width * -0.45, y: 0)
        
        let parent = SKSpriteNode.init(color: UIColor.init(red: 1, green: 1, blue: 1, alpha: 0.5), size: size)
        parent.position = CGPoint.init(x: 0, y: self.frame.minY + size.height)
        parent.zPosition = 1000
        
        parent.addChild(label)
        self.addChild(parent)
        
        self.debugText = label
    }
    
    private func setup() {
        self.setup(image: UIImage.init(named: "sample"), columns: 4, rows: 3)
    }
    
    private func cleanup() {
        self.setup(image: nil, columns: 0, rows: 0)
    }
    
    private func setup(image: UIImage?, columns: Int, rows: Int) {
        self.stage = .transition
        
        let speedFactor = self.settings.speedFactor
        
        // Fade out and remove old stuff
        self.enumerateChildNodes(withName: nodeNameTile) { (tile, stop) in
            tile.run(.fadeOut(withDuration: speedFactor * 0.25)) {
                tile.removeFromParent()
            }
        }

        // Reset board state
        self.columns = columns
        self.rows = rows
        self.emptyColumn = columns - 1
        self.emptyRow = rows - 1
        self.tiles.removeAll()
        self.tilesContentAspect = 0

        // Make texture for the sprite nodes
        var tex: SKTexture?
        if let img = image {
            tex = SKTexture.init(image: img)
            self.tilesContentAspect = img.size.width / img.size.height
        }
        
        // Build nodes for each tile (initially hidden)
        for c in 0..<columns {
            self.tiles.append([])
            for r in 0..<rows {
                let tileNumber = c + r * columns
                
                let rect = getTileRect(column: c, row: r)
                
                var image: SKSpriteNode
                if tex != nil {
                    let subTexRect = CGRect.init(x: CGFloat(c) / CGFloat(columns),
                                                 y: CGFloat(rows - r - 1) / CGFloat(rows),
                                                 width: 1.0 / CGFloat(columns),
                                                 height: 1.0 / CGFloat(rows))
                    let subTex = SKTexture.init(rect: subTexRect, in: tex!)
                    image = SKSpriteNode.init(texture: subTex, size: rect.size)
                } else {
                    let color = tileNumber % 2 == 0 ? SKColor.black : SKColor.red
                    image = SKSpriteNode.init(color: color, size: rect.size)
                }
                image.name = nodeNameTileImage

                let label = SKLabelNode.init(text: String(format: "%d", 1 + tileNumber))
                label.name = nodeNameLabel
                label.fontColor = UIColor(self.settings.tileNumberColor)
                label.fontName = self.settings.tileNumberFontFace
                label.fontSize = rect.height * CGFloat(self.settings.tileNumberFontSize)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = 1
                
                let margin = min(rect.width, rect.height) * -0.5 * self.settings.tileMarginSize
                let cropRect = rect.inflate(margin)
                let crop = SKCropNode()
                crop.name = nodeNameCrop
                //crop.position = CGPoint(x: cropRect.midX, y: cropRect.midY)
                crop.maskNode = SKSpriteNode(color: .black, size: cropRect.size)
                
                let tile = Tile.init(color: .init(white: 0, alpha: 0), size: rect.size)
                tile.name = nodeNameTile
                tile.alpha = 0
                tile.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                tile.position = CGPoint(x: rect.midX, y: rect.midY)
                tile.originalColumn = c
                tile.originalRow = r
                tile.currentColumn = c
                tile.currentRow = r
                tile.label = label
                tile.crop = crop

                crop.addChild(image)
                crop.addChild(label)
                tile.addChild(crop)
                self.addChild(tile)
                
                tiles[c].append(tile)
            }
        }
        
        self.shuffle()

        // Reveal tiles
        for col in self.tiles {
            for tile in col {
                if tile.currentColumn != self.emptyColumn || tile.currentRow != self.emptyRow {
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
        
        self.run(.wait(forDuration: speedFactor * 1.5)) {
            self.stage = .playing
        }
    }
    
    private func solved() {
        self.stage = .transition

        let duration = self.settings.speedFactor * 0.25
        
        // For each tile, remove the chrome to reveal the image
        for col in self.tiles {
            for tile in col {
                tile.label?.run(.fadeOut(withDuration: duration))
                tile.crop?.maskNode?.run(.scale(to: tile.size, duration: duration))
            }
        }

        // Show the empty tile to complete the puzzle
        let emptyTile = self.tiles[self.emptyColumn][self.emptyRow]
        emptyTile.run(.sequence([
                SKAction.fadeAlpha(to: 1, duration: duration),
                SKAction.wait(forDuration: 1.0 /* intentionally without speedFactor multiplier */),
            ])) {
                self.stage = .solved
            }
    }
    
    // Get the rectangle for the given grid coordinate
    private func getTileRect(column: Int, row: Int) -> CGRect {
        var bounds: CGRect = self.frame
        if self.tilesContentAspect > 0 {
            bounds = bounds.middleWithAspect(self.tilesContentAspect)
        }
        let tileWidth = bounds.width / CGFloat(self.columns)
        let tileHeight = bounds.height / CGFloat(self.rows)
        let x = bounds.minX + CGFloat(column) * tileWidth
        let y = bounds.maxY - CGFloat(row + 1) * tileHeight
        return CGRect.init(x: x, y: y, width: tileWidth, height: tileHeight)
    }
    
    private func forEachTileNumberLabel(_ closure: (SKLabelNode, SKSpriteNode) -> Void) {
        for child in self.children {
            if let tile = child as? Tile {
                if let label = tile.label {
                    closure(label, tile)
                }
            }
        }
    }
    
    // Shuffle the board
    private func shuffle() {
        shuffle(10 * self.columns * self.rows)
    }
    
    // Shuffles the board by making count moves
    private func shuffle(_ count: Int) {
        let oldIsPaused = self.isPaused
        self.isPaused = true
        defer { self.isPaused = oldIsPaused }
        
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
        if tile.currentColumn == self.emptyColumn {
            let verticalMoves = tile.currentRow - self.emptyRow
            if verticalMoves < 0 {
                // Shift down emptyRow - currentRow times
                for _ in verticalMoves...(-1) {
                    let slid = self.slideDown()
                    assert(slid, "Couldn't slide down")
                }
                return true
            } else if verticalMoves > 0 {
                // Shift up currentRow - emptyRow times
                for _ in 1...verticalMoves {
                    let slid = self.slideUp()
                    assert(slid, "Couldn't slide up")
                }
                return true
            }
        } else if tile.currentRow == self.emptyRow {
            let horizontalMoves = tile.currentColumn - self.emptyColumn
            if horizontalMoves < 0 {
                // Shift right emptyColumn - currentColumn times
                for _ in horizontalMoves...(-1) {
                    let slid = self.slideRight()
                    assert(slid, "Couldn't slide right")
                }
                return true
            } else if horizontalMoves > 0 {
                // Shift left currentColumn - emptyColumn times
                for _ in 1...horizontalMoves {
                    let slid = self.slideLeft()
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
        return self.slideToEmpty(column: self.emptyColumn + 1, row: self.emptyRow)
    }
    
    // Move one tile right into empty slot if possible
    private func slideRight() -> Bool {
        return self.slideToEmpty(column: emptyColumn - 1, row: self.emptyRow)
    }
    
    // Move one tile up into empty slot if possible
    private func slideUp() -> Bool {
        return self.slideToEmpty(column: self.emptyColumn, row: self.emptyRow + 1)
    }
    
    // Move one tile down into empty slot if possible
    private func slideDown() -> Bool {
        return self.slideToEmpty(column: self.emptyColumn, row: self.emptyRow - 1)
    }

    // Move the specified tile into empty slot
    private func slideToEmpty(column: Int, row: Int) -> Bool {
        if column < 0 || self.columns <= column || row < 0 || self.rows <= row {
            // Can't move in this direction
            return false
        }
        
        let tile = self.tiles[column][row]
        let emptyTile = self.tiles[self.emptyColumn][self.emptyRow]
        // Move the specified tile into the empty area
        self.setTilePosition(tile: tile, column: self.emptyColumn, row: self.emptyRow)
        // And the empty tile gets swapped into the other location
        self.setTilePosition(tile: emptyTile, column: column, row: row)
        self.emptyColumn = column
        self.emptyRow = row
        
        // Figure out the new tile position (for the visible one)
        let newRect = self.getTileRect(column: tile.currentColumn, row: tile.currentRow)
        let newX = newRect.midX
        let newY = newRect.midY

        if !self.isPaused {
            // Animate the tile position
            tile.run(.move(to: CGPoint(x: newX, y: newY), duration: self.settings.speedFactor * 0.125)) {
                self.impactOccurred()
            }
        } else {
            tile.position = CGPoint(x: newX, y: newY)
        }
        
        if isSolved() {
            self.solved()
        } else {
            // Not solved yet
            // TODO: add haptic feedback?
        }
        
        return true
    }
    
    private func setTilePosition(tile: Tile, column: Int, row: Int) {
        tile.currentColumn = column
        tile.currentRow = row
        self.tiles[column][row] = tile
    }
    
    // Returns true iff the puzzle has been solved
    private func isSolved() -> Bool {
        for c in 0..<self.columns {
            for r in 0..<self.rows {
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
