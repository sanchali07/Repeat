import Foundation
import RepeatKit

/// Stand-in data until real PDFs are ingested: a Computer Networks syllabus and
/// six years of past questions containing deliberate repeats and rewordings.
enum Fixtures {

    static func syllabus() -> Syllabus {
        Syllabus(subject: "Computer Networks", code: "CS3591", units: [
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
    }

    static func questions() -> [Question] {
        [
            // DNS — asked three times, worded differently each time.
            Question(text: "Explain the working of DNS with a neat diagram. (16)", marks: 16, year: 2023, source: .endSem, documentName: "2023.pdf"),
            Question(text: "Describe how DNS resolves a domain name.", marks: 16, year: 2021, source: .endSem, documentName: "2021.pdf"),
            Question(text: "Discuss DNS and its working in detail", marks: 16, year: 2019, source: .endSem, documentName: "2019.pdf"),

            // Three way handshake — twice.
            Question(text: "Explain TCP three way handshake connection establishment.", marks: 16, year: 2023, source: .endSem, documentName: "2023.pdf"),
            Question(text: "Describe the three way handshake used by TCP.", marks: 16, year: 2020, source: .endSem, documentName: "2020.pdf"),

            Question(text: "Explain the OSI reference model layers in detail.", marks: 16, year: 2022, source: .endSem, documentName: "2022.pdf"),
            Question(text: "Explain sliding window flow control protocol with example.", marks: 16, year: 2022, source: .endSem, documentName: "2022.pdf"),
            Question(text: "Explain distance vector routing algorithm with example.", marks: 16, year: 2023, source: .endSem, documentName: "2023.pdf"),
            Question(text: "Explain link state routing and compare it with distance vector routing.", marks: 16, year: 2021, source: .endSem, documentName: "2021.pdf"),
            Question(text: "Explain CSMA CD protocol and ethernet frame format.", marks: 16, year: 2020, source: .endSem, documentName: "2020.pdf"),
            Question(text: "Explain congestion control mechanisms in TCP.", marks: 16, year: 2019, source: .endSem, documentName: "2019.pdf"),
            Question(text: "Explain HTTP request and response message format.", marks: 16, year: 2022, source: .endSem, documentName: "2022.pdf"),
            Question(text: "Explain guided transmission media in detail.", marks: 16, year: 2021, source: .endSem, documentName: "2021.pdf"),

            // 2-markers, including a repeat.
            Question(text: "Define subnetting.", marks: 2, year: 2023, source: .endSem, documentName: "2023.pdf"),
            Question(text: "What is subnetting?", marks: 2, year: 2021, source: .endSem, documentName: "2021.pdf"),
            Question(text: "What is meant by network topology?", marks: 2, year: 2023, source: .endSem, documentName: "2023.pdf"),
            Question(text: "State the purpose of ICMP.", marks: 2, year: 2022, source: .endSem, documentName: "2022.pdf"),
            Question(text: "Differentiate TCP and UDP.", marks: 2, year: 2023, source: .endSem, documentName: "2023.pdf"),
            Question(text: "What is hamming code used for?", marks: 2, year: 2022, source: .endSem, documentName: "2022.pdf"),
            Question(text: "Define SMTP.", marks: 2, year: 2021, source: .endSem, documentName: "2021.pdf"),
            Question(text: "What is web caching?", marks: 2, year: 2020, source: .endSem, documentName: "2020.pdf"),
            Question(text: "List the guided transmission media.", marks: 2, year: 2022, source: .endSem, documentName: "2022.pdf"),
            Question(text: "What is error detection?", marks: 2, year: 2023, source: .endSem, documentName: "2023.pdf"),
            Question(text: "Define IPv4 addressing classes.", marks: 2, year: 2020, source: .endSem, documentName: "2020.pdf"),
            Question(text: "What is FTP?", marks: 2, year: 2019, source: .endSem, documentName: "2019.pdf"),
        ]
    }

    /// The full analysis pipeline: map to units, then cluster repeats.
    static func analyze() -> (Syllabus, [QuestionCluster]) {
        let syllabus = syllabus()
        let mapped = TopicMapper().map(questions(), to: syllabus)
        let clusters = QuestionClusterer().cluster(mapped)
        return (syllabus, clusters)
    }
}
