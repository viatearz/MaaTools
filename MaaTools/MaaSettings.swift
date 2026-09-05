//
//  MaaSettings.swift
//  MaaTools
//

import Foundation

class MaaSettings {
    public static let shared = MaaSettings()

    let bundleIdentifier = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
    let settingsUrl: URL
    var settingsData: MaaSettingsData

    init() {
        settingsUrl = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(bundleIdentifier).maa.json")
        do {
            let data = try Data(contentsOf: settingsUrl)
            settingsData = try JSONDecoder().decode(MaaSettingsData.self, from: data)
        } catch {
            settingsData = MaaSettingsData()
            print("[MaaTools] MaaSettings decode failed.")
        }
    }

    lazy var maaTools = settingsData.enabled != 0

    lazy var maaToolsPort = settingsData.port

    lazy var debug = settingsData.debug != 0

    lazy var enableMetalCapture = settingsData.enableMetalCapture != 0
}

struct MaaSettingsData : Codable {
    var enabled = 0
    var port = 1717
    var debug = 0
    var enableMetalCapture = 0

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Int.self, forKey: .enabled)
        port = try container.decode(Int.self, forKey: .port)
        debug = try container.decodeIfPresent(Int.self, forKey: .debug) ?? 0
        enableMetalCapture = try container.decodeIfPresent(Int.self, forKey: .enableMetalCapture) ?? 0
    }
}

typealias PlaySettings = MaaSettings
