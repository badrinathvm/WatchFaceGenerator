#!/usr/bin/swift
// WatchFaceBuilder.swift
// Generates .watchface files from code — no Apple Watch needed.
// Run from the project root: swift Scripts/WatchFaceBuilder.swift

import Foundation

// MARK: - Constants

private let appBundleID      = "com.badarinathvm.PickleRite.watchkitapp"
private let extensionBundleID = "com.badarinathvm.PickleRite.watchkitapp.PickleRite-WidgetExtension"
private let complicationType  = 56

// MARK: - Widget Kinds

enum PickleRiteWidget: String {
    case serve             = "ServeCounterWidget"
    case lob               = "LobCounterWidget"
    case missedReturn      = "ReturnCounterWidget"
    case kitchenFault      = "KitchenFaultCounterWidget"
    case net               = "NetCounterWidget"
    case dink              = "DinkCounterWidget"
    case volley            = "VolleyCounterWidget"
    case smash             = "SmashCounterWidget"
    case slowNetTransition = "SlowNetTransitionCounterWidget"
    case submit            = "SubmitWidget"

    var displayName: String {
        switch self {
        case .serve:             return "Serve Error"
        case .lob:               return "Lob Miss"
        case .missedReturn:      return "Missed Return"
        case .kitchenFault:      return "Kitchen Fault"
        case .net:               return "Net Error"
        case .dink:              return "Dink Error"
        case .volley:            return "Volley Error"
        case .smash:             return "Smash Error"
        case .slowNetTransition: return "Slow Net Transition"
        case .submit:            return "Submit Session"
        }
    }
}

// MARK: - Face Configuration

struct FaceConfiguration {
    let name: String
    let analyticsID: String
    let faceType: String           // Apple-internal: "whistler-digital", "shark", "bundle", etc.
    let appleBundleID: String?     // Only for bundle-based faces (Chronograph, NikeCompact)
    let customization: [String: String]
    let complications: [String: PickleRiteWidget]
    let deviceSize: Int

    init(
        name: String,
        analyticsID: String,
        faceType: String,
        appleBundleID: String? = nil,
        customization: [String: String],
        complications: [String: PickleRiteWidget],
        deviceSize: Int = 8
    ) {
        self.name = name
        self.analyticsID = analyticsID
        self.faceType = faceType
        self.appleBundleID = appleBundleID
        self.customization = customization
        self.complications = complications
        self.deviceSize = deviceSize
    }
}

// MARK: - Builder

struct WatchFaceBuilder {

    let config: FaceConfiguration

    // Builds face.json — the actual watch face configuration
    func buildFaceJSON() throws -> Data {
        var root: [String: Any] = [
            "analytics id": config.analyticsID,
            "forMigration": false,
            "version": 4,
            "customization": config.customization
        ]

        if let appleBundleID = config.appleBundleID {
            root["face type"] = "bundle"
            root["bundle id"] = appleBundleID
        } else {
            root["face type"] = config.faceType
        }

        var complications: [String: Any] = [:]
        for (slot, widget) in config.complications {
            complications[slot] = [
                "app": appBundleID,
                "descriptor": [
                    "containerBundleIdentifier": appBundleID,
                    "kind": widget.rawValue,
                    "extensionBundleIdentifier": extensionBundleID
                ],
                "type": complicationType,
                "extension": appBundleID
            ]
        }
        root["complications"] = complications

        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    // Builds metadata.json — slot summary used by watchOS catalog
    func buildMetadataJSON() throws -> Data {
        // metadata uses hyphenated slot names ("bottom right" → "bottom-right")
        var bundleIDs: [String: String] = [:]
        var names: [String: String] = [:]

        for (slot, widget) in config.complications {
            let key = slot.replacingOccurrences(of: " ", with: "-")
            bundleIDs[key] = appBundleID
            names[key] = widget.displayName
        }

        let metadata: [String: Any] = [
            "device_size": config.deviceSize,
            "complications_bundle_ids": bundleIDs,
            "complications_item_ids": [String: String](),
            "complication_sample_templates": [String: String](),
            "complications_names": names,
            "version": 2
        ]

        return try JSONSerialization.data(
            withJSONObject: metadata,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    // Packs face.json + metadata.json + placeholder PNGs into a .watchface zip
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
        let outputURL = outputDirectory.appendingPathComponent("\(config.name).watchface")
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
        print("✅  \(config.name).watchface  (\(size / 1024)KB)")
    }
}

// MARK: - Pre-built Configurations
// Each entry mirrors the existing .watchface files in WatchFaces/.
// Swap widget kinds here to customise what each slot tracks.

let configurations: [FaceConfiguration] = [

    FaceConfiguration(
        name: "Modular",
        analyticsID: "whistler-digital",
        faceType: "whistler-digital",
        customization: ["color": "multicolor", "numerals": "style 1", "background": "style 1"],
        complications: [
            "top left":      .submit,
            "center":        .dink,
            "bottom left":   .net,
            "bottom center": .missedReturn,
            "bottom right":  .lob
        ]
    ),

    FaceConfiguration(
        name: "ModularCompact",
        analyticsID: "whistler-subdials",
        faceType: "whistler-subdials",
        customization: ["color": "special.multicolor", "style": "digital",
                        "numerals": "style 1", "background": "style 1"],
        complications: [
            "top":    .net,
            "center": .submit,
            "bottom": .missedReturn
        ]
    ),

    FaceConfiguration(
        name: "Infograph",
        analyticsID: "whistler-analog",
        faceType: "whistler-analog",
        customization: ["color": "white"],
        complications: [
            "top left":     .submit,
            "top right":    .lob,
            "slot 1":       .serve,
            "slot 2":       .missedReturn,
            "slot 3":       .net,
            "bezel":        .kitchenFault,
            "bottom left":  .smash,
            "bottom right": .volley
        ]
    ),

    FaceConfiguration(
        name: "Chronograph",
        analyticsID: "shark",
        faceType: "shark",
        appleBundleID: "com.apple.NTKAlaskanFaceBundle.NTKSharkFaceBundle",
        customization: ["color": "seasons.fall2025.neonYellow", "detail": "style 1"],
        complications: [
            "top left":     .submit,
            "top right":    .slowNetTransition,
            "bottom left":  .volley,
            "bottom right": .net
        ]
    ),

    FaceConfiguration(
        name: "NikeDigital",
        analyticsID: "victory-digital-r",
        faceType: "victory digital",
        customization: ["color": "green", "typeface": "style 4"],
        complications: [
            "slot 1": .dink,
            "slot 2": .slowNetTransition,
            "bottom": .submit
        ]
    ),

    FaceConfiguration(
        name: "NikeCompact",
        analyticsID: "shiba",
        faceType: "shiba",
        appleBundleID: "com.apple.NTKShibaFaceBundle",
        customization: ["color": "victory.black & victory.hyperGrape", "style": "style 3"],
        complications: [
            "top":    .submit,
            "center": .net,
            "bottom": .dink
        ]
    )
]

// MARK: - Main
// Output goes to Scripts/output/ — never overwrites the real WatchFaces/ assets.
// Copy a generated file into WatchFaces/ manually once you've verified it.

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDir   = projectRoot.appendingPathComponent("Scripts/output")

print("Output → \(outputDir.path)\n")

for config in configurations {
    let builder = WatchFaceBuilder(config: config)
    do {
        try builder.build(outputDirectory: outputDir)
    } catch {
        print("❌  \(config.name): \(error.localizedDescription)")
    }
}

print("""

Note: snapshot.png / no_borders_snapshot.png are 1×1 placeholders.
To restore real snapshots, copy them from the originals in WatchFaces/:
  unzip -p "PickleRite WatchApp Watch App/WatchFaces/Modular.watchface" snapshot.png > Scripts/output/snapshot.png
""")
