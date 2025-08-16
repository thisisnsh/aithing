//
//  HistoryManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/14/25.
//

import AppKit
import CoreData
import Foundation

struct History: Identifiable, Equatable {
    let id: String
    let lastUpdated: String  // epoch seconds as String
    let title: String?
    let history: [[String: Any]]

    static func == (lhs: History, rhs: History) -> Bool { lhs.id == rhs.id }
}

@objc(HistoryDocMO)
final class HistoryDocMO: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var lastUpdated: Double  // epoch seconds
    @NSManaged var title: String?
    @NSManaged var json: Data  // JSON for [[String: Any]]
}

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    private init() {}

    // Keep a container per id (=> one SQLite per id)
    private var containers: [String: NSPersistentContainer] = [:]

    /// Idempotent: inserts when new, updates when existing. lastUpdated is set to now (epoch).
    @discardableResult
    func store(id: String, title: String? = nil, history: [[String: Any]]) async -> Bool {
        guard JSONSerialization.isValidJSONObject(history) else {
            log("store invalid JSON for id=\(id)")
            return false
        }
        guard let container = await container(for: id) else { return false }
        let ctx = container.newBackgroundContext()
        return await ctx.perform {
            do {
                let req = NSFetchRequest<HistoryDocMO>(entityName: "HistoryDoc")
                req.predicate = NSPredicate(format: "id == %@", id)
                req.fetchLimit = 1
                let mo: HistoryDocMO
                if let existing = try ctx.fetch(req).first {
                    mo = existing
                } else {
                    mo = HistoryDocMO(context: ctx)
                    mo.id = id
                }
                mo.title = title
                mo.lastUpdated = Date().timeIntervalSince1970
                mo.json = try JSONSerialization.data(withJSONObject: history, options: [])

                try ctx.save()
                return true
            } catch {
                self.log("store failed for id=\(id): \(error)")
                return false
            }
        }
    }

    /// Return all History objects from all per-id stores, newest first.
    func getAll(limit: Int? = nil) async -> [History] {
        let urls = Self.existingStoreURLs()
        var results: [History] = []

        for url in urls {
            // open container for this file's id (derived from filename)
            let id = Self.idFromStoreURL(url)
            guard let container = await container(for: id) else { continue }
            let ctx = container.viewContext
            let items: [History] = await ctx.perform {
                let req = NSFetchRequest<HistoryDocMO>(entityName: "HistoryDoc")
                req.fetchLimit = 1
                do {
                    guard let mo = try ctx.fetch(req).first else { return [] }
                    let obj =
                        (try? JSONSerialization.jsonObject(with: mo.json, options: []))
                        as? [[String: Any]] ?? []
                    let hist = History(
                        id: mo.id,
                        lastUpdated: String(Int64(mo.lastUpdated)),
                        title: mo.title,
                        history: obj
                    )
                    return [hist]
                } catch {
                    self.log("getAll fetch failed for id=\(id): \(error)")
                    return []
                }
            }
            results.append(contentsOf: items)
        }

        results.sort { (lhs, rhs) in
            // Compare by numeric epoch descending
            (Double(lhs.lastUpdated) ?? 0) > (Double(rhs.lastUpdated) ?? 0)
        }
        if let limit, results.count > limit {
            return Array(results.prefix(limit))
        }
        return results
    }

    /// Fetch a single History by id.
    func get(id: String) async -> History? {
        guard let container = await container(for: id) else { return nil }
        let ctx = container.viewContext
        return await ctx.perform {
            let req = NSFetchRequest<HistoryDocMO>(entityName: "HistoryDoc")
            req.predicate = NSPredicate(format: "id == %@", id)
            req.fetchLimit = 1
            do {
                guard let mo = try ctx.fetch(req).first else { return nil }
                let obj =
                    (try? JSONSerialization.jsonObject(with: mo.json, options: []))
                    as? [[String: Any]] ?? []
                return History(
                    id: mo.id,
                    lastUpdated: String(Int64(mo.lastUpdated)),
                    title: mo.title,
                    history: obj
                )
            } catch {
                self.log("get failed for id=\(id): \(error)")
                return nil
            }
        }
    }

    /// Remove a single id (deletes its SQLite file).
    @discardableResult
    func delete(id: String) async -> Bool {
        guard let container = containers[id] else {
            // Not loaded yet, just delete files
            Self.deleteStoreFiles(for: id)
            return true
        }
        let psc = container.persistentStoreCoordinator
        if let store = psc.persistentStores.first {
            do { try psc.remove(store) } catch { log("remove store failed: \(error)") }
        }
        Self.deleteStoreFiles(for: id)
        containers.removeValue(forKey: id)
        return true
    }

    /// Remove all ids (deletes directory).
    @discardableResult
    func clearAll() async -> Bool {
        // Remove all loaded stores
        for (id, container) in containers {
            let psc = container.persistentStoreCoordinator
            if let store = psc.persistentStores.first {
                try? psc.remove(store)
            }
            containers.removeValue(forKey: id)
        }
        // Delete directory
        let dir = Self.historyDir()
        try? FileManager.default.removeItem(at: dir)
        return true
    }

    private func container(for id: String) async -> NSPersistentContainer? {
        if let c = containers[id] { return c }
        let model = Self.makeModel()
        let c = NSPersistentContainer(name: "HistoryPerId", managedObjectModel: model)

        let url = Self.storeURL(for: id)
        do { try Self.ensureParentDir(url) } catch {
            log("ensure dir failed: \(error)")
            return nil
        }

        let desc = NSPersistentStoreDescription(url: url)
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
            log("load store failed for id=\(id): \(String(describing: loadError))")
            return nil
        }
        c.viewContext.automaticallyMergesChangesFromParent = true
        c.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        containers[id] = c
        return c
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "HistoryDoc"
        entity.managedObjectClassName = NSStringFromClass(HistoryDocMO.self)

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .stringAttributeType
        id.isOptional = false

        let lastUpdated = NSAttributeDescription()
        lastUpdated.name = "lastUpdated"
        lastUpdated.attributeType = .doubleAttributeType
        lastUpdated.isOptional = false

        let title = NSAttributeDescription()
        title.name = "title"
        title.attributeType = .stringAttributeType
        title.isOptional = true

        let json = NSAttributeDescription()
        json.name = "json"
        json.attributeType = .binaryDataAttributeType
        json.isOptional = false
        json.allowsExternalBinaryDataStorage = true

        entity.properties = [id, lastUpdated, title, json]
        entity.uniquenessConstraints = [["id"]]

        let modelEntities = [entity]
        model.entities = modelEntities
        return model
    }

    private static func appSupportDir() -> URL {
        try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private static func historyDir() -> URL {
        appSupportDir()
            .appendingPathComponent("com.thisisnsh.mac.AIThing", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
    }

    private static func storeURL(for id: String) -> URL {
        historyDir().appendingPathComponent("\(safeFilename(id)).sqlite")
    }

    /// Best-effort reverse (used only for directory scanning; we still read id from DB).
    private static func idFromStoreURL(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private static func existingStoreURLs() -> [URL] {
        let dir = historyDir()
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else { return [] }
        return contents.filter { $0.pathExtension == "sqlite" }
    }

    private static func ensureParentDir(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private static func deleteStoreFiles(for id: String) {
        let url = storeURL(for: id)
        let shm = url.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let wal = url.deletingPathExtension().appendingPathExtension("sqlite-wal")
        [url, shm, wal].forEach { try? FileManager.default.removeItem(at: $0) }
    }

    private static func safeFilename(_ name: String) -> String {
        // Sanitize filename for filesystem; mapping back is lossy – we read the canonical id from Core Data anyway.
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>.")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private func log(_ msg: String) { NSLog("[HistoryStore] \(msg)") }
}
