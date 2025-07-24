#if os(macOS)
    import AppCore
    import AppKit
    import Foundation

    /// macOS implementation of ScreenServiceProtocol
    public final class MacOSScreenService: ScreenServiceProtocol {
        public init() {}

        public var mainScreenBounds: AppCore.CGRect {
            let nsRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            return AppCore.CGRect(
                origin: AppCore.CGPoint(x: nsRect.origin.x, y: nsRect.origin.y),
                size: AppCore.CGSize(width: nsRect.size.width, height: nsRect.size.height)
            )
        }

        public var mainScreenWidth: CGFloat {
            NSScreen.main?.frame.width ?? 1920
        }

        public var mainScreenHeight: CGFloat {
            NSScreen.main?.frame.height ?? 1080
        }

        public var screenScale: CGFloat {
            NSScreen.main?.backingScaleFactor ?? 2.0
        }

        public var isCompact: Bool {
            // macOS is never compact
            false
        }
    }
#endif
