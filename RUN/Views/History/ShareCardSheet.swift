import SwiftUI
import TrackerCore

struct ShareCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettingsStore.self) private var settings

    let activity: SDActivity
    let points: [TrackPoint]

    @State private var hideEndpoints = true
    @State private var renderedImage: UIImage?
    @State private var shareFileURL: URL?
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Toggle("Hide First & Last \(Int(settings.privacyHideRadiusMeters)) m", isOn: $hideEndpoints)
                    .padding(.horizontal)

                Group {
                    if isRendering {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Rendering map snapshot…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 420)
                    } else if let renderedImage {
                        Image(uiImage: renderedImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(radius: 8)
                            .padding(.horizontal)
                    } else {
                        ContentUnavailableView(
                            "Preview Unavailable",
                            systemImage: "map",
                            description: Text("Map snapshot requires network access or valid coordinates.")
                        )
                    }
                }

                Spacer()

                if let shareFileURL {
                    ShareLink(item: shareFileURL) {
                        Label("Share Activity Card", systemImage: "square.and.arrow.up")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RunTheme.electricTeal)
                            .foregroundStyle(RunTheme.midnightSlate)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .navigationTitle("Share Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: hideEndpoints) {
                await renderPreview()
            }
        }
    }

    private func renderPreview() async {
        isRendering = true
        defer { isRendering = false }
        let img = await ShareCardRenderer.renderCard(
            activity: activity,
            points: points,
            unitSystem: settings.unitSystem,
            hideEndpoints: hideEndpoints,
            hideMeters: settings.privacyHideRadiusMeters
        )
        renderedImage = img
        if let img {
            shareFileURL = ShareCardRenderer.writeTemporaryPNG(img, activityID: activity.id)
        } else {
            shareFileURL = nil
        }
    }
}
