import Testing
@testable import MySkin

struct VelviReactionTests {
    private let celebrating: Set<VelviMood> = [.joyful, .proud]

    // MARK: - Check-in

    @Test(arguments: 0...10)
    func flareCheckInIsNeverCelebrated(itch: Int) {
        let cue = VelviReaction.afterCheckIn(itch: itch, mode: .flare)
        #expect(cue.mood == .caring)
        #expect(cue.line == .checkInTough)
    }

    @Test func toughItchThresholdIsSeven() {
        #expect(VelviReaction.toughItch == 7)
    }

    @Test(arguments: 7...10)
    func strongItchIsMetWithCare(itch: Int) {
        let cue = VelviReaction.afterCheckIn(itch: itch, mode: .calm)
        #expect(cue.mood == .caring)
        #expect(!celebrating.contains(cue.mood))
    }

    @Test func easyDayIsJoyful() {
        let cue = VelviReaction.afterCheckIn(itch: 2, mode: .calm)
        #expect(cue.mood == .joyful)
        #expect(cue.motion == .hop)
        #expect(cue.line == .checkInLogged)
    }

    @Test func middleDayIsQuietlyHappy() {
        let cue = VelviReaction.afterCheckIn(itch: 5, mode: .calm)
        #expect(cue.mood == .happy)
        #expect(cue.line == .checkInSaved)
    }

    // MARK: - Greeting

    @Test func flareGreetingIsCaringAtAnyHour() {
        for hour in 0..<24 {
            #expect(VelviReaction.greeting(mode: .flare, hasCheckedInToday: true, hour: hour).mood == .caring)
        }
    }

    @Test func greetingFollowsTheDay() {
        #expect(VelviReaction.greeting(mode: .calm, hasCheckedInToday: false, hour: 9).mood == .curious)
        #expect(VelviReaction.greeting(mode: .calm, hasCheckedInToday: true, hour: 9).mood == .happy)
        #expect(VelviReaction.greeting(mode: .calm, hasCheckedInToday: false, hour: 23).mood == .sleepy)
        #expect(VelviReaction.greeting(mode: .calm, hasCheckedInToday: true, hour: 3).mood == .sleepy)
    }

    // MARK: - Questionnaire and skin now

    @Test func resultWorthDiscussingIsCaring() {
        let cue = VelviReaction.questionnaireResult(needsAttention: true)
        #expect(cue.mood == .caring)
        #expect(!celebrating.contains(VelviReaction.questionnaireResult(needsAttention: false).mood))
    }

    @Test func worseSkinGetsSympathyNotJudgement() {
        #expect(VelviReaction.skinNow(0) == .happy)
        #expect(VelviReaction.skinNow(0.49) == .happy)
        #expect(VelviReaction.skinNow(0.5) == .caring)
        #expect(VelviReaction.skinNow(1) == .caring)
    }

    // MARK: - Onboarding

    @Test func everyOnboardingStepIsDecided() {
        for step in OnboardingStep.allCases {
            let cue = VelviReaction.onboarding(step)
            switch step {
            case .bodyMap, .treatments: #expect(cue == nil, "\(step) needs the whole screen")
            case .welcome, .plan: #expect(cue?.presence == .hero)
            default: #expect(cue?.presence == .companion)
            }
        }
    }

    @Test func disclaimerStaysCalm() {
        let cue = VelviReaction.onboarding(.disclaimer)?.cue
        #expect(cue?.mood == .calm)
        #expect(cue?.prop == nil)
    }

    @Test func linesAreNotEmpty() {
        for line in VelviLine.allCases {
            #expect(!line.text.isEmpty)
        }
    }
}
