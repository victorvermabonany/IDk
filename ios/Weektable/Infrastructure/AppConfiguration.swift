import Foundation

enum AppConfiguration {
    private static let apiURLKey = "WEEKTABLE_API_BASE_URL"
    private static let liveAPIKey = "WEEKTABLE_USE_LIVE_API"

    static func makePlanRepository() -> any PlanRepository {
        let environment = ProcessInfo.processInfo.environment
        let configuredURL = (Bundle.main.object(forInfoDictionaryKey: apiURLKey) as? String)
            .flatMap(URL.init(string:))
        let liveAPIOverride = environment[liveAPIKey]
        let shouldUseLiveAPI = liveAPIOverride != "0"

        if shouldUseLiveAPI, let configuredURL, configuredURL.scheme == "https", configuredURL.host != nil {
            return APIPlanRepository(client: APIClient(baseURL: configuredURL))
        }

        return DemoPlanRepository()
    }
}
