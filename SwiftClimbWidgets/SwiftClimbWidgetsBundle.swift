//
//  SwiftClimbWidgetsBundle.swift
//  SwiftClimbWidgets
//
//  Created by Steve Kelley on 1/22/26.
//

import WidgetKit
import SwiftUI

@main
struct SwiftClimbWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SwiftClimbWidgets()
        SwiftClimbWidgetsControl()
        ClimbingSessionLiveActivity()
    }
}
