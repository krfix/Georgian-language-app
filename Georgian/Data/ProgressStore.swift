import Foundation
import os
import SwiftData

/// Opens the file the learner's progress is saved in, upgrading it from older versions
/// (`GeorgianMigrationPlan`), and, when it can't be opened at all, puts it aside safely so the
/// app can start again without destroying it. Used by the app and by tools/StoreTests (which
/// opens stores written by older versions on the Mac), so it must not use SwiftUI or UIKit.
enum ProgressStore {
    /// The newest schema: the one the app's models (the typealiases in Models.swift) belong to.
    static let currentSchema: any VersionedSchema.Type = GeorgianSchemaV2.self

    static let log = Logger(subsystem: "com.aralearn.ge", category: "progress")

    /// Where progress is kept on the phone.
    static var defaultURL: URL { URL.applicationSupportDirectory.appending(path: "Georgian.store") }

    /// The opened store, and whether the planned upgrade had to be skipped (SwiftData worked
    /// the change out by itself). The tests require `usedFallback == false`.
    struct Opened {
        let container: ModelContainer
        let usedFallback: Bool
    }

    /// Opens the store at `url` (`nil`: in memory only, for UI tests).
    static func open(at url: URL?) throws -> Opened {
        let schema = Schema(versionedSchema: currentSchema)
        let config: ModelConfiguration
        if let url {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            config = ModelConfiguration(schema: schema, url: url)
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        do {
            let container = try ModelContainer(for: schema, migrationPlan: GeorgianMigrationPlan.self, configurations: config)
            return Opened(container: container, usedFallback: false)
        } catch let planned {
            log.error("Opening progress with the migration plan failed: \(String(describing: planned), privacy: .public)")
            // Second try: let SwiftData infer the change itself (adding a model or a property
            // with a default is something it can work out). If that fails too, report the
            // first error: it says more about what went wrong.
            do {
                let container = try ModelContainer(for: schema, configurations: config)
                return Opened(container: container, usedFallback: true)
            } catch {
                log.error("Opening progress without the plan failed too: \(String(describing: error), privacy: .public)")
                throw planned
            }
        }
    }

    /// The store's file and SQLite's two companions.
    static func files(of url: URL) -> [URL] {
        ["", "-shm", "-wal"].map { URL(fileURLWithPath: url.path + $0) }
    }

    /// Deletes the store (the `-resetData` launch option only).
    static func delete(at url: URL) {
        for f in files(of: url) { try? FileManager.default.removeItem(at: f) }
    }

    /// Moves a store that can't be opened into "Progress kept aside/<date and time>/" next to
    /// it, so the app can start with a fresh one. Nothing is deleted: a later version can
    /// bring the old progress back. Returns the folder it went to.
    @discardableResult
    static func setAside(_ url: URL, now: Date = Date()) throws -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let stamp = f.string(from: now)
        let folder = url.deletingLastPathComponent()
            .appending(path: "Progress kept aside", directoryHint: .isDirectory)
            .appending(path: stamp, directoryHint: .isDirectory)
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for f in files(of: url) where fm.fileExists(atPath: f.path) {
            try fm.moveItem(at: f, to: folder.appending(path: f.lastPathComponent))
        }
        log.notice("Progress that could not be opened was kept aside in \(folder.path, privacy: .public)")
        return folder
    }
}
