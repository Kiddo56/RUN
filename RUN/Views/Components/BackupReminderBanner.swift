import SwiftUI

struct BackupReminderBanner: View {
    let daysSinceBackup: Int?
    let onBackupTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(RunTheme.amber)

            VStack(alignment: .leading, spacing: 2) {
                Text("Backup Recommended")
                    .font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Back Up") {
                onBackupTap()
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RunTheme.amber)
            .foregroundStyle(RunTheme.midnightSlate)
            .clipShape(Capsule())
        }
        .padding(12)
        .background(RunTheme.amber.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RunTheme.amber.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var subtitle: String {
        if let daysSinceBackup {
            return "Last backup was \(daysSinceBackup) days ago. Free sideloaded signing expires every 7 days."
        }
        return "No backup created yet. Export one before your 7-day sideload certificate expires."
    }
}
