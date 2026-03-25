import SwiftUI
import TypingAuthSDK

/// The authentication screen shown when a third-party app requests auth.
struct AuthenticationFlowView: View {
    let request: AuthRequest
    let onComplete: (Data) -> Void
    let onCancel: () -> Void

    private let sdk = TypingAuthSDK.shared
    @State private var resultText = ""
    @State private var resultColor: Color = .primary

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { onCancel() }
                    .foregroundStyle(.red)
                Spacer()
                Text("Authenticate")
                    .font(.headline)
                Spacer()
                Button("Cancel") { }.hidden()
            }
            .padding()

            if !sdk.isEnrolled {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Not Enrolled")
                        .font(.title2.weight(.semibold))
                    Text("Open TriTap Auth directly to set up your passcode and train your typing pattern first.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
                Spacer()
            } else {
                if !resultText.isEmpty {
                    Text(resultText)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(resultColor)
                        .padding(.top, 8)
                }

                Text("Type your passcode")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Spacer()

                AuthCaptureView(
                    onSampleReady: { sample in
                        let result = sdk.authenticateSample(sample)
                        let keyManager = SecureEnclaveKeyManager()
                        if let privateKey = keyManager.getSigningKey() {
                            do {
                                let token = try ChallengeToken.sign(
                                    nonce: request.nonce,
                                    outcome: result.passed ? .pass : .fail,
                                    confidence: result.confidence,
                                    privateKey: privateKey
                                )
                                resultText = result.passed ? "Authenticated" : "Rejected"
                                resultColor = result.passed ? .green : .red
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    onComplete(token)
                                }
                            } catch {
                                print("[TriTapAuth] Signing error: \(error)")
                                resultText = "Error"
                                resultColor = .red
                            }
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Capture View

struct AuthCaptureView: UIViewControllerRepresentable {
    let onSampleReady: (AuthenticationSample) -> Void

    func makeUIViewController(context: Context) -> AuthCaptureViewController {
        let vc = AuthCaptureViewController()
        vc.onSampleReady = onSampleReady
        return vc
    }

    func updateUIViewController(_ vc: AuthCaptureViewController, context: Context) {}
}

class AuthCaptureViewController: UIViewController, PasscodeKeyboardDelegate {
    private let motionRecorder = MotionRecorder()
    private var keyboard: PasscodeKeyboardView!
    private var dotsView: PasscodeDotsView!
    private var viewPresentedTimestamp: TimeInterval = 0
    private var digitCount = 0

    var onSampleReady: ((AuthenticationSample) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        viewPresentedTimestamp = ProcessInfo.processInfo.systemUptime

        dotsView = PasscodeDotsView(count: 6)
        dotsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dotsView)

        keyboard = PasscodeKeyboardView(viewPresentedAt: viewPresentedTimestamp)
        keyboard.delegate = self
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboard)

        NSLayoutConstraint.activate([
            dotsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dotsView.bottomAnchor.constraint(equalTo: keyboard.topAnchor, constant: -24),
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            keyboard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])

        motionRecorder.start(viewPresentedAt: viewPresentedTimestamp)
    }

    func keyboardDidEnterDigit(_ digit: Int, touchEvent: TouchEvent) {
        digitCount += 1
        dotsView.setFilledCount(digitCount)
    }

    func keyboardDidDeleteDigit() {
        digitCount = 0
        dotsView.setFilledCount(0)
        keyboard.reset()
        motionRecorder.stop()
        motionRecorder.start(viewPresentedAt: viewPresentedTimestamp)
    }

    func keyboardDidComplete(digits: [Int]) {
        motionRecorder.stop()

        let events = keyboard.collectedTouchEvents()
        let sample = AuthenticationSample(
            label: .unknown,
            touchEvents: events,
            motionSamples: motionRecorder.collectedSnapshots(),
            reactionTime: events.first.map { $0.touchBegan - viewPresentedTimestamp } ?? 0,
            totalDuration: events.last.map { $0.touchEnded - (events.first?.touchBegan ?? 0) } ?? 0
        )

        onSampleReady?(sample)
    }
}
