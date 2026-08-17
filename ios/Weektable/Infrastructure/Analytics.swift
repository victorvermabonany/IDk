import Foundation

enum AnalyticsEvent: String, Sendable {
    case appOpened = "app_opened"
    case plannerStarted = "planner_started"
    case generationStarted = "generation_started"
    case generationCompleted = "generation_completed"
    case generationFailed = "generation_failed"
    case groceryItemChecked = "grocery_item_checked"
    case pantryItemChanged = "pantry_item_changed"
    case swapOpened = "swap_opened"
    case swapCompleted = "swap_completed"
    case paywallViewed = "paywall_viewed"
}

protocol AnalyticsClient: Sendable {
    func track(_ event: AnalyticsEvent) async
}

struct NoOpAnalyticsClient: AnalyticsClient {
    func track(_ event: AnalyticsEvent) async { }
}
