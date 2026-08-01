//
//  Toucher.swift
//  MaaTools
//

import UIKit

class Toucher {
    static weak var keyWindow: UIWindow?
    static weak var keyView: UIView?

    /**
     on invocations with phase "began", an int id is allocated, which can be used later to refer to this touch point.
     on invocations with phase "ended", id is set to nil representing the touch point is no longer valid.
     */
    static func touchcam(point: CGPoint, phase: UITouch.Phase, tid: inout Int?,
                         // Name info for debug use
                         actionName: String, keyName: String) {
        if phase == UITouch.Phase.began {
            if tid != nil {
                return
            }
            tid = -1
            keyWindow = findKeyWindow()
            keyView = keyWindow!.hitTest(point, with: nil)
        } else if tid == nil {
            return
        }
        var recordId = tid!
        tid = PTFakeMetaTouch.fakeTouchId(tid!, at: point, with: phase, in: keyWindow, on: keyView)
        if tid! < 0 {
            tid = nil
        } else {
            recordId = tid!
        }

        if MaaSettings.shared.debug {
            TouchVisualizer.shared.updateTouch(fingerID: recordId, phase: phase, position: point)
        }
    }

    private static func findKeyWindow() -> UIWindow? {
        return UIApplication
            .shared
            .connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .first { $0.isKeyWindow }
    }
}
