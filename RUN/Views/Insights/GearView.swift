import SwiftData
import SwiftUI
import TrackerCore

struct GearView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDGear.addedDate, order: .reverse) private var gearItems: [SDGear]
    @Query private var activities: [SDActivity]

    @State private var showingAddGear = false
    @State private var editingGear: SDGear?

    private var activeGear: [SDGear] {
        gearItems.filter { !$0.isRetired }
    }

    private var retiredGear: [SDGear] {
        gearItems.filter { $0.isRetired }
    }

    var body: some View {
        Group {
            if gearItems.isEmpty {
                ContentUnavailableView(
                    "No Gear Added",
                    systemImage: "shoeprints.fill",
                    description: Text("Track shoes or bikes with automatic mileage and retirement alerts.")
                )
            } else {
                List {
                    if !activeGear.isEmpty {
                        Section("Active Gear") {
                            ForEach(activeGear) { gear in
                                gearRow(gear)
                            }
                        }
                    }

                    if !retiredGear.isEmpty {
                        Section("Retired") {
                            ForEach(retiredGear) { gear in
                                gearRow(gear)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Gear Locker")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddGear = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Gear")
            }
        }
        .sheet(isPresented: $showingAddGear) {
            GearEditorSheet(existing: nil)
        }
        .sheet(item: $editingGear) { gear in
            GearEditorSheet(existing: gear)
        }
    }

    @ViewBuilder
    private func gearRow(_ gear: SDGear) -> some View {
        let logged = activities.filter { $0.gearID == gear.id }.reduce(0.0) { $0 + $1.distanceMeters }
        let total = gear.initialDistanceMeters + logged
        let ratio = gear.maxDistanceMeters > 0 ? (total / gear.maxDistanceMeters) : 0
        let barColor: Color = ratio >= 1.0 ? RunTheme.coral : (ratio >= 0.8 ? RunTheme.amber : RunTheme.emerald)
        let unit = settings.unitSystem

        Button {
            editingGear = gear
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gear.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(gearSubtitle(gear))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if ratio >= 1.0 && !gear.isRetired {
                        Label("Retire Soon", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RunTheme.coral.opacity(0.18))
                            .foregroundStyle(RunTheme.coral)
                            .clipShape(Capsule())
                    }
                }

                ProgressView(value: min(1.0, max(0.0, ratio)))
                    .tint(barColor)

                HStack {
                    Text("\(RunFormatter.distance(meters: total, unit: unit, decimals: 1)) / \(RunFormatter.distance(meters: gear.maxDistanceMeters, unit: unit, decimals: 0))")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(barColor)
                    Spacer()
                    if gear.isDefaultForRun {
                        Text("Default Run")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RunTheme.electricTeal)
                    }
                    if gear.isDefaultForRide {
                        Text("Default Ride")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RunTheme.electricTeal)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func gearSubtitle(_ gear: SDGear) -> String {
        let brandPart = gear.brand.isEmpty ? "" : "\(gear.brand) · "
        return "\(brandPart)\(gear.categoryRaw.capitalized)"
    }
}

struct GearEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    let existing: SDGear?
    @Query private var allGear: [SDGear]

    @State private var name = ""
    @State private var brand = ""
    @State private var categoryRaw = "shoes"
    @State private var initialDistText = "0"
    @State private var maxDistText = "800"
    @State private var isDefaultForRun = false
    @State private var isDefaultForRide = false
    @State private var isRetired = false
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Gear Details") {
                    TextField("Name (e.g. Daily Trainers)", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    Picker("Category", selection: $categoryRaw) {
                        Text("Shoes").tag("shoes")
                        Text("Bike").tag("bike")
                        Text("Other").tag("other")
                    }
                }

                Section("Mileage & Retirement (\(settings.unitSystem.distanceUnitLabel))") {
                    HStack {
                        Text("Prior Distance")
                        Spacer()
                        TextField("0", text: $initialDistText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    HStack {
                        Text("Retirement Limit")
                        Spacer()
                        TextField("800", text: $maxDistText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }

                Section("Defaults & Status") {
                    Toggle("Default for Run / Walk / Hike", isOn: $isDefaultForRun)
                    Toggle("Default for Ride", isOn: $isDefaultForRide)
                    if existing != nil {
                        Toggle("Retired", isOn: $isRetired)
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                if let existing {
                    Section {
                        Button("Delete Gear", role: .destructive) {
                            modelContext.delete(existing)
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add Gear" : "Edit Gear")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let existing {
                    let divisor = settings.unitSystem.metersPerMajorUnit
                    name = existing.name
                    brand = existing.brand
                    categoryRaw = existing.categoryRaw
                    initialDistText = String(format: "%.0f", existing.initialDistanceMeters / divisor)
                    maxDistText = String(format: "%.0f", existing.maxDistanceMeters / divisor)
                    isDefaultForRun = existing.isDefaultForRun
                    isDefaultForRide = existing.isDefaultForRide
                    isRetired = existing.isRetired
                    notes = existing.notes
                } else {
                    maxDistText = settings.unitSystem == .metric ? "800" : "500"
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveGear() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveGear() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let unitMeters = settings.unitSystem.metersPerMajorUnit
        let initDist = max(0, (Double(initialDistText.replacingOccurrences(of: ",", with: ".")) ?? 0) * unitMeters)
        let maxDist = max(unitMeters, (Double(maxDistText.replacingOccurrences(of: ",", with: ".")) ?? 800) * unitMeters)

        if isDefaultForRun {
            for item in allGear where item.id != existing?.id {
                item.isDefaultForRun = false
            }
        }
        if isDefaultForRide {
            for item in allGear where item.id != existing?.id {
                item.isDefaultForRide = false
            }
        }

        if let existing {
            existing.name = cleanName
            existing.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.categoryRaw = categoryRaw
            existing.initialDistanceMeters = initDist
            existing.maxDistanceMeters = maxDist
            existing.isDefaultForRun = isDefaultForRun
            existing.isDefaultForRide = isDefaultForRide
            existing.isRetired = isRetired
            existing.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let gear = SDGear(
                name: cleanName,
                categoryRaw: categoryRaw,
                brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                initialDistanceMeters: initDist,
                maxDistanceMeters: maxDist,
                isRetired: false,
                isDefaultForRun: isDefaultForRun,
                isDefaultForRide: isDefaultForRide,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(gear)
        }
        try? modelContext.save()
        dismiss()
    }
}
