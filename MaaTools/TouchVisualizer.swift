//
//  TouchVisualizer.swift
//  MaaTools
//

import UIKit

final class TouchVisualizer {

    static let shared = TouchVisualizer()

    private var window: TouchOverlayWindow?

    func updateTouch(
        fingerID: Int,
        phase: UITouch.Phase,
        position: CGPoint
    ) {
        DispatchQueue.main.async {
            if self.window == nil {
                if let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }) {
                    self.window = TouchOverlayWindow(windowScene: windowScene)
                }
            }

            self.window?.overlayView.updateTouch(
                fingerID: fingerID,
                phase: phase,
                position: position
            )
        }
    }
}

final class TouchOverlayWindow: UIWindow {

    let overlayView = TouchOverlayView()

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)

        backgroundColor = .clear
        windowLevel = .alert + 1000
        isHidden = false
        isUserInteractionEnabled = false

        rootViewController = UIViewController()
        rootViewController?.view.backgroundColor = .clear
        rootViewController?.view.addSubview(overlayView)

        overlayView.frame = bounds
        overlayView.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func hitTest(
        _ point: CGPoint,
        with event: UIEvent?
    ) -> UIView? {
        // Let touches pass through
        return nil
    }
}

final class TouchIndicatorView: UIView {

    let label = UILabel()

    init(id: Int) {
        super.init(frame: CGRect(x: 0, y: 0, width: 70, height: 70))

        layer.cornerRadius = 35
        layer.borderWidth = 3

        let color = Self.color(for: id)

        backgroundColor = color.withAlphaComponent(0.25)
        layer.borderColor = color.cgColor

        label.text = "\(id)"
        label.textAlignment = .center
        label.textColor = color
        label.font = .boldSystemFont(ofSize: 24)

        label.frame = bounds
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    static func color(for id: Int) -> UIColor {
        let colors: [UIColor] = [
            .systemRed,
            .systemBlue,
            .systemGreen,
            .systemOrange,
            .systemPurple,
            .systemPink,
            .systemYellow,
            .systemTeal
        ]

        return colors[id % colors.count]
    }
}

final class TouchOverlayView: UIView {

    private var indicators: [Int: TouchIndicatorView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func updateTouch(
        fingerID: Int,
        phase: UITouch.Phase,
        position: CGPoint
    ) {

        switch phase {

        case .began:

            let indicator = TouchIndicatorView(id: fingerID)
            indicator.center = position
            indicator.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
            indicator.alpha = 0

            addSubview(indicator)

            UIView.animate(withDuration: 0.15) {
                indicator.alpha = 1
                indicator.transform = .identity
            }

            indicators[fingerID] = indicator

        case .moved:

            guard let indicator = indicators[fingerID] else {
                return
            }

            indicator.center = position

        case .ended, .cancelled:

            guard let indicator = indicators[fingerID] else {
                return
            }

            indicator.center = position

            UIView.animate(
                withDuration: 0.35,
                delay: 0.2,
                options: [.curveEaseOut],
                animations: {
                    indicator.alpha = 0
                    indicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                },
                completion: { _ in
                    indicator.removeFromSuperview()
                }
            )

            indicators.removeValue(forKey: fingerID)
            
        default:
            break
        }
    }
}
