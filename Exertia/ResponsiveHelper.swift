import UIKit

struct Responsive {
    // MARK: - Reference Device (iPhone 16 Pro)
    private static let referenceWidth: CGFloat = 393
    private static let referenceHeight: CGFloat = 852

    // MARK: - Screen Dimensions
    static var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    static var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }

    // MARK: - Scale Factors
    /// Horizontal scale relative to iPhone 16 Pro width (393pt)
    static var scale: CGFloat {
        screenWidth / referenceWidth
    }

    /// Vertical scale relative to iPhone 16 Pro height (852pt)
    static var verticalScale: CGFloat {
        screenHeight / referenceHeight
    }

    // MARK: - Device Checks
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var isSmallPhone: Bool {
        !isIPad && screenWidth <= 375
    }

    static var isLargePhone: Bool {
        !isIPad && screenWidth >= 428
    }

    // MARK: - Scaling Methods

    /// Scales font size proportionally, clamped to 0.85x min and 1.5x max (for iPad readability)
    static func font(_ size: CGFloat) -> CGFloat {
        let scaled = size * scale
        let minSize = size * 0.85
        let maxSize = size * (isIPad ? 1.5 : 1.15)
        return min(max(scaled, minSize), maxSize)
    }

    /// Scales horizontal padding/margins proportionally
    static func padding(_ value: CGFloat) -> CGFloat {
        let scaled = value * scale
        // On iPad, cap padding to avoid excessive whitespace
        return isIPad ? min(scaled, value * 1.8) : scaled
    }

    /// Scales a size value (icons, images, buttons) proportionally
    static func size(_ value: CGFloat) -> CGFloat {
        let scaled = value * scale
        return isIPad ? min(scaled, value * 1.6) : scaled
    }

    /// Scales vertically (for heights, vertical offsets)
    static func verticalSize(_ value: CGFloat) -> CGFloat {
        value * verticalScale
    }

    /// Scales corner radius (less aggressive — half the delta)
    static func cornerRadius(_ value: CGFloat) -> CGFloat {
        let factor = 1.0 + (scale - 1.0) * 0.5
        return value * factor
    }

    // MARK: - Component Sizes
    static var tabBarHeight: CGFloat {
        if isIPad { return 85 }
        if isSmallPhone { return 58 }
        return 70
    }

    static var tabBarCornerRadius: CGFloat {
        tabBarHeight / 2
    }

    static var navBarHeight: CGFloat {
        isIPad ? 60 : 50
    }

    /// Maximum content width on iPad to prevent overly wide layouts
    static var maxContentWidth: CGFloat {
        isIPad ? 600 : screenWidth
    }

    /// Side inset to center-constrain content on iPad
    static var contentInset: CGFloat {
        if isIPad {
            return max((screenWidth - maxContentWidth) / 2, 30)
        }
        return 20
    }

    /// Gradient background height, scaled by device
    static var gradientHeight: CGFloat {
        isIPad ? 450 : verticalSize(350)
    }
}
