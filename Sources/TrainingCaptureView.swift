import SwiftUI
import TypingAuthSDK

/// Training capture view for TriTapAuth — collects enrollment samples.
struct TrainingCaptureView: View {
    let onDone: () -> Void
    @State private var sampleCount = TypingAuthSDK.shared.enrollmentSampleCount

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") { onDone() }
                    .padding()
            }

            Text("\(sampleCount) samples")
                .font(.title2.weight(.bold))
                .padding(.bottom, 4)

            Text(sampleCount < 20 ? "Keep going — need at least 20" : "Looking good!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TrainingKeyboardView(
                onSampleCaptured: { sample in
                    TypingAuthSDK.shared.addEnrollmentSample(sample)
                    sampleCount = TypingAuthSDK.shared.enrollmentSampleCount
                }
            )
        }
    }
}

struct TrainingKeyboardView: UIViewControllerRepresentable {
    let onSampleCaptured: (AuthenticationSample) -> Void

    func makeUIViewController(context: Context) -> TrainingCaptureViewController {
        let vc = TrainingCaptureViewController()
        vc.onSampleCaptured = onSampleCaptured
        return vc
    }

    func updateUIViewController(_ vc: TrainingCaptureViewController, context: Context) {}
}

class TrainingCaptureViewController: UIViewController, PasscodeKeyboardDelegate {
    private let motionRecorder = MotionRecorder()
    private var keyboard: PasscodeKeyboardView!
    private var dotsView: PasscodeDotsView!
    private var viewPresentedTimestamp: TimeInterval = 0
    private var digitCount = 0

    var onSampleCaptured: ((AuthenticationSample) -> Void)?

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

    private func resetCapture() {
        digitCount = 0
        dotsView.setFilledCount(0)
        keyboard.reset()
        viewPresentedTimestamp = ProcessInfo.processInfo.systemUptime
        motionRecorder.stop()
        motionRecorder.start(viewPresentedAt: viewPresentedTimestamp)
    }

    func keyboardDidEnterDigit(_ digit: Int, touchEvent: TouchEvent) {
        digitCount += 1
        dotsView.setFilledCount(digitCount)
    }

    func keyboardDidDeleteDigit() {
        resetCapture()
    }

    func keyboardDidComplete(digits: [Int]) {
        motionRecorder.stop()

        let events = keyboard.collectedTouchEvents()
        let sample = AuthenticationSample(
            label: .authorized,
            touchEvents: events,
            motionSamples: motionRecorder.collectedSnapshots(),
            reactionTime: events.first.map { $0.touchBegan - viewPresentedTimestamp } ?? 0,
            totalDuration: events.last.map { $0.touchEnded - (events.first?.touchBegan ?? 0) } ?? 0
        )

        onSampleCaptured?(sample)

        // Brief flash then reset for next sample
        UIView.animate(withDuration: 0.15) {
            self.dotsView.alpha = 0.3
        } completion: { _ in
            UIView.animate(withDuration: 0.15) {
                self.dotsView.alpha = 1.0
            }
            self.resetCapture()
        }
    }
}
