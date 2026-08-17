import Foundation

enum AppConfiguration {
    private static let apiURLKeys = ["COVE_API_BASE_URL", "WEEKTABLE_API_BASE_URL"]
    private static let runtimeModeKey = "COVE_RUNTIME_MODE"
    private static let privacyURLKeys = ["COVE_PRIVACY_URL", "WEEKTABLE_PRIVACY_URL"]
    private static let termsURLKeys = ["COVE_TERMS_URL", "WEEKTABLE_TERMS_URL"]
    private static let supportURLKeys = ["COVE_SUPPORT_URL", "WEEKTABLE_SUPPORT_URL"]

    static var privacyURL: URL? { configuredHTTPSURL(for: privacyURLKeys) }
    static var termsURL: URL? { configuredHTTPSURL(for: termsURLKeys) }
    static var supportURL: URL? { configuredHTTPSURL(for: supportURLKeys) }

    static func makePlanRepository() -> any PlanRepository {
        let environment = ProcessInfo.processInfo.environment
        let configuredURL = configuredHTTPSURL(for: apiURLKeys)
        let configuredMode = environment[runtimeModeKey]?.lowercased()
            ?? (Bundle.main.object(forInfoDictionaryKey: runtimeModeKey) as? String)?.lowercased()
            ?? "development_fixture"
        let fixtureMode = configuredMode == "development_fixture"
        let liveMode = configuredMode == "staging_live" || configuredMode == "production_live"

        if liveMode, let configuredURL {
            return APIPlanRepository(client: APIClient(baseURL: configuredURL))
        }

#if DEBUG
        if fixtureMode { return DemoPlanRepository() }
        if !liveMode { return UnavailablePlanRepository(reason: "Cove’s runtime mode is invalid. Configure COVE_RUNTIME_MODE before testing.") }
        return UnavailablePlanRepository(reason: "Cove’s staging service address is missing or invalid. Your planner answers are saved. Configure COVE_API_BASE_URL and try again.")
#else
        return UnavailablePlanRepository(reason: "Cove’s service address is missing or invalid. Your planner answers are saved. Please install a correctly configured beta build and try again.")
#endif
    }

#if DEBUG
    static func makePreviewRepository() -> any PlanRepository { DemoPlanRepository() }
#endif

    private static func configuredHTTPSURL(for keys: [String]) -> URL? {
        for key in keys {
            let value = ProcessInfo.processInfo.environment[key]
                ?? (Bundle.main.object(forInfoDictionaryKey: key) as? String)
            guard let value,
                  let url = URL(string: value), url.scheme == "https", url.host != nil else { continue }
            return url
        }
        return nil
    }
}
