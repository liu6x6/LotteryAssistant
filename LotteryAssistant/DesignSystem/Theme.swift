import SwiftUI

enum AppTheme {
    enum Color {
        static let primary = SwiftUI.Color.indigo
        static let accent = SwiftUI.Color.orange
        static let surface = SwiftUI.Color(uiColor: .secondarySystemBackground)
        static let text = SwiftUI.Color.primary
        static let secondaryText = SwiftUI.Color.secondary
        static let positive = SwiftUI.Color.green
        static let error = SwiftUI.Color.red
        static let redBall = SwiftUI.Color.red
        static let blueBall = SwiftUI.Color.blue
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 24
    }

    enum Motion {
        static let feedback = Animation.easeInOut(duration: 0.2)
    }
}
