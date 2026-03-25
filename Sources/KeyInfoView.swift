import SwiftUI
import TypingAuthSDK

/// Settings view showing the Secure Enclave key fingerprint and management options.
struct KeyInfoView: View {
    private let keyManager = SecureEnclaveKeyManager()
    @State private var showRotateConfirm = false

    var body: some View {
        List {
            Section {
                if let fingerprint = keyManager.publicKeyFingerprint() {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Device Key Fingerprint")
                            .font(.subheadline.weight(.semibold))
                        Text(fingerprint)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                } else {
                    Text("No signing key found")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Apps paired with TriTap Auth can verify this fingerprint to confirm they're communicating with your device.")
            }

            Section {
                Button(role: .destructive) {
                    showRotateConfirm = true
                } label: {
                    Label("Rotate Signing Key", systemImage: "key.rotate")
                }
                .confirmationDialog(
                    "Rotate signing key?",
                    isPresented: $showRotateConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Rotate Key", role: .destructive) {
                        keyManager.deleteKey()
                        try? keyManager.generateSigningKey()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All apps paired with TriTap Auth will need to re-verify on their next authentication. Only do this if you suspect your key has been compromised.")
                }
            } footer: {
                Text("Generates a new key in the Secure Enclave. The old key is permanently deleted.")
            }
        }
        .navigationTitle("Signing Key")
    }
}
