import MapKit
import SwiftData
import SwiftUI
import TrackerCore

struct RoutesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings
    @Environment(LocationRecordingService.self) private var recorder

    @Binding var selectedTab: AppTab
    var onDismiss: (() -> Void)? = nil

    @Query(sort: \SDSavedRoute.createdAt, order: .reverse)
    private var routes: [SDSavedRoute]

    @State private var showingBuilder = false
    @State private var showingImporter = false
    @State private var selectedRoute: SDSavedRoute?
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var showingImportAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if routes.isEmpty {
                    ContentUnavailableView(
                        "No Saved Routes",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                        description: Text("Draw a route by tapping waypoints on the map or import a GPX file to follow during activities.")
                    )
                } else {
                    List {
                        ForEach(routes) { route in
                            Button {
                                selectedRoute = route
                            } label: {
                                routeRow(route)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteRoutes)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Routes")
            .toolbar {
                if let onDismiss {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { onDismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingBuilder = true
                        } label: {
                            Label("Draw Route on Map", systemImage: "hand.tap")
                        }

                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import GPX Route…", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Route")
                }
            }
            .sheet(isPresented: $showingBuilder) {
                RouteBuilderView()
            }
            .sheet(item: $selectedRoute) { route in
                RouteDetailSheet(
                    route: route,
                    onFollow: {
                        recorder.selectRouteToFollow(route)
                        selectedRoute = nil
                        selectedTab = .record
                        onDismiss?()
                    }
                )
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: DataTransferService.gpxContentTypes
            ) { result in
                handleImport(result)
            }
            .alert(importAlertTitle, isPresented: $showingImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importAlertMessage)
            }
        }
    }

    @ViewBuilder
    private func routeRow(_ route: SDSavedRoute) -> some View {
        let wps = route.decodedWaypoints()
        let previewCoords = wps.map { PreviewCoordinate(latitude: $0.latitude, longitude: $0.longitude) }

        HStack(spacing: 12) {
            RouteThumbnailBadge(
                coordinates: previewCoords,
                symbolName: "point.topleft.down.curvedto.point.bottomright.up"
            )
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(RunFormatter.distance(meters: route.distanceMeters, unit: settings.unitSystem)) · \(wps.count) waypoints")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if recorder.activeFollowedRoute?.id == route.id {
                Text("Active")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RunTheme.emerald.opacity(0.18))
                    .foregroundStyle(RunTheme.emerald)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 3)
    }

    private func deleteRoutes(at offsets: IndexSet) {
        for idx in offsets {
            let route = routes[idx]
            if recorder.activeFollowedRoute?.id == route.id {
                recorder.clearFollowedRoute()
            }
            modelContext.delete(route)
        }
        try? modelContext.save()
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let route = try DataTransferService.importGPXAsRoute(from: url, modelContext: modelContext)
                importAlertTitle = "Route Imported"
                importAlertMessage = "Saved '\(route.name)' (\(RunFormatter.distance(meters: route.distanceMeters, unit: settings.unitSystem)))."
                showingImportAlert = true
            } catch {
                importAlertTitle = "Route Import Failed"
                importAlertMessage = error.localizedDescription
                showingImportAlert = true
            }
        case .failure(let error):
            importAlertTitle = "Import Cancelled"
            importAlertMessage = error.localizedDescription
            showingImportAlert = true
        }
    }
}

struct RouteDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettingsStore.self) private var settings

    let route: SDSavedRoute
    let onFollow: () -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var exportedGPXURL: URL?

    var body: some View {
        let waypoints = route.decodedWaypoints()
        let coords = waypoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        NavigationStack {
            VStack(spacing: 16) {
                Map(position: $cameraPosition) {
                    if coords.count >= 2 {
                        MapPolyline(coordinates: coords)
                            .stroke(RunTheme.electricTeal, lineWidth: 5)
                    }
                    if let first = coords.first {
                        Marker("Start", systemImage: "flag.fill", coordinate: first)
                            .tint(RunTheme.emerald)
                    }
                    if let last = coords.last, coords.count > 1 {
                        Marker("Finish", systemImage: "flag.checkered", coordinate: last)
                            .tint(RunTheme.coral)
                    }
                }
                .frame(height: 270)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Distance", value: RunFormatter.distance(meters: route.distanceMeters, unit: settings.unitSystem))
                    LabeledContent("Waypoints", value: "\(waypoints.count)")
                    LabeledContent("Source", value: route.source.replacingOccurrences(of: "_", with: " ").capitalized)
                    if !route.notes.isEmpty {
                        Text(route.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        onFollow()
                    } label: {
                        Label("Follow Route on Record", systemImage: "location.north.line.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RunTheme.electricTeal)
                            .foregroundStyle(RunTheme.midnightSlate)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if let exportedGPXURL {
                        ShareLink(item: exportedGPXURL) {
                            Label("Export Route GPX", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle(route.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if let region = fitRouteRegion(for: coords) {
                    cameraPosition = .region(region)
                }
                exportedGPXURL = try? DataTransferService.exportRouteGPX(route: route)
            }
        }
    }

    private func fitRouteRegion(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coords.isEmpty else { return nil }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) * 0.5, longitude: (minLon + maxLon) * 0.5),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.003, (maxLat - minLat) * 1.35),
                longitudeDelta: max(0.003, (maxLon - minLon) * 1.35)
            )
        )
    }
}
