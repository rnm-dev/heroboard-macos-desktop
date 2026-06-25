import SwiftUI

/// Pill-style segmented control with a gradient highlight on the selected option.
struct GradientSegmented<T: Hashable>: View {
    @Binding var selection: T
    let options: [(label: String, value: T)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection

                Text(option.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selected ? .white : .white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        Group {
                            if selected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(HBTheme.brandGradient)
                                    .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
                                    .padding(2)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = option.value }
                    }
            }
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10)))
    }
}
