//
//  HistoryManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/14/25.
//

import AppKit
import CoreData
import Foundation

// MARK: - Managed Object

@objc(HistoryEntryMO)
final class HistoryEntryMO: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var timestamp: Date
    @NSManaged var title: String?
    @NSManaged var kind: String?
    @NSManaged var json: Data  // JSON blob for arbitrary payload
}

// MARK: - HistoryCoreDataManager

@MainActor
final class HistoryCoreDataManager: ObservableObject {
    static let shared = HistoryCoreDataManager()

    // MARK: Public API (non-throwing)

    /// Append an entry for a tab (newest-first by timestamp).
    @discardableResult
    func append(
        _ item: [String: Any],
        for tabId: String,
        title: String? = nil,
        kind: String? = nil
    ) async -> Bool {
        guard JSONSerialization.isValidJSONObject(item),
            let json = try? JSONSerialization.data(withJSONObject: item, options: [])
        else {
            log("append invalid JSON")
            return false
        }

        guard let container = await container(for: tabId) else { return false }
        let ctx = container.newBackgroundContext()
        return await ctx.perform {
            let obj = HistoryEntryMO(context: ctx)
            obj.id = UUID()
            obj.timestamp = Date()
            obj.title = title
            obj.kind = kind
            obj.json = json
            do {
                try ctx.save()
                return true
            } catch {
                self.log("append save failed: \(error)")
                return false
            }
        }
    }

    /// Fetch entries for a tab (newest-first). Optional filters.
    ///
    /// - Parameters:
    ///   - limit: cap result count (nil = no cap)
    ///   - since: only items with timestamp >= since
    ///   - kind: filter by kind (exact match)
    ///   - search: case/diacritic-insensitive contains on `title`
    func fetch(
        for tabId: String,
        limit: Int? = nil,
        since: Date? = nil,
        kind: String? = nil,
        search: String? = nil
    ) async -> [HistoryEntry] {
        guard let container = await container(for: tabId) else { return [] }
        let ctx = container.viewContext

        return await ctx.perform {
            let req = NSFetchRequest<HistoryEntryMO>(entityName: "HistoryEntry")
            var preds: [NSPredicate] = []
            if let since { preds.append(NSPredicate(format: "timestamp >= %@", since as NSDate)) }
            if let kind { preds.append(NSPredicate(format: "kind == %@", kind)) }
            if let q = search, !q.isEmpty {
                preds.append(NSPredicate(format: "title CONTAINS[cd] %@", q))
            }
            if !preds.isEmpty {
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: preds)
            }
            req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            if let limit { req.fetchLimit = limit }

            do {
                let results = try ctx.fetch(req)
                return results.compactMap { mo in
                    HistoryEntry(
                        id: mo.id,
                        timestamp: mo.timestamp,
                        title: mo.title,
                        kind: mo.kind,
                        json: (try? JSONSerialization.jsonObject(with: mo.json)) as? [String: Any]
                            ?? [:]
                    )
                }
            } catch {
                self.log("fetch failed: \(error)")
                return []
            }
        }
    }

    /// Delete a single entry by id in a tab store.
    @discardableResult
    func deleteEntry(id: UUID, for tabId: String) async -> Bool {
        guard let container = await container(for: tabId) else { return false }
        let ctx = container.newBackgroundContext()
        return await ctx.perform {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: "HistoryEntry")
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            let del = NSBatchDeleteRequest(fetchRequest: req)
            do {
                try ctx.execute(del)
                try ctx.save()
                return true
            } catch {
                self.log("deleteEntry failed: \(error)")
                return false
            }
        }
    }

    /// Remove all entries for a tab (drops the SQLite file).
    @discardableResult
    func clear(tabId: String) async -> Bool {
        guard let container = tabContainers[tabId] else {
            // Nothing loaded; try removing file if it exists
            let url = Self.storeURL(for: tabId)
            try? FileManager.default.removeItem(at: url)
            return true
        }
        // Tear down store cleanly
        let psc = container.persistentStoreCoordinator
        if let store = psc.persistentStores.first {
            do {
                try psc.remove(store)
            } catch {
                log("remove store failed: \(error)")
            }
        }
        // Remove files on disk
        let url = Self.storeURL(for: tabId)
        let shm = url.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let wal = url.deletingPathExtension().appendingPathExtension("sqlite-wal")
        [url, shm, wal].forEach { try? FileManager.default.removeItem(at: $0) }
        tabContainers.removeValue(forKey: tabId)
        return true
    }

    /// Count entries in a tab.
    func count(for tabId: String) async -> Int {
        guard let container = await container(for: tabId) else { return 0 }
        let ctx = container.viewContext
        return await ctx.perform {
            let req = NSFetchRequest<NSNumber>(entityName: "HistoryEntry")
            req.resultType = .countResultType
            do { return try ctx.count(for: req) } catch {
                self.log("count failed: \(error)")
                return 0
            }
        }
    }

    // MARK: Internals

    private init() {}

    // One container per tabId (=> one SQLite per tab)
    private var tabContainers: [String: NSPersistentContainer] = [:]

    /// Lazily create/load a container for a given tabId.
    private func container(for tabId: String) async -> NSPersistentContainer? {
        if let c = tabContainers[tabId] { return c }
        let model = Self.makeModel()
        let c = NSPersistentContainer(name: "HistoryModel", managedObjectModel: model)

        // Store location: ~/Library/Application Support/com.thisisnsh.mac.AIThing/History/<tabId>.sqlite
        let storeURL = Self.storeURL(for: tabId)
        do {
            try Self.ensureParentDir(storeURL)
        } catch {
            log("ensure dir failed: \(error)")
            return nil
        }

        let desc = NSPersistentStoreDescription(url: storeURL)
        desc.type = NSSQLiteStoreType
        desc.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        desc.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        c.persistentStoreDescriptions = [desc]

        var ok = false
        var loadError: Error?
        c.loadPersistentStores { _, error in
            if let error {
                loadError = error
                ok = false
            } else {
                ok = true
            }
        }
        if !ok {
            log("load store failed: \(String(describing: loadError))")
            return nil
        }
        // Performance niceties
        c.viewContext.automaticallyMergesChangesFromParent = true
        c.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        tabContainers[tabId] = c
        return c
    }

    // MARK: Model + Paths

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Entity: HistoryEntry
        let entity = NSEntityDescription()
        entity.name = "HistoryEntry"
        entity.managedObjectClassName = NSStringFromClass(HistoryEntryMO.self)

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false

        let timestamp = NSAttributeDescription()
        timestamp.name = "timestamp"
        timestamp.attributeType = .dateAttributeType
        timestamp.isOptional = false

        let title = NSAttributeDescription()
        title.name = "title"
        title.attributeType = .stringAttributeType
        title.isOptional = true

        let kind = NSAttributeDescription()
        kind.name = "kind"
        kind.attributeType = .stringAttributeType
        kind.isOptional = true

        let json = NSAttributeDescription()
        json.name = "json"
        json.attributeType = .binaryDataAttributeType
        json.isOptional = false
        json.allowsExternalBinaryDataStorage = true

        entity.properties = [id, timestamp, title, kind, json]
        entity.uniquenessConstraints = [["id"]]

        model.entities = [entity]
        return model
    }

    private static func storeURL(for tabId: String) -> URL {
        let base = appSupportDir()
            .appendingPathComponent("com.thisisnsh.mac.AIThing", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
        return base.appendingPathComponent("\(safeFilename(tabId)).sqlite")
    }

    private static func appSupportDir() -> URL {
        try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private static func safeFilename(_ name: String) -> String {
        // Sanitize tab IDs for filesystem
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>.")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private static func ensureParentDir(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func log(_ msg: String) {
        NSLog("[HistoryCoreData] \(msg)")
    }
}

// MARK: - Lightweight value type for consumers

struct HistoryEntry: Identifiable {
    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        lhs.id == rhs.id
    }

    let id: UUID
    let timestamp: Date
    let title: String?
    let kind: String?
    let json: [String: Any]
}
