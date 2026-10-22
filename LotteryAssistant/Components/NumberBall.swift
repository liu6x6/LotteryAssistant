import SwiftUI

struct NumberBall: View {
    let number: Int
    let color: Color
    var isSelected = false
    var isMatched = false
    var size: CGFloat = 36

    var body: some View {
        Text(String(format: "%02d", number))
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.opacity(isSelected ? 1 : 0.82), in: Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
            }
            .overlay {
                if isMatched {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .padding(-3)
                    Circle()
                        .stroke(AppTheme.Color.error, lineWidth: 3)
                        .padding(-6)
                }
            }
            .shadow(color: color.opacity(isSelected ? 0.32 : 0), radius: 6, y: 3)
            .accessibilityLabel("\(color == AppTheme.Color.redBall ? "红球" : "蓝球") \(number)\(isSelected ? "，已选择" : "")\(isMatched ? "，已命中" : "")")
    }
}

struct NumberRow: View {
    let frontNumbers: [Int]
    let backNumbers: [Int]
    var matchedFrontNumbers: Set<Int> = []
    var matchedBackNumbers: Set<Int> = []

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            ForEach(frontNumbers, id: \.self) {
                NumberBall(
                    number: $0,
                    color: AppTheme.Color.redBall,
                    isMatched: matchedFrontNumbers.contains($0),
                    size: 30
                )
            }
            ForEach(backNumbers, id: \.self) {
                NumberBall(
                    number: $0,
                    color: AppTheme.Color.blueBall,
                    isMatched: matchedBackNumbers.contains($0),
                    size: 30
                )
            }
        }
    }
}
