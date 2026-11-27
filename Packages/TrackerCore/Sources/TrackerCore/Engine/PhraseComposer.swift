import Foundation

public enum VoiceQualityRank: Int, Codable, Sendable, Comparable {
    case defaultQuality = 1
    case enhanced = 2
    case premium = 3

    public var label: String {
        switch self {
        case .defaultQuality: return "Default"
        case .enhanced: return "Enhanced"
        case .premium: return "Premium"
        }
    }

    public static func < (lhs: VoiceQualityRank, rhs: VoiceQualityRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct VoiceDescriptor: Identifiable, Sendable, Equatable {
    public let identifier: String
    public let name: String
    public let languageCode: String
    public let quality: VoiceQualityRank

    public var id: String { identifier }

    public init(identifier: String, name: String, languageCode: String, quality: VoiceQualityRank) {
        self.identifier = identifier
        self.name = name
        self.languageCode = languageCode
        self.quality = quality
    }
}

public enum VoiceRanker {
    /// Filters to the user's primary language (falling back to English if none match) and ranks
    /// Premium > Enhanced > Default, preferring exact locale matches and then name order.
    public static func rankVoices(
        _ voices: [VoiceDescriptor],
        preferredLocaleIdentifier: String
    ) -> [VoiceDescriptor] {
        let normalizedLocale = preferredLocaleIdentifier.replacingOccurrences(of: "_", with: "-").lowercased()
        let baseLang = normalizedLocale.split(separator: "-").first.map(String.init) ?? "en"

        var matching = voices.filter { voice in
            let vLang = voice.languageCode.replacingOccurrences(of: "_", with: "-").lowercased()
            return vLang == normalizedLocale || vLang.hasPrefix(baseLang + "-") || vLang == baseLang
        }

        if matching.isEmpty {
            matching = voices.filter { $0.languageCode.lowercased().hasPrefix("en") }
        }
        if matching.isEmpty {
            matching = voices
        }

        return matching.sorted { lhs, rhs in
            if lhs.quality != rhs.quality {
                return lhs.quality > rhs.quality
            }
            let lhsExact = lhs.languageCode.replacingOccurrences(of: "_", with: "-").lowercased() == normalizedLocale
            let rhsExact = rhs.languageCode.replacingOccurrences(of: "_", with: "-").lowercased() == normalizedLocale
            if lhsExact != rhsExact {
                return lhsExact
            }
            if lhs.name != rhs.name {
                return lhs.name < rhs.name
            }
            return lhs.identifier < rhs.identifier
        }
    }

    /// Resolves the saved identifier if still installed; otherwise picks the top-ranked voice and indicates fallback.
    public static func resolveVoice(
        savedIdentifier: String?,
        rankedVoices: [VoiceDescriptor]
    ) -> (selected: VoiceDescriptor?, didFallbackFromMissingSaved: Bool) {
        if let saved = savedIdentifier, !saved.isEmpty {
            if let exact = rankedVoices.first(where: { $0.identifier == saved }) {
                return (exact, false)
            }
            return (rankedVoices.first, true)
        }
        return (rankedVoices.first, false)
    }
}

public enum CueKind: String, Sendable, Hashable {
    case start
    case split
    case timeInterval
    case lap
    case pause
    case resume
    case finish
    case offRoute
    case goalReached
    case restTimerDone
    case workoutPR
    case workoutComplete
    case preview
}

public struct SpokenSegment: Sendable, Equatable {
    public let text: String
    public let preUtteranceDelay: TimeInterval
    public let postUtteranceDelay: TimeInterval

    public init(text: String, preUtteranceDelay: TimeInterval = 0.0, postUtteranceDelay: TimeInterval = 0.12) {
        self.text = text
        self.preUtteranceDelay = preUtteranceDelay
        self.postUtteranceDelay = postUtteranceDelay
    }
}

public struct SpokenCue: Sendable, Equatable {
    public let kind: CueKind
    public let segments: [SpokenSegment]
    public let templateIndex: Int

    public var fullText: String {
        segments.map(\.text).joined(separator: " ")
    }

    public init(kind: CueKind, segments: [SpokenSegment], templateIndex: Int) {
        self.kind = kind
        self.segments = segments
        self.templateIndex = templateIndex
    }
}

/// Pure, deterministic, conversational speech phrase composer.
/// Converts raw metrics into spoken words (never written shorthand like "5:22/km")
/// with natural pauses, non-repeating templates, and occasional encouragement.
public struct PhraseComposer: Sendable {
    private var lastTemplateIndex: [CueKind: Int] = [:]
    private var splitCueCount: Int = 0
    private var stepCounter: Int = 0

    public init() {}

    // MARK: - Spoken Number & Unit Formatters

    public static func spokenInteger(_ value: Int) -> String {
        if value < 0 {
            return "minus " + spokenInteger(-value)
        }
        let ones = [
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
            "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
            "seventeen", "eighteen", "nineteen"
        ]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

        if value < 20 {
            return ones[value]
        }
        if value < 100 {
            let t = value / 10
            let r = value % 10
            return r == 0 ? tens[t] : "\(tens[t])-\(ones[r])"
        }
        if value < 1000 {
            let h = value / 100
            let r = value % 100
            return r == 0 ? "\(ones[h]) hundred" : "\(ones[h]) hundred \(spokenInteger(r))"
        }
        let th = value / 1000
        let r = value % 1000
        return r == 0 ? "\(spokenInteger(th)) thousand" : "\(spokenInteger(th)) thousand \(spokenInteger(r))"
    }

    public static func spokenDecimalOnePlace(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "zero" }
        let roundedTenths = Int((value * 10.0).rounded())
        let whole = roundedTenths / 10
        let tenth = roundedTenths % 10
        if tenth == 0 {
            return spokenInteger(whole)
        }
        return "\(spokenInteger(whole)) point \(spokenInteger(tenth))"
    }

    public static func spokenDistance(meters: Double, unit: UnitSystem) -> String {
        let major = max(0, meters / unit.metersPerMajorUnit)
        let roundedTenths = Int((major * 10.0).rounded())
        let singular = (roundedTenths == 10)
        let unitWord: String
        switch unit {
        case .metric:
            unitWord = singular ? "kilometre" : "kilometres"
        case .imperial:
            unitWord = singular ? "mile" : "miles"
        }
        return "\(spokenDecimalOnePlace(major)) \(unitWord)"
    }

    public static func spokenPace(secondsPerMeter: Double, unit: UnitSystem) -> String {
        guard secondsPerMeter.isFinite, secondsPerMeter > 0 else {
            return "steady pace"
        }
        let totalSec = Int((secondsPerMeter * unit.metersPerMajorUnit).rounded())
        guard totalSec > 0, totalSec < 5999 else {
            return "steady pace"
        }
        let mins = totalSec / 60
        let secs = totalSec % 60
        let unitWord = (unit == .metric) ? "kilometre" : "mile"

        if secs == 0 {
            return "\(spokenInteger(mins)) flat per \(unitWord)"
        } else if secs < 10 {
            return "\(spokenInteger(mins)) oh \(spokenInteger(secs)) per \(unitWord)"
        } else {
            return "\(spokenInteger(mins)) \(spokenInteger(secs)) per \(unitWord)"
        }
    }

    public static func spokenSpeed(metersPerSecond: Double, unit: UnitSystem) -> String {
        guard metersPerSecond.isFinite, metersPerSecond > 0 else {
            return "zero"
        }
        let value: Double
        let unitPhrase: String
        switch unit {
        case .metric:
            value = metersPerSecond * 3.6
            unitPhrase = "kilometres per hour"
        case .imperial:
            value = metersPerSecond * 2.2369362920544
            unitPhrase = "miles per hour"
        }
        return "\(spokenDecimalOnePlace(value)) \(unitPhrase)"
    }

    public static func spokenDuration(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "zero seconds" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60

        var parts: [String] = []
        if hours > 0 {
            parts.append("\(spokenInteger(hours)) \(hours == 1 ? "hour" : "hours")")
        }
        if mins > 0 {
            parts.append("\(spokenInteger(mins)) \(mins == 1 ? "minute" : "minutes")")
        }
        if hours == 0 && (secs > 0 || parts.isEmpty) {
            parts.append("\(spokenInteger(secs)) \(secs == 1 ? "second" : "seconds")")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Conversational Cue Builders

    public mutating func composeStart(type: ActivityType) -> SpokenCue {
        let name = type.displayName.lowercased()
        let templates = [
            "Starting your \(name). Have a good one.",
            "\(type.displayName) started. Find your rhythm.",
            "Off you go, \(name) is live."
        ]
        let idx = nextTemplateIndex(for: .start, count: templates.count)
        return SpokenCue(kind: .start, segments: [SpokenSegment(text: templates[idx])], templateIndex: idx)
    }

    public mutating func composePause(auto: Bool) -> SpokenCue {
        let templates: [String] = auto
            ? ["Auto paused.", "Paused automatically.", "Taking a quick breather, auto paused."]
            : ["Paused.", "Workout paused.", "Timer paused."]
        let idx = nextTemplateIndex(for: .pause, count: templates.count)
        return SpokenCue(kind: .pause, segments: [SpokenSegment(text: templates[idx])], templateIndex: idx)
    }

    public mutating func composeResume(auto: Bool) -> SpokenCue {
        let templates: [String] = auto
            ? ["Back moving, resumed.", "Auto resumed.", "Moving again, timer resumed."]
            : ["Resumed.", "Back underway.", "Rolling again."]
        let idx = nextTemplateIndex(for: .resume, count: templates.count)
        return SpokenCue(kind: .resume, segments: [SpokenSegment(text: templates[idx])], templateIndex: idx)
    }

    public mutating func composeSplit(
        splitIndex: Int,
        splitPaceSecondsPerMeter: Double,
        splitSpeedMPS: Double,
        totalDistanceMeters: Double,
        totalMovingTime: TimeInterval,
        type: ActivityType,
        unit: UnitSystem
    ) -> SpokenCue {
        splitCueCount += 1
        let unitWord = (unit == .metric) ? "kilometre" : "mile"
        let indexWord = Self.spokenInteger(splitIndex)
        let ratePhrase = type.prefersSpeedOverPace
            ? Self.spokenSpeed(metersPerSecond: splitSpeedMPS, unit: unit)
            : Self.spokenPace(secondsPerMeter: splitPaceSecondsPerMeter, unit: unit)
        let timePhrase = Self.spokenDuration(seconds: totalMovingTime)

        let templates: [[SpokenSegment]] = [
            [
                SpokenSegment(text: "\(unitWord.capitalized) \(indexWord).", postUtteranceDelay: 0.16),
                SpokenSegment(text: "Split pace, \(ratePhrase).", postUtteranceDelay: 0.14),
                SpokenSegment(text: "Total time, \(timePhrase).", postUtteranceDelay: 0.10)
            ],
            [
                SpokenSegment(text: "That's \(indexWord) \(splitIndex == 1 ? unitWord : unitWord + "s") done.", postUtteranceDelay: 0.16),
                SpokenSegment(text: "Last split was \(ratePhrase).", postUtteranceDelay: 0.12)
            ],
            [
                SpokenSegment(text: "Passing \(unitWord) \(indexWord), in \(timePhrase).", postUtteranceDelay: 0.16),
                SpokenSegment(text: "Current split, \(ratePhrase).", postUtteranceDelay: 0.12)
            ]
        ]

        let idx = nextTemplateIndex(for: .split, count: templates.count)
        var segments = templates[idx]

        // Occasional encouragement (every 3rd split, never constant)
        if splitCueCount % 3 == 0 {
            let cheers = ["Nice steady rhythm.", "Strong effort, keep it smooth.", "Looking great out there."]
            let cheer = cheers[(splitCueCount / 3) % cheers.count]
            segments.append(SpokenSegment(text: cheer, preUtteranceDelay: 0.12, postUtteranceDelay: 0.08))
        }

        return SpokenCue(kind: .split, segments: segments, templateIndex: idx)
    }

    public mutating func composeTimeInterval(
        movingTime: TimeInterval,
        distanceMeters: Double,
        currentPaceSecondsPerMeter: Double,
        currentSpeedMPS: Double,
        type: ActivityType,
        unit: UnitSystem
    ) -> SpokenCue {
        let mins = max(1, Int((movingTime / 60.0).rounded()))
        let distPhrase = Self.spokenDistance(meters: distanceMeters, unit: unit)
        let ratePhrase = type.prefersSpeedOverPace
            ? Self.spokenSpeed(metersPerSecond: currentSpeedMPS, unit: unit)
            : Self.spokenPace(secondsPerMeter: currentPaceSecondsPerMeter, unit: unit)

        let templates: [[SpokenSegment]] = [
            [
                SpokenSegment(text: "\(Self.spokenInteger(mins)) minutes in.", postUtteranceDelay: 0.14),
                SpokenSegment(text: "Distance, \(distPhrase), at \(ratePhrase).")
            ],
            [
                SpokenSegment(text: "Time check, \(Self.spokenInteger(mins)) minutes.", postUtteranceDelay: 0.14),
                SpokenSegment(text: "You've covered \(distPhrase).")
            ]
        ]
        let idx = nextTemplateIndex(for: .timeInterval, count: templates.count)
        return SpokenCue(kind: .timeInterval, segments: templates[idx], templateIndex: idx)
    }

    public mutating func composeLap(
        lapNumber: Int,
        lapDistanceMeters: Double,
        lapDuration: TimeInterval,
        unit: UnitSystem
    ) -> SpokenCue {
        let lapNum = Self.spokenInteger(lapNumber)
        let dist = Self.spokenDistance(meters: lapDistanceMeters, unit: unit)
        let dur = Self.spokenDuration(seconds: lapDuration)
        let templates: [String] = [
            "Lap \(lapNum) marked, \(dist) in \(dur).",
            "Starting lap \(Self.spokenInteger(lapNumber + 1)). Previous lap was \(dur)."
        ]
        let idx = nextTemplateIndex(for: .lap, count: templates.count)
        return SpokenCue(kind: .lap, segments: [SpokenSegment(text: templates[idx])], templateIndex: idx)
    }

    public mutating func composeFinish(
        distanceMeters: Double,
        movingTime: TimeInterval,
        unit: UnitSystem
    ) -> SpokenCue {
        let dist = Self.spokenDistance(meters: distanceMeters, unit: unit)
        let dur = Self.spokenDuration(seconds: movingTime)
        let templates: [[SpokenSegment]] = [
            [
                SpokenSegment(text: "Activity complete.", postUtteranceDelay: 0.18),
                SpokenSegment(text: "You covered \(dist), in \(dur). Well done.")
            ],
            [
                SpokenSegment(text: "Nice work, session saved.", postUtteranceDelay: 0.16),
                SpokenSegment(text: "Total distance, \(dist), total time, \(dur).")
            ]
        ]
        let idx = nextTemplateIndex(for: .finish, count: templates.count)
        return SpokenCue(kind: .finish, segments: templates[idx], templateIndex: idx)
    }

    public mutating func composeOffRoute(distanceMeters: Double, unit: UnitSystem) -> SpokenCue {
        let approxMeters = Int((distanceMeters / 10.0).rounded()) * 10
        let distPhrase: String
        if unit == .metric {
            distPhrase = "\(Self.spokenInteger(max(10, approxMeters))) metres"
        } else {
            let feet = max(30, Int(((distanceMeters * 3.28084) / 10.0).rounded()) * 10)
            distPhrase = "\(Self.spokenInteger(feet)) feet"
        }
        let templates = [
            "Heads up, you're off route by about \(distPhrase).",
            "Off route, about \(distPhrase) from your track."
        ]
        let idx = nextTemplateIndex(for: .offRoute, count: templates.count)
        return SpokenCue(kind: .offRoute, segments: [SpokenSegment(text: templates[idx])], templateIndex: idx)
    }

    public mutating func composeGoalReached(goalTitle: String) -> SpokenCue {
        let templates = [
            "Goal reached! You just hit \(goalTitle).",
            "Milestone unlocked, \(goalTitle) is complete."
        ]
        let idx = nextTemplateIndex(for: .goalReached, count: templates.count)
        return SpokenCue(kind: .goalReached, segments: [SpokenSegment(text: templates[idx])], templateIndex: idx)
    }

    public mutating func composeRestTimerDone(nextExerciseName: String? = nil) -> SpokenCue {
        let templates: [String]
        if let next = nextExerciseName, !next.isEmpty {
            templates = [
                "Rest is up. Ready for your next set of \(next).",
                "Time to lift. Back to \(next).",
                "Break over, step up for \(next)."
            ]
        } else {
            templates = [
                "Rest is up. Ready for your next set.",
                "Break is over, time for the next set.",
                "Timer done. Let's go."
            ]
        }
        let idx = nextTemplateIndex(for: .restTimerDone, count: templates.count)
        return SpokenCue(kind: .restTimerDone, segments: [SpokenSegment(text: templates[idx])], templateIndex: idx)
    }

    public mutating func composeWorkoutPR(exerciseName: String) -> SpokenCue {
        let templates = [
            "New personal record on \(exerciseName)!",
            "That's a new P R on \(exerciseName). Strong set."
        ]
        let idx = nextTemplateIndex(for: .workoutPR, count: templates.count)
        return SpokenCue(kind: .workoutPR, segments: [SpokenSegment(text: templates[idx])], templateIndex: idx)
    }

    public mutating func composeWorkoutComplete(durationSeconds: TimeInterval, completedSets: Int) -> SpokenCue {
        let dur = Self.spokenDuration(seconds: durationSeconds)
        let setsWord = Self.spokenInteger(completedSets)
        let templates = [
            "Strength workout complete. \(setsWord) sets in \(dur). Great session.",
            "Nice lifting. You logged \(setsWord) sets over \(dur)."
        ]
        let idx = nextTemplateIndex(for: .workoutComplete, count: templates.count)
        return SpokenCue(kind: .workoutComplete, segments: [SpokenSegment(text: templates[idx])], templateIndex: idx)
    }

    public static func previewSample(unit: UnitSystem) -> SpokenCue {
        let dist = spokenDistance(meters: unit == .metric ? 2500 : 3218.7, unit: unit)
        let pace = spokenPace(secondsPerMeter: unit == .metric ? 0.322 : 0.322, unit: unit)
        return SpokenCue(
            kind: .preview,
            segments: [
                SpokenSegment(text: "Distance, \(dist).", postUtteranceDelay: 0.16),
                SpokenSegment(text: "Current pace, \(pace). Nice steady rhythm.")
            ],
            templateIndex: 0
        )
    }

    private mutating func nextTemplateIndex(for kind: CueKind, count: Int) -> Int {
        guard count > 1 else { return 0 }
        stepCounter += 1
        let previous = lastTemplateIndex[kind]
        var candidate = stepCounter % count
        if candidate == previous {
            candidate = (candidate + 1) % count
        }
        lastTemplateIndex[kind] = candidate
        return candidate
    }
}
