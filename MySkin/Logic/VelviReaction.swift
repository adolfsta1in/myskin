import Foundation

/// What Velvi does at a given moment: how it looks, what it plays, and an optional line.
struct VelviCue: Equatable {
    var mood: VelviMood
    var prop: VelviProp?
    var motion: VelviMotion = .hop
    var line: VelviLine?
}

/// How big Velvi is on an onboarding step.
enum VelviPresence: Equatable {
    /// Large, the centre of the screen (welcome, plan).
    case hero
    /// Small companion above the step's title.
    case companion
}

/// Velvi's lines. Stable cases so tests compare meaning, not wording.
/// Lines never advise on treatment and never celebrate symptoms.
enum VelviLine: CaseIterable, Equatable {
    case checkInLogged
    case checkInSaved
    case checkInTough

    var text: String {
        switch self {
        case .checkInLogged: String(localized: "Logged. See you tomorrow.")
        case .checkInSaved: String(localized: "Saved. Thanks for checking in.")
        case .checkInTough: String(localized: "That sounds tough. It's in your diary.")
        }
    }
}

/// Picks Velvi's mood and reaction for each moment. Pure rules, so the tone can be tested:
/// on a hard day (Flare, strong itch, a result worth discussing) Velvi is caring, never celebrating.
enum VelviReaction {
    /// Itch from which a check-in counts as a hard day.
    static let toughItch = 7
    /// Itch up to which a check-in counts as an easy day.
    static let easyItch = 3

    static func afterCheckIn(itch: Int, mode: AppMode) -> VelviCue {
        if mode == .flare || itch >= toughItch {
            VelviCue(mood: .caring, motion: .nod, line: .checkInTough)
        } else if itch <= easyItch {
            VelviCue(mood: .joyful, motion: .hop, line: .checkInLogged)
        } else {
            VelviCue(mood: .happy, motion: .nod, line: .checkInSaved)
        }
    }

    /// The small Velvi next to the greeting on Today.
    static func greeting(mode: AppMode, hasCheckedInToday: Bool, hour: Int) -> VelviCue {
        if mode == .flare { return VelviCue(mood: .caring, motion: .nod) }
        if hour < 5 || hour >= 22 { return VelviCue(mood: .sleepy, motion: .nod) }
        return VelviCue(mood: hasCheckedInToday ? .happy : .curious, motion: .wave)
    }

    static func questionnaireResult(needsAttention: Bool) -> VelviCue {
        needsAttention ? VelviCue(mood: .caring, motion: .nod) : VelviCue(mood: .happy, motion: .nod)
    }

    /// «How is your skin right now?» — 0 almost clear … 1 severe flare. Never judges, only sympathises.
    static func skinNow(_ level: Double) -> VelviMood {
        level >= 0.5 ? .caring : .happy
    }

    /// While the itch slider moves on the first check-in: sympathy from a strong itch on, never joy.
    static func firstCheckIn(itch: Int) -> VelviMood {
        itch >= toughItch ? .caring : .happy
    }

    /// Velvi on each onboarding step; `nil` hides it where the step needs the whole screen.
    static func onboarding(_ step: OnboardingStep) -> (cue: VelviCue, presence: VelviPresence)? {
        switch step {
        case .welcome: (VelviCue(mood: .happy, prop: .report, motion: .wave), .hero)
        case .disclaimer: (VelviCue(mood: .calm, motion: .nod), .companion)
        case .aboutYou, .psoriasisProfile, .joints: (VelviCue(mood: .curious), .companion)
        case .skinNow: (VelviCue(mood: skinNow(0.35)), .companion)
        case .goals: (VelviCue(mood: .happy), .companion)
        case .insight: (VelviCue(mood: .thinking), .companion)
        case .bodyMap, .treatments: nil
        case .firstCheckIn: (VelviCue(mood: firstCheckIn(itch: 0)), .companion)
        case .notifications: (VelviCue(mood: .happy, prop: .bell), .companion)
        case .privacy: (VelviCue(mood: .calm, prop: .lock), .companion)
        case .plan: (VelviCue(mood: .proud, prop: .report), .hero)
        }
    }
}
