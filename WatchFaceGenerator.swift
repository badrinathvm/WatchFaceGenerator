#!/usr/bin/swift
// WatchFaceGenerator.swift
// Generates .watchface files by combining an app identity config and a face catalog.
//
// Usage:
//   swift WatchFaceGenerator.swift [options]
//
// Options:
//   --init                        Interactive setup wizard — generates app.json and faces.json
//   --app <path>                  Path to app identity JSON (default: app.json)
//   --faces <path>                Path to face catalog JSON (default: faces.json)
//   --app-bundle-id <id>          Override bundleID from app.json
//   --extension-bundle-id <id>    Override extensionBundleID from app.json
//   --widget <kind> <displayName> Add a widget inline (repeatable)
//   --face <name> "slot=kind,..."  Assign widgets to a face template inline (repeatable)

import Foundation

// MARK: - ANSI / Box UI

private enum C {
    static let reset   = "\u{001B}[0m"
    static let bold    = "\u{001B}[1m"
    static let cyan    = "\u{001B}[36m"
    static let blue    = "\u{001B}[34m"
    static let yellow  = "\u{001B}[33m"
    static let green   = "\u{001B}[32m"
    static let red     = "\u{001B}[31m"
    static let magenta = "\u{001B}[35m"
    static let white   = "\u{001B}[97m"
    static let bCyan   = "\u{001B}[96m"
    static let bBlue   = "\u{001B}[94m"
    static let bYellow = "\u{001B}[93m"
    static let bGreen  = "\u{001B}[92m"
    static let bRed    = "\u{001B}[91m"
}

private let boxWidth = 54

private func pad(_ text: String, to width: Int) -> String {
    let visible = text.replacingOccurrences(of: "\u{001B}[^m]*m", with: "", options: .regularExpression)
    let spaces = max(0, width - visible.count)
    return text + String(repeating: " ", count: spaces)
}

// ╔══ Double-line header box ══╗
func headerBox(_ title: String, color: String = C.bCyan) {
    let inner  = boxWidth - 2
    let bar    = String(repeating: "═", count: inner)
    let padded = pad(" \(C.bold)\(title)\(C.reset)\(color)", to: inner)
    print("\n\(color)╔\(bar)╗\(C.reset)")
    print("\(color)║\(C.reset)\(padded)\(color)║\(C.reset)")
    print("\(color)╚\(bar)╝\(C.reset)")
}

// ┌── Single-line question box ──┐
func questionBox(_ title: String, subtitle: String? = nil, color: String = C.bBlue) {
    let inner  = boxWidth - 2
    let bar    = String(repeating: "─", count: inner)
    let padded = pad(" \(C.bold)\(title)\(C.reset)\(color)", to: inner)
    print("\n\(color)┌\(bar)┐\(C.reset)")
    print("\(color)│\(C.reset)\(padded)\(color)│\(C.reset)")
    if let sub = subtitle {
        let subPadded = pad(" \(C.reset)\(sub)\(color)", to: inner)
        print("\(color)│\(C.reset)\(subPadded)\(color)│\(C.reset)")
    }
    print("\(color)└\(bar)┘\(C.reset)")
}

func successBox(_ message: String) {
    let inner  = boxWidth - 2
    let bar    = String(repeating: "─", count: inner)
    let padded = pad(" \(C.bold)\(C.bGreen)✅  \(message)\(C.reset)\(C.green)", to: inner)
    print("\(C.green)┌\(bar)┐\(C.reset)")
    print("\(C.green)│\(C.reset)\(padded)\(C.green)│\(C.reset)")
    print("\(C.green)└\(bar)┘\(C.reset)")
}

func errorBox(_ message: String) {
    print("\(C.bRed)  ✖  \(message)\(C.reset)")
}

func inputPrompt() -> String {
    print("\(C.bold)\(C.white)  ▶  \(C.reset)", terminator: "")
    return readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
}


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

// MARK: - Face Type Catalog (built-in templates)

struct FaceTemplate {
    let name: String
    let analyticsID: String
    let faceType: String
    let appleBundleID: String?
    let customization: [String: String]
    let slots: [String]
}

let knownFaceTemplates: [FaceTemplate] = [
    FaceTemplate(
        name: "Modular", analyticsID: "whistler-digital", faceType: "whistler-digital",
        appleBundleID: nil,
        customization: ["color": "multicolor", "numerals": "style 1", "background": "style 1"],
        slots: ["top left", "center", "bottom left", "bottom center", "bottom right"]
    ),
    FaceTemplate(
        name: "ModularCompact", analyticsID: "whistler-subdials", faceType: "whistler-subdials",
        appleBundleID: nil,
        customization: ["color": "special.multicolor", "style": "digital", "numerals": "style 1", "background": "style 1"],
        slots: ["top", "center", "bottom"]
    ),
    FaceTemplate(
        name: "Infograph", analyticsID: "whistler-analog", faceType: "whistler-analog",
        appleBundleID: nil,
        customization: ["color": "white"],
        slots: ["top left", "top right", "slot 1", "slot 2", "slot 3", "bezel", "bottom left", "bottom right"]
    ),
    FaceTemplate(
        name: "Chronograph", analyticsID: "shark", faceType: "shark",
        appleBundleID: "com.apple.NTKAlaskanFaceBundle.NTKSharkFaceBundle",
        customization: ["color": "seasons.fall2025.neonYellow", "detail": "style 1"],
        slots: ["top left", "top right", "bottom left", "bottom right"]
    ),
    FaceTemplate(
        name: "NikeDigital", analyticsID: "victory-digital-r", faceType: "victory digital",
        appleBundleID: nil,
        customization: ["color": "green", "typeface": "style 4"],
        slots: ["slot 1", "slot 2", "bottom"]
    ),
    FaceTemplate(
        name: "NikeCompact", analyticsID: "shiba", faceType: "shiba",
        appleBundleID: "com.apple.NTKShibaFaceBundle",
        customization: ["color": "victory.black & victory.hyperGrape", "style": "style 3"],
        slots: ["top", "center", "bottom"]
    ),
    FaceTemplate(
        name: "Meridian", analyticsID: "blackcomb", faceType: "blackcomb",
        appleBundleID: nil,
        customization: ["color": "Pistachio", "style": "style 1"],
        slots: ["subdial top", "subdial right", "subdial bottom", "subdial left"]
    ),
    FaceTemplate(
        name: "ModularDuo", analyticsID: "cloudraker", faceType: "cloudraker",
        appleBundleID: "com.apple.NTKCloudrakerFaceBundle",
        customization: ["color": "special.multicolor", "numerals": "style 1"],
        slots: ["top left", "center", "bottom"]
    ),
]

// MARK: - CLI Parsing

struct CLIArgs {
    var runInit: Bool = false
    var appPath: String = "app.json"
    var facesPath: String = "faces.json"
    var bundleID: String? = nil
    var extensionBundleID: String? = nil
    var widgets: [String: String] = [:]
    var faceAssignments: [(String, String)] = []
}

func parseArgs() -> CLIArgs {
    var args = CLIArgs()
    var iter = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iter.next() {
        switch arg {
        case "--init":                args.runInit = true
        case "--app":                 args.appPath = iter.next() ?? args.appPath
        case "--faces":               args.facesPath = iter.next() ?? args.facesPath
        case "--app-bundle-id":       args.bundleID = iter.next()
        case "--extension-bundle-id": args.extensionBundleID = iter.next()
        case "--widget":
            if let kind = iter.next(), let displayName = iter.next() {
                args.widgets[kind] = displayName
            }
        case "--face":
            if let name = iter.next(), let assignments = iter.next() {
                args.faceAssignments.append((name, assignments))
            }
        default: break
        }
    }
    return args
}

// Builds AppIdentity + FacesCatalog purely from CLI flags (no files needed)
func buildConfigFromFlags(_ args: CLIArgs) -> (AppIdentity, FacesCatalog)? {
    guard (!args.widgets.isEmpty || !args.faceAssignments.isEmpty),
          let bundleID = args.bundleID,
          let extensionBundleID = args.extensionBundleID else { return nil }

    let app = AppIdentity(bundleID: bundleID, extensionBundleID: extensionBundleID,
                          complicationType: 56, widgets: args.widgets)
    var faces: [FaceConfig] = []
    for (templateName, assignmentsStr) in args.faceAssignments {
        guard let template = knownFaceTemplates.first(where: { $0.name.lowercased() == templateName.lowercased() }) else {
            print("\(C.bYellow)  ⚠  Unknown face '\(templateName)' — known: \(knownFaceTemplates.map(\.name).joined(separator: ", "))\(C.reset)")
            continue
        }
        var complications: [String: String] = [:]
        for pair in assignmentsStr.split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                complications[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        faces.append(FaceConfig(name: template.name, analyticsID: template.analyticsID,
                                faceType: template.faceType, appleBundleID: template.appleBundleID,
                                customization: template.customization, complications: complications,
                                deviceSize: nil, snapshotPath: nil, noBordersSnapshotPath: nil))
    }
    return (app, FacesCatalog(faces: faces))
}

// MARK: - Interactive Setup Wizard

@discardableResult
func runSetup(appPath: String, facesPath: String, projectRoot: URL, writeFiles: Bool) -> (AppIdentity, FacesCatalog) {

    headerBox("WATCHFACE GENERATOR SETUP")

    // ── 1. Bundle ID ──────────────────────────────────────────────────────────
    questionBox("What is the App Bundle ID?",
                subtitle: "e.g.  com.example.myapp.watchkitapp",
                color: C.bBlue)
    let bundleID = inputPrompt()

    // ── 2. Extension Bundle ID ────────────────────────────────────────────────
    let defaultExt = bundleID.isEmpty ? "com.example.myapp.watchkitapp.WidgetExtension"
                                      : "\(bundleID).WidgetExtension"
    questionBox("What is the Extension Bundle ID?",
                subtitle: "e.g.  \(defaultExt)",
                color: C.bBlue)
    let extInput = inputPrompt()
    let extensionBundleID = extInput.isEmpty ? defaultExt : extInput

    // ── 3. Widget Catalog ─────────────────────────────────────────────────────
    headerBox("WIDGET CATALOG", color: C.bYellow)
    print("\n\(C.yellow)  Add each WidgetKit widget kind and its display name.")
    print("  Leave the widget kind empty when you're done.\(C.reset)")

    var widgets: [String: String] = [:]
    var widgetIndex = 1

    while true {
        questionBox("Widget \(widgetIndex) — Kind",
                    subtitle: "The identifier defined in your WidgetKit extension  (empty to finish)",
                    color: C.yellow)
        let kind = inputPrompt()
        if kind.isEmpty { break }

        questionBox("Widget \(widgetIndex) — Display Name",
                    subtitle: "Human-readable name shown in the watch face catalog",
                    color: C.yellow)
        let nameInput = inputPrompt()
        let displayName = nameInput.isEmpty ? kind : nameInput
        widgets[kind] = displayName
        widgetIndex += 1

        print("\n\(C.bGreen)  ✓  \(kind) → \(displayName)\(C.reset)")
    }

    if widgets.isEmpty {
        print("\n\(C.bYellow)  ⚠  No widgets defined — complication slots will be empty in faces.json.\(C.reset)")
    } else {
        print("\n\(C.bGreen)  \(widgets.count) widget(s) registered.\(C.reset)")
    }

    // ── 4. Face Configuration ─────────────────────────────────────────────────
    headerBox("FACE CONFIGURATION", color: C.magenta)
    let widgetKinds = widgets.keys.sorted()
    print("\n\(C.magenta)  Assign widgets to slots for each face type.")
    if !widgetKinds.isEmpty {
        print("  Available kinds: \(C.bold)\(widgetKinds.joined(separator: "  "))\(C.reset)\(C.magenta)")
    }
    print("  \(C.bold)[R]\(C.reset)\(C.magenta)andom  \(C.bold)[S]\(C.reset)\(C.magenta)pecific  \(C.bold)[N]\(C.reset)\(C.magenta) skip\(C.reset)")

    var faceDicts: [[String: Any]] = []

    for template in knownFaceTemplates {
        questionBox("\(template.name)  (\(template.faceType))",
                    subtitle: "Slots: \(template.slots.joined(separator: "  ·  "))",
                    color: C.magenta)
        print("\(C.magenta)  \(C.bold)[R]\(C.reset)\(C.magenta)andom  \(C.bold)[S]\(C.reset)\(C.magenta)pecific  \(C.bold)[N]\(C.reset)\(C.magenta)skip\(C.reset)  ", terminator: "")
        let choice = (readLine()?.trimmingCharacters(in: .whitespaces) ?? "").lowercased()

        if choice == "n" { continue }

        var complications: [String: String] = [:]

        if choice == "r" {
            // Random — shuffle widgets and assign across slots, cycling if needed
            guard !widgetKinds.isEmpty else {
                print("\(C.bYellow)  ⚠  No widgets to assign — skipping \(template.name)\(C.reset)")
                continue
            }
            let shuffled = widgetKinds.shuffled()
            for (i, slot) in template.slots.enumerated() {
                complications[slot] = shuffled[i % shuffled.count]
            }
            print("")
            for (slot, kind) in complications.sorted(by: { $0.key < $1.key }) {
                print("  \(C.cyan)\(slot)\(C.reset)  →  \(C.bold)\(kind)\(C.reset)")
            }
        } else {
            // Specific — ask per slot
            print("\n\(C.magenta)  Enter a widget kind for each slot, or leave empty to omit.\(C.reset)")
            for slot in template.slots {
                print("\n\(C.bold)\(C.white)    \(slot)\(C.reset)")
                print("\(C.bold)\(C.white)  ▶  \(C.reset)", terminator: "")
                let kind = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
                if !kind.isEmpty { complications[slot] = kind }
            }
        }

        if complications.isEmpty {
            print("\n\(C.yellow)  (no slots assigned — skipping \(template.name))\(C.reset)")
            continue
        }

        var face: [String: Any] = [
            "name": template.name,
            "analyticsID": template.analyticsID,
            "faceType": template.faceType,
            "customization": template.customization,
            "complications": complications
        ]
        if let appleBundleID = template.appleBundleID { face["appleBundleID"] = appleBundleID }
        faceDicts.append(face)
        print("\n\(C.bGreen)  ✓  \(template.name) — \(complications.count) slot(s) configured\(C.reset)")
    }

    // ── Build result ──────────────────────────────────────────────────────────
    let appIdentity = AppIdentity(bundleID: bundleID, extensionBundleID: extensionBundleID,
                                  complicationType: 56, widgets: widgets)
    let facesCatalog = FacesCatalog(faces: faceDicts.compactMap { dict -> FaceConfig? in
        guard let name         = dict["name"]        as? String,
              let analyticsID  = dict["analyticsID"] as? String,
              let faceType     = dict["faceType"]    as? String,
              let customization = dict["customization"] as? [String: String],
              let complications = dict["complications"] as? [String: String]
        else { return nil }
        return FaceConfig(name: name, analyticsID: analyticsID, faceType: faceType,
                          appleBundleID: dict["appleBundleID"] as? String,
                          customization: customization, complications: complications,
                          deviceSize: nil, snapshotPath: nil, noBordersSnapshotPath: nil)
    })

    // ── Optionally write files (--init mode) ──────────────────────────────────
    if writeFiles {
        headerBox("WRITING CONFIG FILES", color: C.bCyan)
        print("")
        let appDict: [String: Any] = [
            "bundleID": bundleID,
            "extensionBundleID": extensionBundleID,
            "complicationType": 56,
            "widgets": widgets
        ]
        let appURL   = URL(fileURLWithPath: appPath,  relativeTo: projectRoot)
        let facesURL = URL(fileURLWithPath: facesPath, relativeTo: projectRoot)
        do {
            let data = try JSONSerialization.data(withJSONObject: appDict, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: appURL)
            successBox("\(appURL.lastPathComponent)  written → \(appURL.path)")
        } catch { errorBox("Failed to write \(appURL.lastPathComponent): \(error.localizedDescription)") }
        do {
            let data = try JSONSerialization.data(withJSONObject: ["faces": faceDicts], options: [.prettyPrinted, .sortedKeys])
            try data.write(to: facesURL)
            successBox("\(facesURL.lastPathComponent)  written → \(facesURL.path)")
        } catch { errorBox("Failed to write \(facesURL.lastPathComponent): \(error.localizedDescription)") }
        print("\n\(C.bold)  Run the generator:\(C.reset)")
        print("  \(C.bCyan)swift WatchFaceGenerator.swift\(C.reset)\n")
    }

    return (appIdentity, facesCatalog)
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
            print("\(C.bYellow)  ⚠  Snapshot override not found: \(url.path)\(C.reset)")
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
        print("  \(C.bGreen)✅  \(face.name).watchface  (\(size / 1024)KB)\(C.reset)")
    }
}

// MARK: - Helpers

func load<T: Decodable>(_ type: T.Type, from path: String, relativeTo root: URL) -> T {
    let url = URL(fileURLWithPath: path, relativeTo: root)
    guard let data = try? Data(contentsOf: url) else {
        errorBox("File not found: \(url.path)")
        exit(1)
    }
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        errorBox("Failed to parse \(url.lastPathComponent): \(error.localizedDescription)")
        exit(1)
    }
}

// MARK: - Main

let cliArgs     = parseArgs()
let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

// --init: wizard → write files → exit (no generation)
if cliArgs.runInit {
    runSetup(appPath: cliArgs.appPath, facesPath: cliArgs.facesPath,
             projectRoot: projectRoot, writeFiles: true)
    exit(0)
}

var app: AppIdentity
var catalog: FacesCatalog
var sourceLabel: (String, String)

let usingInlineFlags = buildConfigFromFlags(cliArgs) != nil
let usingExplicitFiles = CommandLine.arguments.contains("--app") || CommandLine.arguments.contains("--faces")

if let (cliApp, cliCatalog) = buildConfigFromFlags(cliArgs) {
    // Inline flag mode: --widget / --face passed directly
    app         = cliApp
    catalog     = cliCatalog
    sourceLabel = ("(flags)", "(flags)")
} else if usingExplicitFiles {
    // Explicit file mode: --app / --faces passed — read files, skip wizard
    app     = load(AppIdentity.self,  from: cliArgs.appPath,  relativeTo: projectRoot)
    catalog = load(FacesCatalog.self, from: cliArgs.facesPath, relativeTo: projectRoot)
    if let id = cliArgs.bundleID          { app.bundleID = id }
    if let id = cliArgs.extensionBundleID { app.extensionBundleID = id }
    sourceLabel = (URL(fileURLWithPath: cliArgs.appPath,  relativeTo: projectRoot).path,
                   URL(fileURLWithPath: cliArgs.facesPath, relativeTo: projectRoot).path)
} else {
    // Default: always run wizard → generate immediately (no files read or written)
    let (wizardApp, wizardCatalog) = runSetup(
        appPath: cliArgs.appPath, facesPath: cliArgs.facesPath,
        projectRoot: projectRoot, writeFiles: false
    )
    app         = wizardApp
    catalog     = wizardCatalog
    sourceLabel = ("(wizard)", "(wizard)")
}

let outputDir = projectRoot.appendingPathComponent("output")
print("\(C.cyan)  App    → \(sourceLabel.0)\(C.reset)")
print("\(C.cyan)  Faces  → \(sourceLabel.1)\(C.reset)")
print("\(C.cyan)  Output → \(outputDir.path)\(C.reset)\n")

for faceConfig in catalog.faces {
    let builder = WatchFaceBuilder(face: faceConfig, app: app, projectRoot: projectRoot)
    do {
        try builder.build(outputDirectory: outputDir)
    } catch {
        errorBox("\(faceConfig.name): \(error.localizedDescription)")
    }
}

print("\n\(C.yellow)  Note: snapshots default to a 1×1 placeholder when no matching")
print("  file exists in snapshots/. See snapshots/README.md for details.\(C.reset)\n")
