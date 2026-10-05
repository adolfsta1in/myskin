import SwiftData
import SwiftUI

/// Past DLQI and PEST scores, newest first, with a way to take each questionnaire again.
struct QuestionnaireHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuestionnaireResult.date, order: .reverse) private var results: [QuestionnaireResult]
    @State private var taking: QuestionnaireKind?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(QuestionnaireKind.allCases) { kind in
                    section(kind, results: results.filter { $0.kind == kind })
                }
                Text("Scores are a self-check to discuss with your doctor, not a diagnosis.")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 8)
        }
        .screenScaffold()
        .navigationTitle("Questionnaires")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $taking) { kind in
            QuestionnaireView(kind: kind)
        }
    }

    private func section(_ kind: QuestionnaireKind, results: [QuestionnaireResult]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: kind.title, systemImage: kind.systemImage)
            if let latest = results.first {
                ResultSummary(kind: kind, score: latest.score, date: latest.date)
            } else {
                Text("Not taken yet.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            if results.count > 1 {
                Divider()
                ForEach(results.dropFirst()) { result in
                    HStack {
                        Text(result.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                        Spacer()
                        Text("\(result.score) · \(Questionnaires.headline(kind, score: result.score))")
                            .font(.rounded(.subheadline, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { delete(result) }
                    }
                }
            }
            Button(results.isEmpty ? "Take it now" : "Take it again", systemImage: "square.and.pencil") {
                taking = kind
            }
            .font(.rounded(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.accent)
        }
        .glassCard()
    }

    private func delete(_ result: QuestionnaireResult) {
        modelContext.delete(result)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}

/// Latest score of one questionnaire.
private struct ResultSummary: View {
    let kind: QuestionnaireKind
    let score: Int
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(score)")
                    .font(.rounded(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("of \(Questionnaires.maxScore(kind)) · \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            Label(Questionnaires.headline(kind, score: score),
                  systemImage: Questionnaires.needsAttention(kind, score: score) ? "exclamationmark.circle" : "checkmark.circle")
                .font(.rounded(.headline, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(Questionnaires.interpretation(kind, score: score))
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        QuestionnaireHistoryView()
    }
    .previewSetup()
}
