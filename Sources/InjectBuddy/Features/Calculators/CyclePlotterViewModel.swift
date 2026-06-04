import Foundation
import SwiftUI

// ─── CyclePlotterViewModel ───────────────────────────────────────────────────
// Owns the plotter's editable lines + cycle length and derives the plotted series
// by porting the app.js curve-builder: totalDays = cycleDays + maxWashout,
// step = max(minHalfLife<0.1 ? 0.02 : 0.25, totalDays/800), labels 0…totalDays,
// per-line data = pkTotalLevel × (allTesto ? TESTO_NGDL_FACTOR : 1).

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
    @Published private(set) var allTesto: Bool = true

    init() { rebuild() }

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

        let allTestoFlag = validLines.allSatisfy { $0.compound.category == "Testosterone" }
        allTesto = allTestoFlag
        let factor = allTestoFlag ? CalculatorEngine.testoNgdlFactor : 1.0

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
                let lvl = CalculatorEngine.pkTotalLevel(t: lt, entries: entries) * factor
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
