import SwiftUI
import TypingAuthSDK

@main
struct TriTapAuthApp: App {
    @State private var authHandler = AuthRequestHandler()

    init() {
        // Generate Secure Enclave signing key on first launch
        let keyManager = SecureEnclaveKeyManager()
        if !keyManager.hasKey {
            do {
                try keyManager.generateSigningKey()
                print("[TriTapAuth] Generated Secure Enclave signing key")
                if let fp = keyManager.publicKeyFingerprint() {
                    print("[TriTapAuth] Key fingerprint: \(fp)")
                }
            } catch {
                print("[TriTapAuth] Error generating key: \(error)")
            }
        } else {
            print("[TriTapAuth] Signing key already exists")
            if let fp = keyManager.publicKeyFingerprint() {
                print("[TriTapAuth] Key fingerprint: \(fp)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let request = authHandler.pendingRequest {
                    AuthenticationFlowView(
                        request: request,
                        onComplete: { token in
                            authHandler.completeAuth(token: token)
                        },
                        onCancel: {
                            authHandler.cancelAuth()
                        }
                    )
                } else {
                    HomeView()
                }
            }
            .onOpenURL { url in
                authHandler.handleIncomingURL(url)
            }
        }
    }
}
