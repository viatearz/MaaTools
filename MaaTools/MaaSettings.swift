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
}

class MaaSettingsData : Codable {
    var enabled = 0
    var port = 1717
    var debug = 0
}

typealias PlaySettings = MaaSettings
