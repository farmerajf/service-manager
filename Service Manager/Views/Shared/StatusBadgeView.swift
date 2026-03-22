import SwiftUI

struct StatusBadgeView: View {
    let status: ServiceStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay {
                if case .starting = status {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 12, height: 12)
                        .opacity(0.5)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: pulseAnimation)
                        .onAppear { pulseAnimation = true }
                }
            }
    }

    @State private var pulseAnimation = false

    private var color: Color {
        switch status {
        case .stopped:
            return .gray
        case .starting:
            return .yellow
        case .running:
            return .green
        case .crashed:
            return .red
        }
    }
}
