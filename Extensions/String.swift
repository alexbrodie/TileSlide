//
//  extension_String.swift
//  TileSlide
//
//  Created by Alex Brodie on 2/15/2022.
//  Copyright © 2022 Alex Brodie. All rights reserved.
//

import Foundation

extension String {
    public func substring(_ i: Int) -> String {
        let start = index(startIndex, offsetBy: i)
        let end = index(start, offsetBy: 1)
        return String(self[start..<end])
    }

    public func substring(_ range: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(startIndex, offsetBy: range.upperBound)
        return String(self[start..<end])
    }

    public func substring(_ range: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(startIndex, offsetBy: range.upperBound)
        return String(self[start...end])
    }
}
