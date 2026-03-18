import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager

    @Binding var locationName: String
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var radius: Double

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false

    private var displayCoordinate: CLLocationCoordinate2D? {
        selectedCoordinate ?? (latitude != 0 ? CLLocationCoordinate2D(latitude: latitude, longitude: longitude) : nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                mapView
                searchOverlay
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { confirmLocation() }
                        .disabled(displayCoordinate == nil)
                }
                ToolbarItem(placement: .bottomBar) {
                    radiusControl
                }
            }
            .onAppear {
                if latitude != 0 {
                    selectedCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    position = .region(MKCoordinateRegion(
                        center: selectedCoordinate!,
                        latitudinalMeters: radius * 4,
                        longitudinalMeters: radius * 4
                    ))
                } else if let current = locationManager.currentLocation {
                    position = .region(MKCoordinateRegion(
                        center: current,
                        latitudinalMeters: 1000,
                        longitudinalMeters: 1000
                    ))
                } else {
                    locationManager.requestCurrentLocation()
                }
            }
        }
    }

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $position) {
                if let coord = displayCoordinate {
                    Annotation("", coordinate: coord) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                    }

                    MapCircle(center: coord, radius: radius)
                        .foregroundStyle(Color.accentColor.opacity(0.15))
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .onTapGesture { screenPoint in
                if let coordinate = proxy.convert(screenPoint, from: .local) {
                    selectedCoordinate = coordinate
                    locationName = ""
                    reverseGeocode(coordinate)
                }
            }
        }
    }

    private var searchOverlay: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search location", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit { search() }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()

            if !searchResults.isEmpty {
                List(searchResults, id: \.self) { item in
                    Button {
                        selectSearchResult(item)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.name ?? "Unknown")
                                .font(.body)
                            if let subtitle = item.placemark.title {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 200)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            }

            Spacer()

            if let coord = displayCoordinate {
                Text(locationName.isEmpty
                    ? String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
                    : locationName
                )
                .font(.caption)
                .padding(8)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 60)
            }

            // "Use Current Location" button
            Button {
                if let current = locationManager.currentLocation {
                    selectedCoordinate = current
                    position = .region(MKCoordinateRegion(
                        center: current,
                        latitudinalMeters: radius * 4,
                        longitudinalMeters: radius * 4
                    ))
                    reverseGeocode(current)
                } else {
                    locationManager.requestCurrentLocation()
                }
            } label: {
                Label("Current Location", systemImage: "location.fill")
                    .padding(10)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 8)
        }
    }

    private var radiusControl: some View {
        HStack {
            Text("Radius:")
            Slider(value: $radius, in: 50...2000, step: 50)
            Text("\(Int(radius))m")
                .monospacedDigit()
                .frame(width: 55, alignment: .trailing)
        }
    }

    private func search() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        if let coord = locationManager.currentLocation {
            request.region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 50000,
                longitudinalMeters: 50000
            )
        }

        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            searchResults = response?.mapItems ?? []
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        selectedCoordinate = coord
        locationName = item.name ?? ""
        searchText = ""
        searchResults = []
        position = .region(MKCoordinateRegion(
            center: coord,
            latitudinalMeters: radius * 4,
            longitudinalMeters: radius * 4
        ))
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            if let placemark = placemarks?.first {
                locationName = [placemark.name, placemark.locality]
                    .compactMap { $0 }
                    .joined(separator: ", ")
            }
        }
    }

    private func confirmLocation() {
        if let coord = displayCoordinate {
            latitude = coord.latitude
            longitude = coord.longitude
        }
        dismiss()
    }
}
