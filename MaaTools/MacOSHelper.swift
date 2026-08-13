//
//  MacOSHelper.swift
//  MaaTools
//

import Foundation
import UIKit
import ScreenCaptureKit
import OSLog

class MacOSHelper {
    public static let shared: MacOSHelper? = MacOSHelper()

    private static let logger = Logger(subsystem: "PlayTools", category: "MaaTools")
    private static var didLogSCKFallback = false

    // Cached ScreenCaptureKit filter. Building it requires enumerating all
    // shareable content, which is relatively expensive; MAA requests a frame
    // roughly once a second, so reuse the filter while the window is unchanged
    // and refresh it periodically.
    @available(macOS 14.0, macCatalyst 18.2, *)
    private final class SCKCache {
        var filter: SCContentFilter?
        var frame = CGRect.zero
        var windowID: CGWindowID = 0
        var refreshedAt = Date.distantPast

        func resolve(for windowNumber: Int) async throws -> (SCContentFilter, CGRect) {
            let now = Date()
            let windowID = CGWindowID(windowNumber)
            if let filter, self.windowID == windowID, now.timeIntervalSince(refreshedAt) < 3 {
                return (filter, frame)
            }
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw SCKError.windowNotFound
            }
            let newFilter = SCContentFilter(desktopIndependentWindow: window)
            filter = newFilter
            frame = window.frame
            self.windowID = windowID
            refreshedAt = now
            return (newFilter, frame)
        }
    }

    // Stored as AnyObject to avoid availability annotations on stored properties.
    private var sckCache: AnyObject?

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

    var windowImage: CGImage? {
        guard let windowID = NSApplication.shared.windows.first?.windowNumber else {
            return nil
        }
        return CoreGraphics.CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(windowID), [.bestResolution, .boundsIgnoreFraming])
    }

    // Capture strategy: try the legacy CGWindowListCreateImage first (it works
    // on older macOS without needing Screen Recording permission). On macOS 27
    // beta it returns a flat dark frame for Metal content, so when the result
    // looks blank we fall back to ScreenCaptureKit, which captures the real
    // composited window content.
    @MainActor
    func captureImage() async -> CGImage? {
        // 1) Legacy path first: works on older macOS without Screen Recording.
        let legacy = windowImage
        if let legacy = legacy, !looksBlank(legacy) {
            return legacy
        }

        // 2) Legacy frame looks blank (e.g. macOS 27 beta returns a flat dark
        // frame for Metal windows): retry with ScreenCaptureKit.
        if #available(macOS 14.0, macCatalyst 18.2, *),
           let windowNumber = NSApplication.shared.windows.first?.windowNumber {
            do {
                let cache = (sckCache as? SCKCache) ?? SCKCache()
                let (filter, frame) = try await cache.resolve(for: windowNumber)
                sckCache = cache
                let config = SCStreamConfiguration()
                let scale = UIScreen.main.scale > 0 ? UIScreen.main.scale : 2
                config.width = Int(frame.width * scale)
                config.height = Int(frame.height * scale)
                config.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                logSCKFallbackOnce()
                return image
            } catch {
                Self.logger.error("ScreenCaptureKit failed, returning legacy capture: \(error, privacy: .public)")
            }
        }
        return legacy
    }

    private enum SCKError: Error {
        case windowNotFound
    }

    private func logSCKFallbackOnce() {
        guard !Self.didLogSCKFallback else { return }
        Self.didLogSCKFallback = true
        Self.logger.info("ScreenCaptureKit fallback active (legacy capture returns blank frames)")
    }

    // A blank/legacy-broken frame is nearly uniform with no bright pixels,
    // e.g. the flat dark frame CGWindowListCreateImage returns on macOS 27 beta
    // for Metal windows (everything ~44/255). Real frames have bright content.
    private func looksBlank(_ image: CGImage) -> Bool {
        let sw = 96, sh = 54
        var buf = [UInt8](repeating: 0, count: sw * sh * 4)
        guard let ctx = CGContext(data: &buf, width: sw, height: sh,
                                  bitsPerComponent: 8, bytesPerRow: sw * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return false
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: sw, height: sh))
        var maxV = 0
        var sum = 0
        for i in stride(from: 0, to: buf.count, by: 4) {
            let v = Int(max(buf[i], buf[i + 1], buf[i + 2]))
            if v > maxV { maxV = v }
            sum += v
        }
        let avg = sum / (sw * sh)
        return maxV < 80 || (avg < 60 && maxV - avg < 12)
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
