import Foundation
import RepeatKit

// A tiny check harness — stands in for XCTest until Xcode's test frameworks
// are available, and doubles as a printable demo of the pipeline.
var failures = 0
@MainActor func check(_ label: String, _ condition: @autoclosure () -> Bool, _ detail: String = "") {
    if condition() {
        print("  PASS  \(label)")
    } else {
        failures += 1
        print("  FAIL  \(label)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

let (syllabus, clusters) = Fixtures.analyze()
let currentYear = 2025

// MARK: - Repeat detection

print("\nCLUSTERING")
let dns = clusters.first { $0.canonicalText.lowercased().contains("dns") }
check("three reworded DNS questions merge into one", dns?.occurrences == 3,
      "got \(dns?.occurrences ?? 0)")
check("merged DNS cluster records all three years", dns?.years == [2023, 2021, 2019],
      "got \(dns?.years ?? [])")

let handshake = clusters.first { $0.canonicalText.lowercased().contains("handshake") }
check("two reworded handshake questions merge", handshake?.occurrences == 2,
      "got \(handshake?.occurrences ?? 0)")

check("'Define subnetting' == 'What is subnetting?'",
      clusters.first { $0.canonicalText.lowercased().contains("subnetting") }?.occurrences == 2)

let distanceVector = clusters.first { $0.canonicalText.lowercased().contains("distance vector routing algorithm") }
let linkState = clusters.first { $0.canonicalText.lowercased().contains("link state") }
check("related-but-different questions stay separate",
      distanceVector != nil && linkState != nil && distanceVector?.id != linkState?.id)

// MARK: - Syllabus mapping

print("\nUNIT MAPPING")
let mappedFraction = Double(clusters.filter { $0.unitNumber != nil }.count) / Double(clusters.count)
check("over 80% of questions map onto a unit", mappedFraction > 0.8,
      String(format: "%.0f%%", mappedFraction * 100))
check("DNS lands in Unit 5", dns?.unitNumber == 5, "got \(dns?.unitNumber.map(String.init) ?? "nil")")
check("handshake lands in Unit 4", handshake?.unitNumber == 4, "got \(handshake?.unitNumber.map(String.init) ?? "nil")")

// MARK: - Ranking

print("\nRANKING")
let ranked = clusters.sorted { $0.score(currentYear: currentYear) > $1.score(currentYear: currentYear) }
check("the 3x-repeated question ranks first",
      ranked.first?.canonicalText.contains("DNS") == true,
      "got '\(ranked.first?.canonicalText ?? "-")'")

// MARK: - Paper generation

print("\nEND SEM PATTERN")
let endSem = ExamPattern.endSemester(unitCount: 5)
let paper = PaperGenerator(currentYear: currentYear).generate(from: clusters, pattern: endSem, syllabus: syllabus)
check("total is 100 marks", paper.totalMarks == 100, "got \(paper.totalMarks)")
check("duration is 180 minutes", paper.durationMinutes == 180)
check("Part A prints 10 slots", paper.sections[0].slots.count == 10)
check("Part A is worth 20", paper.sections[0].attemptableMarks == 20)
check("Part B prints 5 slots", paper.sections[1].slots.count == 5)
check("Part B is worth 80", paper.sections[1].attemptableMarks == 80)
check("every Part B slot has an (a) OR (b)",
      paper.sections[1].slots.allSatisfy { $0.alternatives.count == 2 })
check("slot numbering runs 1...15 continuously",
      paper.sections.flatMap { $0.slots.map(\.number) } == Array(1...15))

let printed = paper.sections.flatMap(\.slots).flatMap(\.alternatives)
    .filter { !$0.isPlaceholder }.map(\.text)
check("no question repeats within one paper", Set(printed).count == printed.count)

let partBUnits = paper.sections[1].slots.compactMap { $0.alternatives.first?.unitNumber }
check("Part B slot n leads with a Unit n question", partBUnits == [1, 2, 3, 4, 5],
      "got \(partBUnits)")

print("\nMST PATTERN")
let mst = ExamPattern.mst1(units: [1, 2])
let mstPaper = PaperGenerator(currentYear: currentYear).generate(from: clusters, pattern: mst, syllabus: syllabus)
check("MST-1 is 5x2 + (any 4 of 5)x5 = 30 marks", mstPaper.totalMarks == 30, "got \(mstPaper.totalMarks)")
check("duration is 90 minutes", mstPaper.durationMinutes == 90)
check("Part A prints 5 two-markers", mstPaper.sections[0].slots.count == 5)
check("Part A is worth 10", mstPaper.sections[0].attemptableMarks == 10)
check("Part B prints 5 questions to answer 4", mstPaper.sections[1].slots.count == 5,
      "got \(mstPaper.sections[1].slots.count)")
check("Part B is worth 20 (4 answered x 5)", mstPaper.sections[1].attemptableMarks == 20)
let mst2 = ExamPattern.mst2(units: [3, 4])
let mst2Units = PaperGenerator(currentYear: currentYear)
    .generate(from: clusters, pattern: mst2, syllabus: syllabus)
    .sections.flatMap(\.slots).flatMap(\.alternatives)
    .filter { !$0.isPlaceholder }.compactMap(\.unitNumber)
check("MST-2 stays inside units 3-4", mst2Units.allSatisfy { [3, 4].contains($0) }, "got \(mst2Units)")
let mstUnits = mstPaper.sections.flatMap(\.slots).flatMap(\.alternatives)
    .filter { !$0.isPlaceholder }.compactMap(\.unitNumber)
check("MST-1 stays inside units 1-2", mstUnits.allSatisfy { [1, 2].contains($0) }, "got \(mstUnits)")

print("\nPATTERN IS DATA, NOT CODE")
var custom = ExamPattern.endSemester(unitCount: 5)
custom.sections[0].slotCount = 6
custom.sections[0].marksPerQuestion = 5
custom.sections[1].slotCount = 3
custom.sections[1].choiceStyle = .answerAny(answer: 2, printed: 3)
check("edited pattern recomputes to 62 marks", custom.totalMarks == 62, "got \(custom.totalMarks)")
let customPaper = PaperGenerator(currentYear: currentYear).generate(from: clusters, pattern: custom, syllabus: syllabus)
check("edited section prints 6 slots", customPaper.sections[0].slots.count == 6)
check("answerAny prints single questions, not OR-pairs",
      customPaper.sections[1].slots.allSatisfy { $0.alternatives.count == 1 })

// MARK: - Output

print("\nSEMANTIC SEPARATION (IDF-weighted, on-device, no API)")
let idx = QuestionClusterer().similarityReport(Fixtures.questions())
let probes = [
    ("same, reworded", "Explain the working of DNS with a neat diagram", "Describe how DNS resolves a domain name"),
    ("same, reworded", "Explain TCP three way handshake connection establishment", "Describe the three way handshake used by TCP"),
    ("same, reworded", "Define subnetting", "What is subnetting?"),
    ("DIFFERENT topic", "Explain distance vector routing algorithm with example", "Explain link state routing and compare it with distance vector routing"),
    ("DIFFERENT topic", "Explain the working of DNS", "Explain CSMA CD protocol and ethernet frame format"),
]
for (kind, a, b) in probes {
    print(String(format: "  %.3f  %-16@ %@", idx.similarity(a, b), kind, String(a.prefix(44))))
}

print("\n" + String(repeating: "=", count: 66))
print(PaperTextRenderer().render(paper))
print(String(repeating: "=", count: 66))

print("\nMOST LIKELY QUESTIONS")
for cluster in ranked.prefix(8) {
    let unit = cluster.unitNumber.map { "U\($0)" } ?? "U?"
    let years = cluster.years.map(String.init).joined(separator: ", ")
    let head = cluster.canonicalText.prefix(52)
    print(String(format: "  %@  %dx  %-54@ [%@]", unit, cluster.occurrences, String(head), years))
}

print(failures == 0 ? "\nAll checks passed.\n" : "\n\(failures) check(s) failed.\n")
exit(failures == 0 ? 0 : 1)
