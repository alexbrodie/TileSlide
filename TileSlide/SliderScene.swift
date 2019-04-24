//
//  SliderScene.swift
//  TileSlide
//
//  Created by Alexander Brodie on 4/23/19.
//  Copyright © 2019 Alex Brodie. All rights reserved.
//

import SpriteKit
import GameplayKit

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
        
        convenience init(column: Int, row: Int, color: SKColor, rect: CGRect) {
            self.init(color: color, size: rect.size)
            self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.position = CGPoint(x: rect.midX, y: rect.midY)
            self.originalColumn = column
            self.originalRow = row
            self.currentColumn = column
            self.currentRow = row
        }
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

    override func didMove(to view: SKView) {
        setup(columns: 3, rows: 4)
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
    
    private func setup(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        self.emptyColumn = columns - 1
        self.emptyRow = rows - 1
        tiles.removeAll()
        
        //let tex = SKTexture.init
        
        for c in 0..<columns {
            tiles.append([])
            for r in 0..<rows {
                let tileNumber = c + r * columns;
                
                let rect = getRect(column: c, row: r)
                let color = tileNumber % 2 == 0 ? SKColor.black : SKColor.red
                let tile = Tile.init(column: c, row: r, color: color, rect: rect)
                self.addChild(tile)
                
                let label = SKLabelNode.init(text: String(format: "%d", 1 + tileNumber))
                label.fontColor = SKColor.white
                label.fontSize = rect.height / 2
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                tile.addChild(label)
                
                tiles[c].append(tile)
            }
        }
        
        let emptyTile = self.tiles[self.emptyColumn][self.emptyRow]
        emptyTile.alpha = 0
        
        shuffle()
    }
    
    // Get the rectangle for the given grid coordinate
    private func getRect(column: Int, row: Int) -> CGRect {
        let f = self.frame
        let tileWidth = f.width / CGFloat(self.columns)
        let tileHeight = f.height / CGFloat(self.rows)
        let x = f.minX + CGFloat(column) * tileWidth
        let y = f.minY + CGFloat(self.rows - row - 1) * tileHeight
        return CGRect.init(x: x, y: y, width: tileWidth, height: tileHeight)
    }
    
    // Moves the specified tile if possible
    private func tryMoveTile(_ tile: Tile) -> Bool {
        if tile.currentColumn == self.emptyColumn {
            if tile.currentRow < self.emptyRow {
                // Shift down emptyRow - currentRow times
                return self.shiftDown()
            } else {
                // Shift up currentRow - emptyRow times
                return self.shiftUp()
            }
        } else if tile.currentRow == self.emptyRow {
            if tile.currentColumn < self.emptyColumn {
                // Shift right emptyColumn - currentColumn times
                return self.shiftRight()
            } else {
                // Shift left currentColumn - emptyColumn times
                return self.shiftLeft()
            }
        } else {
            // Can't move
            return false
        }
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
        let newRect = self.getRect(column: tile.currentColumn, row: tile.currentRow)
        let newX = newRect.midX
        let newY = newRect.midY
        
        // Animate the tile position
        tile.run(SKAction.move(to: CGPoint(x: newX, y: newY), duration: 0.1))
        
        if isSolved() {
            // Show the empty tile to complete the puzzle
            emptyTile.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 1, duration: 0.25),
                SKAction.wait(forDuration: 0.75),
                SKAction.fadeAlpha(to: 0, duration: 0.25),
                SKAction.run { self.shuffle() }
                ]))
            
            // Loop over each tile...
            /*for child in self.children {
                if let tile = child as? Tile {
                }
            }*/
        } else {
            // Not solved yet
            // TODO: add haptic feedback?
        }
        
        return true
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
