import SwiftUI
import SwiftData

struct AlarmListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alarm.hour, order: .forward) private var alarms: [Alarm]
    @EnvironmentObject private var coordinator: AlarmCoordinator
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationManager: NotificationManager

    @State private var showingAddAlarm = false
    @State private var hasRequestedPermissions = false

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
                    EditButton()
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
            .onAppear {
                if !hasRequestedPermissions {
                    hasRequestedPermissions = true
                    locationManager.requestPermission()
                    Task { await notificationManager.requestPermission() }
                }
                coordinator.setModelContext(modelContext)
                coordinator.syncRegions()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Alarms", systemImage: "alarm")
        } description: {
            Text("Tap + to add a location-based alarm")
        }
    }

    private var alarmList: some View {
        List {
            ForEach(alarms) { alarm in
                AlarmRow(alarm: alarm)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Navigate to edit
                    }
            }
            .onDelete(perform: deleteAlarms)
        }
        .listStyle(.plain)
    }

    private func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            let alarm = alarms[index]
            notificationManager.cancelAlarm(alarm)
            locationManager.stopMonitoringRegion(identifier: alarm.regionIdentifier)
            modelContext.delete(alarm)
        }
        try? modelContext.save()
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
                    if enabled {
                        coordinator.syncRegions()
                    } else {
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
