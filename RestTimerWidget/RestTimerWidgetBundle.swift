//
//  RestTimerWidgetBundle.swift
//  RestTimerWidget
//
//  Created by Moritz Gößl on 12.01.26.
//

import WidgetKit
import SwiftUI

@main
struct RestTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        RestTimerWidget()
        RestTimerWidgetControl()
        RestTimerLiveActivity()
    }
}
