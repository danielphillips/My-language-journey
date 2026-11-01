import Foundation
import Testing
@testable import MyRussianCore

@Suite("Milestone catalogue")
struct MilestoneCatalogTests {
    let a1 = MilestoneCatalog.milestones(for: .a1)

    @Test func a1RoadmapIsOrganisedIntoTheSevenCompetenciesInOrder() {
        #expect(Competency.allCases.map(\.title) == [
            "Cyrillic & Pronunciation", "Vocabulary", "Grammar", "Speaking", "Listening", "Reading", "Writing"
        ])
        var seen: [Competency] = []
        for milestone in a1 where seen.last != milestone.competency { seen.append(milestone.competency) }
        #expect(seen == Competency.allCases)
    }

    @Test func milestoneIdentifiersAreUniqueBecauseStatusesArePersistedByID() {
        #expect(Set(a1.map(\.id)).count == a1.count)
        #expect(a1.allSatisfy { $0.id.hasPrefix("a1.") })
    }

    @Test func includesConcreteUnderstandableMilestones() {
        let titles = a1.map(\.title)
        #expect(titles.contains("Recognise all 33 Cyrillic letters"))
        #expect(titles.contains("Understand grammatical gender"))
    }

    @Test func milestonesAreHonestlyLabelledAsAppAuthored() {
        #expect(a1.allSatisfy { $0.basis == .appAuthored })
    }

    @Test func competenciesMapToTheTORFLSubtestTheyPrepareFor() {
        #expect(Competency.vocabulary.torflSubtest == "Vocabulary & Grammar")
        #expect(Competency.grammar.torflSubtest == "Vocabulary & Grammar")
        #expect(Competency.listening.torflSubtest == "Listening")
        #expect(Competency.alphabet.torflSubtest == nil)
    }

    @Test func noRoadmapIsInventedForOtherLevelsYet() {
        for level in ProficiencyLevel.allCases where level != .a1 {
            #expect(MilestoneCatalog.milestones(for: level).isEmpty)
        }
    }
}

@Suite("Milestone status")
struct MilestoneStatusTests {
    @Test func fourStatusesInOrder() {
        #expect(MilestoneStatus.allCases.map(\.title) == ["Not Started", "Learning", "Comfortable", "Demonstrated"])
    }

    @Test func nextStatusCyclesForQuickTapToAdvance() {
        #expect(MilestoneStatus.notStarted.next == .learning)
        #expect(MilestoneStatus.learning.next == .comfortable)
        #expect(MilestoneStatus.comfortable.next == .demonstrated)
        #expect(MilestoneStatus.demonstrated.next == .notStarted)
    }
}

@Suite("Roadmap progress")
struct RoadmapProgressTests {
    let milestones = MilestoneCatalog.milestones(for: .a1)

    @Test func everythingStartsNotStarted() {
        let progress = RoadmapProgress(milestones: milestones, statuses: [:])
        #expect(progress.count(of: .notStarted) == milestones.count)
        #expect(progress.securedFraction == 0)
    }

    @Test func competencyProgressCountsComfortableAndDemonstratedAsSecured() throws {
        let alphabet = milestones.filter { $0.competency == .alphabet }
        let statuses = [
            alphabet[0].id: MilestoneStatus.demonstrated,
            alphabet[1].id: .comfortable,
            alphabet[2].id: .learning
        ]
        let progress = RoadmapProgress(milestones: milestones, statuses: statuses)
        let summary = try #require(progress.competencies.first { $0.competency == .alphabet })
        #expect(summary.total == alphabet.count)
        #expect(summary.count(of: .demonstrated) == 1)
        #expect(summary.count(of: .comfortable) == 1)
        #expect(summary.count(of: .learning) == 1)
        #expect(summary.securedFraction == 2.0 / Double(alphabet.count))
    }

    @Test func changingAStatusUpdatesProgress() {
        var statuses: [String: MilestoneStatus] = [:]
        let id = milestones[0].id
        statuses[id] = .learning
        #expect(RoadmapProgress(milestones: milestones, statuses: statuses).count(of: .learning) == 1)
        statuses[id] = .demonstrated
        let progress = RoadmapProgress(milestones: milestones, statuses: statuses)
        #expect(progress.count(of: .learning) == 0)
        #expect(progress.count(of: .demonstrated) == 1)
    }

    @Test func statusesForUnknownMilestonesAreIgnored() {
        let progress = RoadmapProgress(milestones: milestones, statuses: ["retired.id": .demonstrated])
        #expect(progress.count(of: .demonstrated) == 0)
    }

    @Test func upNextPrefersInProgressMilestonesThenRoadmapOrder() {
        let progress = RoadmapProgress(milestones: milestones, statuses: [
            milestones[0].id: .demonstrated,
            milestones[5].id: .learning
        ])
        let next = progress.upNext(limit: 3)
        #expect(next.map(\.id) == [milestones[5].id, milestones[1].id, milestones[2].id])
    }

    @Test func remainingCountsEverythingNotYetSecured() {
        let progress = RoadmapProgress(milestones: milestones, statuses: [
            milestones[0].id: .comfortable,
            milestones[1].id: .learning
        ])
        #expect(progress.remainingCount == milestones.count - 1)
    }
}
