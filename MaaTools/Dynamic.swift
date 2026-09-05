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

    typealias ContentRectMethod = @convention(c) (AnyObject, Selector, CGRect) -> CGRect
    private static let contentRectSelector = NSSelectorFromString("contentRectForFrameRect:")

    func contentRect(forFrameRect frameRect: CGRect) -> CGRect {
        let selector = Self.contentRectSelector
        let methodIMP = obj.method(for: selector)
        let method = unsafeBitCast(methodIMP, to: ContentRectMethod.self)
        return method(obj, selector, frameRect)
    }
}

class PTFakeMetaTouch {
    typealias FakeTouchMethod = @convention(c) (AnyClass, Selector, Int, CGPoint, UITouch.Phase, UIWindow?, UIView?) -> Int
    private static let fakeTouchClass: AnyClass? = NSClassFromString("PTFakeMetaTouch")
    private static let fakeTouchSelector = NSSelectorFromString("fakeTouchId:AtPoint:withTouchPhase:inWindow:onView:")
    private static let fakeTouchMethod: FakeTouchMethod? = {
        guard let methodIMP = fakeTouchClass?.method(for: fakeTouchSelector) else {
            return nil
        }
        return unsafeBitCast(methodIMP, to: FakeTouchMethod.self)
    }()

    static func fakeTouchId(_ pointId: Int, at point: CGPoint, with phase: UITouch.Phase, in window: UIWindow?, on view: UIView?) -> Int {
        guard let cls = fakeTouchClass,
              let method = fakeTouchMethod else {
            return -1
        }
        return method(cls, fakeTouchSelector, pointId, point, phase, window, view)
    }
}
