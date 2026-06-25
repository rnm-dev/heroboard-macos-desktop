import SwiftUI

/// A cardiogram (ECG) glyph wrapped in a circular progress arc that fills over the ~60s heartbeat
/// interval. When a heartbeat is sent (HeartbeatStats.sentToday increments) the arc snaps back to
/// zero and the glyph pulses.
struct HeartbeatIndicator: View {
    @ObservedObject private var stats = HeartbeatStats.shared

    private let interval: TimeInterval = 60
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let accent = Color(red: 0.30, green: 0.85, blue: 0.45)

    @State private var progress: CGFloat = 0
    @State private var pulse = false
    @State private var lastCount = HeartbeatStats.shared.sentToday

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            ECGShape()
                .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 18, height: 12)
                .scaleEffect(pulse ? 1.4 : 1.0)
        }
        .frame(width: 30, height: 30)
        .onReceive(ticker) { _ in updateProgress() }
        .onReceive(stats.$sentToday) { newCount in
            guard newCount != lastCount else { return }

            lastCount = newCount
            beat()
        }
    }

    private func updateProgress() {
        guard let last = stats.lastSentAt else {
            progress = 0
            return
        }

        let fraction = min(CGFloat(Date().timeIntervalSince(last) / interval), 1)
        withAnimation(.linear(duration: 1)) {
            progress = fraction
        }
    }

    private func beat() {
        // Fast reset of the arc + a quick pulse of the glyph.
        withAnimation(.easeOut(duration: 0.2)) {
            progress = 0
            pulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.35)) {
                pulse = false
            }
        }
    }
}
