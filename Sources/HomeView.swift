import SwiftUI
import TypingAuthSDK

/// Home screen shown when TriTapAuth is opened directly (not via URL scheme).
/// Allows the user to enroll, train, and manage their typing biometric.
struct HomeView: View {
    @State private var isEnrolled = TypingAuthSDK.shared.isEnrolled
    @State private var showCapture = false
    @State private var samplesCollected = TypingAuthSDK.shared.enrollmentSampleCount

    private let sdk = TypingAuthSDK.shared
    private let keyManager = SecureEnclaveKeyManager()
    private let minimumSamples = 20

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isEnrolled {
                        Label("Enrolled", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        HStack {
                            Text("Training Samples")
                            Spacer()
                            Text("\(samplesCollected)")
                                .bold()
                        }
                    } else {
                        Label("Not Enrolled", systemImage: "shield.slash")
                            .foregroundStyle(.orange)
                        Text("Tap Train to set up your passcode and typing pattern.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showCapture = true
                    } label: {
                        Label(isEnrolled ? "Train More" : "Start Training", systemImage: "figure.walk")
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    if samplesCollected > 0 && samplesCollected < minimumSamples {
                        Text("Need at least \(minimumSamples) samples. You have \(samplesCollected).")
                    }
                }

                Section {
                    if let fingerprint = keyManager.publicKeyFingerprint() {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Device Signing Key")
                                .font(.subheadline.weight(.semibold))
                            Text(fingerprint)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }

                    NavigationLink {
                        KeyInfoView()
                    } label: {
                        Label("Key Management", systemImage: "key")
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Third-party apps that use TriTap will show this fingerprint. Verify it matches to confirm secure pairing.")
                }
            }
            .navigationTitle("TriTap Auth")
            .fullScreenCover(isPresented: $showCapture) {
                TrainingCaptureView(
                    onDone: {
                        showCapture = false
                        if samplesCollected >= 3 {
                            sdk.finalizeEnrollment()
                        }
                        isEnrolled = sdk.isEnrolled
                        samplesCollected = sdk.enrollmentSampleCount
                    }
                )
            }
            .onAppear {
                samplesCollected = sdk.enrollmentSampleCount
                isEnrolled = sdk.isEnrolled
            }
        }
    }
}
