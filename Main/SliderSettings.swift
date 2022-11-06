//
//  SliderSettings.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/10/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Foundation
import SwiftUI

final class SliderSettings: ObservableObject {
    // True if impact feedback should be used
    @Published var enableHaptics: Bool = true;
    // True if tilting device should be used as an input to slide tiles
    @Published var enableTiltToSlide: Bool = false;
    // What set of symbols or glyphs to show for each tile's label
    @Published var tileLabelType: LabelType = .none
    // Color for the labels that contain numbers or glyphs representing each tile
    @Published var tileLabelColor: Color = .init(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.75)
    // Font for the labels that contain the numbers or glyphs representing each tile
    @Published var tileLabelFont: String = "Avenir-Heavy"
    // Text size for the labels that contain the numbers or glyphs representing each tile, relative to the tile size
    @Published var tileLabelSize: Double = 0.9
    // The margin size around tiles where 1 is all margin, and 0 is no margin
    @Published var tileMarginSize: Double = 0.02;
    // The size of non-movable padding area along the inner edges of the board
    // where 1 is all padding and 0 is no padding
    @Published var boardPaddingSize: Double = 0.05
    // The playback multipler with 1 being normal, and 2 taking twice as long
    @Published var speedFactor: Double = 1.0;
    // This is a handy knob to pass things around for temporarily debugging purposes, e.g.
    // to figure out what value to hard code something to by fiddling with it in game. This
    // isn't to be used by anything in ship-ready code. But leave it here so that we don't
    // have to re-wire up a temp value to do this each time.
    @Published var debug: Double = 0;
}

// This represents the glyph set used for the labels
enum LabelType: Hashable, CaseIterable {
    case none
    case numbers
    case arrows
    /*
    case blackArrows
    case whiteArrows
    case sansSerifArrows
    case wideHeadedLightBarbArrow
    case wideHeadedBarbArrow
    case wideHeadedMediumBarbArrow
    case wideHeadedHeavyBarbArrow
    case wideHeadedVeryHeavyBarbArrow
    */
    // Gets the set of glyphs associated with the labels property
    var glyphs: LabelGlyphSet {
        switch self {
        case .none:             return noneGlyphs
        case .numbers:          return numbersGlyphs
        case .arrows:           return arrowGlyphs
        /*
        case .blackArrows:      return blackArrowGlyphs
        case .whiteArrows:      return whiteArrowGlyphs
        case .sansSerifArrows:  return sansSerifArrowGlyphs
        case .wideHeadedLightBarbArrow:     return wideHeadedLightBarbArrowGlyphs
        case .wideHeadedBarbArrow:          return wideHeadedBarbArrowGlyphs
        case .wideHeadedMediumBarbArrow:    return wideHeadedMediumBarbArrowGlyphs
        case .wideHeadedHeavyBarbArrow:     return wideHeadedHeavyBarbArrowGlyphs
        case .wideHeadedVeryHeavyBarbArrow: return wideHeadedVeryHeavyBarbArrowGlyphs
        */
        }
    }
    func glyphFor(columns: Int, rows: Int, ordinal: Int) -> String {
        guard self != .none else { return "" }
        if glyphs.columns == columns && glyphs.rows == rows {
            return glyphs.values[ordinal]
        }
        return String(format: "%d", 1 + ordinal)
    }
}

struct LabelGlyphSet {
    var name: String
    // The number of columns this glyph set is supposed to fit
    var columns: Int
    // The number of rows this glyph set is supposed to fit
    var rows: Int
    // The individual glyph values for each row and column
    var values: [String]
}

let noneGlyphs = LabelGlyphSet(name: "none", columns: 0, rows: 0, values: [])

let numbersGlyphs = LabelGlyphSet(name: "number", columns: 0, rows: 0, values: [])

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
    "\u{2B09}\u{FE0E}", // U+2B09 : north west black arrow
    "\u{2B06}\u{FE0E}", // U+2B06 : upwards black arrow
    "\u{2B08}\u{FE0E}", // U+2B08 : north east black arrow
    "\u{2B05}\u{FE0E}", // U+2B05 : leftwards black arrow
    "\u{2022}\u{FE0E}",
    //"\u{27A1}\u{FE0E}", // U+2B95 : black rightwards arrow
    "\u{2B95}\u{FE0E}", // U+2B95 : rightwards black arrow
    "\u{2B0B}\u{FE0E}", // U+2B0B : south west black arrow
    "\u{2B07}\u{FE0E}", // U+2B07 : downwards black arrow
    "\u{2B0A}\u{FE0E}", // U+2B0A : south east black arrow
])

let whiteArrowGlyphs = LabelGlyphSet(name: "white arrow", columns: 3, rows: 3, values: [
    "\u{2B01}\u{FE0E}", // U+2B01 : north west white arrow
    "\u{21E7}\u{FE0E}", // U+21E7 : upwards white arrow
    "\u{2B00}\u{FE0E}", // U+2B00 : north east white arrow
    "\u{21E6}\u{FE0E}", // U+21E6 : leftwards white arrow
    "\u{2022}\u{FE0E}",
    "\u{21E8}\u{FE0E}", // U+21E8 : rightwards white arrow
    "\u{2B03}\u{FE0E}", // U+2B03 : south west white arrow
    "\u{21E9}\u{FE0E}", // U+21E9 : downwards white arrow
    "\u{2B02}\u{FE0E}", // U+2B02 : south east white arrow
])

let sansSerifArrowGlyphs = LabelGlyphSet(name: "sans-serif arrow", columns: 3, rows: 3, values: [
    "\u{1F854}\u{FE0E}", "\u{1F851}\u{FE0E}", "\u{1F855}\u{FE0E}",
    "\u{1F850}\u{FE0E}",  "\u{2022}\u{FE0E}", "\u{1F852}\u{FE0E}",
    "\u{1F857}\u{FE0E}", "\u{1F853}\u{FE0E}", "\u{1F856}\u{FE0E}",
])

let wideHeadedLightBarbArrowGlyphs = LabelGlyphSet(name: "wide headed light barb arrow", columns: 3, rows: 3, values: [
    "\u{1F864}\u{FE0E}", "\u{1F861}\u{FE0E}", "\u{1F865}\u{FE0E}",
    "\u{1F860}\u{FE0E}",  "\u{2022}\u{FE0E}", "\u{1F862}\u{FE0E}",
    "\u{1F867}\u{FE0E}", "\u{1F863}\u{FE0E}", "\u{1F866}\u{FE0E}",
])

let wideHeadedBarbArrowGlyphs = LabelGlyphSet(name: "wide headed barb arrow", columns: 3, rows: 3, values: [
    "\u{1F86C}\u{FE0E}", "\u{1F869}\u{FE0E}", "\u{1F86D}\u{FE0E}",
    "\u{1F868}\u{FE0E}",  "\u{2022}\u{FE0E}", "\u{1F86A}\u{FE0E}",
    "\u{1F86F}\u{FE0E}", "\u{1F86B}\u{FE0E}", "\u{1F86E}\u{FE0E}",
])

let wideHeadedMediumBarbArrowGlyphs = LabelGlyphSet(name: "wide headed medium barb arrow", columns: 3, rows: 3, values: [
    "\u{1F874}\u{FE0E}", "\u{1F871}\u{FE0E}", "\u{1F875}\u{FE0E}",
    "\u{1F870}\u{FE0E}",  "\u{2022}\u{FE0E}", "\u{1F872}\u{FE0E}",
    "\u{1F877}\u{FE0E}", "\u{1F873}\u{FE0E}", "\u{1F876}\u{FE0E}",
])

let wideHeadedHeavyBarbArrowGlyphs = LabelGlyphSet(name: "wide headed heavy barb arrow", columns: 3, rows: 3, values: [
    "\u{1F87C}\u{FE0E}", "\u{1F879}\u{FE0E}", "\u{1F87D}\u{FE0E}",
    "\u{1F878}\u{FE0E}",  "\u{2022}\u{FE0E}", "\u{1F87A}\u{FE0E}",
    "\u{1F87F}\u{FE0E}", "\u{1F87B}\u{FE0E}", "\u{1F87E}\u{FE0E}",
])

let wideHeadedVeryHeavyBarbArrowGlyphs = LabelGlyphSet(name: "wide headed very heavy barb arrow", columns: 3, rows: 3, values: [
    "\u{1F884}\u{FE0E}", "\u{1F881}\u{FE0E}", "\u{1F885}\u{FE0E}",
    "\u{1F880}\u{FE0E}",  "\u{2022}\u{FE0E}", "\u{1F882}\u{FE0E}",
    "\u{1F887}\u{FE0E}", "\u{1F883}\u{FE0E}", "\u{1F886}\u{FE0E}",
])

let fontNames = [
    "AcademyEngravedLetPlain",
    "AlNile-Bold",
    "AlNile",
    "AmericanTypewriter",
    "AmericanTypewriter-Bold",
    "AmericanTypewriter-Condensed",
    "AmericanTypewriter-CondensedBold",
    "AmericanTypewriter-CondensedLight",
    "AmericanTypewriter-Light",
    "AppleSDGothicNeo-Thin",
    "AppleSDGothicNeo-UltraLight",
    "AppleSDGothicNeo-Light",
    "AppleSDGothicNeo-Regular",
    "AppleSDGothicNeo-Medium",
    "AppleSDGothicNeo-SemiBold",
    "AppleSDGothicNeo-Bold",
    "AppleSDGothicNeo-Medium",
    "ArialMT",
    "Arial-BoldItalicMT",
    "Arial-BoldMT",
    "Arial-ItalicMT",
    "ArialHebrew",
    "ArialHebrew-Bold",
    "ArialHebrew-Light",
    "ArialRoundedMTBold",
    "Avenir-Black",
    "Avenir-BlackOblique",
    "Avenir-Book",
    "Avenir-BookOblique",
    "Avenir-Heavy",
    "Avenir-HeavyOblique",
    "Avenir-Light",
    "Avenir-LightOblique",
    "Avenir-Medium",
    "Avenir-MediumOblique",
    "Avenir-Oblique",
    "Avenir-Roman",
    "AvenirNext-Bold",
    "AvenirNext-BoldItalic",
    "AvenirNext-DemiBold",
    "AvenirNext-DemiBoldItalic",
    "AvenirNext-Heavy",
    "AvenirNext-HeavyItalic",
    "AvenirNext-Italic",
    "AvenirNext-Medium",
    "AvenirNext-MediumItalic",
    "AvenirNext-Regular",
    "AvenirNext-UltraLight",
    "AvenirNext-UltraLightItalic",
    "AvenirNextCondensed-Bold",
    "AvenirNextCondensed-BoldItalic",
    "AvenirNextCondensed-DemiBold",
    "AvenirNextCondensed-DemiBoldItalic",
    "AvenirNextCondensed-Heavy",
    "AvenirNextCondensed-HeavyItalic",
    "AvenirNextCondensed-Italic",
    "AvenirNextCondensed-Medium",
    "AvenirNextCondensed-MediumItalic",
    "AvenirNextCondensed-Regular",
    "AvenirNextCondensed-UltraLight",
    "AvenirNextCondensed-UltraLightItalic",
    "BanglaSangamMN",
    "BanglaSangamMN-Bold",
    "Baskerville",
    "Baskerville-Bold",
    "Baskerville-BoldItalic",
    "Baskerville-Italic",
    "Baskerville-SemiBold",
    "Baskerville-SemiBoldItalic",
    "BodoniOrnamentsITCTT",
    "BodoniSvtyTwoITCTT-Bold",
    "BodoniSvtyTwoITCTT-Book",
    "BodoniSvtyTwoITCTT-BookIta",
    "BodoniSvtyTwoOSITCTT-Bold",
    "BodoniSvtyTwoOSITCTT-Book",
    "BodoniSvtyTwoOSITCTT-BookIt",
    "BodoniSvtyTwoSCITCTT-Book",
    "BradleyHandITCTT-Bold",
    "ChalkboardSE-Bold",
    "ChalkboardSE-Light",
    "ChalkboardSE-Regular",
    "Chalkduster",
    "Cochin",
    "Cochin-Bold",
    "Cochin-BoldItalic",
    "Cochin-Italic",
    "Copperplate",
    "Copperplate-Bold",
    "Copperplate-Light",
    "Courier",
    "Courier-Bold",
    "Courier-BoldOblique",
    "Courier-Oblique",
    "CourierNewPS-BoldItalicMT",
    "CourierNewPS-BoldMT",
    "CourierNewPS-ItalicMT",
    "CourierNewPSMT",
    "DINAlternate-Bold",
    "DINCondensed-Bold",
    "DamascusBold",
    "Damascus",
    "DamascusLight",
    "DamascusMedium",
    "DamascusSemiBold",
    "DevanagariSangamMN",
    "DevanagariSangamMN-Bold",
    "Didot",
    "Didot-Bold",
    "Didot-Italic",
    "DiwanMishafi",
    "EuphemiaUCAS",
    "EuphemiaUCAS-Bold",
    "EuphemiaUCAS-Italic",
    "Farah",
    "Futura-CondensedExtraBold",
    "Futura-CondensedMedium",
    "Futura-Medium",
    "Futura-MediumItalic",
    "GeezaPro",
    "GeezaPro-Bold",
    "Georgia",
    "Georgia-Bold",
    "Georgia-BoldItalic",
    "Georgia-Italic",
    "GillSans",
    "GillSans-SemiBold",
    "GillSans-SemiBoldItalic",
    "GillSans-Bold",
    "GillSans-BoldItalic",
    "GillSans-UltraBold",
    "GillSans-Italic",
    "GillSans-Light",
    "GillSans-LightItalic",
    "GujaratiSangamMN",
    "GujaratiSangamMN-Bold",
    "GurmukhiMN",
    "GurmukhiMN-Bold",
    "STHeitiSC-Light",
    "STHeitiSC-Medium",
    "STHeitiTC-Light",
    "STHeitiTC-Medium",
    "Helvetica",
    "Helvetica-Bold",
    "Helvetica-BoldOblique",
    "Helvetica-Light",
    "Helvetica-LightOblique",
    "Helvetica-Oblique",
    "HelveticaNeue",
    "HelveticaNeue-Bold",
    "HelveticaNeue-BoldItalic",
    "HelveticaNeue-CondensedBlack",
    "HelveticaNeue-CondensedBold",
    "HelveticaNeue-Italic",
    "HelveticaNeue-Light",
    "HelveticaNeue-LightItalic",
    "HelveticaNeue-Medium",
    "HelveticaNeue-MediumItalic",
    "HelveticaNeue-UltraLight",
    "HelveticaNeue-UltraLightItalic",
    "HelveticaNeue-Thin",
    "HelveticaNeue-ThinItalic",
    "HiraMinProN-W3",
    "HiraMinProN-W6",
    "HiraginoSans-W3",
    "HiraginoSans-W6",
    "HoeflerText-Black",
    "HoeflerText-BlackItalic",
    "HoeflerText-Italic",
    "HoeflerText-Regular",
    "IowanOldStyle-Bold",
    "IowanOldStyle-BoldItalic",
    "IowanOldStyle-Italic",
    "IowanOldStyle-Roman",
    "Kailasa",
    "Kailasa-Bold",
    "KannadaSangamMN",
    "KannadaSangamMN-Bold",
    "KhmerSangamMN",
    "KohinoorBangla-Light",
    "KohinoorBangla-Regular",
    "KohinoorBangla-Semibold",
    "KohinoorDevanagari-Book",
    "KohinoorDevanagari-Light",
    "KohinoorDevanagari-Medium",
    "KohinoorTelugu-Light",
    "KohinoorTelugu-Regular",
    "KohinoorTelugu-Medium",
    "LaoSangamMN",
    "MalayalamSangamMN",
    "MalayalamSangamMN-Bold",
    "Menlo-BoldItalic",
    "Menlo-Regular",
    "Menlo-Bold",
    "Menlo-Italic",
    "Marion-Italic",
    "MarkerFelt-Thin",
    "MarkerFelt-Wide",
    "Noteworthy-Bold",
    "Noteworthy-Light",
    "Optima-Bold",
    "Optima-BoldItalic",
    "Optima-ExtraBlack",
    "Optima-Italic",
    "Optima-Regular",
    "OriyaSangamMN",
    "OriyaSangamMN-Bold",
    "Palatino-Bold",
    "Palatino-BoldItalic",
    "Palatino-Italic",
    "Palatino-Roman",
    "Papyrus",
    "Papyrus-Condensed",
    "PartyLetPlain",
    "PingFangHK-Ultralight",
    "PingFangHK-Light",
    "PingFangHK-Thin",
    "PingFangHK-Regular",
    "PingFangHK-Medium",
    "PingFangHK-Semibold",
    "PingFangSC-Ultralight",
    "PingFangSC-Light",
    "PingFangSC-Thin",
    "PingFangSC-Regular",
    "PingFangSC-Medium",
    "PingFangSC-Semibold",
    "PingFangTC-Ultralight",
    "PingFangTC-Light",
    "PingFangTC-Thin",
    "PingFangTC-Regular",
    "PingFangTC-Medium",
    "PingFangTC-Semibold",
    "SavoyeLetPlain",
    "SinhalaSangamMN",
    "SinhalaSangamMN-Bold",
    "SnellRoundhand",
    "SnellRoundhand-Black",
    "SnellRoundhand-Bold",
    "Symbol",
    "TamilSangamMN",
    "TamilSangamMN-Bold",
    "TeluguSangamMN",
    "TeluguSangamMN-Bold",
    "Thonburi",
    "Thonburi-Bold",
    "Thonburi-Light",
    "TimesNewRomanPS-BoldItalicMT",
    "TimesNewRomanPS-BoldMT",
    "TimesNewRomanPS-ItalicMT",
    "TimesNewRomanPSMT",
    "Trebuchet-BoldItalic",
    "TrebuchetMS",
    "TrebuchetMS-Bold",
    "TrebuchetMS-Italic",
    "Verdana",
    "Verdana-Bold",
    "Verdana-BoldItalic",
    "Verdana-Italic",
    "ZapfDingbatsITC",
    "Zapfino",
]

