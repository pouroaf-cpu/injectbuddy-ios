import Foundation
import SwiftUI

// ─── CyclePlotterViewModel ───────────────────────────────────────────────────
// Owns the plotter's editable lines + cycle length and derives the plotted series
// by porting the app.js curve-builder: totalDays = cycleDays + maxWashout,
// step = max(minHalfLife<0.1 ? 0.02 : 0.25, totalDays/800), labels 0…totalDays,
// per-line data = pkTotalLevel, UNSCALED.
//
// ─── T-42: there is no factor here, and there cannot be one ─────────────────
//
// This used to read `pkTotalLevel × (allTesto ? CalculatorEngine.testoNgdlFactor
// : 1)`, with 13.5 as the factor, and `CyclePlotterScreen` titled the result
// `Estimated level (ng/dL)`. On the shipped default — 100 mg/week Test E, 12
// weeks — the model peaks at 118.56 and the scaled curve peaked at **1,600.5**,
// which is the units AND the range of a real serum testosterone result. (Both
// figures are computed from this model, not estimated;
// `PlotterNoNgdlFactorTests.test_theDeletedFactorLandedTheCurveInLabRange`
// asserts the pair so the claim fails rather than ages.) A number labelled
// ng/dL invites comparison against bloodwork, and a user whose lab disagrees
// with the curve has been given a reason to change a dose.
//
// The live plotter publishes its own answer to this, and it names what a real
// conversion needs — `public/legacy/cycle-plotter/index.html:2297` on
// `feature/dosage-status-model`:
//
//   "Absolute serum concentrations (in ng/dL) require compound-specific
//    pharmacokinetic parameters including volume of distribution and
//    bioavailability that are not reliably available for all compounds."
//
// VOLUME OF DISTRIBUTION AND BIOAVAILABILITY, BOTH COMPOUND-SPECIFIC. iOS used
// 13.5 — ONE GLOBAL SCALAR. One scalar cannot encode a per-compound parameter,
// let alone two of them. The factor was gated on all-testosterone selections, so
// that single number stood in for the Vd AND the bioavailability of four
// different esters at once — enanthate, cypionate, propionate, undecanoate,
// half-lives 4.5 / 6.0 / 0.8 / 21.0 days — and NO SINGLE VALUE IS CORRECT FOR
// ALL FOUR. So the number was not merely approximate and not merely
// uncalibrated: it was STRUCTURALLY INCAPABLE OF BEING RIGHT, while wearing the
// units of a test the user can go and have taken, on a screen whose compound
// list runs to 27 rows.
//
// `spec/math-spec.md` §4.1 says the same thing in a sentence written for ports:
//
//   "This yields mg-equivalents of active drug, not ng/dL. … the chart is
//    labelled in mg and must never claim a lab number. A port must not add a
//    unit conversion here."
//
// `ng/dL` appears NOWHERE in `public/legacy/cycle-plotter/pk.js` — not an axis,
// not a label, not a computation (verified by grep). The web's own axis unit is
// the string `relative units` (`app.jsx:557`).
//
// The all-testosterone flag went with the factor. It existed only to choose
// between the fabricated units and the real ones, and there is now one answer
// for every selection.

/// One editable compound line on the plotter.
struct PlotterLine: Identifiable, Equatable {
    let id = UUID()
    var compoundId: String
    var dose: Double
    var freqDays: Double

    var compound: PlotterCompound {
        PlotterCompound.all.first { $0.id == compoundId } ?? PlotterCompound.all[0]
    }
}

/// A point on a plotted curve.
struct PlotterPoint: Identifiable, Equatable {
    let id = UUID()
    let day: Double
    let level: Double
}

/// A named series for the chart.
struct PlotterSeries: Identifiable, Equatable {
    let id: String
    let label: String
    let points: [PlotterPoint]
}

@MainActor
final class CyclePlotterViewModel: ObservableObject {
    @Published var lines: [PlotterLine] = [
        PlotterLine(compoundId: "test-e", dose: 100, freqDays: 7)
    ] { didSet { rebuild() } }

    @Published var cycleWeeks: Int = 12 { didSet { rebuild() } }

    @Published private(set) var series: [PlotterSeries] = []

    /// T-17 — opened ON something, or opened empty.
    ///
    /// The seed replaces the placeholder line rather than being appended to it. A
    /// user who tapped "See your levels over time" on a 140mg/week enanthate protocol
    /// and arrived at their compound PLUS an unrelated 100mg test-e line would be
    /// reading a chart of two protocols, one of which they never entered — on a
    /// screen whose entire output is a plasma level.
    ///
    /// `didSet` does NOT fire for an assignment inside `init`, which is why `rebuild()`
    /// is called explicitly here and why it must stay after the assignment.
    init(seed: PlotterSeed? = nil) {
        if let seed {
            lines = [PlotterLine(compoundId: seed.compoundId,
                                 dose: seed.dose,
                                 freqDays: seed.freqDays)]
        }
        rebuild()
    }

    func addLine() {
        lines.append(PlotterLine(compoundId: "test-e", dose: 100, freqDays: 7))
    }

    func remove(_ line: PlotterLine) {
        lines.removeAll { $0.id == line.id }
        if lines.isEmpty { addLine() }
    }

    private func rebuild() {
        let validLines = lines.filter { $0.dose > 0 && $0.dose.isFinite }
        guard !validLines.isEmpty else { series = []; return }

        let cDays = Double(cycleWeeks) * 7

        // maxWashout = max over lines of ceil(4.3 * halfLife)
        let maxWash = validLines.reduce(0.0) { acc, l in
            max(acc, (4.3 * l.compound.halfLife).rounded(.up))
        }
        let totalDays = cDays + maxWash

        let minHalfLife = validLines.reduce(Double.infinity) { min($0, $1.compound.halfLife) }
        let step = max(minHalfLife < 0.1 ? 0.02 : 0.25, totalDays / 800)

        // labels: 0 … totalDays inclusive
        var labels: [Double] = []
        var t = 0.0
        let upper = totalDays + step * 0.5
        while t <= upper {
            labels.append((t * 100).rounded() / 100)
            t += step
        }

        var built: [PlotterSeries] = []
        for line in validLines {
            let c = line.compound
            let entries = CalculatorEngine.pkBuildEntries(
                halfLife: c.halfLife, tmax: c.tmax, dose: line.dose,
                freqDays: line.freqDays, cycleDays: cDays)
            let points = labels.map { lt -> PlotterPoint in
                // NO FACTOR. The only transform between the model and the chart is
                // the 4-dp round below; anything MULTIPLICATIVE here is the T-42
                // defect returning. `PlotterNoNgdlFactorTests` asserts this series
                // against `pkTotalLevel` itself rather than against a recorded
                // curve, so a reintroduced scalar fails instead of being re-baselined.
                //
                // The 4-dp round is iOS's own and is left alone: `Math.round(… *
                // 10000)` appears in NEITHER `pk.js` NOR `app.js` (checked, not
                // assumed). It is a display quantisation, not a unit change, so it
                // is out of T-42's scope — recorded here rather than quietly
                // described as the web's.
                let lvl = CalculatorEngine.pkTotalLevel(t: lt, entries: entries)
                return PlotterPoint(day: lt, level: (lvl * 10000).rounded() / 10000)
            }
            built.append(PlotterSeries(
                id: line.id.uuidString,
                label: "\(c.label) \(CalculatorEngine.fmt(line.dose, 0))\(c.unit)",
                points: points))
        }
        series = built
    }
}
