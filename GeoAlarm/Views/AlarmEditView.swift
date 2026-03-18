import SwiftUI
import SwiftData
import AVFoundation

struct AlarmEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coordinator: AlarmCoordinator

    let alarm: Alarm?

    @State private var hour: Int
    @State private var minute: Int
    @State private var label: String
    @State private var repeatDays: Set<Int>
    @State private var locationName: String
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var radius: Double
    @State private var soundType: AlarmSoundType
    @State private var soundDuration: AlarmSoundDuration

    @State private var showingLocationPicker = false
    @State private var previewPlayer: AVAudioPlayer?
    @State private var isPreviewing = false

    private var isNew: Bool { alarm == nil }

    init(alarm: Alarm?) {
        self.alarm = alarm
        _hour = State(initialValue: alarm?.hour ?? Calendar.current.component(.hour, from: Date()))
        _minute = State(initialValue: alarm?.minute ?? 0)
        _label = State(initialValue: alarm?.label ?? "Alarm")
        _repeatDays = State(initialValue: alarm?.repeatDays ?? [])
        _locationName = State(initialValue: alarm?.locationName ?? "")
        _latitude = State(initialValue: alarm?.latitude ?? 0)
        _longitude = State(initialValue: alarm?.longitude ?? 0)
        _radius = State(initialValue: alarm?.radiusMeters ?? 200)
        _soundType = State(initialValue: alarm?.soundType ?? AlarmSoundSettings.defaultType)
        _soundDuration = State(initialValue: alarm?.soundDuration ?? AlarmSoundSettings.defaultDuration)
    }

    private var selectedTime: Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: Binding(
                        get: { selectedTime },
                        set: { newValue in
                            hour = Calendar.current.component(.hour, from: newValue)
                            minute = Calendar.current.component(.minute, from: newValue)
                        }
                    ), displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                Section {
                    TextField("Label", text: $label)

                    RepeatDaysPicker(selectedDays: $repeatDays)
                }

                Section("Location") {
                    if latitude != 0 || longitude != 0 {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(locationName.isEmpty ? "Selected location" : locationName)
                                    .font(.body)
                                Text("Radius: \(Int(radius))m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Change") {
                                showingLocationPicker = true
                            }
                        }
                    } else {
                        Button {
                            showingLocationPicker = true
                        } label: {
                            Label("Choose Location", systemImage: "mappin.and.ellipse")
                        }
                    }
                }

                Section("Sound") {
                    Picker("Type", selection: $soundType) {
                        ForEach(AlarmSoundType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: soundType) { _, _ in stopPreview() }

                    Picker("Duration", selection: $soundDuration) {
                        ForEach(AlarmSoundDuration.allCases) { dur in
                            Text(dur.label).tag(dur)
                        }
                    }

                    Button {
                        if isPreviewing {
                            stopPreview()
                        } else {
                            playPreview()
                        }
                    } label: {
                        Label(isPreviewing ? "Stop" : "Preview", systemImage: isPreviewing ? "stop.fill" : "play.fill")
                    }
                }
            }
            .navigationTitle(isNew ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(latitude == 0 && longitude == 0)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    locationName: $locationName,
                    latitude: $latitude,
                    longitude: $longitude,
                    radius: $radius
                )
            }
        }
    }

    private func save() {
        if let alarm {
            alarm.hour = hour
            alarm.minute = minute
            alarm.label = label
            alarm.repeatDays = repeatDays
            alarm.locationName = locationName
            alarm.latitude = latitude
            alarm.longitude = longitude
            alarm.radiusMeters = radius
            alarm.soundType = soundType
            alarm.soundDuration = soundDuration
        } else {
            let newAlarm = Alarm(
                label: label,
                hour: hour,
                minute: minute,
                isEnabled: true,
                repeatDays: repeatDays,
                locationName: locationName,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radius,
                soundType: soundType,
                soundDuration: soundDuration
            )
            modelContext.insert(newAlarm)
        }

        try? modelContext.save()
        coordinator.syncRegions()
        stopPreview()
        dismiss()
    }

    private func playPreview() {
        let filename = AlarmSoundSettings.filename(type: soundType, duration: soundDuration)
        let name = filename.replacingOccurrences(of: ".caf", with: "")
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.numberOfLoops = 0
            previewPlayer?.play()
            isPreviewing = true

            // Auto-stop after the sound finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(soundDuration.rawValue) + 0.5) {
                if isPreviewing { stopPreview() }
            }
        } catch {}
    }

    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        isPreviewing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct RepeatDaysPicker: View {
    @Binding var selectedDays: Set<Int>

    private static let allDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    private let days = Calendar.current.shortWeekdaySymbols

    private var isEveryDay: Bool {
        selectedDays == Self.allDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Every day", isOn: Binding(
                get: { isEveryDay },
                set: { newValue in
                    selectedDays = newValue ? Self.allDays : []
                }
            ))

            if !isEveryDay {
                HStack(spacing: 6) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        let weekday = index + 1
                        Button {
                            if selectedDays.contains(weekday) {
                                selectedDays.remove(weekday)
                            } else {
                                selectedDays.insert(weekday)
                            }
                        } label: {
                            Text(String(day.prefix(1)))
                                .font(.caption.bold())
                                .frame(width: 36, height: 36)
                                .background(
                                    selectedDays.contains(weekday)
                                        ? Color.accentColor
                                        : Color(.systemGray5)
                                )
                                .foregroundStyle(
                                    selectedDays.contains(weekday) ? .white : .primary
                                )
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
