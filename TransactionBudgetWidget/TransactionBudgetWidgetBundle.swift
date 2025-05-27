//
//  TransactionBudgetWidgetBundle.swift
//  TransactionBudgetWidget
//
//  Created by Benjamin CAILLET on 25.05.25.
//

import WidgetKit
import SwiftUI

@main
struct TransactionBudgetWidgetBundle: WidgetBundle {
    var body: some Widget {
        SingleBudgetWidget()
        TwoBudgetsWidget()
        FourBudgetsWidget()
        MediumBudgetBarWidget()
    }
}
