import Foundation
import ReferenceEmu
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// ParityProbe — headless measurement harness.
// Edit the "Current experiment" block per experiment; commit the findings, not the probe churn.
//
// Reusable helpers:
//   ram(_ a:) / vdpReg(_ r:) / wX,wY(_ slot:) — read ROM state
//   cd() -> scroll countdown (0xC020:0xC021, starts 907 for Galaxy, −1/frame)
//   score() -> BCD hundreds byte at 0xC031
//   playerAlive() -> is entity slot 0 the player?
//   dodge()/idleBot() -> RefButtons bots (survive + fire)
//   census(label:bot:) -> a full-stage spawn/kill/score log (deterministic; two bots agree)
//   dumpPNG(name:) -> write the current framebuffer to scratchpad/<name>.png
//
// Boot (title → gameplay): run([], 300); run(.fire, 5); run([], 8)

let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else { fputs("no rom\n", stderr); exit(1) }
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("load failed\n", stderr); exit(1) }

let SCRATCH = "/private/tmp/claude-501/-Users-ptysell-Code-astro-warrior--claude-worktrees-pickup-instructions-93133d/7d20f6fd-25ba-481f-bdc4-588cf58cb9ca/scratchpad"

@MainActor func step(_ b: RefButtons) { core.step(buttons: b, pause: false) }
@MainActor func run(_ b: RefButtons, _ n: Int) { for _ in 0..<n { step(b) } }
@MainActor func ram(_ a: Int) -> Int { Int(core.readRAM(a)) }
@MainActor func vdpReg(_ r: Int) -> Int { Int(core.readVDPReg(r)) }
@MainActor func wX(_ s: Int) -> Double { Double(ram(s + 0x0A) | (ram(s + 0x0B) << 8)) / 256.0 }
@MainActor func wY(_ s: Int) -> Double { Double(ram(s + 0x08) | (ram(s + 0x09) << 8)) / 256.0 }
@MainActor func cd() -> Int { ram(0xC020) | (ram(0xC021) << 8) }
@MainActor func score() -> Int { ram(0xC031) }
@MainActor func playerAlive() -> Bool { ram(0xC600) == 1 }
@MainActor func structHex(_ s: Int) -> String {
    (0..<0x20).map { String(format: "%02X", ram(s + $0)) }.joined(separator: " ")
}
let slots = Array(stride(from: 0xC600, to: 0xD000, by: 0x40))
func isFX(_ t: Int) -> Bool { t == 11 || t == 12 || t == 19 }
func isEnemy(_ t: Int) -> Bool { t != 0 && t != 1 && t != 2 && t != 18 && !isFX(t) }

@MainActor func dodge() -> RefButtons {
    let px = wX(0xC600), py = wY(0xC600)
    var threatX: Double? = nil, best = 1e9
    for s in slots {
        let t = ram(s); if t == 0 || t == 1 || t == 2 || t == 18 || isFX(t) { continue }
        let ex = wX(s), ey = wY(s), dy = py - ey
        if dy > -24, dy < 90 { let d = abs(ex - px) + dy * 0.25; if d < best { best = d; threatX = ex } }
    }
    var b: RefButtons = [.fire]
    if let tx = threatX { b.insert(tx > px ? .left : .right) }
    if py < 150 { b.insert(.down) } else if py > 176 { b.insert(.up) }
    if px < 40 { b.remove(.left); b.insert(.right) }
    if px > 216 { b.remove(.right); b.insert(.left) }
    return b
}

// Hold near centre, fire, never dodge — the worst-case survivor (for determinism tests).
@MainActor func idleBot() -> RefButtons {
    let px = wX(0xC600)
    var b: RefButtons = [.fire]
    if px < 120 { b.insert(.right) } else if px > 136 { b.insert(.left) }
    return b
}

@MainActor func dumpPNG(_ name: String) {
    guard let img = core.frame else { print("no frame for \(name)"); return }
    let url = URL(fileURLWithPath: "\(SCRATCH)/\(name).png") as CFURL
    guard let dst = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dst, img, nil)
    CGImageDestinationFinalize(dst)
}

// One full-stage census pass. Logs SPAWN/KILL/SCORE keyed by scroll countdown. The Galaxy
// schedule is scroll-scripted & deterministic — DODGE and IDLE bots produce identical spawns.
@MainActor func census(label: String, bot: () -> RefButtons) -> [String] {
    core.reset()
    run([], 300); run(.fire, 5); run([], 8)
    var lines: [String] = ["=== CENSUS \(label) ==="]
    var lastType = [Int](repeating: 0, count: slots.count)
    var pending = [Int: (left: Int, cd: Int)]()
    var lastScore = score()
    var maxCd = cd()
    var frame = 0
    while frame < 1000 {
        step(bot()); frame += 1
        let c = cd(); maxCd = max(maxCd, c)
        for (i, p) in pending {
            if p.left <= 0 { let s = slots[i]; lines.append("  POS slot=\(i) cd=\(p.cd) x=\(Int(wX(s))) y=\(Int(wY(s)))"); pending[i] = nil }
            else { pending[i] = (p.left - 1, p.cd) }
        }
        for (i, s) in slots.enumerated() {
            let t = ram(s), prev = lastType[i]
            if t != prev {
                if isEnemy(t) && !isEnemy(prev) { lines.append("SPAWN cd=\(c) slot=\(i) type=\(t)"); pending[i] = (3, c) }
                else if isEnemy(prev) && !isEnemy(t), t == 19 || t == 11 || t == 12 { lines.append("KILL cd=\(c) slot=\(i) type=\(prev)") }
                lastType[i] = t
            }
        }
        let sc = score(); if sc != lastScore { lines.append("SCORE cd=\(c) delta=\(sc-lastScore)"); lastScore = sc }
        if c == 0 { break }
    }
    lines.append("maxCd=\(maxCd) endFrame=\(frame) endScore=\(score())")
    return lines
}

// ── Current experiment: verify the Galaxy spawn schedule is deterministic ──
// (See docs/parity-findings.md §3 for the extracted schedule this confirms.)
let a = census(label: "DODGE") { dodge() }
let b = census(label: "IDLE")  { idleBot() }
print((a + [""] + b).joined(separator: "\n"))
