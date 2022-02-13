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
    // Color for the labels that contain the number of each tile
    @Published var tileNumberColor: Color = .init(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.75)
    // Font for the labels that contain the number of each tile
    let tileNumberFontFace: String = "Avenir-Heavy"
    // Text size for the labels that contain the number of each tile relative to the tile size
    @Published var tileNumberFontSize: Float = 0.9
    let tileMargin: Float = 3;
}
