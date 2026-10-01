import SwiftData
import SwiftUI

/// One question per page; the result is saved as a `QuestionnaireResult` after the last answer.
/// Present it in a sheet.
struct QuestionnaireView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var session: QuestionnaireSession
    @State private var hasStarted = false
    @State private var savedScore: Int?
    @State private var saveError: String?

    init(kind: QuestionnaireKind) {
        _session = State(initialValue: QuestionnaireSession(kind: kind))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let savedScore {
                        ResultCard(kind: session.kind, score: savedScore)
                    } else if !hasStarted {
                        intro
                    } else if let question = session.current {
                        page(question)
                            .id(question.id)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
            }
            .screenScaffold()
            .navigationTitle(session.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if savedScore == nil {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if savedScore != nil {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.vertical, 8)
            }
        }
        .interactiveDismissDisabled(hasStarted && savedScore == nil)
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            SoftIllustration(systemImage: session.kind.systemImage, size: 120)
                .frame(maxWidth: .infinity)
            Text(Questionnaires.intro(session.kind))
                .font(.rounded(.body))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your answers stay in your diary. This is not a diagnosis — discuss the result with your doctor.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard()
    }

    private func page(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Question \(question.id) of \(session.questions.count)")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                ProgressView(value: session.progress)
                    .tint(Theme.accent)
                Text(question.text)
                    .font(.rounded(.title3, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                ChoiceCard(
                    title: option.title,
                    systemImage: "circle.dashed",
                    isSelected: session.answers[session.index] == index
                ) {
                    choose(index)
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if savedScore != nil {
            EmptyView()
        } else if !hasStarted {
            PrimaryButton(title: "Start") {
                withAnimation(.smooth) { hasStarted = true }
            }
        } else if session.canGoBack {
            SecondaryButton(title: "Previous question") {
                withAnimation(.smooth) { session.goBack() }
            }
        }
    }

    private func choose(_ option: Int) {
        withAnimation(.smooth(duration: 0.3)) { session.answer(option) }
        guard session.isFinished, let result = session.makeResult() else { return }
        modelContext.insert(result)
        do {
            try modelContext.save()
            withAnimation(.smooth) { savedScore = result.score }
        } catch {
            modelContext.rollback()
            withAnimation(.smooth) { session.goBack() }
            saveError = error.localizedDescription
        }
    }
}

/// Score with its interpretation, shown after finishing and in the history.
struct ResultCard: View {
    let kind: QuestionnaireKind
    let score: Int

    var body: some View {
        let attention = Questionnaires.needsAttention(kind, score: score)
        VStack(alignment: .leading, spacing: 12) {
            Label("Saved to your diary", systemImage: "checkmark.circle.fill")
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.sageDeep)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(score)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("of \(Questionnaires.maxScore(kind))")
                    .font(.rounded(.title3))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(Questionnaires.headline(kind, score: score))
                .font(.rounded(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(Questionnaires.interpretation(kind, score: score))
                .font(.rounded(.body))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard(tint: attention ? Theme.intensityMild : Theme.sageSoft)
    }
}

#Preview("DLQI") {
    QuestionnaireView(kind: .dlqi)
        .previewSetup()
}
