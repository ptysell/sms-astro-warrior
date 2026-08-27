import Foundation
import ReferenceEmu

// ParityProbe — headless measurement harness.
// Edit this file per experiment; commit the findings, not the probe state.
//
// Helpers:
//   ram(_ a: Int) -> Int          — read one work-RAM byte
//   wX/wY(_ slot: Int) -> Double  — read 8.8 fixed-point position from an entity slot
//   vdpReg(_ r: Int) -> Int       — read VDP register (0–15; reg 9 = vertical scroll)
//   dodge() -> RefButtons          — simple dodging bot input (fires + avoids enemies)
//
// Boot sequence (title → gameplay):
//   run([], 300); run(.fire, 5); run([], 8); run([], 60)

let romPath = "/Users/ptysell/Code/astro-warrior/docs/AstroWarrior.sms"
guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else { fputs("no rom\n", stderr); exit(1) }
let core = SMSPlusCore()
guard core.load(rom: data) else { fputs("load failed\n", stderr); exit(1) }

@MainActor func step(_ b: RefButtons) { core.step(buttons: b, pause: false) }
@MainActor func run(_ b: RefButtons, _ n: Int) { for _ in 0..<n { step(b) } }
@MainActor func ram(_ a: Int) -> Int { Int(core.readRAM(a)) }
@MainActor func vdpReg(_ r: Int) -> Int { Int(core.readVDPReg(r)) }
@MainActor func wX(_ s: Int) -> Double { Double(ram(s + 0x0A) | (ram(s + 0x0B) << 8)) / 256.0 }
@MainActor func wY(_ s: Int) -> Double { Double(ram(s + 0x08) | (ram(s + 0x09) << 8)) / 256.0 }
let slots = Array(stride(from: 0xC600, to: 0xD000, by: 0x40))
func isFX(_ t: Int) -> Bool { t == 11 || t == 12 || t == 19 }

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

// ── Current experiment: (none — edit and run) ──
print("ParityProbe ready. Edit main.swift with your experiment.")
