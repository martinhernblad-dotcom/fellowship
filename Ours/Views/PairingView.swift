import SwiftUI

struct PairingView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .choose
    @State private var generatedCode: String? = nil
    @State private var enteredCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var joinSuccess = false

    enum Mode { case choose, create, join }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                content
            }
            .navigationTitle("Anslut till partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fontDesign(.rounded)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .choose:   chooseView
        case .create:   createView
        case .join:     joinView
        }
    }

    // MARK: - Choose

    private var chooseView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "C96E4B"), Color(hex: "A0503A")],
                        startPoint: .top, endPoint: .bottom))
                Text("Synka med varandra")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("Dela allt med din partner i realtid")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 12)

            VStack(spacing: 14) {
                pairingButton(
                    icon: "plus.circle.fill",
                    title: "Skapa par-kod",
                    subtitle: "Generera en kod och dela med din partner",
                    color: Color(hex: "D08A62")
                ) { withAnimation { mode = .create } }

                pairingButton(
                    icon: "arrow.right.circle.fill",
                    title: "Ange par-kod",
                    subtitle: "Skriv in koden din partner skapade",
                    color: Color(hex: "9E9267")
                ) { withAnimation { mode = .join } }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func pairingButton(icon: String, title: String, subtitle: String,
                                color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(18)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create

    private var createView: some View {
        VStack(spacing: 28) {
            Spacer()

            if let code = generatedCode {
                VStack(spacing: 16) {
                    Text("Din par-kod")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                    Text(formattedCode(code))
                        .font(.system(size: 46, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(8)
                    Text("Dela denna kod med din partner.\nDen är giltig tills de ansluter.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)

                ShareLink(item: "Anslut till mig i Fellowship med koden: \(formattedCode(code))") {
                    Label("Dela kod", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "D08A62"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Button("Klar") { dismiss() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Skapar par-kod…")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.45))
                }
                .task { await generateCode() }
            }

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "E05A4A"))
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    private func generateCode() async {
        do {
            let code = try await viewModel.createCoupleCode()
            generatedCode = code
        } catch {
            errorMessage = "Kunde inte skapa kod. Kontrollera iCloud-inloggning."
        }
    }

    // MARK: - Join

    private var joinView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 20) {
                Text("Ange par-kod")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                TextField("", text: $enteredCode,
                          prompt: Text("T.ex. A3K9TQ").foregroundColor(.white.opacity(0.28)))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .tracking(6)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: enteredCode) { _, newVal in
                        enteredCode = String(newVal.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    }
                    .padding(.vertical, 20)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 24)
            }

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "E05A4A"))
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }

            Button {
                guard enteredCode.count == 6, !isLoading else { return }
                isLoading = true
                errorMessage = nil
                Task { await attemptJoin() }
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Anslut")
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(enteredCode.count == 6
                            ? Color(hex: "D08A62")
                            : Color.surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .disabled(enteredCode.count < 6 || isLoading)
            .animation(.easeInOut(duration: 0.15), value: enteredCode.count)

            Spacer()
        }
    }

    private func attemptJoin() async {
        do {
            let ok = try await viewModel.joinCouple(code: enteredCode)
            if ok {
                dismiss()
            } else {
                errorMessage = "Hittade ingen par-kod \"\(enteredCode)\". Dubbelkolla koden."
                isLoading = false
            }
        } catch {
            errorMessage = "Anslutning misslyckades. Kontrollera iCloud-inloggning."
            isLoading = false
        }
    }

    private func formattedCode(_ code: String) -> String {
        let upper = code.uppercased()
        guard upper.count == 6 else { return upper }
        return String(upper.prefix(3)) + " " + String(upper.suffix(3))
    }
}
