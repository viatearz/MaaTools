//
//  MaaBootstrap.swift
//  MaaTools
//

import UIKit
import OSLog

public class MaaBootstrap: NSObject {
    private static let logger = Logger(subsystem: "PlayTools", category: "MaaTools")

    @objc public static func launch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            guard let playSettingsClass = NSClassFromString("PlayTools.PlaySettings") else {
                Self.logger.error("PlayTools was not injected, skip running MaaTools.")
                return
            }

            if let playSettings = playSettingsClass.value(forKey: "shared") as? NSObject,
               playSettings.responds(to: NSSelectorFromString("maaTools")),
               playSettings.value(forKey: "maaTools") as? Bool == true {
                Self.logger.warning("You are already using PlayCover with embedded MaaTools, skip running the standalone MaaTools.")
                return
            }

            if ArknightsMetalCapture.installation == true {
                print("[MaaTools] Installed Metal capture hooks.")
            }

            if Bundle.main.bundleIdentifier == "jp.co.bandainamcoent.BNEI0421" {
                Self.logger.log("Initialize MaaTools (Gakumasu)...")
                MaaTools_Gakumasu.shared.initialize()
            } else {
                Self.logger.log("Initialize MaaTools...")
                MaaTools.shared.initialize()
            }
        }
    }
}
