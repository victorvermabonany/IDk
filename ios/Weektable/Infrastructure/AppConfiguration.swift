import Foundation

enum AppConfiguration {
    private static let apiURLKey = "WEEKTABLE_API_BASE_URL"
    private static let liveAPIKey = "WEEKTABLE_USE_LIVE_API"
    private static let privacyURLKey = "WEEKTABLE_PRIVACY_URL"
    private static let termsURLKey = "WEEKTABLE_TERMS_URL"
    private static let supportURLKey = "WEEKTABLE_SUPPORT_URL"

    static var privacyURL: URL? { configuredHTTPSURL(for: privacyURLKey) }
    static var termsURL: URL? { configuredHTTPSURL(for: termsURLKey) }
    static var supportURL: URL? { configuredHTTPSURL(for: supportURLKey) }

    static func makePlanRepository() -> any PlanRepository {
        let environment = ProcessInfo.processInfo.environment
        let configuredURL = (Bundle.main.object(forInfoDictionaryKey: apiURLKey) as? String)
            .flatMap(URL.init(string:))
        let liveAPIOverride = environment[liveAPIKey]
        let shouldUseLiveAPI = liveAPIOverride != "0"

        if shouldUseLiveAPI, let configuredURL, configuredURL.scheme == "https", configuredURL.host != nil {
            return APIPlanRepository(client: APIClient(baseURL: configuredURL))
        }

#if DEBUG
        return DemoPlanRepository()
#else
        return UnavailablePlanRepository(reason: "Weektable’s service address is missing or invalid. Your planner answers are saved. Please install a correctly configured beta build and try again.")
#endif
    }

    private static func configuredHTTPSURL(for key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}
