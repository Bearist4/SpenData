import WidgetKit
import SwiftUI

#if WIDGET_EXTENSION
@main
#endif
struct TransactionBudgetWidgetBundle: WidgetBundle {
    var body: some Widget {
        TransactionBudgetWidget()
    }
} 