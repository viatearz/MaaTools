//
//  MacOSHelper.swift
//  MaaTools
//

import Foundation
import UIKit

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
