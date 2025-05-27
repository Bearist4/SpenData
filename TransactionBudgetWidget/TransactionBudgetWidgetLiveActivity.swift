//
//  TransactionBudgetWidgetLiveActivity.swift
//  TransactionBudgetWidget
//
//  Created by Benjamin CAILLET on 25.05.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TransactionBudgetWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TransactionBudgetWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransactionBudgetWidgetAttributes.self) { context in
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

extension TransactionBudgetWidgetAttributes {
    fileprivate static var preview: TransactionBudgetWidgetAttributes {
        TransactionBudgetWidgetAttributes(name: "World")
    }
}

extension TransactionBudgetWidgetAttributes.ContentState {
    fileprivate static var smiley: TransactionBudgetWidgetAttributes.ContentState {
        TransactionBudgetWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TransactionBudgetWidgetAttributes.ContentState {
         TransactionBudgetWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TransactionBudgetWidgetAttributes.preview) {
   TransactionBudgetWidgetLiveActivity()
} contentStates: {
    TransactionBudgetWidgetAttributes.ContentState.smiley
    TransactionBudgetWidgetAttributes.ContentState.starEyes
}
