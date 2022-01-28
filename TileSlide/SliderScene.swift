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

class SliderScene: SKScene {
    
    class Tile : SKSpriteNode {
        // The original column position the tile occupies
        var originalColumn: Int = -1

        // The original row position the tile occupies
        var originalRow: Int = -1

        // The current column position the tile occupies
        var currentColumn: Int = -1
        
        // The current row position the tile occupies
        var currentRow: Int = -1
    }
    
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
    
    // Generator for feedback, e.g. haptics
    private var feedback: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator.init(style: .medium)
    
    // Object to fetch accelerometer/gyro data
    private var motion: CMMotionManager = CMMotionManager()
    
    // Last time that tilting the device shifted a tile
    private var lastTiltShift: Date = Date.init()
    
    // Place to show text for debugging
    private var debugText: SKLabelNode? = nil

    override func didMove(to view: SKView) {
        if self.motion.isDeviceMotionAvailable {
            self.motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        }

        self.makeDebugText()
        
        self.setup(columns: 3, rows: 3)
    }
    
    override func update(_ currentTime: TimeInterval) {
        let tiltDelay = 0.5
        let pitchOffset = -0.75
        let tiltThreshold = 0.25

        if let data = self.motion.deviceMotion {
            // Wait this long between processing tilt shifts
            let now = Date.init()
            if self.lastTiltShift + tiltDelay < now {
                let yaw = data.attitude.yaw
                let pitch = data.attitude.pitch + pitchOffset
                let roll = data.attitude.roll
                if let debugText = self.debugText {
                    debugText.text = String(format: "Y = %.02f P = %.02f R = %.02f", yaw, pitch, roll)
                }
                
                var shifted = false
               
                // Only process one direction whichever is greatest
                if abs(pitch) > abs(roll) {
                    if pitch < -tiltThreshold {
                        // Negative pitch == tilt forward
                        shifted = self.shiftUp()
                    } else if pitch > tiltThreshold {
                        // Positive pitch == tilt backward
                        shifted = self.shiftDown()
                    }
                }
                
                if !shifted {
                    if roll < -tiltThreshold {
                        // Negative roll == tilt left
                        shifted = self.shiftLeft()
                    } else if roll > tiltThreshold {
                        // Positive roll == tilt right
                        shifted = self.shiftRight()
                    }
                }
                
                if shifted {
                    feedback.impactOccurred()
                    self.lastTiltShift = now
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            // Walk ancestors until we get a tile
            let location = t.location(in: self)
            var node: SKNode? = self.atPoint(location)
            while node != nil {
                if let tile = node! as? Tile {
                    // Move the tile the touch was in
                    _ = tryMoveTile(tile)
                    break
                }
                
                node = node!.parent
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
    
    private func setup(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        self.emptyColumn = columns - 1
        self.emptyRow = rows - 1
        tiles.removeAll()
        
        var tex: SKTexture?;
        if var img = UIImage.init(named: "sample") {
            // If aspect ratio of image is different from area we're displaying in, rotate it
            let imgSize = img.size
            let frameSize = self.frame.size
            if (imgSize.width > imgSize.height) != (frameSize.width > frameSize.height) {
                img = img.rotate(degrees: 90)
            }
            
            // TODO: crop to prevent squishing image

            tex = SKTexture.init(image: img)
        }
        
        for c in 0..<columns {
            tiles.append([])
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
                tile.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                tile.position = CGPoint(x: rect.midX, y: rect.midY)
                tile.originalColumn = c
                tile.originalRow = r
                tile.currentColumn = c
                tile.currentRow = r
                self.addChild(tile)
                
                let label = SKLabelNode.init(text: String(format: "%d", 1 + tileNumber))
                label.fontColor = SKColor.white
                label.fontSize = rect.height * 0.4
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = 1
                tile.addChild(label)
                
                tiles[c].append(tile)
            }
        }
        
        let emptyTile = self.tiles[self.emptyColumn][self.emptyRow]
        emptyTile.alpha = 0
        
        shuffle()
    }
    
    // Get the rectangle for the given grid coordinate
    private func getTileRect(column: Int, row: Int) -> CGRect {
        let f = self.frame
        let tileWidth = f.width / CGFloat(self.columns)
        let tileHeight = f.height / CGFloat(self.rows)
        let x = f.minX + CGFloat(column) * tileWidth
        let y = f.minY + CGFloat(self.rows - row - 1) * tileHeight
        return CGRect.init(x: x, y: y, width: tileWidth, height: tileHeight)
    }
    
    private func setLabelAlpha(alpha: CGFloat) {
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
    
    // Moves the specified tile if possible
    private func tryMoveTile(_ tile: Tile) -> Bool {
        if tile.currentColumn == self.emptyColumn {
            let verticalMoves = tile.currentRow - self.emptyRow
            if verticalMoves < 0 {
                // Shift down emptyRow - currentRow times
                for _ in verticalMoves...(-1) {
                    let shifted = self.shiftDown()
                    assert(shifted, "Couldn't shift down")
                }
                return true
            } else if verticalMoves > 0 {
                // Shift up currentRow - emptyRow times
                for _ in 1...verticalMoves {
                    let shifted = self.shiftUp()
                    assert(shifted, "Couldn't shift up")
                }
                return true
            }
        } else if tile.currentRow == self.emptyRow {
            let horizontalMoves = tile.currentColumn - self.emptyColumn
            if horizontalMoves < 0 {
                // Shift right emptyColumn - currentColumn times
                for _ in horizontalMoves...(-1) {
                    let shifted = self.shiftRight()
                    assert(shifted, "Couldn't shift right")
                }
                return true
            } else if horizontalMoves > 0 {
                // Shift left currentColumn - emptyColumn times
                for _ in 1...horizontalMoves {
                    let shifted = self.shiftLeft()
                    assert(shifted, "Couldn't shift left")
                }
                return true
            }
        }

        // Can't move
        return false
    }
    
    // Shuffle the board
    private func shuffle() {
        shuffle(count: 10 * self.columns * self.rows)
    }
    
    // Shuffles the board by making count moves
    private func shuffle(count: Int) {
        var shuffleCount: Int = 0
        var lastDirection: Int = 42;  // Something out of bounds [-2,5]
        
        while shuffleCount < count {
            let direction = Int.random(in: 0..<4) // NESW
            
            var shifted: Bool = false

            // Disallow the reverse of the previous - no left then right or up then down.
            // Values were chosen such that this means not a difference of 2
            if abs(direction - lastDirection) != 2 {
                switch direction {
                case 0: shifted = shiftUp()
                case 1: shifted = shiftRight()
                case 2: shifted = shiftDown()
                case 3: shifted = shiftLeft()
                default: assert(false, "unexpected direction")
                }
            }

            if shifted {
                lastDirection = direction
                shuffleCount += 1
            }
        }
        
        self.setLabelAlpha(alpha: 1)
    }
    
    // Move one tile left into empty slot if possible
    private func shiftLeft() -> Bool {
        return self.moveToEmpty(column: self.emptyColumn + 1, row: self.emptyRow)
    }
    
    // Move one tile right into empty slot if possible
    private func shiftRight() -> Bool {
        return self.moveToEmpty(column: emptyColumn - 1, row: self.emptyRow)
    }
    
    // Move one tile up into empty slot if possible
    private func shiftUp() -> Bool {
        return self.moveToEmpty(column: self.emptyColumn, row: self.emptyRow + 1)
    }
    
    // Move one tile down into empty slot if possible
    private func shiftDown() -> Bool {
        return self.moveToEmpty(column: self.emptyColumn, row: self.emptyRow - 1)
    }

    // Move the specified tile into empty slot
    private func moveToEmpty(column: Int, row: Int) -> Bool {
        if column < 0 || self.columns <= column || row < 0 || self.rows <= row {
            // Can't move in this direction
            return false
        }
        
        let tile = self.tiles[column][row]
        let emptyTile = self.tiles[self.emptyColumn][self.emptyRow]

        // Move the specified tile into the empty area
        tile.currentColumn = self.emptyColumn
        tile.currentRow = self.emptyRow
        self.tiles[self.emptyColumn][self.emptyRow] = tile

        // And the empty tile gets swapped into the other location
        emptyTile.currentColumn = column
        emptyTile.currentRow = row
        self.tiles[column][row] = emptyTile
        self.emptyColumn = column
        self.emptyRow = row
        
        // Figure out the new tile position (for the visible one)
        let newRect = self.getTileRect(column: tile.currentColumn, row: tile.currentRow)
        let newX = newRect.midX
        let newY = newRect.midY
        
        // Animate the tile position
        tile.run(SKAction.move(to: CGPoint(x: newX, y: newY), duration: 0.1))
        
        if isSolved() {
            // Show the empty tile to complete the puzzle
            emptyTile.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 1, duration: 0.25),
                SKAction.wait(forDuration: 2),
                SKAction.fadeAlpha(to: 0, duration: 0.25),
                SKAction.run { self.shuffle() }
                ]))

            self.setLabelAlpha(alpha: 0)
        } else {
            // Not solved yet
            // TODO: add haptic feedback?
        }
        
        return true
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
