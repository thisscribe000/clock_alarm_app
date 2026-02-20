//
//  clock_alarm_appLiveActivity.swift
//  clock_alarm_app
//
//  Created by FNL ABJ on 20/02/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct clock_alarm_appAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct clock_alarm_appLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: clock_alarm_appAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension clock_alarm_appAttributes {
    fileprivate static var preview: clock_alarm_appAttributes {
        clock_alarm_appAttributes(name: "World")
    }
}

extension clock_alarm_appAttributes.ContentState {
    fileprivate static var smiley: clock_alarm_appAttributes.ContentState {
        clock_alarm_appAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: clock_alarm_appAttributes.ContentState {
         clock_alarm_appAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: clock_alarm_appAttributes.preview) {
   clock_alarm_appLiveActivity()
} contentStates: {
    clock_alarm_appAttributes.ContentState.smiley
    clock_alarm_appAttributes.ContentState.starEyes
}
