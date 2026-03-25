import SwiftUI
import Observation
import TypingAuthSDK

/// Parsed authentication request from a third-party app.
struct AuthRequest {
    let nonce: Data
    let callbackURL: String  // Full callback URL scheme + path
}

/// Handles incoming URL scheme requests from third-party apps.
@Observable
class AuthRequestHandler {

    var pendingRequest: AuthRequest?

    /// Parse an incoming tritap-auth:// URL.
    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "tritap-auth",
              url.host == "authenticate" else {
            print("[TriTapAuth] Ignoring unknown URL: \(url)")
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let nonceB64 = components.queryItems?.first(where: { $0.name == "nonce" })?.value,
              let callbackStr = components.queryItems?.first(where: { $0.name == "callback" })?.value else {
            print("[TriTapAuth] Malformed auth request — missing nonce or callback")
            return
        }

        guard let nonceData = CryptoUtils.base64urlDecode(nonceB64),
              nonceData.count == 32 else {
            print("[TriTapAuth] Invalid nonce — must be 32 bytes")
            return
        }

        print("[TriTapAuth] Auth request received — callback: \(callbackStr)")
        pendingRequest = AuthRequest(nonce: nonceData, callbackURL: callbackStr)
    }

    /// Complete authentication by calling back to the requesting app with a signed token.
    func completeAuth(token: Data) {
        guard let request = pendingRequest else { return }

        let tokenB64 = CryptoUtils.base64urlEncode(token)
        let callbackStr = "\(request.callbackURL)?token=\(tokenB64)"

        if let callbackURL = URL(string: callbackStr) {
            UIApplication.shared.open(callbackURL) { success in
                if success {
                    print("[TriTapAuth] Callback sent successfully")
                } else {
                    print("[TriTapAuth] Failed to open callback URL")
                }
            }
        }

        pendingRequest = nil
    }

    /// Cancel authentication — notify the requesting app.
    func cancelAuth() {
        guard let request = pendingRequest else { return }

        let callbackStr = "\(request.callbackURL)?error=cancelled"
        if let callbackURL = URL(string: callbackStr) {
            UIApplication.shared.open(callbackURL)
        }

        pendingRequest = nil
    }
}
