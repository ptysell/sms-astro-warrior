import Foundation
import ReferenceEmu
import GameSim

// ParityScore — the parity YARDSTICK.
//
// Turns "the side-by-side isn't close" from a feeling into a NUMBER. It drives the real
// ROM (SMS Plus core = ground truth) and our headless GameSim.World off ONE open-loop
// input tape, then scores them frame-for-frame on:
//   • player-position error   (px, over the window where both ships are alive)
//   • enemy-population curve   (ROM count vs sim count each frame)
//   • spawn timeline          (when each side first puts N enemies on the field)
//
// The tape is captured once from the ROM's own `dodge` survival bot, so it is a fixed,
// reproducible button stream — feeding the *same* stream to both cores is what makes the
// comparison fair (closed-loop bots would read different state and diverge trivially).
//
// This is a Track-B probe primitive (motion capture + divergence metric). Re-run it after
// any sim change; the headline DIVERGENCE number should go down. Deterministic.
//
//   cd AstroWarriorKit && swift run ParityScore
//   ASTRO_FRAMES=3000 swift run ParityScore     # longer window
//   ASTRO_ROM=/path/to.sms swift run ParityScore # explicit ROM

// ─────────────────────────────────────────── ROM discovery ───────────────────────────────
func findROM() -> String? {
    var candidates: [String] = []
    if let env = ProcessInfo.processInfo.environment["ASTRO_ROM"] { candidates.append(env) }
    // main.swift lives at <pkg>/Sources/ParityScore/main.swift
    let here = URL(fileURLWithPath: #filePath)
    let pkg = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    candidates.append(pkg.appendingPathComponent("Sources/ParityDebug/Resources/AstroWarrior.sms").path)
    candidates.append(pkg.deletingLastPathComponent().appendingPathComponent("docs/AstroWarrior.sms").path)
    candidates.append("Sources/ParityDebug/Resources/AstroWarrior.sms")
    candidates.append("/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms")
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
}

guard let romPath = findROM(), let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else {
    fputs("ParityScore: ROM not found. Set ASTRO_ROM=/path/to/AstroWarrior.sms\n", stderr); exit(1)
}
let N = Int(ProcessInfo.processInfo.environment["ASTRO_FRAMES"] ?? "") ?? 1500

// ─────────────────────────────────────────── ROM (ground truth) ──────────────────────────
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("ParityScore: ROM load failed\n", stderr); exit(1) }

let slots = Array(stride(from: 0xC600, to: 0xD000, by: 0x40))
@MainActor func ram(_ a: Int) -> Int { Int(core.readRAM(a)) }
@MainActor func word(_ a: Int) -> Double { Double(ram(a) | (ram(a + 1) << 8)) / 256.0 }
@MainActor func romPlayer() -> (x: Double, y: Double) { (word(0xC60A), word(0xC608)) } // screen px
@MainActor func romPlayerAlive() -> Bool { ram(0xC600) == 1 }
@MainActor func romWaveIdx() -> Int { ram(0xC211) }
func isFX(_ t: Int) -> Bool { t == 11 || t == 12 || t == 19 }
func isEnemy(_ t: Int) -> Bool { t != 0 && t != 1 && t != 2 && t != 18 && !isFX(t) }

// The ROM's own survival bot (kept in sync with ParityProbe's dodge()). Closed-loop on the
// ROM only — we RECORD the buttons it presses so we can replay them open-loop into the sim.
@MainActor func dodge() -> RefButtons {
    let px = word(0xC60A), py = word(0xC608)
    var threatX: Double? = nil, best = 1e9
    for s in slots {
        let t = ram(s); if !isEnemy(t) { continue }
        let ex = word(s + 0x0A), ey = word(s + 0x08), dy = py - ey
        if dy > -24, dy < 90 { let d = abs(ex - px) + dy * 0.25; if d < best { best = d; threatX = ex } }
    }
    var b: RefButtons = [.fire]
    if let tx = threatX { b.insert(tx > px ? .left : .right) }
    if py < 150 { b.insert(.down) } else if py > 176 { b.insert(.up) }
    if px < 40 { b.remove(.left); b.insert(.right) }
    if px > 216 { b.remove(.right); b.insert(.left) }
    return b
}

struct Frame {                       // one aligned frame of ground-truth ROM state
    let px, py: Double               // player, screen px (y down)
    let alive: Bool
    let waveIdx: Int
    let enemyCount: Int
    let enemyTypes: [Int]            // types present this frame (for the timeline)
}

@MainActor func captureROM() -> (tape: [RefButtons], frames: [Frame]) {
    core.reset()
    // Boot: title → gameplay (same sequence ParityProbe uses).
    for _ in 0..<300 { core.step(buttons: [], pause: false) }
    for _ in 0..<5   { core.step(buttons: [.fire], pause: false) }
    for _ in 0..<8   { core.step(buttons: [], pause: false) }
    var tape: [RefButtons] = [], frames: [Frame] = []
    for _ in 0..<N {
        let b = dodge()
        tape.append(b)
        core.step(buttons: b, pause: false)
        var count = 0, types: [Int] = []
        for s in slots { let t = ram(s); if isEnemy(t) { count += 1; types.append(t) } }
        let p = romPlayer()
        frames.append(Frame(px: p.x, py: p.y, alive: romPlayerAlive(),
                            waveIdx: romWaveIdx(), enemyCount: count, enemyTypes: types))
    }
    return (tape, frames)
}

// ─────────────────────────────────────────── SIM (our port) ──────────────────────────────
func intent(from b: RefButtons) -> Intent {
    var ax = 0.0, ay = 0.0
    if b.contains(.left)  { ax -= 1 };  if b.contains(.right) { ax += 1 }
    if b.contains(.up)    { ay += 1 };  if b.contains(.down)  { ay -= 1 }   // sim +y = up
    return Intent(moveAxis: Vec2(ax, ay), fire: b.contains(.fire))
}

struct SimFrame { let px, py: Double; let alive: Bool; let scrollY: Double; let enemyCount: Int }

@MainActor func runSim(tape: [RefButtons]) -> [SimFrame] {
    let world = World()
    world.step(Intent(fire: true))          // flip title → playing (analog of the ROM boot)
    var out: [SimFrame] = []
    for b in tape {
        world.step(intent(from: b))
        let enemies = world.entities.compactMap { $0 as? Enemy }
        // sim logical → screen px (y down), matching the ROM's coordinate frame
        out.append(SimFrame(px: world.player.position.x,
                            py: LOGICAL_HEIGHT - world.player.position.y,
                            alive: !world.player.isDead && world.mode != .gameOver,
                            scrollY: world.scrollY, enemyCount: enemies.count))
    }
    return out
}

// ─────────────────────────────────────────── run + score ─────────────────────────────────
let (tape, rom) = captureROM()
let sim = runSim(tape: tape)
let n = min(rom.count, sim.count)
// Skip boot transients: the ROM player entity's position words are 0 for the first frames
// after gameplay starts (entity not yet populated). WARMUP is excluded from every metric.
let WARMUP = min(60, n)

// —— Player-position error (only while BOTH ships alive AND the ROM player is on-field) ——
var perr: [Double] = []
for f in WARMUP..<n where rom[f].alive && sim[f].alive && rom[f].px > 1 {
    let dx = rom[f].px - sim[f].px, dy = rom[f].py - sim[f].py
    perr.append((dx * dx + dy * dy).squareRoot())
}
let meanPErr = perr.isEmpty ? Double.nan : perr.reduce(0, +) / Double(perr.count)
let maxPErr  = perr.max() ?? .nan
let firstRomDeath = rom.firstIndex { !$0.alive } ?? n
let firstSimDeath = sim.firstIndex { !$0.alive } ?? n

// —— Enemy population (measured over [WARMUP, n); timeline below uses absolute frames) ——
let romCounts = rom.prefix(n).map { $0.enemyCount }
let simCounts = sim.prefix(n).map { $0.enemyCount }
let measured = max(1, n - WARMUP)
let romMean = Double(romCounts[WARMUP..<n].reduce(0, +)) / Double(measured)
let simMean = Double(simCounts[WARMUP..<n].reduce(0, +)) / Double(measured)
let romPeak = romCounts.max() ?? 0, simPeak = simCounts.max() ?? 0
var countDiffSum = 0, framesSimEmptyRomNot = 0
for f in WARMUP..<n {
    countDiffSum += abs(romCounts[f] - simCounts[f])
    if simCounts[f] == 0 && romCounts[f] > 0 { framesSimEmptyRomNot += 1 }
}
let meanCountDiff = Double(countDiffSum) / Double(measured)

// —— Spawn timeline: first frame each side reaches k enemies on the field ——
func firstReach(_ counts: [Int], _ k: Int) -> Int? { counts.firstIndex { $0 >= k } }

func fmt(_ d: Double) -> String { d.isNaN ? "  n/a" : String(format: "%6.1f", d) }
func f0(_ i: Int) -> String { String(format: "%4d", i) }

print("""
╔══════════════════════════════════════════════════════════════════════╗
║  ParityScore — Galaxy stage, \(f0(n))-frame window (~\(n/60)s)          ║
║  ROM ground truth (dodge tape)  vs  GameSim.World (same tape)          ║
╚══════════════════════════════════════════════════════════════════════╝

PLAYER POSITION  (screen px, measured only while both ships alive)
    frames both-alive : \(f0(perr.count)) / \(f0(measured))  (after \(WARMUP)-frame warmup)
    mean error        : \(fmt(meanPErr)) px
    max  error        : \(fmt(maxPErr)) px
    first death       : ROM @\(f0(firstRomDeath))   SIM @\(f0(firstSimDeath))
    pos @f\(WARMUP)        : ROM (\(fmt(rom[WARMUP].px)),\(fmt(rom[WARMUP].py)))  SIM (\(fmt(sim[WARMUP].px)),\(fmt(sim[WARMUP].py)))

ENEMY POPULATION  (active enemies on field, per frame)
    mean count        : ROM \(fmt(romMean))   SIM \(fmt(simMean))
    peak count        : ROM \(f0(romPeak))     SIM \(f0(simPeak))
    mean |Δcount|     : \(fmt(meanCountDiff))  enemies/frame
    frames sim-empty  : \(f0(framesSimEmptyRomNot)) / \(f0(measured))  (ROM had enemies, sim had none)

SPAWN TIMELINE  (first frame the field holds ≥k enemies)
        k :   1    2    3    4    6    8
    ROM   : \((1...8).filter{[1,2,3,4,6,8].contains($0)}.map{ k in firstReach(romCounts,k).map(f0) ?? "  — " }.joined(separator: " "))
    SIM   : \((1...8).filter{[1,2,3,4,6,8].contains($0)}.map{ k in firstReach(simCounts,k).map(f0) ?? "  — " }.joined(separator: " "))
""")

// —— Population shape, sampled every ~N/24 frames (ROM vs SIM side by side) ——
let step = max(1, n / 24)
print("\nPOPULATION OVER TIME  (every \(step) frames)   ROM │ SIM   waveIdx")
for f in stride(from: 0, to: n, by: step) {
    let r = romCounts[f], s = simCounts[f]
    let bar = { (c: Int) in String(repeating: "█", count: min(c, 20)) }
    print(String(format: "  f%4d  %2d │ %2d  idx%2d  %@ · %@",
                 f, r, s, rom[f].waveIdx, bar(r), bar(s)))
}

// —— Headline composite (v1): lower is closer. Documented so "reduce the number" has a target.
let headline = (meanPErr.isNaN ? 0 : meanPErr) + 6 * meanCountDiff
print(String(format: "\nDIVERGENCE (v1 = meanPlayerErr + 6·mean|Δcount|) = %.1f   ← drive this down\n", headline))
