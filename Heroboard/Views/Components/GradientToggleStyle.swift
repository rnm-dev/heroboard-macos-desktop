import SwiftUI

/// A switch toggle whose "on" track uses the brand gradient instead of system blue.
struct GradientToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn

        return ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(Color.white.opacity(0.16))
            if isOn { Capsule().fill(HBTheme.brandGradient) }
            Circle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.3), radius: 1, y: 0.5)
                .frame(width: 20, height: 20)
                .padding(2)
        }
        .frame(width: 42, height: 24)
        .contentShape(Capsule())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) { configuration.$isOn.wrappedValue.toggle() }
        }
    }
}
