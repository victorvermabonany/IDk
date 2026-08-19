import Foundation

enum GenerationFailureKind: Equatable {
    case budget
    case constraints
    case pricing
    case temporary
    case offline
    case expired
}

struct GenerationFailure: Equatable {
    let kind: GenerationFailureKind
    let title: String
    let message: String

    static func userFacing(for error: Error, request: PlannerRequest) -> GenerationFailure {
        if error is DemoPlanningError {
            return budgetFailure(request: request)
        }

        if let apiError = error as? APIError {
            switch apiError {
            case .configuration, .invalidResponse:
                return temporaryFailure
            case let .server(status, code, _):
                switch code?.uppercased() {
                case "BUDGET_TOO_LOW":
                    return budgetFailure(request: request)
                case "CONSTRAINT_CONFLICT":
                    return constraintFailure(request: request)
                case "UNPRICED_BASKET", "PROVIDER_UNAVAILABLE":
                    return pricingFailure
                case "MODEL_FAILURE":
                    return temporaryFailure
                default:
                    if status == 404 { return expiredFailure }
                    if status == 409 || status == 422 { return constraintFailure(request: request) }
                    if status == 429 || status >= 500 { return temporaryFailure }
                }
            }
        }

        if error is URLError { return offlineFailure }
        return temporaryFailure
    }

    private static func budgetFailure(request: PlannerRequest) -> GenerationFailure {
        let people = request.householdSize == 1 ? "person" : "people"
        return GenerationFailure(
            kind: .budget,
            title: "We couldn’t make this week fit.",
            message: "\(request.dinnerCount) dinners for \(request.householdSize) \(people) won’t fit within your \(request.budgetCents.currency) budget with the current preferences."
        )
    }

    private static func constraintFailure(request: PlannerRequest) -> GenerationFailure {
        let hasFoodRequirements = !request.allergies.isEmpty || !request.dietaryRestrictions.isEmpty || !request.dislikedFoodItems.isEmpty
        let detail = hasFoodRequirements
            ? "Cove couldn’t find \(request.dinnerCount) dinners that meet your food preferences and \(request.maxCookingMinutes)-minute cooking limit."
            : "Cove couldn’t find \(request.dinnerCount) dinners that meet the selected meal and cooking-time preferences."
        return GenerationFailure(
            kind: .constraints,
            title: "These preferences don’t work together yet.",
            message: detail
        )
    }

    private static let pricingFailure = GenerationFailure(
        kind: .pricing,
        title: "We couldn’t price this week.",
        message: "Cove couldn’t confirm enough package prices for your selected store. Choose another store or try again."
    )

    private static let temporaryFailure = GenerationFailure(
        kind: .temporary,
        title: "We couldn’t finish your week.",
        message: "Nothing you entered was lost. Please try again in a moment."
    )

    private static let offlineFailure = GenerationFailure(
        kind: .offline,
        title: "You’re offline.",
        message: "Nothing you entered was lost. Reconnect, then try again."
    )

    private static let expiredFailure = GenerationFailure(
        kind: .expired,
        title: "This plan request expired.",
        message: "Your planner answers are still here. Review them, then build the week again."
    )
}
