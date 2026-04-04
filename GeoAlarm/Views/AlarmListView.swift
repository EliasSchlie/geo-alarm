import SwiftUI
import SwiftData

struct AlarmListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alarm.hour, order: .forward) private var alarms: [Alarm]
    @EnvironmentObject private var coordinator: AlarmCoordinator
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationManager: NotificationManager

    @State private var showingAddAlarm = false
    @State private var showingSettings = false

    private var needsLocationUpgrade: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .denied || status == .restricted
    }

    var body: some View {
        NavigationStack {
            Group {
                if alarms.isEmpty {
                    emptyState
                } else {
                    alarmList
                }
            }
            .navigationTitle("GeoAlarm")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddAlarm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AlarmEditView(alarm: nil)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                coordinator.setModelContext(modelContext)
                coordinator.syncRegions()

                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestPermission()
                }
                if !notificationManager.isAuthorized {
                    Task { await notificationManager.requestPermission() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            if needsLocationUpgrade {
                locationWarning
            }
            ContentUnavailableView {
                Label("No Alarms", systemImage: "alarm")
            } description: {
                Text("Tap + to add a location-based alarm")
            }
        }
    }

    private var alarmList: some View {
        List {
            if needsLocationUpgrade {
                Section {
                    locationWarning
                }
            }

            ForEach(alarms) { alarm in
                AlarmRow(alarm: alarm)
                    .contentShape(Rectangle())
            }
            .onDelete(perform: deleteAlarms)
        }
        .listStyle(.plain)
    }

    private var locationWarning: some View {
        VStack(spacing: 8) {
            Label("Location set to \"While Using\"", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline.bold())
            Text("Alarms need \"Always\" location access to ring when the app is closed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.bold())
        }
        .padding()
    }

    private func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            let alarm = alarms[index]
            notificationManager.cancelAlarm(alarm)
            locationManager.stopMonitoringRegion(identifier: alarm.regionIdentifier)
            modelContext.delete(alarm)
        }
        try? modelContext.save()
        coordinator.syncRegions()
    }
}

struct AlarmRow: View {
    @Bindable var alarm: Alarm
    @EnvironmentObject private var coordinator: AlarmCoordinator
    @EnvironmentObject private var notificationManager: NotificationManager

    @State private var showingEdit = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.system(size: 48, weight: .light, design: .default))
                    .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                    .monospacedDigit()

                HStack(spacing: 8) {
                    Text(alarm.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !alarm.locationName.isEmpty {
                        Label(alarm.locationName, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }

                    Text(alarm.repeatDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $alarm.isEnabled)
                .labelsHidden()
                .onChange(of: alarm.isEnabled) { _, enabled in
                    coordinator.syncRegions()
                    if !enabled {
                        notificationManager.cancelAlarm(alarm)
                    }
                }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            AlarmEditView(alarm: alarm)
        }
    }
}
