//
//  TodosWidgetLiveActivity.swift
//  TodosWidget
//
//  Created by marcus on 2025/11/15.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TodosWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TodosWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodosWidgetAttributes.self) { context in
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

extension TodosWidgetAttributes {
    fileprivate static var preview: TodosWidgetAttributes {
        TodosWidgetAttributes(name: "World")
    }
}

extension TodosWidgetAttributes.ContentState {
    fileprivate static var smiley: TodosWidgetAttributes.ContentState {
        TodosWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TodosWidgetAttributes.ContentState {
         TodosWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TodosWidgetAttributes.preview) {
   TodosWidgetLiveActivity()
} contentStates: {
    TodosWidgetAttributes.ContentState.smiley
    TodosWidgetAttributes.ContentState.starEyes
}
