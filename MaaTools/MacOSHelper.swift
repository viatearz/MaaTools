//
//  MacOSHelper.swift
//  MaaTools
//

import Foundation
import UIKit
import OSLog
import ScreenCaptureKit

class MacOSHelper {
    public static let shared: MacOSHelper? = MacOSHelper()

    var windowTitle: String? {
        get {
            NSApplication.shared.windows.first?.title
        }
        set {
            if let newValue {
                DispatchQueue.main.async {
                    NSApplication.shared.windows.first?.title = newValue
                }
            }
        }
    }

    private let logger = Logger(subsystem: "PlayTools", category: "MaaTools")

    @MainActor private var windowID: CGWindowID? {
        guard let windowNumber = NSApplication.shared.windows.first?.windowNumber else {
            logger.error("Cannot find any window of the app")
            return nil
        }
        return CGWindowID(windowNumber)
    }

    @available(macCatalyst, deprecated: 18.2, renamed: "windowImage()")
    @MainActor private var windowImage: CGImage? {
        guard let windowID else {
            return nil
        }
        return CoreGraphics.CGWindowListCreateImage(.null, .optionIncludingWindow, windowID,
                                                    [.bestResolution, .boundsIgnoreFraming, .shouldBeOpaque])
    }

    @available(macCatalyst 18.2, *)
    @MainActor private func captureImage(_ windowID: CGWindowID) async throws -> CGImage? {
        let content = try await SCShareableContent.currentProcess
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            logger.error("Cannot find the shareable content of the window")
            return nil
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let info = SCShareableContent.info(for: filter)
        let config = SCStreamConfiguration()
        let scale = CGFloat(info.pointPixelScale)
        config.width = max(1, Int(ceil(info.contentRect.width * scale)))
        config.height = max(1, Int(ceil(info.contentRect.height * scale)))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false
        config.shouldBeOpaque = true
        config.ignoreShadowsSingleWindow = true
        config.ignoreGlobalClipSingleWindow = true
        config.captureResolution = .best
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    @MainActor func windowImage() async -> CGImage? {
        if #available(macCatalyst 18.2, *) {
            do {
                guard let windowID else { return nil }
                return try await captureImage(windowID)
            } catch {
                logger.error("ScreenCaptureKit current-process capture failed: \(error)")
                return nil
            }
        } else {
            return windowImage
        }
    }

    var windowContentRect: CGRect {
        guard let window = NSApplication.shared.windows.first else {
            return CGRect()
        }
        return window.contentRect(forFrameRect: window.frame)
    }

    var windowFrame: CGRect {
         return NSApplication.shared.windows.first?.frame ?? CGRect()
    }

    func terminateApplication() {
        NSApplication.shared.terminate(self)
    }
}

typealias AKInterface = MacOSHelper
