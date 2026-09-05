# Repeat

An iPhone app that reads your previous-year question papers and tells you what is
actually likely to come up — then builds a practice paper in your exam's format.

## What it does

1. **Ingest** — reads question papers, including PDFs that are just photographs of
   the printed paper, using on-device OCR.
2. **Analyse** — maps every question onto a syllabus topic, then merges the ones
   that are the same question reworded. "Explain the working of DNS with a neat
   diagram" and "Describe how DNS resolves a domain name" become one question
   asked twice.
3. **Rank** — repeats count, recent years count more, assignments count less.
4. **Generate** — fills a configurable exam pattern with the highest-ranked
   questions, respecting unit coverage and mark weights.

## No API keys, no cost, nothing generative

Question matching is deterministic arithmetic over your own papers: IDF-weighted
term vectors with bigrams and an acronym boost, anchored on the syllabus topic
list so questions on different listed topics never merge. OCR transcribes what is
on the page. Nothing invents a question that was never asked.

Apple's `NLEmbedding` sentence vectors were measured against real exam text and
rejected — they scored two unrelated questions as more similar than two identical
ones.

## Layout

| Path | What it is |
| --- | --- |
| `RepeatKit/` | The engine, as a Swift package. Models, clustering, topic mapping, paper generation, OCR ingestion. |
| `RepeatApp/` | The SwiftUI iOS app. |
| `design/` | UI mockups. |

## Running the engine's checks

```bash
swift run RepeatDemo   # 29 assertions over the analysis pipeline, prints a generated paper
swift run IngestDemo   # OCR end to end on a synthesised image-only PDF
```

Both run from `RepeatKit/` and need no simulator.

## Exam patterns

Patterns are data, not code — every count, mark value and choice rule is editable
in the app.

- **End Sem** — 3 hours, 100 marks: Part A 10 x 2, Part B 5 x 16 with (a)/(b) internal choice
- **MST-1 / MST-2** — 90 minutes, 30 marks: Part A 5 x 2, Part B any 4 of 5 x 5

## Not built yet

Document-picker import UI, the review-extraction screen, PDF export, and
persistence. The OCR pipeline behind import is written and tested; it just has no
screen in front of it.
