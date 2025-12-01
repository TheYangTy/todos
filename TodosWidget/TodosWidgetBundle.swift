import WidgetKit
import SwiftUI

@main
struct TodosWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodosWidget()
        TodosOverviewWidget()
        
        TodaySummaryLockWidget()
        ProgressRingLockWidget()
        MiniListLockWidget()
    }
}
