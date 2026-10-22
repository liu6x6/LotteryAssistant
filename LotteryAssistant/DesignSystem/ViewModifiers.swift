import SwiftUI

struct AppCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Color.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.Color.primary.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous))
            .animation(AppTheme.Motion.feedback, value: configuration.isPressed)
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCard())
    }
}
