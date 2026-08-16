import Foundation
import SwiftData

@Model
final class PersistedPayload {
    @Attribute(.unique) var key: String
    var data: Data
    var updatedAt: Date

    init(key: String, data: Data, updatedAt: Date = .now) {
        self.key = key
        self.data = data
        self.updatedAt = updatedAt
    }
}

@MainActor
final class PersistenceController {
    let container: ModelContainer
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: PersistedPayload.self, configurations: configuration)
            context = ModelContext(container)
        } catch {
            fatalError("Unable to initialize Weektable persistence: \(error)")
        }
    }

    func save<Value: Encodable>(_ value: Value, key: String) throws {
        let data = try encoder.encode(value)
        let descriptor = FetchDescriptor<PersistedPayload>(predicate: #Predicate { $0.key == key })
        if let existing = try context.fetch(descriptor).first {
            existing.data = data
            existing.updatedAt = .now
        } else {
            context.insert(PersistedPayload(key: key, data: data))
        }
        try context.save()
    }

    func load<Value: Decodable>(_ type: Value.Type, key: String) throws -> Value? {
        let descriptor = FetchDescriptor<PersistedPayload>(predicate: #Predicate { $0.key == key })
        guard let payload = try context.fetch(descriptor).first else { return nil }
        return try decoder.decode(type, from: payload.data)
    }

    func remove(key: String) throws {
        let descriptor = FetchDescriptor<PersistedPayload>(predicate: #Predicate { $0.key == key })
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
        try context.save()
    }
}

enum PersistenceKey {
    static let plannerDraft = "planner-draft"
    static let cachedPlan = "cached-plan"
    static let generationJob = "generation-job"
    static let groceryState = "grocery-state"
}

struct GroceryState: Codable, Equatable {
    var checkedItemIDs: Set<String> = []
    var ownedItemIDs: Set<String> = []
}
