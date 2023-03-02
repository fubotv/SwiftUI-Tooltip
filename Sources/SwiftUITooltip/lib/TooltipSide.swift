//
//  TooltipSide.swift
//
//  Created by Antoni Silvestrovic on 24/10/2020.
//  Copyright © 2020 Quassum Manus. All rights reserved.
//

import SwiftUI


public enum TooltipSide: Int {
    case top = 4
    case bottom = 0

    func getArrowAngleRadians() -> Optional<Double> {
        return Double(self.rawValue) * .pi / 4
    }
    
    func shouldShowArrow() -> Bool {
        return true
    }
}
