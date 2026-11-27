import Foundation
import XCTest
@testable import TrackerCore

final class PhraseComposerTests: XCTestCase {
    func testSpokenNumbersPaceAndDistanceAvoidWrittenShorthand() {
        let paceMetric = PhraseComposer.spokenPace(secondsPerMeter: 322.0 / 1000.0, unit: .metric)
        XCTAssertEqual(paceMetric, "five twenty-two per kilometre")
        XCTAssertFalse(paceMetric.contains(":"))
        XCTAssertFalse(paceMetric.contains("/"))

        let paceOhFive = PhraseComposer.spokenPace(secondsPerMeter: 245.0 / 1000.0, unit: .metric)
        XCTAssertEqual(paceOhFive, "four oh five per kilometre")

        let distMetric = PhraseComposer.spokenDistance(meters: 2500, unit: .metric)
        XCTAssertEqual(distMetric, "two point five kilometres")
        XCTAssertFalse(distMetric.contains("2.5"))

        let distOneKm = PhraseComposer.spokenDistance(meters: 1000, unit: .metric)
        XCTAssertEqual(distOneKm, "one kilometre")

        let distImperial = PhraseComposer.spokenDistance(meters: 1609.344 * 3.2, unit: .imperial)
        XCTAssertEqual(distImperial, "three point two miles")
    }

    func testPhraseComposerNeverRepeatsSameTemplateBackToBackAndEncouragesOccasionally() {
        var composer = PhraseComposer()
        var previousIndex: Int?
        var encouragementCount = 0

        for i in 1...6 {
            let cue = composer.composeSplit(
                splitIndex: i,
                splitPaceSecondsPerMeter: 0.305,
                splitSpeedMPS: 3.28,
                totalDistanceMeters: Double(i) * 1000.0,
                totalMovingTime: Double(i) * 305.0,
                type: .run,
                unit: .metric
            )
            if let prev = previousIndex {
                XCTAssertNotEqual(cue.templateIndex, prev, "Split cue repeated template index consecutively")
            }
            previousIndex = cue.templateIndex
            if cue.segments.count > 2 && (cue.fullText.contains("rhythm") || cue.fullText.contains("effort") || cue.fullText.contains("great")) {
                encouragementCount += 1
            }
        }

        XCTAssertEqual(encouragementCount, 2, "Encouragement should occur occasionally (every 3rd split), not constantly")
    }

    func testVoiceRankerOrdersPremiumOverEnhancedOverDefaultAndFallsBackWhenMissing() {
        let voices = [
            VoiceDescriptor(identifier: "def-us", name: "Samantha", languageCode: "en-US", quality: .defaultQuality),
            VoiceDescriptor(identifier: "enh-gb", name: "Daniel", languageCode: "en-GB", quality: .enhanced),
            VoiceDescriptor(identifier: "prem-us", name: "Zoe", languageCode: "en-US", quality: .premium),
            VoiceDescriptor(identifier: "prem-fr", name: "Amelie", languageCode: "fr-FR", quality: .premium)
        ]

        let ranked = VoiceRanker.rankVoices(voices, preferredLocaleIdentifier: "en_US")
        XCTAssertEqual(ranked.map(\.identifier), ["prem-us", "enh-gb", "def-us"])

        let resolvedExisting = VoiceRanker.resolveVoice(savedIdentifier: "enh-gb", rankedVoices: ranked)
        XCTAssertEqual(resolvedExisting.selected?.identifier, "enh-gb")
        XCTAssertFalse(resolvedExisting.didFallbackFromMissingSaved)

        let resolvedMissing = VoiceRanker.resolveVoice(savedIdentifier: "deleted.ios.upgrade.voice", rankedVoices: ranked)
        XCTAssertEqual(resolvedMissing.selected?.identifier, "prem-us")
        XCTAssertTrue(resolvedMissing.didFallbackFromMissingSaved)
    }
}
