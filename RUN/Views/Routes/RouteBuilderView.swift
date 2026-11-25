import MapKit
import SwiftData
import SwiftUI
import TrackerCore

struct RouteBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var routeName = ""
    @State private var routeNotes = ""
    @State private var waypoints: [RouteWaypoint] = []
    @State private var showingSaveSheet = false

    private var totalDistanceMeters: Double {
        RouteNavigationEngine.totalDistanceMeters(waypoints: waypoints)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        UserAnnotation()

                        if waypoints.count >= 2 {
                            MapPolyline(
                                coordinates: waypoints.map {
                                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                                }
                            )
                            .stroke(RunTheme.electricTeal, lineWidth: 5)
                        }

                        ForEach(Array(waypoints.enumerated()), id: \.element.id) { idx, wp in
                            Marker(
                                "\(idx + 1)",
                                coordinate: CLLocationCoordinate2D(latitude: wp.latitude, longitude: wp.longitude)
                            )
                            .tint(idx == 0 ? RunTheme.emerald : RunTheme.electricTeal)
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                    }
                    .onTapGesture { point in
                        if let coord = proxy.convert(point, from: .local) {
                            waypoints.append(
                                RouteWaypoint(latitude: coord.latitude, longitude: coord.longitude)
                            )
                        }
                    }
                }

                bottomControls
            }
            .navigationTitle("Draw Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if routeName.isEmpty {
                            routeName = "Custom Route (\(RunFormatter.distance(meters: totalDistanceMeters, unit: settings.unitSystem, decimals: 1)))"
                        }
                        showingSaveSheet = true
                    }
                    .disabled(waypoints.count < 2)
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveRouteSheet
            }
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tap map to add waypoints")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(RunFormatter.distance(meters: totalDistanceMeters, unit: settings.unitSystem)) · \(waypoints.count) pts")
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(RunTheme.electricTeal)
                }

                Spacer()

                Button {
                    if !waypoints.isEmpty {
                        waypoints.removeLast()
                    }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(waypoints.isEmpty)

                Button(role: .destructive) {
                    waypoints.removeAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(waypoints.isEmpty)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var saveRouteSheet: some View {
        NavigationStack {
            Form {
                Section("Route Info") {
                    TextField("Route Name", text: $routeName)
                    TextField("Notes (optional)", text: $routeNotes, axis: .vertical)
                    LabeledContent("Distance", value: RunFormatter.distance(meters: totalDistanceMeters, unit: settings.unitSystem))
                    LabeledContent("Waypoints", value: "\(waypoints.count)")
                }
            }
            .navigationTitle("Save Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSaveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleanName = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let route = SDSavedRoute(
                            name: cleanName.isEmpty ? "Saved Route" : cleanName,
                            notes: routeNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                            distanceMeters: totalDistanceMeters,
                            source: "drawn"
                        )
                        route.updateWaypoints(waypoints)
                        modelContext.insert(route)
                        try? modelContext.save()
                        showingSaveSheet = false
                        dismiss()
                    }
                }
            }
        }
    }
}
