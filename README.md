# TriTap Auth

A production on-device authenticator powered by [TypingAuthSDK](https://github.com/khooten/TypingAuthSDK). TriTap Auth identifies users by their unique typing biometrics — delivering three-factor authentication in a single passcode entry.

Third-party apps call TriTap Auth via URL scheme, the user types their passcode, and a cryptographically signed result is returned. No server, no network, no biometric data ever leaves the device.

## How It Works

### For Users

1. **Set up once**: Open TriTap Auth, choose a 6-digit passcode, and type it 40+ times to train your typing profile
2. **Authenticate**: When an app requests authentication, TriTap Auth opens automatically. Type your passcode. If your typing pattern matches, you're in.
3. **Gets better over time**: Each successful authentication strengthens your profile through continuous learning

### For Developers

Integrate TriTap authentication into your app with a few lines of code:

```swift
import TriTapClient

// Set your app's callback URL scheme (once, at launch)
TriTapClient.callbackScheme = "myapp"

// Authenticate
TriTapClient.authenticate { result in
    switch result {
    case .success(let verification):
        if verification.passed {
            // User authenticated -- proceed
            print("Confidence: \(verification.confidence)")
        } else {
            // Biometric mismatch
        }
    case .failure(let error):
        switch error {
        case .authenticatorNotInstalled:
            // Prompt user to install TriTap Auth
        case .signatureInvalid:
            // Response was tampered with
        case .publicKeyMismatch:
            // Possible spoofing -- signing key changed
        default:
            print("Error: \(error)")
        }
    }
}

// Handle the callback in your SwiftUI App
.onOpenURL { url in
    TriTapClient.handleCallback(url: url)
}
```

Add to your app's Info.plist:
- `CFBundleURLTypes`: Register your callback URL scheme (e.g., `myapp`)
- `LSApplicationQueriesSchemes`: Add `tritap-auth`

Add the SDK dependency:
```
https://github.com/khooten/TypingAuthSDK
```
Select the **TriTapClient** library product (lightweight -- verification only, no biometric engine).

## Security Architecture

### Three-Factor Authentication

| Factor | Implementation |
|--------|---------------|
| **Something you know** | The 6-digit passcode |
| **Something you have** | The device itself -- training data is stored locally and never exported |
| **Something you are** | Your typing biometrics -- 14 measurements per keystroke across 6 digits |

### Challenge-Response Protocol

TriTap Auth uses a Secure Enclave-based challenge-response protocol to prevent callback spoofing:

```
Your App                              TriTap Auth
  |                                        |
  | Generate 32-byte nonce                 |
  | Store in Keychain                      |
  |                                        |
  | tritap-auth://authenticate             |
  |   ?nonce=<base64url>                   |
  |   &callback=myapp://tritap-result      |
  | =====================================> |
  |                                        | User types passcode
  |                                        | Biometric scoring (AND gate)
  |                                        | Sign with Secure Enclave P-256 key
  | <===================================== |
  | myapp://tritap-result?token=<base64url>|
  |                                        |
  | Verify ECDSA signature                 |
  | Check nonce matches                    |
  | Pin public key (first use)             |
```

**Security properties:**
- **Anti-spoofing**: ECDSA signature from Secure Enclave -- unforgeable without physical hardware access
- **Anti-replay**: Single-use nonce with 120-second expiration
- **Key pinning**: Trust-on-first-use (TOFU) model detects key substitution after initial pairing
- **No network**: Works offline, no server dependency, no cloud breach risk
- **Device-bound**: Secure Enclave keys are non-exportable and tied to the physical device

### The AND Gate

The biometric engine requires ALL measured features to match within tolerance against a SINGLE training sample, independently at each digit. This is fundamentally different from averaging:

- An impostor might match your timing OR your touch position independently
- But matching ALL 14 features on ALL 6 digits simultaneously against any one training sample is exponentially harder
- One outlier feature on one digit blocks the entire match

### Why This Is More Secure

| Attack | FaceID | Fingerprint | Passcode | TriTap |
|--------|--------|-------------|----------|--------|
| Hold phone to sleeping person's face | Succeeds | -- | -- | Fails |
| Lift fingerprint from surface | -- | Succeeds | -- | Fails |
| Shoulder-surf the code | -- | -- | Succeeds | Fails (need the typing pattern too) |
| Steal the device | Succeeds (if they know you) | Succeeds (if they have your print) | Succeeds (if they saw the code) | Fails (training data on device + biometric) |

## Building

1. Clone this repo
2. Open the Xcode project
3. Add [TypingAuthSDK](https://github.com/khooten/TypingAuthSDK) as a Swift Package dependency
4. Set the URL scheme `tritap-auth` in Info.plist under `CFBundleURLTypes`
5. Set bundle identifier to `com.moneyrecon.tritapauth`
6. Build and run on a **real iOS device**

> Note: Requires a physical device. The Secure Enclave and CoreMotion sensors are not available in the simulator.

## Project Structure

```
TriTapAuth/
  Sources/
    TriTapAuthApp.swift          -- Entry point, Secure Enclave key setup, URL handler
    AuthRequestHandler.swift     -- Parses incoming authentication requests
    AuthenticationFlowView.swift -- Passcode UI, biometric scoring, token signing
    HomeView.swift               -- Enrollment and training when opened directly
    KeyInfoView.swift            -- Signing key fingerprint display and rotation
```

## Related Projects

- [TypingAuthSDK](https://github.com/khooten/TypingAuthSDK) -- The core biometric engine and client SDK (Swift Package)
- [TriTap Test](https://github.com/khooten/TriTapTest) -- Reference app for testing and analyzing the biometric engine

## License

Apache License 2.0 -- see [LICENSE](LICENSE) for details.

Use it, modify it, build on it, include it in commercial products. The Apache 2.0 license provides explicit patent protection -- no one can patent this approach and prevent others from using it.
