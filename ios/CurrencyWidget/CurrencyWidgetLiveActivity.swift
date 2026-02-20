//
//  CurrencyWidgetLiveActivity.swift
//  CurrencyWidget
//
//  Created by FNL ABJ on 20/02/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CurrencyWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CurrencyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CurrencyWidgetAttributes.self) { context in
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

extension CurrencyWidgetAttributes {
    fileprivate static var preview: CurrencyWidgetAttributes {
        CurrencyWidgetAttributes(name: "World")
    }
}

extension CurrencyWidgetAttributes.ContentState {
    fileprivate static var smiley: CurrencyWidgetAttributes.ContentState {
        CurrencyWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CurrencyWidgetAttributes.ContentState {
         CurrencyWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CurrencyWidgetAttributes.preview) {
   CurrencyWidgetLiveActivity()
} contentStates: {
    CurrencyWidgetAttributes.ContentState.smiley
    CurrencyWidgetAttributes.ContentState.starEyes
}
