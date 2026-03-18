import SwiftUI
import AVFoundation

struct AlarmRingingView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var player: AVAudioPlayer?
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Pulsing bell icon
                Image(systemName: "bell.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                VStack(spacing: 8) {
                    Text(notificationManager.activeAlarmLabel ?? "Alarm")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)

                    Text(timeString())
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                Spacer()

                // Buttons
                HStack(spacing: 60) {
                    Button {
                        stopSound()
                        notificationManager.snoozeActiveAlarm()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 36))
                            Text("Snooze")
                                .font(.callout)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 100)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                    }

                    Button {
                        stopSound()
                        notificationManager.dismissActiveAlarm()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.system(size: 36))
                            Text("Dismiss")
                                .font(.callout)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 100)
                        .background(Color.red.opacity(0.6))
                        .clipShape(Circle())
                    }
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {
            pulseScale = 1.15
            playSound()
        }
        .onDisappear {
            stopSound()
        }
    }

    private func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private func playSound() {
        let sType = notificationManager.activeAlarmSoundType ?? .classic
        let sDur = notificationManager.activeAlarmSoundDuration ?? .thirty
        guard let url = AlarmSoundSettings.bundleURL(type: sType, duration: sDur) else { return }
        startPlayer(url: url)
    }

    private func startPlayer(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1 // Loop indefinitely
            player?.volume = 1.0
            player?.play()
        } catch {
            // Fallback: at least vibrate
        }
    }

    private func stopSound() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
