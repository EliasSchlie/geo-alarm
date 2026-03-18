import SwiftUI

struct SettingsView: View {
    @State private var defaultSoundType = AlarmSoundSettings.defaultType
    @State private var defaultDuration = AlarmSoundSettings.defaultDuration

    var body: some View {
        NavigationStack {
            Form {
                Section("Default Alarm Sound") {
                    Picker("Sound", selection: $defaultSoundType) {
                        ForEach(AlarmSoundType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: defaultSoundType) { _, val in
                        AlarmSoundSettings.defaultType = val
                    }

                    Picker("Duration", selection: $defaultDuration) {
                        ForEach(AlarmSoundDuration.allCases) { dur in
                            Text(dur.label).tag(dur)
                        }
                    }
                    .onChange(of: defaultDuration) { _, val in
                        AlarmSoundSettings.defaultDuration = val
                    }
                }

                Section {
                    SoundPreviewButton(type: defaultSoundType, duration: defaultDuration)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SoundPreviewButton: View {
    let type: AlarmSoundType
    let duration: AlarmSoundDuration

    @State private var isPlaying = false
    @State private var player: AVAudioPlayer?

    var body: some View {
        Button {
            if isPlaying {
                stopPreview()
            } else {
                playPreview()
            }
        } label: {
            Label(isPlaying ? "Stop Preview" : "Preview Sound", systemImage: isPlaying ? "stop.fill" : "play.fill")
        }
    }

    private func playPreview() {
        guard let url = AlarmSoundSettings.bundleURL(type: type, duration: duration) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = 0
            player?.play()
            isPlaying = true

            // Auto-stop after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration.rawValue)) {
                stopPreview()
            }
        } catch {}
    }

    private func stopPreview() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}

import AVFoundation
