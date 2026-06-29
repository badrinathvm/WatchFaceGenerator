#!/usr/bin/swift
// WatchFaceGenerator.swift
// Generates .watchface files by combining an app identity config and a face catalog.
//
// Usage:
//   swift WatchFaceGenerator.swift [options]
//
// Options:
//   --app <path>                  Path to app identity JSON (default: app.json)
//   --faces <path>                Path to face catalog JSON (default: faces.json)
//   --app-bundle-id <id>          Override bundleID from app.json
//   --extension-bundle-id <id>    Override extensionBundleID from app.json

import Foundation

// MARK: - Schema

struct AppIdentity: Decodable {
    var bundleID: String
    var extensionBundleID: String
    var complicationType: Int
    var widgets: [String: String]  // widgetKind → displayName
}

struct FacesCatalog: Decodable {
    var faces: [FaceConfig]
}

struct FaceConfig: Decodable {
    let name: String
    let analyticsID: String
    let faceType: String
    let appleBundleID: String?
    let customization: [String: String]
    let complications: [String: String]  // slot → widgetKind
    let deviceSize: Int?
    let snapshotPath: String?            // optional override; auto-resolved from faceType if absent
    let noBordersSnapshotPath: String?   // optional override; falls back to snapshotPath resolution
}

// MARK: - CLI Parsing

func parseArgs() -> (appPath: String, facesPath: String, bundleID: String?, extensionBundleID: String?) {
    var appPath = "app.json"
    var facesPath = "faces.json"
    var bundleID: String?
    var extensionBundleID: String?

    var iter = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iter.next() {
        switch arg {
        case "--app":                 appPath = iter.next() ?? appPath
        case "--faces":               facesPath = iter.next() ?? facesPath
        case "--app-bundle-id":       bundleID = iter.next()
        case "--extension-bundle-id": extensionBundleID = iter.next()
        default: break
        }
    }
    return (appPath, facesPath, bundleID, extensionBundleID)
}

// MARK: - Builder

struct WatchFaceBuilder {
    let face: FaceConfig
    let app: AppIdentity
    let projectRoot: URL

    private var faceTypeSlug: String {
        face.faceType.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    private func resolvedSnapshot(override path: String?, suffix: String) -> Data? {
        if let path {
            let url = URL(fileURLWithPath: path, relativeTo: projectRoot)
            if let data = try? Data(contentsOf: url) { return data }
            print("⚠️  Snapshot override not found: \(url.path)")
        }
        let autoURL = projectRoot
            .appendingPathComponent("snapshots")
            .appendingPathComponent("\(faceTypeSlug)\(suffix).png")
        return try? Data(contentsOf: autoURL)
    }

    func buildFaceJSON() throws -> Data {
        var root: [String: Any] = [
            "analytics id": face.analyticsID,
            "forMigration": false,
            "version": 4,
            "customization": face.customization
        ]

        if let bundleID = face.appleBundleID {
            root["face type"] = "bundle"
            root["bundle id"] = bundleID
        } else {
            root["face type"] = face.faceType
        }

        var complications: [String: Any] = [:]
        for (slot, widgetKind) in face.complications {
            complications[slot] = [
                "app": app.bundleID,
                "descriptor": [
                    "containerBundleIdentifier": app.bundleID,
                    "kind": widgetKind,
                    "extensionBundleIdentifier": app.extensionBundleID
                ],
                "type": app.complicationType,
                "extension": app.bundleID
            ]
        }
        root["complications"] = complications

        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    func buildMetadataJSON() throws -> Data {
        // metadata uses hyphenated slot names ("bottom right" → "bottom-right")
        var bundleIDs: [String: String] = [:]
        var names: [String: String] = [:]

        for (slot, widgetKind) in face.complications {
            let key = slot.replacingOccurrences(of: " ", with: "-")
            bundleIDs[key] = app.bundleID
            names[key] = app.widgets[widgetKind] ?? widgetKind
        }

        let metadata: [String: Any] = [
            "device_size": face.deviceSize ?? 8,
            "complications_bundle_ids": bundleIDs,
            "complications_item_ids": [String: String](),
            "complication_sample_templates": [String: String](),
            "complications_names": names,
            "version": 2
        ]

        return try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    }

    func build(outputDirectory: URL) throws {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        try buildFaceJSON().write(to: tmpDir.appendingPathComponent("face.json"))
        try buildMetadataJSON().write(to: tmpDir.appendingPathComponent("metadata.json"))

        let placeholder = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg=="
        )!
        let snapshotData  = resolvedSnapshot(override: face.snapshotPath, suffix: "") ?? placeholder
        let noBordersData = resolvedSnapshot(override: face.noBordersSnapshotPath, suffix: "-no-borders") ?? snapshotData
        try snapshotData.write(to: tmpDir.appendingPathComponent("snapshot.png"))
        try noBordersData.write(to: tmpDir.appendingPathComponent("no_borders_snapshot.png"))

        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let outputURL = outputDirectory.appendingPathComponent("\(face.name).watchface")
        try? fm.removeItem(at: outputURL)

        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.arguments = [
            "-j", outputURL.path,
            tmpDir.appendingPathComponent("face.json").path,
            tmpDir.appendingPathComponent("metadata.json").path,
            tmpDir.appendingPathComponent("snapshot.png").path,
            tmpDir.appendingPathComponent("no_borders_snapshot.png").path
        ]
        try zip.run()
        zip.waitUntilExit()

        let size = (try? fm.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
        print("✅  \(face.name).watchface  (\(size / 1024)KB)")
    }
}

// MARK: - Helpers

func load<T: Decodable>(_ type: T.Type, from path: String, relativeTo root: URL) -> T {
    let url = URL(fileURLWithPath: path, relativeTo: root)
    guard let data = try? Data(contentsOf: url) else {
        print("❌  File not found: \(url.path)")
        exit(1)
    }
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        print("❌  Failed to parse \(url.lastPathComponent): \(error.localizedDescription)")
        exit(1)
    }
}

// MARK: - Main

let (appPath, facesPath, cliBundleID, cliExtensionBundleID) = parseArgs()

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

var app     = load(AppIdentity.self, from: appPath, relativeTo: projectRoot)
let catalog = load(FacesCatalog.self, from: facesPath, relativeTo: projectRoot)

// CLI overrides take precedence over app.json values
if let id = cliBundleID          { app.bundleID = id }
if let id = cliExtensionBundleID { app.extensionBundleID = id }

let outputDir = projectRoot.appendingPathComponent("output")
print("App    → \(URL(fileURLWithPath: appPath, relativeTo: projectRoot).path)")
print("Faces  → \(URL(fileURLWithPath: facesPath, relativeTo: projectRoot).path)")
print("Output → \(outputDir.path)\n")

for faceConfig in catalog.faces {
    let builder = WatchFaceBuilder(face: faceConfig, app: app, projectRoot: projectRoot)
    do {
        try builder.build(outputDirectory: outputDir)
    } catch {
        print("❌  \(faceConfig.name): \(error.localizedDescription)")
    }
}

print("""

Note: snapshot.png / no_borders_snapshot.png default to a 1×1 placeholder
when no matching file exists in snapshots/. See snapshots/README.md for details.
""")
