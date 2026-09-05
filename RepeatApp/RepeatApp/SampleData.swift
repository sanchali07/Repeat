import Foundation

/// Opens the app in a realistic working state. These are real Computer Networks
/// questions run through the actual engine — the clustering, topic mapping and
/// ranking you see on screen are computed at launch, not hardcoded.
enum SampleData {

    static let syllabus = Syllabus(subject: "Computer Networks", code: "CS3591", units: [
        SyllabusUnit(number: 1, title: "Introduction and Physical Layer",
            topics: ["network topology", "OSI model", "TCP/IP protocol suite", "transmission media", "guided media"]),
        SyllabusUnit(number: 2, title: "Data Link Layer",
            topics: ["error detection", "error correction", "hamming code", "flow control", "sliding window", "CSMA CD", "ethernet"]),
        SyllabusUnit(number: 3, title: "Network Layer",
            topics: ["IPv4 addressing", "subnetting", "routing algorithms", "distance vector routing", "link state routing", "ICMP"]),
        SyllabusUnit(number: 4, title: "Transport Layer",
            topics: ["TCP", "UDP", "three way handshake", "congestion control", "flow control window"]),
        SyllabusUnit(number: 5, title: "Application Layer",
            topics: ["DNS", "HTTP", "SMTP", "FTP", "electronic mail", "web caching"]),
    ])

    static let rawQuestions: [Question] = [
        Question(text: "Explain the working of DNS with a neat diagram.", marks: 16, year: 2023, source: .endSem, documentName: "2023 End Sem.pdf"),
        Question(text: "Describe how DNS resolves a domain name.", marks: 16, year: 2021, source: .endSem, documentName: "2021 End Sem.pdf"),
        Question(text: "Discuss DNS and its working in detail.", marks: 16, year: 2019, source: .endSem, documentName: "2019 End Sem.pdf"),

        Question(text: "Explain TCP three way handshake connection establishment.", marks: 16, year: 2023, source: .endSem, documentName: "2023 End Sem.pdf"),
        Question(text: "Describe the three way handshake used by TCP.", marks: 16, year: 2020, source: .endSem, documentName: "2020 End Sem.pdf"),

        Question(text: "Explain the OSI reference model layers in detail.", marks: 16, year: 2022, source: .endSem, documentName: "2022 End Sem.pdf"),
        Question(text: "Explain sliding window flow control protocol with example.", marks: 16, year: 2022, source: .endSem, documentName: "2022 End Sem.pdf"),
        Question(text: "Explain sliding window protocol.", marks: 16, year: 2019, source: .endSem, documentName: "2019 End Sem.pdf"),
        Question(text: "Explain distance vector routing algorithm with example.", marks: 16, year: 2023, source: .endSem, documentName: "2023 End Sem.pdf"),
        Question(text: "Explain link state routing and compare it with distance vector routing.", marks: 16, year: 2021, source: .endSem, documentName: "2021 End Sem.pdf"),
        Question(text: "Explain CSMA CD protocol and ethernet frame format.", marks: 16, year: 2020, source: .endSem, documentName: "2020 End Sem.pdf"),
        Question(text: "Explain congestion control mechanisms in TCP.", marks: 16, year: 2019, source: .endSem, documentName: "2019 End Sem.pdf"),
        Question(text: "Explain HTTP request and response message format.", marks: 16, year: 2022, source: .endSem, documentName: "2022 End Sem.pdf"),
        Question(text: "Explain guided transmission media in detail.", marks: 16, year: 2021, source: .endSem, documentName: "2021 End Sem.pdf"),

        Question(text: "Define subnetting.", marks: 2, year: 2023, source: .endSem, documentName: "2023 End Sem.pdf"),
        Question(text: "What is subnetting?", marks: 2, year: 2021, source: .endSem, documentName: "2021 End Sem.pdf"),
        Question(text: "What is meant by network topology?", marks: 2, year: 2023, source: .endSem, documentName: "2023 End Sem.pdf"),
        Question(text: "State the purpose of ICMP.", marks: 2, year: 2022, source: .endSem, documentName: "2022 End Sem.pdf"),
        Question(text: "Differentiate TCP and UDP.", marks: 2, year: 2023, source: .endSem, documentName: "2023 End Sem.pdf"),
        Question(text: "What is hamming code used for?", marks: 2, year: 2022, source: .endSem, documentName: "2022 End Sem.pdf"),
        Question(text: "Define SMTP.", marks: 2, year: 2021, source: .endSem, documentName: "2021 End Sem.pdf"),
        Question(text: "What is web caching?", marks: 2, year: 2020, source: .endSem, documentName: "2020 End Sem.pdf"),
        Question(text: "List the guided transmission media.", marks: 2, year: 2022, source: .endSem, documentName: "2022 End Sem.pdf"),
        Question(text: "What is error detection?", marks: 2, year: 2023, source: .endSem, documentName: "2023 End Sem.pdf"),
        Question(text: "Define IPv4 addressing classes.", marks: 2, year: 2020, source: .endSem, documentName: "2020 End Sem.pdf"),
        Question(text: "What is FTP?", marks: 2, year: 2019, source: .endSem, documentName: "2019 End Sem.pdf"),
        Question(text: "Expand and define CSMA CD.", marks: 2, year: 2021, source: .endSem, documentName: "2021 End Sem.pdf"),
        Question(text: "What is congestion control?", marks: 2, year: 2022, source: .endSem, documentName: "2022 End Sem.pdf"),
    ]
}

/// The analysed state the whole UI reads from.
@MainActor
final class Library: ObservableObject {
    @Published private(set) var clusters: [QuestionCluster] = []
    @Published var pattern: ExamPattern = .endSemester(unitCount: 5)

    let syllabus = SampleData.syllabus
    private let currentYear = Calendar.current.component(.year, from: .now)

    init() { analyse() }

    private func analyse() {
        let mapped = TopicMapper().map(SampleData.rawQuestions, to: syllabus)
        clusters = QuestionClusterer().cluster(mapped)
            .sorted { $0.score(currentYear: currentYear) > $1.score(currentYear: currentYear) }
    }

    var paperCount: Int {
        Set(SampleData.rawQuestions.map(\.documentName)).count
    }

    /// Question count per unit, for the histogram on the subject card.
    func countsByUnit() -> [(unit: Int, count: Int, hottest: Int)] {
        syllabus.units.map { unit in
            let inUnit = clusters.filter { $0.unitNumber == unit.number }
            return (unit.number, inUnit.count, inUnit.map(\.occurrences).max() ?? 0)
        }
    }

    func generate() -> GeneratedPaper {
        PaperGenerator(currentYear: currentYear)
            .generate(from: clusters, pattern: pattern, syllabus: syllabus)
    }
}
