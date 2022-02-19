//
//  SliderSettings.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/10/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Foundation
import SwiftUI

struct LabelGlyphSet {
    var name: String
    // The number of columns this glyph set is supposed to fit
    var columns: Int
    // The number of rows this glyph set is supposed to fit
    var rows: Int
    // The individual glyph values for each row and column
    var values: [String]
}

// This represents the glyph set used for the "number" labels
enum LabelType {
    case numbers
    case arrows
    case blackArrows
    case whiteArrows
    // Gets the set of glyphs associated with the labels property
    func glyphs() -> LabelGlyphSet? {
        switch self {
        case .numbers:
            return nil
        case .arrows:
            return arrowGlyphs
        case .blackArrows:
            return blackArrowGlyphs
        case .whiteArrows:
            return whiteArrowGlyphs
        }
    }
    func glyphFor(columns: Int, rows: Int, ordinal: Int) -> String {
        if let glyphs = glyphs() {
            if glyphs.columns == columns && glyphs.rows == rows {
                return glyphs.values[ordinal]
            }
        }
        return String(format: "%d", 1 + ordinal)
    }
}

final class SliderSettings: ObservableObject {
    // True if impact feedback should be used
    @Published var enableHaptics: Bool = true;
    // True if tilting device should be used as an input to slide tiles
    @Published var enableTiltToSlide: Bool = false;
    // Color for the labels that contain the number of each tile
    @Published var tileNumberColor: Color = .init(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.75)
    // Font for the labels that contain the number of each tile
    @Published var tileNumberFontFace: String = "Avenir-Heavy"
    // Text size for the labels that contain the number of each tile relative to the tile size
    @Published var tileNumberFontSize: Double = 0.9
    // The margin size around tiles where 1 is all margin, and 0 is no margin
    @Published var tileMarginSize: Double = 0.02;
    // The playback multipler with 1 being normal, and 2 taking twice as long
    @Published var speedFactor: Double = 1.0;
    // This is a handy knob to pass things around for temporarily debugging purposes, e.g.
    // to figure out what value to hard code something to by fiddling with it in game. This
    // isn't to be used by anything in ship-ready code. But leave it here so that we don't
    // have to re-wire up a temp value to do this each time.
    @Published var debug: Double = 0;
    // What set of symbols or glyphs to show for each tile's label
    @Published var labels: LabelType = .numbers

}

let arrowGlyphs = LabelGlyphSet(name: "arrow", columns: 3, rows: 3, values: [
    "\u{2196}\u{FE0E}", // U+2196 : north west arrow
    "\u{2191}\u{FE0E}", // U+2191 : upwards arrow
    "\u{2197}\u{FE0E}", // U+2197 : north east arrow
    "\u{2190}\u{FE0E}", // U+2190 : leftwards arrow
    "\u{2022}\u{FE0E}", // U+2022 :
    "\u{2192}\u{FE0E}", // U+2192 : rightwards arrow
    "\u{2199}\u{FE0E}", // U+2199 : south west arrow
    "\u{2193}\u{FE0E}", // U+2193 : downwards arrow
    "\u{2198}\u{FE0E}", // U+2198 : south east arrow
])

let blackArrowGlyphs = LabelGlyphSet(name: "black arrow", columns: 3, rows: 3, values: [
    "\u{2B01}\u{FE0E}", // U+2B01 : north west black arrow
    "\u{2B06}\u{FE0E}", // U+2B06 : upwards black arrow
    "\u{2B08}\u{FE0E}", // U+2B08 : north east black arrow
    "\u{2B05}\u{FE0E}", // U+2B05 : leftwards black arrow
    "\u{2022}\u{FE0E}",
    "\u{2B95}\u{FE0E}", // U+2B95 : rightwards black arrow
    "\u{2B03}\u{FE0E}", // U+2B03 : south west black arrow
    "\u{2B07}\u{FE0E}", // U+2B07 : downwards black arrow
    "\u{2B02}\u{FE0E}", // U+2B02 : south east black arrow
])

let whiteArrowGlyphs = LabelGlyphSet(name: "white arrow", columns: 3, rows: 3, values: [
    "\u{2B00}\u{FE0E}", // U+2B00 : north east white arrow
    "\u{21E7}\u{FE0E}", // U+21E7 : upwards white arrow
    "\u{2B01}\u{FE0E}", // U+2B01 : north west white arrow
    "\u{21E6}\u{FE0E}", // U+21E6 : leftwards white arrow
    "\u{2022}\u{FE0E}",
    "\u{21E8}\u{FE0E}", // U+21E8 : rightwards white arrow
    "\u{2B03}\u{FE0E}", // U+2B03 : south west white arrow
    "\u{21E9}\u{FE0E}", // U+21E9 : downwards white arrow
    "\u{2B02}\u{2B02}", // U+2B02 : south east white arrow
])

