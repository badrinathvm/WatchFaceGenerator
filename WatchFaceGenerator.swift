#!/usr/bin/swift
// WatchFaceGenerator.swift
// Generates .watchface files from watchface-config.json — no Apple Watch needed.
//
// Usage:
//   swift WatchFaceGenerator.swift [options]
//
// Options:
//   --config <path>               Path to JSON config (default: watchface-config.json)
//   --app-bundle-id <id>          Override appBundleID from config
//   --extension-bundle-id <id>    Override extensionBundleID from config

import Foundation

// MARK: - Config Schema

struct AppConfig: Decodable {
    var appBundleID: String
    var extensionBundleID: String
    var complicationType: Int
    var widgets: [String: String]  // widgetKind → displayName
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
}

// MARK: - CLI Parsing

func parseArgs() -> (configPath: String, appBundleID: String?, extensionBundleID: String?) {
    var configPath = "watchface-config.json"
    var appBundleID: String?
    var extensionBundleID: String?

    var iter = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iter.next() {
        switch arg {
        case "--config":              configPath = iter.next() ?? configPath
        case "--app-bundle-id":       appBundleID = iter.next()
        case "--extension-bundle-id": extensionBundleID = iter.next()
        default: break
        }
    }
    return (configPath, appBundleID, extensionBundleID)
}

// MARK: - Builder

struct WatchFaceBuilder {
    let face: FaceConfig
    let config: AppConfig

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
                "app": config.appBundleID,
                "descriptor": [
                    "containerBundleIdentifier": config.appBundleID,
                    "kind": widgetKind,
                    "extensionBundleIdentifier": config.extensionBundleID
                ],
                "type": config.complicationType,
                "extension": config.appBundleID
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
            bundleIDs[key] = config.appBundleID
            names[key] = config.widgets[widgetKind] ?? widgetKind
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

        // 1×1 black PNG — placeholder until real snapshots are captured from Apple Watch
        let placeholder = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg=="
        )!
        try placeholder.write(to: tmpDir.appendingPathComponent("snapshot.png"))
        try placeholder.write(to: tmpDir.appendingPathComponent("no_borders_snapshot.png"))

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

// MARK: - Main

let (configPath, cliAppBundleID, cliExtensionBundleID) = parseArgs()

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let configURL   = URL(fileURLWithPath: configPath, relativeTo: projectRoot)

guard let configData = try? Data(contentsOf: configURL) else {
    print("❌  Config file not found: \(configURL.path)")
    print("    Run from the project root or pass --config <path>")
    exit(1)
}

var appConfig: AppConfig
do {
    appConfig = try JSONDecoder().decode(AppConfig.self, from: configData)
} catch {
    print("❌  Failed to parse config: \(error.localizedDescription)")
    exit(1)
}

// CLI overrides take precedence over JSON values
if let id = cliAppBundleID       { appConfig.appBundleID = id }
if let id = cliExtensionBundleID { appConfig.extensionBundleID = id }

let outputDir = projectRoot.appendingPathComponent("output")
print("Config → \(configURL.path)")
print("Output → \(outputDir.path)\n")

for faceConfig in appConfig.faces {
    let builder = WatchFaceBuilder(face: faceConfig, config: appConfig)
    do {
        try builder.build(outputDirectory: outputDir)
    } catch {
        print("❌  \(faceConfig.name): \(error.localizedDescription)")
    }
}

print("""

Note: snapshot.png / no_borders_snapshot.png are 1×1 placeholders.
To restore real snapshots, extract them from the originals:
  unzip -p "WatchFaces/Modular.watchface" snapshot.png > output/snapshot.png
""")
