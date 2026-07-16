import SwiftUI

// Bottom snackbar shown for a few seconds after any delete, offering "Ångra".
struct UndoToast: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        if let snapshot = viewModel.undoSnapshot {
            HStack(spacing: 16) {
                Text(snapshot.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)

                Button {
                    Task { await viewModel.undoLastDelete() }
                } label: {
                    Text("Ångra")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "D08A62"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .fontDesign(.rounded)
        }
    }
}
