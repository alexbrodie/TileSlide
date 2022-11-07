//
//  SliderBoard.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/14/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Foundation

// A slider board is a grid of tiles, one of which is denoted as "empty".
// In addition to a (column, row) coordinates, the various positions in
// the grid are given an index reading left to right, top to bottom.
// Tiles are then identified by their "ordinal" - the name we give to the
// index of the solved position of the tile.
class SliderBoard: Hashable {
    
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
    
    static func ==(lhs: SliderBoard, rhs: SliderBoard) -> Bool {
        return  lhs.columns == rhs.columns &&
                lhs.rows == rhs.rows &&
                lhs.emptyOrdinal == rhs.emptyOrdinal &&
                lhs.ordinalPositions == rhs.ordinalPositions
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ordinalPositions)
    }

//    public var hashValue: Int {
//        // It's sufficient to just use ordinalPositions for hash values
//        // as the other information generally is similar. Each element of
//        // the array is a integer less than the number of tiles, so we can
//        // construct a (ordinalPositions.count) digit number of base
//        // (colums * rows).
//        let base = columns * rows;
//        var result = 0
//        for i in ordinalPositions {
//            result = base * result + i
//        }
//        return result
//    }
    
    public init() {
        columns = 0
        rows = 0
        emptyOrdinal = -1
        ordinalPositions = []
    }

    public init(columns inColumns: Int,
                rows inRows: Int,
                emptyOrdinal inEmptyOrdinal: Int) {
        columns = inColumns
        rows = inRows
        emptyOrdinal = inEmptyOrdinal
        ordinalPositions = Array(0..<(inColumns * inRows))
    }
    
    public init(_ cloneFrom: SliderBoard) {
        columns = cloneFrom.columns
        rows = cloneFrom.rows
        emptyOrdinal = cloneFrom.emptyOrdinal
        ordinalPositions = cloneFrom.ordinalPositions
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
    
    // Returns an array moves that if taken in order would lead to a solved board.
    // Each move is defined by the ordinal of the tile adjacent to the empty square
    // that is being moved.
    public func calculateSolution() -> [Int] {
        guard !isSolved else { return [Int]() }

        // Processing queue used to implement breadth first traversal
        struct Move {
            // The ordinal that was moved
            var ordinals: [Int]
            // The board state after ordinals were moved
            var board: SliderBoard
        }
        var queue = [Move]()
        queue.append(Move(ordinals: [], board: self))
        
        // A lookup to prevent processing of the same board twice
        var seen = Set<SliderBoard>()
        
        // The offsets define all the possible things we can do
        struct Offset {
            var dx: Int
            var dy: Int
        }
        let offsets: [Offset] = [
            Offset(dx: 0,  dy: -1),
            Offset(dx: 1,  dy: 0),
            Offset(dx: 0,  dy: 1),
            Offset(dx: -1, dy: 0)
        ]

        // Stats, for debugging mostly
        var movesAttempted: Int = 0
        var movedPerformed: Int = 0
        var novelBoards: Int = 0

        while !queue.isEmpty {
            let current = queue.removeFirst()
            for offset in offsets {
                movesAttempted += 1
                let nextBoard = SliderBoard(current.board)
                if let nextOrdinal = nextBoard.swapWithEmpty(horizontalOffset: offset.dx, verticalOffset: offset.dy) {
                    movedPerformed += 1
                    var nextOrdinals = current.ordinals
                    nextOrdinals.append(nextOrdinal)
                    if nextBoard.isSolved {
                        return nextOrdinals
                    }
                    if seen.insert(nextBoard).inserted {
                        // Unsolved, not yet seen before board
                        novelBoards += 1
                        queue.append(Move(ordinals: nextOrdinals, board: nextBoard))
                    }
                }
            }
        }
                
        assertionFailure("Unsolvable board")
        return [Int]()
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
