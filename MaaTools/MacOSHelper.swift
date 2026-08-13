//
//  MacOSHelper.swift
//  MaaTools
//

import Foundation
import UIKit
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
    func captureImage() async -> CGImage? {
        let legacy = windowImage
        if let legacy = legacy, !looksBlank(legacy) {
            return legacy
        }
        if #available(macOS 14.0, macCatalyst 18.2, *) {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                guard let windowNumber = NSApplication.shared.windows.first?.windowNumber,
                      let window = content.windows.first(where: { $0.windowID == CGWindowID(windowNumber) }) else {
                    return legacy
                }
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                config.width = Int(window.frame.width * 2)
                config.height = Int(window.frame.height * 2)
                config.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                print("[MaaTools] used ScreenCaptureKit fallback")
                return image
            } catch {
                print("[MaaTools] ScreenCaptureKit failed, returning legacy capture: \(error)")
            }
        }
        return legacy
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
