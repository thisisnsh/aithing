//
//  HistoryManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/14/25.
//

import AppKit
import CoreData
import Foundation
import os

@MainActor
final class HistoryStore: ObservableObject {

    // Keep a container per id (=> one SQLite per id)
    private var containers: [String: NSPersistentContainer] = [:]

    /// Idempotent: inserts when new, updates when existing. lastUpdated is set to now (epoch).
    @discardableResult
    func store(id: String, history: [ChatItem], unseen: Bool? = nil)
        async -> Bool
    {
        let jsonHistory = ChatItem.toDictionaries(history)
        guard JSONSerialization.isValidJSONObject(jsonHistory) else {
            logger.error("store invalid JSON for id=\(id)")
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
                    mo.title = "New Chat"
                    if let unseen = unseen {
                        mo.unseen = unseen
                    } else {
                        mo.unseen = false
                    }
                }

                mo.lastUpdated = Date().timeIntervalSince1970
                mo.json = try JSONSerialization.data(withJSONObject: jsonHistory, options: [])

                try ctx.save()
                return true
            } catch {
                logger.error("store failed for id=\(id): \(error)")
                return false
            }
        }
    }

    /// Returns all chat histories from all stores, sorted by most recent first.
    ///
    /// - Parameter limit: Optional maximum number of histories to return
    /// - Returns: Array of History objects sorted by lastUpdated timestamp
    func getAll(limit: Int? = nil) async -> [History] {
        let urls = Self.existingStoreURLs()
        var results: [History] = []

        // Use TaskGroup to process all URLs concurrently
        results = await withTaskGroup(of: [History].self) { group in
            for url in urls {
                let id = Self.idFromStoreURL(url)
                guard Self.storeExists(for: id) else { return [] }
                group.addTask {
                    // open container for this file's id (derived from filename)
                    guard let container = await self.container(for: id) else { return [] }
                    let ctx = container.viewContext
                    let items: [History] = await ctx.perform {
                        let req = NSFetchRequest<HistoryDocMO>(entityName: "HistoryDoc")
                        req.fetchLimit = 1
                        do {
                            guard let mo = try ctx.fetch(req).first else { return [] }
                            let obj =
                                (try? JSONSerialization.jsonObject(with: mo.json, options: []))
                                as? [[String: Any]] ?? []
                            let unseen = (mo.value(forKey: "unseen") as? Bool) ?? false
                            let hist = History(
                                id: mo.id,
                                lastUpdated: String(Int64(mo.lastUpdated)),
                                title: mo.title,
                                history: ChatItem.fromDictionaries(obj),
                                unseen: unseen
                            )
                            return [hist]
                        } catch {
                            logger.error("getAll fetch failed for id=\(id): \(error)")
                            return []
                        }
                    }
                    return items
                }
            }

            // Collect all results from the group
            for await items in group {
                results.append(contentsOf: items)
            }

            return results
        }

        results.sort { (lhs, rhs) in
            // Compare by numeric epoch descending
            (Double(lhs.lastUpdated) ?? 0) > (Double(rhs.lastUpdated) ?? 0)
        }
        if let limit, results.count > limit {
            let keep = Array(results.prefix(limit))  // newest N
            let toDelete = results.dropFirst(limit)  // the older rest
            for h in toDelete {
                _ = await delete(id: h.id)  // best-effort delete
            }
            return keep
        }
        return results
    }

    /// Fetch a single History by id.
    func get(id: String) async -> History? {
        guard Self.storeExists(for: id) else { return nil }
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
                let unseen = (mo.value(forKey: "unseen") as? Bool) ?? false
                return History(
                    id: mo.id,
                    lastUpdated: String(Int64(mo.lastUpdated)),
                    title: mo.title,
                    history: ChatItem.fromDictionaries(obj),
                    unseen: unseen
                )
            } catch {
                logger.error("get failed for id=\(id): \(error)")
                return nil
            }
        }
    }

    /// Set the unseen flag for a given history id.
    @discardableResult
    func setUnseen(id: String, unseen: Bool) async -> Bool {
        guard Self.storeExists(for: id) else { return false }
        guard let container = await container(for: id) else { return false }
        let ctx = container.newBackgroundContext()
        return await ctx.perform {
            do {
                let req = NSFetchRequest<HistoryDocMO>(entityName: "HistoryDoc")
                req.predicate = NSPredicate(format: "id == %@", id)
                req.fetchLimit = 1
                guard let mo = try ctx.fetch(req).first else { return false }
                guard mo.unseen != unseen else { return false }
                mo.unseen = unseen
                // Do NOT modify lastUpdated here; this is a view-state flag.
                try ctx.save()
                return true
            } catch {
                logger.error("setUnseen failed for id=\(id): \(error)")
                return false
            }
        }
    }

    /// Set the title for a given history id.
    @discardableResult
    func setTitle(id: String, title: String) async -> Bool {
        guard Self.storeExists(for: id) else { return false }
        guard let container = await container(for: id) else { return false }
        let ctx = container.newBackgroundContext()
        return await ctx.perform {
            do {
                let req = NSFetchRequest<HistoryDocMO>(entityName: "HistoryDoc")
                req.predicate = NSPredicate(format: "id == %@", id)
                req.fetchLimit = 1
                guard let mo = try ctx.fetch(req).first else { return false }
                guard mo.title != title else { return false }
                if title.isEmpty { return false }                
                mo.title = title
                // Do NOT modify lastUpdated here; this is a view-state flag.
                try ctx.save()
                return true
            } catch {
                logger.error("setTitle failed for id=\(id): \(error)")
                return false
            }
        }
    }

    /// Remove a single id (deletes its SQLite file).
    @discardableResult
    func delete(id: String) async -> Bool {
        logger.info("Delete history id: \(id)")
        guard let container = containers[id] else {
            // Not loaded yet, just delete files
            Self.deleteStoreFiles(for: id)
            return true
        }
        let psc = container.persistentStoreCoordinator
        if let store = psc.persistentStores.first {
            do { try psc.remove(store) } catch {
                logger.error("remove store failed: \(error)")
            }
        }
        Self.deleteStoreFiles(for: id)
        containers.removeValue(forKey: id)
        return true
    }

    private func container(for id: String) async -> NSPersistentContainer? {
        if let c = containers[id] { return c }
        let model = Self.makeModel()
        let c = NSPersistentContainer(name: "HistoryPerId", managedObjectModel: model)

        let url = Self.storeURL(for: id)
        do { try Self.ensureParentDir(url) } catch {
            logger.error("ensure dir failed: \(error)")
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
            logger.error("load store failed for id=\(id): \(String(describing: loadError))")
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

        // unseen flag with default false
        let unseen = NSAttributeDescription()
        unseen.name = "unseen"
        unseen.attributeType = .booleanAttributeType
        unseen.isOptional = false
        unseen.defaultValue = false

        entity.properties = [id, lastUpdated, title, json, unseen]
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

    private static func storeExists(for id: String) -> Bool {
        let url = storeURL(for: id)
        return FileManager.default.fileExists(atPath: url.path)
    }
}
