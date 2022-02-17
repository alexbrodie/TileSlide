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
                emptyOrdinal inEmptyOrdinal: Int) {
        columns = inColumns
        rows = inRows
        emptyOrdinal = inEmptyOrdinal
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
