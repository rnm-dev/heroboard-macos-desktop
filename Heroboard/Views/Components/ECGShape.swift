import SwiftUI

/// A single ECG / cardiogram beat drawn in the view's rect (flat → P bump → tall R spike → S dip → flat).
struct ECGShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        var path = Path()
        path.move(to: point(0, 0.5))
        path.addLine(to: point(0.22, 0.5))
        path.addLine(to: point(0.36, 0.64))
        path.addLine(to: point(0.5, 0.06))
        path.addLine(to: point(0.62, 0.94))
        path.addLine(to: point(0.74, 0.5))
        path.addLine(to: point(1, 0.5))
        return path
    }
}
