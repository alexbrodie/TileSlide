//
//  SliderScene.swift
//  TileSlide
//
//  Created by Alexander Brodie on 4/23/19.
//  Copyright © 2019 Alex Brodie. All rights reserved.
//

import CoreMotion
import GameplayKit
import SpriteKit

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
}

class SliderScene: SKScene {
    
    private class Tile : SKSpriteNode {
        // The original column position the tile occupies
        var originalColumn: Int = -1
        // The original row position the tile occupies
        var originalRow: Int = -1
        // The current column position the tile occupies
        var currentColumn: Int = -1
        // The current row position the tile occupies
        var currentRow: Int = -1
    }
    
    private enum Stage {
        case uninitialized
        case transition
        case playing
        case solved
    }
    
    private var stage: Stage = .uninitialized
    
    // True if impact feedback should be used
    private var enableHaptics: Bool = true
    // True if tilting device should be used as an input to slide tiles
    private var enableTiltToSlide: Bool = false;
    // Color for the labels that contain the number of each tile
    private var numberLabelTextColor: UIColor = UIColor.init(white: 0.7, alpha: 0.6)
    // Font for the labels that contain the number of each tile
    private let numberLabelFontName = "Avenir-Heavy"
    // Text size for the labels that contain the number of each tile relative to the tile size
    private let numberLabelFontSize = 0.9
    
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
    
    // Used when doing a batch operation to disable animations and feedback
    // for any slide operations
    private var animateSlide: Bool = true
    
    // Generator for feedback, e.g. haptics
    private var impactFeedback: UIImpactFeedbackGenerator? = nil
    
    // Object to fetch accelerometer/gyro data
    private var motionManager: CMMotionManager? = nil
    // Last time that tilting the device slid a tile
    private var lastTiltShift: Date = Date.init()
    
    // Place to show text for debugging
    private var debugText: SKLabelNode? = nil

    override func didMove(to view: SKView) {
        self.backgroundColor = UIColor.black
        //self.setEnableTiltToSlide(true);
        //self.makeDebugText()
        self.setup()
    }
    
    override func update(_ currentTime: TimeInterval) {
        let tiltDelay = 0.5
        let pitchOffset = -0.75
        let tiltThreshold = 0.25

        if self.stage == .playing && self.enableTiltToSlide {
            if let data = self.motionManager!.deviceMotion {
                // Wait this long between processing tilt slides
                let now = Date.init()
                if self.lastTiltShift + tiltDelay < now {
                    let yaw = data.attitude.yaw
                    let pitch = data.attitude.pitch + pitchOffset
                    let roll = data.attitude.roll
                    if let debugText = self.debugText {
                        debugText.text = String(format: "Y = %.02f P = %.02f R = %.02f", yaw, pitch, roll)
                    }
                    
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
        switch self.stage {
        case .playing:
            for t in touches {
                // Walk ancestors until we get a tile
                let location = t.location(in: self)
                var node: SKNode? = self.atPoint(location)
                while node != nil {
                    if let tile = node! as? Tile {
                        // Move the tile the touch was in
                        _ = trySlideTile(tile)
                        break
                    }
                    
                    node = node!.parent
                }
            }
        case .solved:
            setup()
        default:
            break
        }
    }
    
    private func setEnableTiltToSlide(_ enable: Bool) {
        self.enableTiltToSlide = enable;
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
        if self.enableHaptics {
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
        
        let label = SKLabelNode.init(text: "Debug\nText");
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
        self.setup(image: UIImage.init(named: "sample"), columns: 3, rows: 4)
    }
    
    private func cleanup() {
        self.setup(image: nil, columns: 0, rows: 0)
    }
    
    private func setup(image: UIImage?, columns: Int, rows: Int) {
        self.stage = .transition
        
        // Fade out and remove old stuff
        for col in self.tiles {
            for tile in col {
                tile.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.2),
                    SKAction.run { tile.removeFromParent() },
                    ]))
            }
        }

        // Reset tile data
        self.columns = columns
        self.rows = rows
        self.emptyColumn = columns - 1
        self.emptyRow = rows - 1
        self.tiles.removeAll()
        self.tilesContentAspect = 0

        // Make texture for the sprite nodes
        var tex: SKTexture?;
        if var img = image {
            // If aspect ratio of image is different from area we're displaying in, rotate it
            //let imgSize = img.size
            //let frameSize = self.frame.size
            //if (imgSize.width > imgSize.height) != (frameSize.width > frameSize.height) {
            //    img = img.rotate(degrees: 90)
            //}
            
            // TODO: crop to prevent squishing image

            tex = SKTexture.init(image: img)
            self.tilesContentAspect = img.size.width / img.size.height
        }
        
        // Build nodes for each tile (initially hidden)
        for c in 0..<columns {
            self.tiles.append([])
            for r in 0..<rows {
                let tileNumber = c + r * columns;
                
                let rect = getTileRect(column: c, row: r)
                var tile: Tile
                if tex != nil {
                    let subTexRect = CGRect.init(x: CGFloat(c) / CGFloat(columns),
                                                 y: CGFloat(rows - r - 1) / CGFloat(rows),
                                                 width: 1.0 / CGFloat(columns),
                                                 height: 1.0 / CGFloat(rows))
                    let subTex = SKTexture.init(rect: subTexRect, in: tex!)
                    tile = Tile.init(texture: subTex, size: rect.size)
                } else {
                    let color = tileNumber % 2 == 0 ? SKColor.black : SKColor.red
                    tile = Tile.init(color: color, size: rect.size)
                }
                tile.alpha = 0
                tile.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                tile.position = CGPoint(x: rect.midX, y: rect.midY)
                tile.originalColumn = c
                tile.originalRow = r
                tile.currentColumn = c
                tile.currentRow = r

                let label = SKLabelNode.init(text: String(format: "%d", 1 + tileNumber))
                label.fontColor = self.numberLabelTextColor
                label.fontName = self.numberLabelFontName
                label.fontSize = rect.height * self.numberLabelFontSize
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = 1
                tile.addChild(label)
                
                tiles[c].append(tile)
                self.addChild(tile)
            }
        }
        
        self.shuffle()

        // Reveal tiles
        for col in self.tiles {
            for tile in col {
                if tile.currentColumn != self.emptyColumn || tile.currentRow != self.emptyRow {
                    let tilePercentile = CGFloat(tile.originalColumn + tile.originalRow * columns) / CGFloat(columns * rows - 1);
                    tile.run(SKAction.sequence([
                        SKAction.wait(forDuration: tilePercentile * 0.2),
                        SKAction.fadeAlpha(to: 1, duration: 0.3),
                        ]))
                }
            }
        }
        
        self.run(SKAction.wait(forDuration: 0.5),
                 completion: { self.stage = .playing })
    }
    
    private func solved() {
        self.stage = .transition
        self.setLabelAlpha(0)

        // Show the empty tile to complete the puzzle
        let emptyTile = self.tiles[self.emptyColumn][self.emptyRow]
        emptyTile.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 1, duration: 0.25),
                SKAction.wait(forDuration: 0.75),
            ]),
            completion: { self.stage = .solved })
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
        let y = bounds.minY + CGFloat(self.rows - row - 1) * tileHeight
        return CGRect.init(x: x, y: y, width: tileWidth, height: tileHeight)
    }
    
    private func setLabelAlpha(_ alpha: CGFloat) {
        for child in self.children {
            if let tile = child as? Tile {
                for child2 in tile.children {
                    if let label = child2 as? SKLabelNode {
                        label.run(SKAction.fadeAlpha(to: alpha, duration: 0.25))
                    }
                }
            }
        }
    }
    
    // Shuffle the board
    private func shuffle() {
        let oldAnimateSlide = self.animateSlide
        self.animateSlide = false
        defer { self.animateSlide = oldAnimateSlide }

        let oldIsPaused = self.isPaused
        self.isPaused = true
        defer { self.isPaused = oldIsPaused }
        
        shuffle(10 * self.columns * self.rows)
    }
    
    // Shuffles the board by making count moves
    private func shuffle(_ count: Int) {
        var shuffleCount: Int = 0
        var lastDirection: Int = 42;  // Something out of bounds [-2,5]
        
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

        if self.animateSlide {
            // Animate the tile position
            tile.run(SKAction.sequence([
                SKAction.move(to: CGPoint(x: newX, y: newY), duration: 0.1),
                SKAction.run { self.impactOccurred() },
                ]))
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
