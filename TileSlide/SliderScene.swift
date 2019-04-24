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
    
    class Tile : SKShapeNode {
        // The original column position the tile occupies
        var originalColumn: Int = -1

        // The original row position the tile occupies
        var originalRow: Int = -1

        // The current column position the tile occupies
        var currentColumn: Int = -1
        
        // The current row position the tile occupies
        var currentRow: Int = -1
        
        convenience init(column: Int, row: Int, rect: CGRect) {
            self.init(rect: rect)
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
        self.columns = 3
        self.rows = 4
        self.emptyColumn = self.columns - 1
        self.emptyRow = self.rows - 1
        tiles.removeAll()
        
        for c in 0..<self.columns {
            tiles.append([])
            for r in 0..<self.rows {
                let rect = getRect(column: c, row: r)
                let tile = Tile.init(column: c, row: r, rect: rect)
                tile.lineWidth = 3;
                tile.strokeColor = SKColor.magenta
                self.addChild(tile)
                
                let label = SKLabelNode.init(text: String(format: "%d", 1 + c + r * self.columns))
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.position = CGPoint(x: rect.midX, y: rect.midY)
                tile.addChild(label)
                
                tiles[c].append(tile)
            }
        }
        
        let emptyTile = self.tiles[self.emptyColumn][self.emptyRow]
        emptyTile.alpha = 0
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            // Walk ancestors until we get a tile
            var node: SKNode? = self.atPoint(t.location(in: self))
            while node != nil {
                if let tile = node! as? Tile {
                    // Move the tile the touch was in
                    tryMoveTile(tile)
                    break
                }
                
                node = node!.parent
            }
        }
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
    private func tryMoveTile(_ tile: Tile) {
        if tile.currentColumn == self.emptyColumn {
            if tile.currentRow < self.emptyRow {
                // Shift down emptyRow - currentRow times
                self.shiftDown()
            } else {
                // Shift up currentRow - emptyRow times
                self.shiftUp()
            }
        } else if tile.currentRow == self.emptyColumn {
            if tile.currentColumn < self.emptyColumn {
                // Shift right emptyColumn - currentColumn times
                self.shiftRight()
            } else {
                // Shift left currentColumn - emptyColumn times
                self.shiftLeft()
            }
        } else {
            // Can't move
        }
    }
    
    // Move one tile left into empty slot if possible
    private func shiftLeft() {
        // If empty column is not the right, we can...
        if self.emptyColumn + 1 < self.columns {
            self.moveToEmpty(column: self.emptyColumn + 1, row: self.emptyRow)
        }
    }
    
    // Move one tile right into empty slot if possible
    private func shiftRight() {
        // If empty column is not the left, we can...
        if self.emptyColumn > 0 {
            self.moveToEmpty(column: emptyColumn - 1, row: self.emptyRow)
        }
    }
    
    // Move one tile up into empty slot if possible
    private func shiftUp() {
        // If empty row is not the bottom, we can...
        if self.emptyRow + 1 < self.rows {
            self.moveToEmpty(column: self.emptyColumn, row: self.emptyRow + 1)
        }
    }
    
    // Move one tile down into empty slot if possible
    private func shiftDown() {
        // If empty row is not the top, we can...
        if self.emptyRow > 0 {
            self.moveToEmpty(column: self.emptyColumn, row: self.emptyRow - 1)
        }
    }

    // Move the specified tile into empty slot
    private func moveToEmpty(column: Int, row: Int) {
        let tile = self.tiles[column][row]
        let emptyTile = self.tiles[self.emptyColumn][self.emptyRow]

        tile.currentColumn = self.emptyColumn
        tile.currentRow = self.emptyRow
        self.tiles[self.emptyColumn][self.emptyRow] = tile;

        emptyTile.currentColumn = column
        emptyTile.currentRow = row
        self.tiles[column][row] = emptyTile
        self.emptyColumn = column
        self.emptyRow = row
        
        let newRect = self.getRect(column: tile.currentColumn, row: tile.currentRow)
        
        //tile.run(SKAction.move(to: newRect.origin, duration: 0.5))
        tile.position = newRect.origin

        if isSolved() {
            
        } else {
            
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
