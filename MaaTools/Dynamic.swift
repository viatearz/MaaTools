//
//  Dynamic.swift
//  MaaTools
//

import Foundation
import UIKit

class NSApplication {
    static let shared: NSApplication = {
        let obj = NSClassFromString("NSApplication")?.value(forKey: "sharedApplication") as? AnyObject
        return NSApplication(obj!)
    }()

    private var obj: AnyObject
    
    private init(_ obj: AnyObject) {
        self.obj = obj
    }

    var windows: [NSWindow] {
        var result: [NSWindow] = []
        if let windowObjs = obj.value(forKey: "windows") as? [AnyObject] {
            for windowObj in windowObjs {
                result.append(NSWindow(windowObj))
            }
        }
        return result
    }

    func terminate(_ sender: AnyObject?) {
        typealias TerminateMethod = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let selector = NSSelectorFromString("terminate:")
        let methodIMP = obj.method(for: selector)
        let method = unsafeBitCast(methodIMP, to: TerminateMethod.self)
        method(obj, selector, sender)
    }
}

class NSWindow {
    typealias ContentRectMethod = @convention(c) (AnyObject, Selector, CGRect) -> CGRect
    private static var initialized = false
    private static var contentRectSelector: Selector?
    private static var contentRectMethod: ContentRectMethod?

    private static func initialize() {
        let nsWindowClass: AnyClass? = NSClassFromString("NSWindow")

        contentRectSelector = NSSelectorFromString("contentRectForFrameRect:")

        if let methodIMP = nsWindowClass?.method(for: contentRectSelector) {
            contentRectMethod = unsafeBitCast(methodIMP, to: ContentRectMethod.self)
        }
    }

    private var obj: AnyObject

    init(_ obj: AnyObject) {
        self.obj = obj
    }

    var title: String {
        get {
            return obj.value(forKey: "title") as? String ?? ""
        }
        set {
            obj.setValue(newValue, forKey: "title")
        }
    }

    var windowNumber: Int {
        return obj.value(forKey: "windowNumber") as? Int ?? 0
    }

    var frame: CGRect {
        return obj.value(forKey: "frame") as? CGRect ?? .zero
    }

    func contentRect(forFrameRect frameRect: CGRect) -> CGRect {
        if !Self.initialized {
            Self.initialize()
            Self.initialized = true
        }

        guard let method = Self.contentRectMethod,
              let selector = Self.contentRectSelector else {
            return .zero
        }

        return method(obj, selector, frameRect)
    }
}

class PTFakeMetaTouch {
    typealias FakeTouchMethod = @convention(c) (AnyClass, Selector, Int, CGPoint, UITouch.Phase, UIWindow?, UIView?) -> Int
    private static var initialized = false
    private static var fakeTouchClass: AnyClass?
    private static var fakeTouchSelector: Selector?
    private static var fakeTouchMethod: FakeTouchMethod?

    private static func initialize() {
        fakeTouchClass = NSClassFromString("PTFakeMetaTouch")

        fakeTouchSelector = NSSelectorFromString("fakeTouchId:AtPoint:withTouchPhase:inWindow:onView:")

        if let methodIMP = fakeTouchClass?.method(for: fakeTouchSelector) {
            fakeTouchMethod = unsafeBitCast(methodIMP, to: FakeTouchMethod.self)
        }
    }

    static func fakeTouchId(_ pointId: Int,
                            at point: CGPoint,
                            with phase: UITouch.Phase,
                            in window: UIWindow?,
                            on view: UIView?) -> Int {
        if !initialized {
            initialize()
            initialized = true
        }

        guard let cls = fakeTouchClass,
              let selector = fakeTouchSelector,
              let method = fakeTouchMethod else {
            return -1
        }

        return method(cls, selector, pointId, point, phase, window, view)
    }
}

typealias CGWindowID = UInt32

struct CGWindowListOption: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let optionAll = Self([])
    public static let optionOnScreenOnly = Self(rawValue: 1 << 0)
    public static let optionOnScreenAboveWindow = Self(rawValue: 1 << 1)
    public static let optionOnScreenBelowWindow = Self(rawValue: 1 << 2)
    public static let optionIncludingWindow = Self(rawValue: 1 << 3)
    public static let excludeDesktopElements = Self(rawValue: 1 << 4)
}

struct CGWindowImageOption: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let `default` = Self([])
    public static let boundsIgnoreFraming = Self(rawValue: 1 << 0)
    public static let shouldBeOpaque = Self(rawValue: 1 << 1)
    public static let onlyShadows = Self(rawValue: 1 << 2)
    public static let bestResolution = Self(rawValue: 1 << 3)
    public static let nominalResolution = Self(rawValue: 1 << 4)
}

class CoreGraphics {
    typealias CGWindowListCreateImageFunction = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
    private static var initialized = false
    private static var createImageFunction: CGWindowListCreateImageFunction?

    private static func initialize() {
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW),
              let symbol = dlsym(handle, "CGWindowListCreateImage") else {
            return
        }
    
        createImageFunction = unsafeBitCast(symbol, to: CGWindowListCreateImageFunction.self)
    }

    static func CGWindowListCreateImage(_ screenBounds: CGRect,
                                        _ listOption: CGWindowListOption,
                                        _ windowID: CGWindowID,
                                        _ imageOption: CGWindowImageOption) -> CGImage? {
        if !initialized {
            initialize()
            initialized = true
        }

        guard let function = createImageFunction else {
            return nil
        }

        let imageRef = function(screenBounds, listOption.rawValue, windowID, imageOption.rawValue)
        return imageRef?.takeRetainedValue() ?? nil
    }
}
