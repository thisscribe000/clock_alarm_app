//
//  clock_alarm_appBundle.swift
//  clock_alarm_app
//
//  Created by FNL ABJ on 20/02/2026.
//

import WidgetKit
import SwiftUI

@main
struct clock_alarm_appBundle: WidgetBundle {
    var body: some Widget {
        clock_alarm_app()
        clock_alarm_appControl()
        clock_alarm_appLiveActivity()
    }
}
