import Foundation

// MARK: - Input

/// Value copy of one check-in for the pattern engine, plus two facts filled by `PatternInput.days`.
nonisolated struct PatternDay: Hashable, Sendable {
    var day: Date
    var itch: Int
    var sleep: Int? = nil
    var mood: Int? = nil
    var triggers: [Trigger] = []
    var customTags: [String] = []
    /// Nil means food wasn't logged that day (unknown, not «none»).
    var foods: [Food]? = nil
    var customFoods: [String] = []
    var newSpots = false
    var humidity: Double? = nil
    var uvIndex: Double? = nil
    var temperature: Double? = nil
    /// Any `FlareDetector` signal that day. Only used to describe findings.
    var hasFlareSignal = false
    /// A planned dose that day wasn't marked done. Nil when unknown (see `PatternInput`).
    var missedDose: Bool? = nil

    /// Food is known when the user logged it, including «None of these» or only own foods.
    var isFoodLogged: Bool { foods != nil || !customFoods.isEmpty }
}

extension DailyCheckIn {
    var patternDay: PatternDay {
        PatternDay(
            day: day, itch: itch, sleep: sleep, mood: mood, triggers: triggers, customTags: customTags,
            foods: foodIDs.map { $0.compactMap(Food.init(rawValue:)) }, customFoods: customFoods,
            newSpots: newSpots, humidity: humidity, uvIndex: uvIndex, temperature: temperature
        )
    }
}

/// A treatment's schedule with its dose marks, for the «missed doses» factor.
struct PatternTreatment {
    let schedule: DoseSchedule
    let logs: [LoggedDose]
}

/// Fills the facts that need other models (flare signals, missed doses). Runs on the main actor;
/// the result goes to `Patterns.report`, which can run anywhere.
enum PatternInput {
    /// A day counts as known for missed doses only if the treatment has a mark this close to it:
    /// many people don't mark doses, and an unmarked dose is then not a missed one.
    static let markedNearbyDays = 3

    static func days(
        checkIns: [PatternDay],
        zones: [DatedZoneScore] = [],
        treatments: [PatternTreatment] = [],
        asOf now: Date,
        calendar: Calendar = .current
    ) -> [PatternDay] {
        let samples = checkIns.map { CheckInSample(day: $0.day, itch: $0.itch, newSpots: $0.newSpots) }
        let markedDays: [Set<Date>] = treatments.map { treatment in
            Set(treatment.logs.compactMap { $0.scheduledAt.map { calendar.startOfDay(for: $0) } })
        }
        return checkIns.map { checkIn in
            var result = checkIn
            let day = calendar.startOfDay(for: checkIn.day)
            result.hasFlareSignal = !FlareDetector.signals(on: day, checkIns: samples, zones: zones, calendar: calendar).isEmpty
            result.missedDose = missedDose(on: day, treatments: treatments, markedDays: markedDays, asOf: now, calendar: calendar)
            return result
        }
    }

    private static func missedDose(
        on day: Date,
        treatments: [PatternTreatment],
        markedDays: [Set<Date>],
        asOf now: Date,
        calendar: Calendar
    ) -> Bool? {
        var anyPlanned = false
        var anyKnown = false
        for (index, treatment) in treatments.enumerated() {
            let doses = DoseScheduler.doses(on: day, schedule: treatment.schedule, logs: treatment.logs, calendar: calendar)
                .filter { $0.scheduledAt <= now }
            guard !doses.isEmpty else { continue }
            anyPlanned = true
            let isMarking = (-markedNearbyDays...markedNearbyDays).contains { offset in
                calendar.date(byAdding: .day, value: offset, to: day).map { markedDays[index].contains($0) } ?? false
            }
            guard isMarking else { continue }
            anyKnown = true
            if doses.contains(where: { $0.status != .done }) { return true }
        }
        if !anyPlanned { return false }
        return anyKnown ? false : nil
    }
}

// MARK: - Factors

/// Something logged in the diary that may go with itch. Custom tags and foods are lowercased,
/// so «Eggs» and «eggs» are one factor.
nonisolated enum PatternFactor: Hashable, Sendable {
    case trigger(Trigger)
    case food(Food)
    case customTag(String)
    case customFood(String)
    case dryAir, humidAir, highUV, cold
    case poorSleep, lowMood
    case missedDoses

    /// Stable id, e.g. `trigger.stress`, `food.dairy`, `tag.long flight`.
    var id: String {
        switch self {
        case .trigger(let trigger): "trigger.\(trigger.rawValue)"
        case .food(let food): "food.\(food.rawValue)"
        case .customTag(let tag): "tag.\(tag)"
        case .customFood(let food): "customFood.\(food)"
        case .dryAir: "weather.dryAir"
        case .humidAir: "weather.humidAir"
        case .highUV: "weather.highUV"
        case .cold: "weather.cold"
        case .poorSleep: "poorSleep"
        case .lowMood: "lowMood"
        case .missedDoses: "missedDoses"
        }
    }

    /// Delay windows (days before the itch day) to test, by how the factor is thought to act.
    var lags: [ClosedRange<Int>] {
        switch self {
        case .trigger(.stress): Patterns.Threshold.stressLags
        case .trigger(.infection), .trigger(.skinInjury), .trigger(.newMedication), .trigger(.sunburn): Patterns.Threshold.delayedLags
        case .poorSleep, .lowMood: Patterns.Threshold.nextDayLags
        default: Patterns.Threshold.shortLags
        }
    }

    /// Sleep and mood follow itch as often as they precede it.
    var mayBeResultOfItch: Bool { self == .poorSleep || self == .lowMood }

    var isFood: Bool {
        switch self {
        case .food, .customFood: true
        default: false
        }
    }

    /// Whether the factor was there that day; nil when it's unknown.
    /// With a check-in, a trigger or tag that isn't picked counts as «not there»: the list is
    /// on the check-in, so not picking it is an answer. Food and weather can be missing.
    func isPresent(on day: PatternDay) -> Bool? {
        switch self {
        case .trigger(let trigger): day.triggers.contains(trigger)
        case .customTag(let tag): day.customTags.contains { Patterns.key($0) == tag }
        case .food(let food): day.isFoodLogged ? (day.foods ?? []).contains(food) : nil
        case .customFood(let food): day.isFoodLogged ? day.customFoods.contains { Patterns.key($0) == food } : nil
        case .dryAir: day.humidity.map { $0 < WeatherInfo.dryHumidity }
        case .humidAir: day.humidity.map { $0 > WeatherInfo.humidHumidity }
        case .highUV: day.uvIndex.map { $0 >= Patterns.Threshold.highUV }
        case .cold: day.temperature.map { $0 < Patterns.Threshold.coldTemperature }
        case .poorSleep: day.sleep.map { $0 <= Patterns.Threshold.poorSleep }
        case .lowMood: day.mood.map { $0 <= Patterns.Threshold.lowMood }
        case .missedDoses: day.missedDose
        }
    }
}

// MARK: - Output

nonisolated enum PatternDirection: String, Sendable {
    case worse, better
}

nonisolated enum PatternStrength: Int, Comparable, Sendable {
    case weak = 1, moderate, strong

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .weak: "Weak"
        case .moderate: "Moderate"
        case .strong: "Strong"
        }
    }
}

nonisolated struct PatternFinding: Hashable, Sendable, Identifiable {
    let factor: PatternFactor
    /// Display name, as the user typed it for own tags and foods.
    let title: String
    let direction: PatternDirection
    let strength: PatternStrength
    /// Days before the itch day, e.g. 2…3.
    let lag: ClosedRange<Int>
    /// Itch days with the factor in the window, and with it surely absent.
    let exposedDays: Int
    let unexposedDays: Int
    /// Separate runs of days with the factor.
    let episodes: Int
    let meanItchExposed: Double
    let meanItchUnexposed: Double
    let flareShareExposed: Double
    let flareShareUnexposed: Double
    let p: Double
    let q: Double
    /// Titles of factors logged on mostly the same days.
    let oftenLoggedWith: [String]
    /// The link fades (or can't be checked) on days without those factors.
    let hardToTellApart: Bool
    /// Found on less than `Threshold.confidentCheckIns` check-ins.
    let isEarly: Bool

    var id: String { factor.id }

    var summary: String {
        "Itch was \(direction == .worse ? "higher" : "lower") \(Patterns.lagPhrase(lag)) \(Patterns.subject(factor, title: title))"
    }

    var explanation: String {
        let one = Patterns.number(meanItchExposed)
        let other = Patterns.number(meanItchUnexposed)
        var text = "\(Patterns.lagPhrase(lag).capitalizingFirst) \(Patterns.subject(factor, title: title)), itch averaged \(one)/10, vs \(other)/10 on other days (\(episodes) times)."
        if factor.mayBeResultOfItch {
            text += " \(title) can also be a result of itch."
        }
        if !oftenLoggedWith.isEmpty {
            text += " Often logged together with \(oftenLoggedWith.formatted(.list(type: .and)))"
            text += hardToTellApart ? " — hard to tell which one goes with itch." : "."
        }
        text += " This is a pattern in your diary, not proof of cause. Discuss it with your doctor before changing your diet or treatment."
        return text
    }
}

/// A factor with enough data and no clear link.
nonisolated struct PatternUnclear: Hashable, Sendable, Identifiable {
    let factor: PatternFactor
    let title: String
    /// Itch days with the factor in the window.
    let exposedDays: Int

    var id: String { factor.id }
}

/// A factor seen in the diary, not often enough to test yet.
nonisolated struct PatternPending: Hashable, Sendable, Identifiable {
    let factor: PatternFactor
    let title: String
    let episodes: Int

    var id: String { factor.id }
}

nonisolated struct PatternReport: Hashable, Sendable {
    /// Strongest first.
    let findings: [PatternFinding]
    let unclear: [PatternUnclear]
    let notEnoughData: [PatternPending]
    let checkInDays: Int
    /// More check-ins needed before the first analysis; 0 once it runs.
    let checkInsUntilFirstAnalysis: Int

    static let empty = PatternReport(findings: [], unclear: [], notEnoughData: [], checkInDays: 0, checkInsUntilFirstAnalysis: Patterns.Threshold.minCheckIns)
}

// MARK: - Engine

/// Links between logged factors and itch in the user's own diary. Deterministic: no random,
/// no clock — the days are the whole input.
///
/// For each factor and delay window, every itch day is «exposed» (factor on a day in the window),
/// «unexposed» (window fully known, factor absent) or skipped. Itch is compared against the
/// person's own local baseline (a line through check-ins within ±10 days), which removes slow
/// changes such as a new treatment starting to work. The difference is tested with a t-test whose
/// sample size is shrunk for day-to-day autocorrelation, then Benjamini–Hochberg over all tested
/// pairs. This works from about three weeks of check-ins; findings before six weeks are «early».
nonisolated enum Patterns {
    enum Threshold {
        /// Check-ins before the first analysis (three weeks of daily logging).
        static let minCheckIns = 21
        /// Below this many check-ins a finding is «early» and at most moderate.
        static let confidentCheckIns = 42
        static let minExposedDays = 5
        static let minUnexposedDays = 5
        static let minEpisodes = 3
        static let minExposedShare = 0.1
        static let maxExposedShare = 0.9
        /// Baseline: check-ins within this many days on each side, at least `minBaselinePoints`.
        static let baselineDays = 10
        static let minBaselinePoints = 5
        static let maxQ = 0.2
        static let weak = (delta: 0.7, q: 0.2)
        static let moderate = (delta: 1.0, q: 0.1)
        static let strong = (delta: 1.5, q: 0.05, episodes: 5)
        /// Factors logged on the same days this often (Jaccard index) are flagged together.
        static let overlap = 0.6

        static let shortLags: [ClosedRange<Int>] = [0...1, 2...3]
        static let nextDayLags: [ClosedRange<Int>] = [1...1, 2...3]
        static let stressLags: [ClosedRange<Int>] = [1...3, 4...7]
        /// Skin injury ~10–14 days (Koebner), guttate after strep ~2–3 weeks.
        static let delayedLags: [ClosedRange<Int>] = [4...7, 8...14, 15...21]

        static let highUV = 6.0
        static let coldTemperature = 5.0
        static let poorSleep = 3
        static let lowMood = 2
    }

    static func report(days input: [PatternDay], calendar: Calendar = .current) -> PatternReport {
        let timeline = Timeline(input, calendar: calendar)
        let checkInDays = timeline.count
        guard checkInDays >= Threshold.minCheckIns else {
            return PatternReport(findings: [], unclear: [], notEnoughData: [], checkInDays: checkInDays,
                                 checkInsUntilFirstAnalysis: Threshold.minCheckIns - checkInDays)
        }
        let isEarly = checkInDays < Threshold.confidentCheckIns
        let names = displayNames(input)
        let factors = candidateFactors(input)
        let presence = Dictionary(uniqueKeysWithValues: factors.map { ($0, timeline.presence(of: $0)) })

        // Every factor × window that has enough data.
        var tested: [Comparison] = []
        var pending: [PatternFactor] = []
        for factor in factors {
            let comparisons = factor.lags.compactMap { compare(presence[factor] ?? [], lag: $0, timeline: timeline) }
            if comparisons.isEmpty { pending.append(factor) }
            tested += comparisons.map { Comparison(factor: factor, stats: $0) }
        }
        let qValues = benjaminiHochberg(tested.map(\.stats.p))

        // Best window per factor.
        var best: [PatternFactor: (Comparison, Double)] = [:]
        for (comparison, q) in zip(tested, qValues) {
            if let current = best[comparison.factor], current.1 < q || (current.1 == q && abs(current.0.stats.delta) >= abs(comparison.stats.delta)) { continue }
            best[comparison.factor] = (comparison, q)
        }

        var findings: [PatternFinding] = []
        var unclear: [PatternUnclear] = []
        for factor in factors {
            guard let (comparison, q) = best[factor] else { continue }
            let name = title(factor, names: names)
            let stats = comparison.stats
            guard var strength = strength(stats, q: q, isEarly: isEarly) else {
                unclear.append(PatternUnclear(factor: factor, title: name, exposedDays: stats.exposed))
                continue
            }
            if isEarly { strength = min(strength, .moderate) }
            let others = factors.filter { $0 != factor && jaccard(presence[factor] ?? [], presence[$0] ?? []) >= Threshold.overlap }
            let tangled = others.contains { other in
                guard let alone = compare(presence[factor] ?? [], lag: stats.lag, timeline: timeline, excluding: presence[other] ?? [], otherLag: stats.lag) else { return true }
                return alone.p > Threshold.maxQ || (alone.delta > 0) != (stats.delta > 0)
            }
            findings.append(PatternFinding(
                factor: factor, title: name, direction: stats.delta > 0 ? .worse : .better, strength: strength,
                lag: stats.lag, exposedDays: stats.exposed, unexposedDays: stats.unexposed, episodes: stats.episodes,
                meanItchExposed: stats.meanExposed, meanItchUnexposed: stats.meanUnexposed,
                flareShareExposed: stats.flareExposed, flareShareUnexposed: stats.flareUnexposed,
                p: stats.p, q: q, oftenLoggedWith: others.map { self.title($0, names: names) },
                hardToTellApart: tangled, isEarly: isEarly
            ))
        }
        findings.sort {
            if $0.strength != $1.strength { return $0.strength > $1.strength }
            let a = abs($0.meanItchExposed - $0.meanItchUnexposed), b = abs($1.meanItchExposed - $1.meanItchUnexposed)
            return a != b ? a > b : $0.id < $1.id
        }
        // A factor that often fell into a stronger finding's window can look linked by chance:
        // keep it only if the link holds on days clear of that stronger factor.
        var kept: [PatternFinding] = []
        for finding in findings {
            let explained = kept.contains { stronger in
                guard !finding.oftenLoggedWith.contains(stronger.title) else { return false }
                guard let alone = compare(presence[finding.factor] ?? [], lag: finding.lag, timeline: timeline,
                                          excluding: presence[stronger.factor] ?? [], otherLag: stronger.lag) else { return true }
                return alone.p > Threshold.maxQ || (alone.delta > 0) != (finding.direction == .worse)
            }
            if explained {
                unclear.append(PatternUnclear(factor: finding.factor, title: finding.title, exposedDays: finding.exposedDays))
            } else {
                kept.append(finding)
            }
        }
        findings = kept
        let notEnoughData = pending.map { factor in
            PatternPending(factor: factor, title: title(factor, names: names), episodes: episodes(presence[factor] ?? []))
        }
        return PatternReport(
            findings: findings, unclear: unclear.sorted { $0.title < $1.title },
            notEnoughData: notEnoughData.sorted { $0.title < $1.title },
            checkInDays: checkInDays, checkInsUntilFirstAnalysis: 0
        )
    }

    // MARK: Timeline

    /// Check-ins indexed by calendar day from the first one; days without a check-in are nil.
    struct Timeline {
        let days: [PatternDay?]

        init(_ input: [PatternDay], calendar: Calendar) {
            var byDay: [Date: PatternDay] = [:]
            for day in input { byDay[calendar.startOfDay(for: day.day)] = day }
            guard let first = byDay.keys.min(), let last = byDay.keys.max() else { days = []; return }
            let length = (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1
            days = (0..<length).map { offset in
                calendar.date(byAdding: .day, value: offset, to: first).flatMap { byDay[$0] }
            }
        }

        var count: Int { days.compactMap { $0 }.count }

        func presence(of factor: PatternFactor) -> [Bool?] {
            days.map { $0.flatMap(factor.isPresent(on:)) }
        }

        /// Itch minus a line fitted through check-ins within ±`baselineDays` (the day itself left out).
        /// A line, not a mean, so a steady trend is removed at the edges of the diary too.
        func residual(at index: Int) -> Double? {
            guard let itch = days[index]?.itch else { return nil }
            let range = max(0, index - Threshold.baselineDays)...min(days.count - 1, index + Threshold.baselineDays)
            let points = range.compactMap { i -> (Double, Double)? in
                guard i != index, let value = days[i]?.itch else { return nil }
                return (Double(i - index), Double(value))
            }
            guard points.count >= Threshold.minBaselinePoints else { return nil }
            let n = Double(points.count)
            let meanX = points.map(\.0).reduce(0, +) / n
            let meanY = points.map(\.1).reduce(0, +) / n
            let sxx = points.map { ($0.0 - meanX) * ($0.0 - meanX) }.reduce(0, +)
            let sxy = points.map { ($0.0 - meanX) * ($0.1 - meanY) }.reduce(0, +)
            let slope = sxx > 0 ? sxy / sxx : 0
            // Prediction at x = 0, the day itself.
            return Double(itch) - (meanY - slope * meanX)
        }
    }

    // MARK: Comparison

    struct Stats {
        let lag: ClosedRange<Int>
        let exposed: Int
        let unexposed: Int
        let episodes: Int
        let meanExposed: Double
        let meanUnexposed: Double
        let flareExposed: Double
        let flareUnexposed: Double
        /// Difference of mean residuals, exposed minus unexposed.
        let residualDelta: Double
        let p: Double

        /// Raw difference shown to the user.
        var delta: Double { meanExposed - meanUnexposed }
    }

    private struct Comparison {
        let factor: PatternFactor
        let stats: Stats
    }

    /// Compares itch days with the factor in the window to days with the window known and clear.
    /// `excluding`: also skip days with that other factor in its own window (`otherLag`).
    static func compare(
        _ presence: [Bool?],
        lag: ClosedRange<Int>,
        timeline: Timeline,
        excluding other: [Bool?] = [],
        otherLag: ClosedRange<Int> = 0...0
    ) -> Stats? {
        var exposure: [Bool] = []
        var residuals: [Double] = []
        var itch: [Double] = []
        var flare: [Bool] = []
        for index in timeline.days.indices {
            guard let day = timeline.days[index], let residual = timeline.residual(at: index) else { continue }
            let window = (index - lag.upperBound)...(index - lag.lowerBound)
            guard window.lowerBound >= 0 else { continue }
            if !other.isEmpty {
                let otherWindow = max(0, index - otherLag.upperBound)...max(0, index - otherLag.lowerBound)
                if otherWindow.contains(where: { other[$0] == true }) { continue }
            }
            let values = window.map { presence[$0] }
            let isExposed: Bool
            if values.contains(true) {
                isExposed = true
            } else if values.allSatisfy({ $0 == false }) {
                isExposed = false
            } else {
                continue
            }
            exposure.append(isExposed)
            residuals.append(residual)
            itch.append(Double(day.itch))
            flare.append(day.hasFlareSignal)
        }

        let exposedCount = exposure.filter { $0 }.count
        let unexposedCount = exposure.count - exposedCount
        let episodeCount = episodes(other.isEmpty ? presence : zip(presence, other).map { $1 == true ? nil : $0 })
        guard exposedCount >= Threshold.minExposedDays, unexposedCount >= Threshold.minUnexposedDays,
              episodeCount >= Threshold.minEpisodes else { return nil }
        let share = Double(exposedCount) / Double(exposure.count)
        guard share >= Threshold.minExposedShare, share <= Threshold.maxExposedShare else { return nil }

        func mean(_ values: [Double], _ pick: Bool) -> Double {
            let chosen = zip(values, exposure).filter { $0.1 == pick }.map(\.0)
            return chosen.reduce(0, +) / Double(chosen.count)
        }
        func flareShare(_ pick: Bool) -> Double {
            let chosen = zip(flare, exposure).filter { $0.1 == pick }
            return Double(chosen.filter(\.0).count) / Double(chosen.count)
        }
        let residualDelta = mean(residuals, true) - mean(residuals, false)
        return Stats(
            lag: lag, exposed: exposedCount, unexposed: unexposedCount, episodes: episodeCount,
            meanExposed: mean(itch, true), meanUnexposed: mean(itch, false),
            flareExposed: flareShare(true), flareUnexposed: flareShare(false),
            residualDelta: residualDelta,
            p: pValue(exposure: exposure, residuals: residuals, delta: residualDelta)
        )
    }

    /// Two-sided t-test of the residual difference, with the sample size shrunk for autocorrelation
    /// of both series (Bartlett / Dutilleul): n_eff = n / (1 + 2 Σ ρ_x(k) ρ_y(k)).
    /// Neighbouring days are alike, so treating them as independent would find patterns in noise.
    static func pValue(exposure: [Bool], residuals: [Double], delta: Double) -> Double {
        let n = residuals.count
        let x = exposure.map { $0 ? 1.0 : 0.0 }
        let maxLag = min(7, n / 4)
        var sum = 0.0
        if maxLag >= 1 {
            for k in 1...maxLag { sum += autocorrelation(x, k) * autocorrelation(residuals, k) }
        }
        let effective = min(Double(n), max(4, Double(n) / max(1 + 2 * sum, 0.5)))
        let exposedCount = Double(exposure.filter { $0 }.count)
        let unexposedCount = Double(n) - exposedCount
        let scale = effective / Double(n)
        let mean1 = zip(residuals, exposure).filter(\.1).map(\.0).reduce(0, +) / exposedCount
        let mean0 = zip(residuals, exposure).filter { !$0.1 }.map(\.0).reduce(0, +) / unexposedCount
        var squares = 0.0
        for (value, isExposed) in zip(residuals, exposure) {
            let d = value - (isExposed ? mean1 : mean0)
            squares += d * d
        }
        let df = effective - 2
        guard df >= 1 else { return 1 }
        let pooled = squares / Double(n - 2)
        let standardError = (pooled * (1 / (exposedCount * scale) + 1 / (unexposedCount * scale))).squareRoot()
        guard standardError > 0 else { return delta == 0 ? 1 : 0 }
        return studentTwoSidedP(t: delta / standardError, df: df)
    }

    static func autocorrelation(_ values: [Double], _ lag: Int) -> Double {
        guard values.count > lag + 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
        guard variance > 0 else { return 0 }
        var covariance = 0.0
        for i in lag..<values.count { covariance += (values[i] - mean) * (values[i - lag] - mean) }
        return covariance / variance
    }

    /// Adjusted p-values (q) in the input order.
    static func benjaminiHochberg(_ pValues: [Double]) -> [Double] {
        let m = Double(pValues.count)
        let order = pValues.indices.sorted { pValues[$0] < pValues[$1] }
        var q = Array(repeating: 1.0, count: pValues.count)
        var running = 1.0
        for (rank, index) in order.enumerated().reversed() {
            running = min(running, pValues[index] * m / Double(rank + 1))
            q[index] = min(running, 1)
        }
        return q
    }

    /// The smaller of the raw and the baseline-adjusted difference decides, so a slow trend
    /// can't make a link look stronger than it is. Both must point the same way.
    /// Early findings need the moderate level of certainty even to show as weak.
    private static func strength(_ stats: Stats, q: Double, isEarly: Bool) -> PatternStrength? {
        guard (stats.delta > 0) == (stats.residualDelta > 0) else { return nil }
        if isEarly && q > Threshold.moderate.q { return nil }
        let size = min(abs(stats.delta), abs(stats.residualDelta))
        if size >= Threshold.strong.delta, q <= Threshold.strong.q, stats.episodes >= Threshold.strong.episodes { return .strong }
        if size >= Threshold.moderate.delta, q <= Threshold.moderate.q { return .moderate }
        if size >= Threshold.weak.delta, q <= Threshold.weak.q { return .weak }
        return nil
    }

    // MARK: Helpers

    /// Runs of days with the factor; a day without it or without a check-in ends a run.
    static func episodes(_ presence: [Bool?]) -> Int {
        var count = 0
        var previous = false
        for value in presence {
            let isOn = value == true
            if isOn && !previous { count += 1 }
            previous = isOn
        }
        return count
    }

    static func jaccard(_ a: [Bool?], _ b: [Bool?]) -> Double {
        let pairs = zip(a, b)
        let both = pairs.filter { $0 == true && $1 == true }.count
        let either = pairs.filter { $0 == true || $1 == true }.count
        return either == 0 ? 0 : Double(both) / Double(either)
    }

    static func key(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Factors present at least once, in a stable order.
    private static func candidateFactors(_ days: [PatternDay]) -> [PatternFactor] {
        var factors: [PatternFactor] = Trigger.allCases.map { .trigger($0) } + Food.allCases.map { .food($0) }
        factors += Set(days.flatMap(\.customTags).map(key)).filter { !$0.isEmpty }.sorted().map { .customTag($0) }
        factors += Set(days.flatMap(\.customFoods).map(key)).filter { !$0.isEmpty }.sorted().map { .customFood($0) }
        factors += [.dryAir, .humidAir, .highUV, .cold, .poorSleep, .lowMood, .missedDoses]
        return factors.filter { factor in days.contains { factor.isPresent(on: $0) == true } }
    }

    /// First spelling the user typed for each own tag and food.
    private static func displayNames(_ days: [PatternDay]) -> [String: String] {
        var names: [String: String] = [:]
        for day in days.sorted(by: { $0.day < $1.day }) {
            for tag in day.customTags where names["tag.\(key(tag))"] == nil { names["tag.\(key(tag))"] = tag }
            for food in day.customFoods where names["customFood.\(key(food))"] == nil { names["customFood.\(key(food))"] = food }
        }
        return names
    }

    static func title(_ factor: PatternFactor, names: [String: String] = [:]) -> String {
        switch factor {
        case .trigger(let trigger): trigger.title
        case .food(let food): food.title
        case .customTag(let tag): names[factor.id] ?? tag
        case .customFood(let food): names[factor.id] ?? food
        case .dryAir: "Dry air"
        case .humidAir: "Humid air"
        case .highUV: "Strong sun (UV 6+)"
        case .cold: "Cold (below 5 °C)"
        case .poorSleep: "Poor sleep"
        case .lowMood: "Low mood"
        case .missedDoses: "Missed doses"
        }
    }

    /// «dairy», «poor sleep», «Long flight» — what follows «after».
    static func subject(_ factor: PatternFactor, title: String) -> String {
        switch factor {
        case .customTag, .customFood: "«\(title)»"
        case .missedDoses: "missed doses"
        default: title.lowercased()
        }
    }

    static func lagPhrase(_ lag: ClosedRange<Int>) -> String {
        switch (lag.lowerBound, lag.upperBound) {
        case (0, 0): "on days with"
        case (0, 1): "on the same or next day after"
        case (1, 1): "the day after"
        case let (low, high): "\(low)–\(high) days after"
        }
    }

    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    // MARK: Student t distribution

    /// Two-sided p for Student's t: I_{df/(df+t²)}(df/2, 1/2).
    static func studentTwoSidedP(t: Double, df: Double) -> Double {
        guard t.isFinite else { return 0 }
        return min(max(regularizedIncompleteBeta(x: df / (df + t * t), a: df / 2, b: 0.5), 0), 1)
    }

    /// Continued fraction (Numerical Recipes `betai`).
    static func regularizedIncompleteBeta(x: Double, a: Double, b: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        let front = exp(lgamma(a + b) - lgamma(a) - lgamma(b) + a * log(x) + b * log(1 - x))
        if x < (a + 1) / (a + b + 2) {
            return front * betaContinuedFraction(x: x, a: a, b: b) / a
        }
        return 1 - front * betaContinuedFraction(x: 1 - x, a: b, b: a) / b
    }

    private static func betaContinuedFraction(x: Double, a: Double, b: Double) -> Double {
        let tiny = 1e-30
        var c = 1.0
        var d = 1 - (a + b) * x / (a + 1)
        if abs(d) < tiny { d = tiny }
        d = 1 / d
        var h = d
        for m in 1...200 {
            let m = Double(m)
            var aa = m * (b - m) * x / ((a + 2 * m - 1) * (a + 2 * m))
            d = 1 + aa * d
            if abs(d) < tiny { d = tiny }
            c = 1 + aa / c
            if abs(c) < tiny { c = tiny }
            d = 1 / d
            h *= d * c
            aa = -(a + m) * (a + b + m) * x / ((a + 2 * m) * (a + 2 * m + 1))
            d = 1 + aa * d
            if abs(d) < tiny { d = tiny }
            c = 1 + aa / c
            if abs(c) < tiny { c = tiny }
            d = 1 / d
            let step = d * c
            h *= step
            if abs(step - 1) < 3e-14 { break }
        }
        return h
    }
}

private extension String {
    nonisolated var capitalizingFirst: String { prefix(1).uppercased() + String(dropFirst()) }
}
